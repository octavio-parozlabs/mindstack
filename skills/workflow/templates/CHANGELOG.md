# Changelog: <título>

Memoria de la tarea mientras se ejecuta. Lo escriben los roles al terminar cada paso; nadie reescribe, solo se agrega abajo. Es lo primero que lee quien entra a la tarea y lo primero que lee quien mergea.

Quién: `analyst` · `planner` · `developer` · `qa` · `approver` (solo Observaciones; sus decisiones van a `APPROVAL.md` y la deuda a `TECHNICAL_DEBT.md`) · `conflict-resolver` · `orchestrator` · `person`. Los revisores no escriben acá: aparecen como Rol en Revisión.

## Cambios

Una fila por tarea del TODO. Lo que se hizo, no lo que se planeó. Evidencia = comando y salida.

| Fecha | Quién | Qué | Evidencia |
|---|---|---|---|
| 2026-10-20 | developer | tarea 2: reintento con backoff en `pagos.service` | `npm test -- pagos` 12 verdes |

## Observaciones

Lo que se vio y no es de esta tarea: bugs ajenos, código raro, módulos sin test, docs desactualizadas. No se arregla acá; queda anotado para que alguien lo convierta en tarea.

| Fecha | Quién | Qué vio | Dónde |
|---|---|---|---|
| | qa | `parseDate` acepta `""` y devuelve hoy | `shared/dates.ts:12` |

## Propuestas

Lo que sumaría a futuro y no es de esta tarea (no es un bug ni deuda). Sin "dónde se vio" no entra. La fecha es la de cuando se vio. Pasa al backlog en la fase pr (`references/pr.md` paso 3).

| Fecha | Quién | Qué | Por qué suma | Dónde se vio | Contexto | Tamaño |
|---|---|---|---|---|---|---|
| | qa | reintento manual desde el detalle | soporte no puede forzarlo | CB-3 · `pagos.controller.ts:58` | 3 de 12 tests de timeout terminan en "fallido" sin salida; ver Observaciones | S |

## Decisiones

Elecciones que alguien va a cuestionar después, y todo giro respecto del PLAN. Con la alternativa descartada, para que no se vuelva a discutir desde cero, y el principio que la respalda (`PRINCIPLES.md` del plugin). Si la decidió el analista, quién es `analyst` y su evidencia va en una línea debajo.

| Fecha | Quién | Decisión | Alternativa descartada | Principio |
|---|---|---|---|---|
| | | | | |

## Revisión

Las decisiones del approver sobre los hallazgos están en `APPROVAL.md`, una sección por ronda. Acá solo los CI rojos después del push: una fila por fallo, la escribe el `developer` en modo `ci`.

| Ronda | ID | Decisión | Motivo (la línea del log) |
|---|---|---|---|
| ci-1 | CI-1 | arreglar | `lint: 'retry' is defined but never used` |

## Conflictos

Si el resolutor actuó: qué archivos y qué decidió en cada uno.

| Fecha | Archivo | Decisión |
|---|---|---|
| | | |

## Cierre

Lo escribe el orquestador (fase pr) al pasar la tarea a `4-done`, antes del push. El número del PR y la fecha del merge los da GitHub.

- Inicio real: AAAA-MM-DD · Fin real: AAAA-MM-DD (planificado: ver `PLAN.md`)
- Rondas de revisión: n
- Iteraciones: <slug>-2 (<qué agregó>), …
- Qué quedó distinto de lo planeado:
- Deuda que sigue abierta (de `TECHNICAL_DEBT.md`):
