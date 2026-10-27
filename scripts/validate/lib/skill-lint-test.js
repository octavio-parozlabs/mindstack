#!/usr/bin/env node
'use strict';
const assert = require('node:assert/strict');
const { test } = require('node:test');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { lintSkillContent, lintSkillLayout, parseFrontmatter, frontmatterYamlErrors, lintPersonaContent, stripFencedCodeBlocks } = require('./skill-lint.js');

const ok = (fm) => `${fm}\n\n# Título\n\ntexto\n`;
const VALID = '---\nname: alfa\ndescription: Diseña alfas. Usar cuando hay que construir una.\n---';

test('skill válida sin errores', () => {
  assert.deepEqual(lintSkillContent('alfa', ok(VALID)).errors, []);
});
test('description en inglés sin Usar falla', () => {
  assert.ok(lintSkillContent('alfa', ok('---\nname: alfa\ndescription: Designs alphas. Use when building one.\n---')).errors.some(e => /disparador/.test(e)));
});
test('description sin disparador falla', () => {
  const { errors } = lintSkillContent('alfa', ok('---\nname: alfa\ndescription: Diseña alfas.\n---'));
  assert.ok(errors.some(e => /disparador/.test(e)));
});
test('name distinto de la carpeta falla', () => {
  const { errors } = lintSkillContent('beta', ok(VALID));
  assert.ok(errors.some(e => /carpeta es 'beta'/.test(e)));
});
test('sin frontmatter falla', () => {
  assert.ok(lintSkillContent('alfa', '# nada\n').errors.length === 1);
});
test('clave desconocida falla, paths y disable-model-invocation pasan', () => {
  assert.ok(lintSkillContent('alfa', ok('---\nname: alfa\ndescription: X. Usar cuando Y.\nmodel: opus\n---')).errors.some(e => /no permitida/.test(e)));
  assert.deepEqual(lintSkillContent('alfa', ok('---\nname: alfa\ndescription: X. Usar cuando Y.\npaths: ["apps/**"]\ndisable-model-invocation: true\n---')).errors, []);
});
test('description plegada con >- se parsea entera', () => {
  const fm = parseFrontmatter('---\nname: alfa\ndescription: >-\n  Hace A.\n  Usar cuando B.\n---\n');
  assert.equal(fm.description, 'Hace A. Usar cuando B.');
  assert.deepEqual(lintSkillContent('alfa', ok('---\nname: alfa\ndescription: >-\n  Hace A.\n  Usar cuando B.\n---')).errors, []);
});
test('más de 500 líneas avisa', () => {
  const { warnings } = lintSkillContent('alfa', ok(VALID) + '\n'.repeat(500));
  assert.equal(warnings.length, 1);
});
test('YAML: valor con ": " sin comillas falla, con comillas pasa', () => {
  assert.equal(frontmatterYamlErrors('---\nname: a\ndescription: Usar: cuando\n---\n').length, 1);
  assert.equal(frontmatterYamlErrors('---\nname: a\ndescription: "Usar: cuando"\n---\n').length, 0);
});
test('YAML: tab, comilla sin cerrar, backtick inicial fallan', () => {
  assert.equal(frontmatterYamlErrors('---\n\tname: a\n---\n').length, 1);
  assert.equal(frontmatterYamlErrors('---\ndescription: "abierta\n---\n').length, 1);
  assert.equal(frontmatterYamlErrors('---\ndescription: `x` hace\n---\n').length, 1);
});
test('YAML: bloque >- y lista en línea pasan', () => {
  assert.equal(frontmatterYamlErrors('---\ndescription: >-\n  a: b\npaths: ["x/**", "y"]\n---\n').length, 0);
});
test('layout: subdirectorio vacío falla, con archivo pasa', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'skill-'));
  fs.mkdirSync(path.join(root, 'references'));
  assert.equal(lintSkillLayout(root).length, 1);
  fs.writeFileSync(path.join(root, 'references', 'A.md'), 'x');
  assert.equal(lintSkillLayout(root).length, 0);
});
test('agente: name == archivo y description', () => {
  assert.deepEqual(lintPersonaContent('qa', '---\nname: qa\ndescription: Testea.\ntools: Read\nmodel: sonnet\n---\ncuerpo\n').errors, []);
  assert.equal(lintPersonaContent('qa', '---\nname: tester\ndescription: Testea.\n---\nx\n').errors.length, 1);
});
test('stripFencedCodeBlocks conserva líneas', () => {
  const s = 'a\n```\nb\n```\nc\n';
  assert.equal(stripFencedCodeBlocks(s).split('\n').length, s.split('\n').length);
});
