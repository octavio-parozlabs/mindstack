---
rol: qa | code-reviewer | security-auditor
ronda: 1
fecha: AAAA-MM-DD
commit: <sha revisado>
---

# Revisión de <rol>: <título>

<!-- Lo escribe un solo rol; el hook bloquea a los demás. Se reescribe entero en cada ronda: la ronda anterior queda en git y en CHANGELOG.md › Revisión. -->

Solo hallazgos. Sin elogios, sin "considerá", sin nits de estilo. Tabla vacía = nada que objetar.

ID por rol: `QA-n` · `CODE-n` · `SEC-n`. Severidad: **crítica** (pérdida de datos, plata o acceso; bloquea el PR) · **alta** (bug en el camino principal; bloquea el PR) · **media** (bug en camino secundario; puede quedar como deuda con vencimiento) · **baja** (puede quedar como deuda).

| ID | Severidad | Archivo:línea | Qué falla, con qué entrada | CB | Fix en una línea |
|---|---|---|---|---|---|
| QA-1 | alta | `pagos.service.ts:42` | timeout con cobro hecho reintenta y cobra dos veces | CB-1 | consultar estado antes de reintentar |

## A verificar

Lo que parece un fallo y no pudiste confirmar con una entrada concreta. Una línea cada uno. No cuenta como hallazgo ni bloquea.
