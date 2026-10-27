'use strict';
/**
 * skill-lint.js: las reglas de validación de skills y agentes, como librería.
 * El CLI scripts/validate-skills.js es un wrapper fino.
 *
 * Errores (bloquean CI):
 *   - SKILL.md existe en cada carpeta de skills/
 *   - frontmatter YAML válido con 'name' y 'description'
 *   - 'name' == nombre de la carpeta, kebab-case
 *   - solo claves conocidas en el nivel superior del frontmatter
 *   - description <= 1024 caracteres y con disparador ("Usar cuando/al/antes/...")
 *   - ningún subdirectorio vacío
 *   - agentes: frontmatter con 'name' == nombre de archivo y 'description'
 *
 * Avisos:
 *   - SKILL.md pasa de 500 líneas
 */

const fs   = require('fs');
const path = require('path');

const MAX_DESCRIPTION_LENGTH = 1024;
const MAX_SKILL_LINES = 500;

// Claves permitidas en el nivel superior de SKILL.md. `paths` y `disable-model-invocation`
// las usan las skills de stack y los comandos-skill; el resto es la especificación.
const SPEC_FRONTMATTER_KEYS = new Set([
  'name', 'description', 'license', 'compatibility', 'metadata', 'allowed-tools',
  'paths', 'disable-model-invocation', 'argument-hint',
]);

const KEBAB_CASE = /^[a-z0-9]+(-[a-z0-9]+)*$/;

// La description dice CUÁNDO usar la skill, no solo qué hace.

const DESCRIPTION_TRIGGER = /\b(usar|úsala|usala) (cuando|al|antes|después|despues|si|en|para)\b/i;

function stripFencedCodeBlocks(content) {
  const out = [];
  let open = null;
  for (const line of content.split(/\r?\n/)) {
    if (open) {
      const close = line.match(/^ {0,3}(`{3,}|~{3,})[ \t]*$/);
      if (close && close[1][0] === open.marker && close[1].length >= open.length) open = null;
      out.push('');
      continue;
    }
    const start = line.match(/^ {0,3}(`{3,}|~{3,})(.*)$/);
    if (start && !(start[1][0] === '`' && start[2].includes('`'))) {
      open = { marker: start[1][0], length: start[1].length };
      out.push('');
      continue;
    }
    out.push(line);
  }
  return out.join('\n');
}

const FM_RE = /^---[ \t]*\r?\n([\s\S]*?)\r?\n---[ \t]*\r?\n/;

function topLevelFrontmatterKeys(content) {
  const match = content.match(FM_RE);
  if (!match) return [];
  const keys = [];
  for (const line of match[1].split(/\r?\n/)) {
    const m = line.match(/^([A-Za-z0-9_-]+)\s*:/);
    if (m) keys.push(m[1]);
  }
  return keys;
}

/**
 * Parser mínimo de frontmatter: clave: valor por línea. Soporta `description: >-` seguido de
 * líneas indentadas (bloque plegado), que es lo que usan las skills largas.
 */
function parseFrontmatter(content) {
  const match = content.match(FM_RE);
  if (!match) return null;
  const result = {};
  const lines = match[1].split(/\r?\n/);
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (/^\s*#/.test(line)) continue;
    const m = line.match(/^([A-Za-z0-9_-]+)\s*:\s*(.*)$/);
    if (!m) continue;
    const key = m[1];
    let value = m[2].trim();
    if (/^[|>][-+]?$/.test(value)) {
      const block = [];
      while (i + 1 < lines.length && /^\s+\S/.test(lines[i + 1])) block.push(lines[++i].trim());
      value = value[0] === '>' ? block.join(' ') : block.join('\n');
    }
    result[key] = value.replace(/^['"]|['"]$/g, '');
  }
  return result;
}

/** Formas que un parser YAML estricto rechaza y el parser de arriba no. */
function frontmatterYamlErrors(content) {
  const match = content.match(FM_RE);
  if (!match) return [];
  const errors = [];
  const lines = match[1].split(/\r?\n/);
  lines.forEach((line, i) => {
    const lineNo = i + 2;
    if (!line.trim() || /^\s*#/.test(line)) return;
    if (/^[ ]*\t/.test(line)) { errors.push(`Frontmatter línea ${lineNo}: tab como indentación; YAML lo rechaza`); return; }
    if (/^\s+\S/.test(line)) return; // continuación de un bloque o lista: no se analiza
    const colonIdx = line.indexOf(':');
    if (colonIdx === -1) return;
    const value = line.slice(colonIdx + 1).trim();
    if (!value) return;
    const quote = value[0] === '"' || value[0] === "'" ? value[0] : null;
    if (quote) {
      if (value.length < 2 || !value.endsWith(quote)) errors.push(`Frontmatter línea ${lineNo}: comilla sin cerrar`);
      return;
    }
    if (/^[|>][-+]?$/.test(value)) return; // bloque escalar
    if (/^[`@%*,]/.test(value)) { errors.push(`Frontmatter línea ${lineNo}: valor sin comillas que empieza con '${value[0]}'; YAML lo reserva`); return; }
    if (/^[|>]\S/.test(value)) { errors.push(`Frontmatter línea ${lineNo}: '${value[0]}' seguido de texto; YAML lo lee como bloque escalar`); return; }
    if (/^[-?&](\s|$)/.test(value)) { errors.push(`Frontmatter línea ${lineNo}: valor empieza con '${value[0]} '; YAML lo lee como indicador`); return; }
    if (/^\[.*\]$/.test(value) || /^\{.*\}$/.test(value)) return; // colección en línea
    if (/:(\s|$)/.test(value)) errors.push(`Frontmatter línea ${lineNo}: valor sin comillas con ': '; YAML lo lee como mapa anidado`);
  });
  return errors;
}

function lintSkillContent(dirName, content) {
  const errors = [];
  const warnings = [];
  const fm = parseFrontmatter(content);
  if (!fm) {
    errors.push('Falta el frontmatter YAML (bloque --- al principio)');
    return { errors, warnings };
  }
  errors.push(...frontmatterYamlErrors(content));
  for (const key of topLevelFrontmatterKeys(content)) {
    if (!SPEC_FRONTMATTER_KEYS.has(key)) {
      errors.push(`Clave de frontmatter '${key}' no permitida; se aceptan ${[...SPEC_FRONTMATTER_KEYS].join(', ')}`);
    }
  }
  if (!fm.name) errors.push("Falta 'name' en el frontmatter");
  else if (fm.name !== dirName) errors.push(`'name' es '${fm.name}' y la carpeta es '${dirName}'`);
  if (!KEBAB_CASE.test(dirName)) errors.push(`La carpeta '${dirName}' no es kebab-case`);
  if (!fm.description) errors.push("Falta 'description' en el frontmatter");
  else {
    if (fm.description.length > MAX_DESCRIPTION_LENGTH) errors.push(`description tiene ${fm.description.length} caracteres; máximo ${MAX_DESCRIPTION_LENGTH}`);
    if (!DESCRIPTION_TRIGGER.test(fm.description)) errors.push('description sin disparador: agregá "Usar cuando …" / "Usar al …"');
  }
  const lineCount = (content.match(/\n/g) || []).length;
  if (lineCount > MAX_SKILL_LINES) warnings.push(`SKILL.md tiene ${lineCount} líneas, más de ${MAX_SKILL_LINES}; mové detalle a references/`);
  return { errors, warnings };
}

function isEffectivelyEmpty(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.isDirectory()) { if (!isEffectivelyEmpty(path.join(dir, entry.name))) return false; }
    else return false;
  }
  return true;
}

function lintSkillLayout(skillDir) {
  const errors = [];
  const walk = (dir, relBase) => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const rel = relBase ? `${relBase}/${entry.name}` : entry.name;
      const abs = path.join(dir, entry.name);
      if (!entry.isDirectory()) continue;
      if (isEffectivelyEmpty(abs)) errors.push(`Directorio vacío \`${rel}/\`: borralo`);
      else walk(abs, rel);
    }
  };
  walk(skillDir, '');
  return errors;
}

function lintPersonaContent(stem, content) {
  const errors = [];
  const fm = parseFrontmatter(content);
  if (!fm) { errors.push('Falta el frontmatter YAML'); return { errors }; }
  errors.push(...frontmatterYamlErrors(content));
  if (!fm.name) errors.push("Falta 'name'");
  else if (fm.name !== stem) errors.push(`'name' es '${fm.name}' y el archivo es '${stem}' (el name es el subagent_type)`);
  if (!fm.description) errors.push("Falta 'description'");
  return { errors };
}

function lintPersona(fileName, agentsDir) {
  const stem = fileName.replace(/\.md$/, '');
  let content;
  try { content = fs.readFileSync(path.join(agentsDir, fileName), 'utf8'); }
  catch (err) { return { errors: [`No se pudo leer: ${err.message}`] }; }
  return lintPersonaContent(stem, content);
}

function lintSkill(dirName, skillsDir) {
  const skillDir = path.join(skillsDir, dirName);
  const skillPath = path.join(skillDir, 'SKILL.md');
  if (!fs.existsSync(skillPath)) return { errors: ['Falta SKILL.md'], warnings: [] };
  let content;
  try { content = fs.readFileSync(skillPath, 'utf8'); }
  catch (err) { return { errors: [`No se pudo leer SKILL.md: ${err.message}`], warnings: [] }; }
  const result = lintSkillContent(dirName, content);
  result.errors.push(...lintSkillLayout(skillDir));
  return result;
}

module.exports = {
  stripFencedCodeBlocks, parseFrontmatter, topLevelFrontmatterKeys, frontmatterYamlErrors,
  lintSkillContent, lintSkillLayout, lintSkill, lintPersonaContent, lintPersona,
};
