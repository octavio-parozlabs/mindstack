// Renderiza los wireframes de una tarea: <dir>/*.wireloom → <dir>/rendered/*.svg.
// Uso: node scripts/wireframes.mjs todolist/0-draft/<slug>/wireframes   (sale con 1 si alguno no parsea)
// Sin package.json en el repo: la primera vez instala wireloom en $TMPDIR/mindstack-wireloom y lo reusa.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execSync } from 'node:child_process';
import { createRequire } from 'node:module';

const VERSION = '0.7.0'; // ponytail: fija; la sintaxis de wireloom todavía cambia entre versiones menores
const cache = path.join(os.tmpdir(), 'mindstack-wireloom');
const req = createRequire(path.join(cache, 'node_modules', 'x.js'));
let installed;
try { installed = req('wireloom/package.json').version; } catch {}
if (installed !== VERSION) {
  fs.mkdirSync(cache, { recursive: true });
  execSync(`npm i --no-audit --no-fund --silent wireloom@${VERSION}`, { cwd: cache, stdio: 'inherit' });
}
const { render } = req('wireloom');

const dir = path.resolve(process.argv[2] || 'wireframes');
const out = path.join(dir, 'rendered');
const files = fs.existsSync(dir) ? fs.readdirSync(dir).filter((f) => f.endsWith('.wireloom')).sort() : [];
if (!files.length) { console.log(`sin .wireloom en ${dir}`); process.exit(1); }
fs.mkdirSync(out, { recursive: true });

let bad = 0;
for (const f of files) {
  const name = path.basename(f, '.wireloom');
  try {
    const { svg } = await render(name, fs.readFileSync(path.join(dir, f), 'utf8'));
    fs.writeFileSync(path.join(out, `${name}.svg`), svg);
    console.log(`✓ ${f} → rendered/${name}.svg`);
  } catch (e) {
    bad++;
    console.log(`✗ ${f}: ${String(e.message || e).split('\n')[0]}`);
  }
}
process.exit(bad ? 1 : 0);
