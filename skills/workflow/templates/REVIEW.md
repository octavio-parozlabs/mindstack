---
rol: qa | code-reviewer | security-auditor
ronda: 1
fecha: AAAA-MM-DD
base: main
working_tree: <salida de git status --short | wc -l> archivos
---

# Revisión de <rol>: <título>

<!-- Lo escribe un solo rol; el hook bloquea a los demás. Se reescribe entero en cada ronda: la ronda anterior queda en git y en CHANGELOG.md › Revisión. -->

Solo hallazgos. Sin elogios, sin "considerá", sin nits de estilo. Tabla vacía = nada que objetar.

ID por rol: `QA-n` · `CODE-n` · `SEC-n`. Severidad: **crítica** (pérdida de datos, plata o acceso) · **alta** (bug en el camino principal) · **media** (bug en camino secundario) · **baja**. Orienta al `approver`, que decide qué se arregla. Solo lo que el diff trae o hace alcanzable.

| ID | Severidad | Archivo:línea | Qué falla, con qué entrada | CB | Fix en una línea |
|---|---|---|---|---|---|
| QA-1 | alta | `pagos.service.ts:42` | timeout con cobro hecho reintenta y cobra dos veces | CB-1 | consultar estado antes de reintentar |

## A verificar

Lo que parece un fallo y no pudiste confirmar con una entrada concreta. Una línea cada uno. No cuenta como hallazgo ni bloquea.

## Fuera del diff

Lo que ya estaba roto y este cambio no toca ni hace alcanzable. Una línea: qué, `archivo:línea`. No es hallazgo; el approver lo pasa a `CHANGELOG › Observaciones`.

## Propuestas

Lo que al revisar viste que sumaría a futuro y no es un fallo. Una línea: qué, por qué suma, dónde se vio. No cuenta como hallazgo; el orquestador lo pasa al backlog.
