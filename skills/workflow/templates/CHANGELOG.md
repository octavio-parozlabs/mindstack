# Changelog: <título>

Memoria de la tarea mientras se ejecuta. Lo escriben los roles al terminar cada paso; nadie reescribe, solo se agrega abajo. Es lo primero que lee quien entra a la tarea y lo primero que lee quien mergea.

Quién: `analyst` · `planner` · `developer` · `qa` · `code-reviewer` · `security-auditor` · `fixer` · `conflict-resolver` · `consensus` · `person`.

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

## Decisiones

Elecciones que alguien va a cuestionar después, y todo giro respecto del PLAN. Con la alternativa descartada, para que no se vuelva a discutir desde cero, y el principio que la respalda (`references/PRINCIPLES.md` del plugin). Si la decidió un consenso, quién es `consensus` y la evidencia de cada analista va en una línea debajo.

| Fecha | Quién | Decisión | Alternativa descartada | Principio |
|---|---|---|---|---|
| | | | | |

## Deuda técnica

Lo que se dejó a propósito. Sin issue no es deuda, es olvido. Sin vencimiento no es deuda, es para siempre. Origen: el id del hallazgo de revisión que la generó, o `developer` si la dejó el desarrollador.

| Fecha | Quién | Qué falta | Por qué no ahora | Origen | Vence | Issue |
|---|---|---|---|---|---|---|
| | | | | CODE-3 | 2026-12-01 | #45 |

## Revisión

Una fila por hallazgo por ronda. La escribe el corrector al cerrar la ronda. Un CI rojo después del push es una ronda `ci-n` con rol `ci` e ID `CI-n`. Resultado: `corregido` · `deuda #issue` · `rechazado: <motivo>` · `fuera de alcance: <motivo>`.

| Ronda | Rol | ID | Severidad | Resultado |
|---|---|---|---|---|
| 1 | code-reviewer | CODE-1 | alta | corregido |

## Conflictos

Si el resolutor actuó: qué archivos y qué decidió en cada uno.

| Fecha | Archivo | Decisión |
|---|---|---|
| | | |

## Cierre

Lo escribe el orquestador (fase finalize) después del merge.

- Inicio real: AAAA-MM-DD · Fin real: AAAA-MM-DD (planificado: ver `PLAN.md`)
- PR: #n · <url> · mergeado / cerrado sin merge: <motivo>
- Iteraciones: <slug>-2 (<qué agregó>), …
- Qué quedó distinto de lo planeado:
- Deuda que sigue abierta (issues):
