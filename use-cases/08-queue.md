# 08 · Una cola de tareas para el fin de semana, en un solo PR

Varias tareas que dependen entre sí, o que te da igual cuánto tarden: las escribís todas en el mismo worktree y `/orchestrate` las corre en orden, cada una en una sesión nueva, sin que vos mires. Todas viajan en un PR. Es lento y funciona. Si querés rapidez y sabés que no dependen, es el caso 06: un worktree por tarea, en paralelo.

```mermaid
sequenceDiagram
    actor U as Vos
    participant O as Claude (worktree checkout-v2, padre)
    participant H as hija (sesión nueva: panel de tmux o claude -p)
    participant G as git / GitHub

    rect rgb(255, 245, 230)
    Note over U,G: viernes a la tarde: el borrador de cada una, con vos
    U->>O: claude -w checkout-v2 · /mindstack:draft "carrito persistente"
    O-->>U: SPEC checkout-v2 · generá el plan → 1-pending
    U->>O: /mindstack:draft "cupones de descuento en el carrito"
    O->>U: otra tarea para la cola de este PR. ¿slug cupones-carrito?
    U-->>O: sí
    O-->>U: SPEC · plan → 1-pending
    U->>O: /mindstack:draft "resumen de compra con cupón aplicado"
    O-->>U: SPEC resumen-compra · plan → 1-pending
    end

    rect rgb(230, 240, 255)
    Note over U,G: viernes 19 h: lo lanzás y te vas
    U->>O: /mindstack:orchestrate
    O->>U: ¿cuáles corro? [checkout-v2, cupones-carrito, resumen-compra]
    U-->>O: las tres, en ese orden
    O->>O: cola en el git dir
    O->>H: "/mindstack:orchestrate hija checkout-v2" (panel de tmux o segundo plano)
    H->>H: implement → review ×4 ↔ fix → Done · commit local · 4-done
    H-->>O: fin: checkout-v2 en 4-done
    Note over O: suma una línea. Su contexto no crece
    O->>H: hija cupones-carrito (ya ve el código del carrito)
    H-->>O: fin: 4-done
    O->>H: hija resumen-compra
    H-->>O: fin: 4-done
    O->>G: UN push · gh pr create con los tres PR.md · CI
    G-->>O: CI verde
    Note over O: hook de parada: todo en 4-done y CI verde → termina
    end

    rect rgb(240, 255, 240)
    Note over U,G: lunes
    U->>U: un PR, tres tareas, CI verde · probás en localhost
    U->>G: merge
    end
```

## Si una se bloquea a mitad

```mermaid
sequenceDiagram
    participant O as padre
    participant H as hija
    participant G as GitHub
    actor U as Vos
    O->>H: hija cupones-carrito
    H->>H: approver: arreglar CODE-2 cambia cómo se aplican los cupones → APPROVAL: blocked · BLOCKED.md · commit local
    H-->>O: fin: cupones-carrito en blocked/
    Note over O: resumen-compra depende de los cupones: la cola frena
    O->>G: push de lo hecho · gh pr create --draft · "bloqueada: cupones-carrito"
    Note over U: lunes, al abrir claude: ⚠ bloqueada: cupones-carrito — CODE-2 ...
    U->>O: /mindstack:orchestrate
    O->>U: los motivos de BLOCKED.md, uno por pregunta
    U-->>O: opción a
    O->>O: Decisiones · vuelve a 3-in-review · cola: cupones-carrito, resumen-compra
    O->>H: hija cupones-carrito
    H-->>O: 4-done
    O->>H: hija resumen-compra (lo que quedaba de la cola)
    H-->>O: 4-done
    O->>G: push · gh pr comment · gh pr ready · CI verde
```

## Qué cambia respecto de una tarea sola

| | Una tarea | Cola |
|---|---|---|
| Worktree, rama, PR | uno | uno, para todas |
| Quién implementa | el orquestador de tu sesión | una sesión nueva por tarea (panel de tmux al lado del padre si corre en tmux; si no, `claude -p`), en el mismo worktree |
| Push | uno, en la fase pr | uno, al final de la cola (las hijas commitean local) |
| CI | una vez | una vez, sobre todo |
| Se bloquea | `blocked/`, PR a draft si había | la cola frena, lo hecho sube como PR draft, las siguientes quedan en `1-pending` |
| Qué te pregunta | nada | solo cuáles corre, si no se lo dijiste |

## Lo que tiene que estar

Las hijas no pueden frenar a pedir permiso (en tmux las ves trabajar, pero la cola no espera a que contestes): la lista de `permissions.allow` que deja `/mindstack:install` tiene que cubrir `git`, `gh` y los comandos del stack. Y la sesión del padre queda abierta todo el fin de semana: si cerrás la terminal, la cola se corta donde esté, y `/mindstack:orchestrate` la retoma por las carpetas.
