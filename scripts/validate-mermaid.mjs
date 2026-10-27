// Valida cada bloque ```mermaid del repo con el parser real de mermaid.
// Uso: node scripts/validate-mermaid.mjs [raíz]   (default: .)
// Sin package.json en el repo: la primera vez instala mermaid y jsdom en $TMPDIR/mindstack-mermaid y los reusa.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execSync } from 'node:child_process';
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';

const cache = path.join(os.tmpdir(), 'mindstack-mermaid');
if (!fs.existsSync(path.join(cache, 'node_modules', 'mermaid')) || !fs.existsSync(path.join(cache, 'node_modules', 'jsdom'))) {
  fs.mkdirSync(cache, { recursive: true });
  execSync('npm i --no-audit --no-fund --silent mermaid@11 jsdom@25', { cwd: cache, stdio: 'inherit' });
}
const req = createRequire(path.join(cache, 'node_modules', 'x.js'));
const { JSDOM } = req('jsdom');
const dom = new JSDOM('<!DOCTYPE html><html><body></body></html>', { pretendToBeVisual: true });
globalThis.window = dom.window;
globalThis.document = dom.window.document;
Object.defineProperty(globalThis, 'navigator', { value: dom.window.navigator, configurable: true });
const mermaid = (await import(pathToFileURL(req.resolve('mermaid')))).default;
mermaid.initialize({ startOnLoad: false, suppressErrorRendering: true });

const root = path.resolve(process.argv[2] || '.');
const files = [];
(function walk(d) {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    const p = path.join(d, e.name);
    if (e.isDirectory()) { if (!/node_modules|\.git$/.test(p)) walk(p); }
    else if (p.endsWith('.md')) files.push(p);
  }
})(root);

let total = 0, bad = 0;
for (const f of files.sort()) {
  const s = fs.readFileSync(f, 'utf8');
  const re = /```mermaid[ \t]*\r?\n([\s\S]*?)\r?\n```/g;
  let m, i = 0;
  while ((m = re.exec(s))) {
    i++; total++;
    const line = s.slice(0, m.index).split('\n').length;
    try { await mermaid.parse(m[1]); }
    catch (e) {
      bad++;
      console.log(`✗ ${path.relative(root, f)}:${line} (bloque ${i}): ${String(e.message || e).split('\n').slice(0, 3).join(' | ')}`);
    }
  }
}
console.log(`${total} diagramas, ${bad} rotos`);
process.exit(bad ? 1 : 0);
