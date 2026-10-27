# 03 · El dev no puede decidir

Durante la implementación el `developer` encuentra algo que ni el SPEC, ni el PLAN, ni un principio resuelven. No adivina y no te interrumpe de entrada: tres analistas buscan la respuesta en lo que ya existe. Si coinciden, se decide; si no, recién ahí vos.

```mermaid
sequenceDiagram
    actor U as Vos
    participant C as Claude (sesión principal, loop)
    participant DEV as developer
    participant A1 as analyst · historial
    participant A2 as analyst · código
    participant A3 as analyst · principios

    C->>DEV: tarea 2: reintento con idempotencia
    DEV->>DEV: relee SPEC, PLAN, Decisiones: nada dice de dónde sale la clave
    DEV-->>C: DECISION: ¿clave de idempotencia del proveedor o propia? | A: del proveedor (menos código, depende de que exista) / B: propia en tabla pagos (más código, no depende)

    par un solo turno, en paralelo
        C->>A1: ángulo historial: Decisiones de docs/plans/4-done/*/CHANGELOG.md
        C->>A2: ángulo código: ¿cómo se resolvió lo mismo en otro módulo?
        C->>A3: ángulo principios: PRINCIPLES.md, SPEC, PLAN
    end
    A1-->>C: facturas-retry (4-done) eligió clave propia · OPTION: B
    A2-->>C: billing/retry usa la del proveedor desde PR #31 · OPTION: A
    A3-->>C: "una sola forma obvia": ya hay una forma en el repo · OPTION: A

    Note over C: 2 de 3 no es consenso
    C->>U: AskUserQuestion: ¿A o B? historial dice B (facturas-retry), código y principios dicen A (billing/retry)
    U-->>C: A, y anotá que facturas-retry queda como deuda para unificar
    C->>C: CHANGELOG › Decisiones: quién person, A, alternativa B, principio "una sola forma obvia" · Deuda: unificar facturas-retry
    C->>DEV: seguí la tarea 2 con la decisión
```

## Cuando sí hay consenso

Los tres devuelven la misma `OPTION`: el dev escribe la fila en Decisiones con quién `consensus`, una línea por ángulo con su evidencia, y sigue. No te enterás hasta que leés el CHANGELOG, y eso es lo que querés: la pregunta ya tenía respuesta en el repo.

## Por qué tres y no uno

Uno confirma lo que el dev ya pensó. Tres con ángulos distintos (lo que se decidió antes, lo que el código ya hace, lo que los principios dicen) solo coinciden cuando la respuesta es obvia, y el desacuerdo es la señal exacta de que hace falta una persona.

## Sin persona disponible

En CI (`$CI` definido) no hay a quién preguntar: el dev termina con `BLOCKED: consenso sin acuerdo sobre …`, el loop para y la tarea queda en `2-in-progress/` con la pregunta en el CHANGELOG. Retomás con `/mindstack:orchestrate` después de responderla.
