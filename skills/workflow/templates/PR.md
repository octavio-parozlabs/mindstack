<!-- body del PR. Lo arma el orquestador (fase pr) con los datos de la tarea; la persona lo lee en 30 segundos -->

Se mergea con **squash**: a `main` entra un solo commit con el título del PR.

Tarea: `todolist/4-done/<slug>/` (`SPEC.md` dice qué se pidió, `PLAN.md` es el contrato, `CHANGELOG.md` lo que pasó)

## Qué cambia

Un párrafo: el Objetivo del plan, en pasado.

## Checklist

`CHECKLIST.md` tal como la dejó `verifier`: cada línea con su código, su test y su evidencia.

- [x] CA-1 `POST /orders` con quantity ≤ 0 → 400 · código: `orders.schema.ts:12` · test: `orders.spec.ts "CA-1"` · evidencia: 1 passed
- [x] CB-1 stock insuficiente no crea el pedido · código: `orders.service.ts:40` · test: `orders.spec.ts "CB-1"` · evidencia: 1 passed

## Cómo probarlo

La URL del entorno local de la tarea (`CHANGELOG › Cambios`, la levanta `env-up.sh <entorno>` desde el checkout de la rama) o el comando del stack para levantarlo, y qué tocar para ver cada caso borde (CB-n) del SPEC. Es localhost: quien revisa el PR lo levanta en su máquina.

## Revisión

Rondas hechas y resultado, de `APPROVAL.md`: cuántos hallazgos por rol y cuántos de cada decisión del approver; y los CI rojos de `CHANGELOG › Revisión`.

## Lo que la persona tiene que mirar

Lo del `CHANGELOG.md` que necesita una decisión, una línea cada una:

- **Riesgos aceptados y descartes** de `APPROVAL.md`: ID, qué decía el revisor, motivo. Primero los de seguridad.
- Lo abierto de `TECHNICAL_DEBT.md`, con issue y vencimiento.
- Decisiones discutibles y Observaciones fuera de la tarea.

