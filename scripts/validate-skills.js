#!/usr/bin/env node
/**
 * validate-skills.js: valida cada skills/<nombre>/SKILL.md y cada agents/<nombre>.md
 * con las reglas de scripts/lib/skill-lint.js. Exit 0 = ok, 1 = errores.
 */
'use strict';
const fs = require('fs');
const path = require('path');
const { lintSkill, lintPersona } = require('./lib/skill-lint');

const SKILLS_DIR = path.resolve(__dirname, '..', 'skills');
const AGENTS_DIR = path.resolve(__dirname, '..', 'agents');

function main() {
  if (!fs.existsSync(SKILLS_DIR)) { console.error(`ERROR: no existe ${SKILLS_DIR}`); process.exit(1); }
  const skillDirs = fs.readdirSync(SKILLS_DIR).filter(d => fs.statSync(path.join(SKILLS_DIR, d)).isDirectory()).sort();
  let totalErrors = 0, totalWarnings = 0;
  for (const dirName of skillDirs) {
    const { errors, warnings } = lintSkill(dirName, SKILLS_DIR);
    totalErrors += errors.length; totalWarnings += warnings.length;
    if (!errors.length && !warnings.length) { console.log(`  ✓  ${dirName}`); continue; }
    console.log(`${errors.length ? '  ✗ ' : '  ⚠ '} ${dirName}`);
    for (const m of errors) console.log(`       ERROR: ${m}`);
    for (const m of warnings) console.log(`       AVISO: ${m}`);
  }
  const personaFiles = fs.existsSync(AGENTS_DIR)
    ? fs.readdirSync(AGENTS_DIR).filter(f => f.endsWith('.md') && !/^readme\.md$/i.test(f)).sort() : [];
  if (personaFiles.length) console.log('');
  for (const fileName of personaFiles) {
    const { errors } = lintPersona(fileName, AGENTS_DIR);
    totalErrors += errors.length;
    console.log(`${errors.length ? '  ✗ ' : '  ✓ '} agents/${fileName}`);
    for (const m of errors) console.log(`       ERROR: ${m}`);
  }
  const status = totalErrors ? 'FALLÓ' : totalWarnings ? 'PASÓ CON AVISOS' : 'PASÓ';
  console.log(`\n${skillDirs.length} skills y ${personaFiles.length} agentes: ${totalErrors} error(es), ${totalWarnings} aviso(s): ${status}`);
  if (totalErrors) process.exit(1);
}
try { main(); } catch (err) { console.error(`\nERROR: validate-skills: ${err.message}`); process.exit(1); }
