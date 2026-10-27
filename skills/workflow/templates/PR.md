<!-- body del PR. Lo arma /mindstack:pr con los datos de la tarea; la persona lo lee en 30 segundos -->

Tarea: `docs/plans/3-in-review/<slug>/` (`SPEC.md` dice qué se pidió, `PLAN.md` es el contrato, `CHANGELOG.md` lo que pasó)

## Qué cambia

Un párrafo: el Objetivo del plan, en pasado.

## Estado final

El checklist "Estado final" de `PLAN.md`, con cada casilla marcada y el comando o test que lo prueba.

- [x] `GET /orders/:id` responde igual que antes: `npm test -- orders.contract`
- [x] cobertura del diff pasa

## Cómo probarlo

Cómo levantarlo y qué tocar para ver cada caso borde (CB-n) del SPEC.

## Revisión

Rondas hechas y resultado, de `CHANGELOG.md › Revisión`: cuántos hallazgos por rol, cuántos corregidos, cuántos quedaron como deuda.

## Lo que la persona tiene que mirar

Lo del `CHANGELOG.md` que necesita una decisión: Deuda técnica con issue y vencimiento, Decisiones discutibles, Observaciones fuera de la tarea. Una línea cada una.

pr:
