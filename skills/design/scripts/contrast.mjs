#!/usr/bin/env node
// Contraste WCAG 2 entre pares de colores. Uso:
//   node contrast.mjs '<frente>|<fondo>|<mínimo>' …
//   node contrast.mjs '#ffffff|oklch(0.55 0.15 255)|4.5' 'oklch(0.55 0.15 255)|#fafafa|3'
// Colores: #rgb, #rrggbb u oklch(L C H) con L en 0–1 o en %. Sale con 1 si algún par no llega.

const toLinear = (c) => (c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4);

function linearRgb(color) {
  const s = color.trim().toLowerCase();
  const hex = s.match(/^#([0-9a-f]{3}|[0-9a-f]{6})$/);
  if (hex) {
    const h = hex[1].length === 3 ? [...hex[1]].map((x) => x + x).join('') : hex[1];
    return [0, 2, 4].map((i) => toLinear(parseInt(h.slice(i, i + 2), 16) / 255));
  }
  const ok = s.match(/^oklch\(\s*([\d.]+)(%?)\s+([\d.]+)\s+([\d.]+)\s*\)$/);
  if (ok) {
    const L = ok[2] ? ok[1] / 100 : +ok[1];
    const h = (ok[4] * Math.PI) / 180;
    const a = ok[3] * Math.cos(h), b = ok[3] * Math.sin(h);
    const l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3;
    const m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3;
    const q = (L - 0.0894841775 * a - 1.291485548 * b) ** 3;
    // ponytail: fuera de gamut se recorta por canal, igual que el navegador sin gamut mapping
    return [
      4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * q,
      -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * q,
      -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * q,
    ].map((c) => Math.min(1, Math.max(0, c)));
  }
  throw new Error(`color no soportado: ${color}`);
}

const luminance = (c) => {
  const [r, g, b] = linearRgb(c);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
};

export function ratio(a, b) {
  const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (hi + 0.05) / (lo + 0.05);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const pairs = process.argv.slice(2);
  if (!pairs.length) {
    console.error("uso: node contrast.mjs '<frente>|<fondo>|<mínimo>' …");
    process.exit(2);
  }
  let failed = 0;
  for (const p of pairs) {
    const [fg, bg, min = '4.5'] = p.split('|');
    const r = ratio(fg, bg);
    const ok = r >= +min;
    if (!ok) failed++;
    console.log(`${ok ? 'PASA ' : 'FALLA'} ${r.toFixed(2)}:1 (mín ${min})  ${fg} sobre ${bg}`);
  }
  process.exit(failed ? 1 : 0);
}
