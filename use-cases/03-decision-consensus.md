# 03 · El dev no puede decidir

Durante la implementación el `developer` encuentra algo que ni el SPEC, ni el PLAN, ni un principio resuelven. No adivina y no te interrumpe de entrada: un analista busca la respuesta en lo que ya existe. Si la evidencia alcanza, decide; si no, la tarea va a `blocked/` con la pregunta y te enterás al abrir `claude`.

```mermaid
sequenceDiagram
    actor U as Vos
    participant C as Claude (sesión principal, loop)
    participant DEV as developer
    participant A as analyst

    C->>DEV: implementar pagos-timeout 2: reintento con idempotencia
    DEV->>DEV: relee SPEC, PLAN, Decisiones: nada dice de dónde sale la clave
    DEV-->>C: DECISION: ¿clave de idempotencia del proveedor o propia? | A: del proveedor / B: propia en tabla pagos

    C->>A: la pregunta y las opciones
    A->>A: historial: facturas-retry eligió propia · código: billing/retry usa la del proveedor · principios: empate
    A-->>C: OPTION: sin evidencia (historial y código dicen cosas opuestas con el mismo peso)

    C->>C: BLOCKED.md: ¿A o B?, con lo que encontró · git mv → blocked · commit
    C-->>U: bloqueada: clave de idempotencia. Detalle en BLOCKED.md
    Note over U: más tarde, al abrir claude: "⚠ bloqueada: pagos-timeout"
    U->>C: /mindstack:orchestrate
    C->>U: AskUserQuestion: ¿A o B?
    U-->>C: A, y anotá que facturas-retry queda como deuda para unificar
    C->>C: Decisiones: quién person, A · TECHNICAL_DEBT.md: unificar facturas-retry
    C->>C: borra BLOCKED.md · git mv → 2-in-progress · commit unblocked
    C->>DEV: implementar pagos-timeout 2, con la decisión
```

Cuando la evidencia alcanza (`OPTION: A`), el orquestador anota la decisión con quién `analyst` y sigue: no te enterás hasta que leés el CHANGELOG, y eso es lo que querés. Las reglas: `skills/workflow/references/consensus.md`.
