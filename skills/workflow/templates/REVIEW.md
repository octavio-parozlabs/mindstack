---
rol: qa | code-reviewer | security-auditor
ronda: 1
fecha: AAAA-MM-DD
base: main
working_tree: <salida de git status --short | wc -l> archivos
---

# Revisión de <rol>: <título>

<!-- Un archivo por rol, reescrito entero en cada ronda. Quién lo escribe: references/roles-and-artifacts.md. -->

Solo hallazgos. Sin elogios, sin "considerá", sin nits de estilo. Tabla vacía = nada que objetar.

ID por rol: `QA-n` · `CODE-n` · `SEC-n`, numerados de nuevo en cada ronda. Solo lo que el diff trae o hace alcanzable. Máximo `hallazgos_por_revisor` (lo dice el prompt); el resto, a "A verificar".

Severidad, por consecuencia y no por tamaño del fix. Esta es la única escala; orienta al `approver`, que decide qué se arregla:

| Severidad | qa · code-reviewer | security-auditor |
|---|---|---|
| **crítica** | pérdida de datos, plata o acceso | pérdida de datos, plata o acceso |
| **alta** | bug en el camino principal | explotable por un usuario autenticado |
| **media** | bug en un camino secundario | requiere condiciones |
| **baja** | molestia, no bug | defensa en profundidad |

| ID | Severidad | Archivo:línea | Qué falla, con qué entrada | CB | Fix en una línea |
|---|---|---|---|---|---|
| QA-1 | alta | `pagos.service.ts:42` | timeout con cobro hecho reintenta y cobra dos veces | CB-1 | consultar estado antes de reintentar |

## Cerrados

Desde la ronda 2: los IDs que se mandaron a arreglar (`APPROVAL.md › Ronda n-1 › Para corregir`), uno por línea, con `cerrado` o `sigue roto`. Uno que sigue roto va además a la tabla, con `Reabre: R<n-1> <ID>` en Qué falla. Los IDs de la tabla se numeran de nuevo en cada ronda.

## A verificar

Lo que parece un fallo y no pudiste confirmar con una entrada concreta. Una línea cada uno. No cuenta como hallazgo ni bloquea.

## Fuera del diff

Lo que ya estaba roto y este cambio no toca ni hace alcanzable. Una línea: qué, `archivo:línea`. No es hallazgo; el approver lo pasa a `CHANGELOG › Observaciones`.

## Propuestas

Lo que al revisar viste que sumaría a futuro y no es un fallo. Una línea: qué, por qué suma, dónde se vio. No cuenta como hallazgo; el orquestador lo pasa al backlog.
