# Changelog: <título>

Memoria de la tarea mientras se ejecuta. Lo escriben los roles al terminar cada paso; nadie reescribe, solo se agrega abajo. Es lo primero que lee quien entra a la tarea y lo primero que lee quien mergea.

Quién: `analyst` · `planner` · `developer` · `qa` · `approver` · `conflict-resolver` · `orchestrator` · `consensus` · `person`. Los revisores no escriben acá: aparecen como Rol en Revisión.

## Cambios

Una fila por tarea del TODO. Lo que se hizo, no lo que se planeó. Evidencia = comando y salida, no un sha: el código no se commitea hasta que pasa la revisión.

| Fecha | Quién | Qué | Evidencia |
|---|---|---|---|
| 2026-10-20 | developer | tarea 2: reintento con backoff en `pagos.service` | `npm test -- pagos` 12 verdes |

## Observaciones

Lo que se vio y no es de esta tarea: bugs ajenos, código raro, módulos sin test, docs desactualizadas. No se arregla acá; queda anotado para que alguien lo convierta en tarea.

| Fecha | Quién | Qué vio | Dónde |
|---|---|---|---|
| | qa | `parseDate` acepta `""` y devuelve hoy | `shared/dates.ts:12` |

## Propuestas

Lo que mientras trabajabas viste que sumaría a futuro y no es de esta tarea: una feature, una pantalla, una integración. No es un bug (Observaciones) ni algo que dejaste a medias (Deuda). Sin "dónde se vio" no se propone. El orquestador las pasa a `todolist/backlog/PROPUESTAS.md` al llegar a done.

La fecha es la de cuando se vio, no la de done: es la que viaja al backlog. Contexto: lo curioso que acompaña (una observación relacionada, un dato del log, qué lo disparó), en una línea.

| Fecha | Quién | Qué | Por qué suma | Dónde se vio | Contexto | Tamaño |
|---|---|---|---|---|---|---|
| | qa | reintento manual desde el detalle | soporte no puede forzarlo | CB-3 · `pagos.controller.ts:58` | 3 de 12 tests de timeout terminan en "fallido" sin salida; ver Observaciones | S |

## Decisiones

Elecciones que alguien va a cuestionar después, y todo giro respecto del PLAN. Con la alternativa descartada, para que no se vuelva a discutir desde cero, y el principio que la respalda (`PRINCIPLES.md` del plugin). Si la decidió un consenso, quién es `consensus` y la evidencia de cada analista va en una línea debajo.

| Fecha | Quién | Decisión | Alternativa descartada | Principio |
|---|---|---|---|---|
| | | | | |

## Deuda técnica

Lo que se dejó a propósito. Sin issue no es deuda, es olvido. Sin vencimiento no es deuda, es para siempre. Origen: el id del hallazgo de revisión que la generó, o `developer` si la dejó el desarrollador.

| Fecha | Quién | Qué falta | Por qué no ahora | Origen | Vence | Issue |
|---|---|---|---|---|---|---|
| | | | | CODE-3 | 2026-12-01 | #45 |

## Revisión

Una fila por hallazgo por ronda. La escribe el `approver` (`fix.md`). Decisión: `arreglar` · `deuda #issue` · `riesgo aceptado` · `descartado` · `bloqueado`. Lo que no es `arreglar` lleva un motivo que se pueda discutir al mergear: aparece en el PR. Un CI rojo después del push es una ronda `ci-n` con rol `ci` e ID `CI-n`, la escribe el `developer`.

| Ronda | Rol | ID | Severidad | Decisión | Motivo |
|---|---|---|---|---|---|
| 1 | code-reviewer | CODE-1 | alta | arreglar | `orders.service.ts:48` crea el pedido con un producto borrado (rompe CA-2) |
| 1 | security-auditor | SEC-2 | media | riesgo aceptado | rate limit en un endpoint solo de admins internos detrás de VPN; Práctico antes que puro |
| 1 | code-reviewer | CODE-3 | alta | descartado | pide paginar el listado; SPEC › Qué no se hace: "paginación, otra tarea" |

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
- Deuda que sigue abierta (issues):
