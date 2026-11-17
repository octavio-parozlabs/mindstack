# 07 · El backlog: lo que proponés vos y lo que proponen los agentes

`todolist/backlog/` no es un estado: son dos listas de cosas que todavía nadie pidió. `IDEAS.md` es tuyo y ningún agente lo toca. `PROPUESTAS.md` lo arma el orquestador con lo que los agentes vieron mientras trabajaban; una propuesta gana peso cada vez que otra tarea tropieza con lo mismo. Ninguna de las dos se convierte en tarea sola: la elegís vos.

```mermaid
sequenceDiagram
    actor U as Vos
    participant C as Claude
    participant Q as qa
    participant R as code-reviewer
    participant B as backlog/
    participant G as git / GitHub

    rect rgb(255, 245, 230)
    Note over U,G: 2026-10-20 · tarea reintento-pagos, en su worktree
    C->>Q: Agent qa: testear tarea 3
    Q->>Q: CB-3: un pago con timeout queda "fallido" y nadie puede forzarlo
    Q-->>C: CHANGELOG › Propuestas: reintento manual desde el detalle · CB-3 · pagos.controller.ts:58 · S
    Note over C: review limpia, checklist completa, Done verde → fase pr
    C->>B: PROPUESTAS.md: ## Reintento manual (2026-10-20 · qa · reintento-pagos, CB-3)
    C->>G: commit plan(reintento-pagos): done · push · PR
    Note over B: viaja en el PR y al mergear queda en main
    end

    rect rgb(230, 240, 255)
    Note over U,G: 2026-11-02 · otra tarea, panel-soporte
    C->>R: Agent code-reviewer: revisar ronda 1
    R-->>C: REVIEW-code.md › Propuestas: soporte no puede reintentar un cobro · CA-4
    Note over C: fase pr: misma necesidad, otro texto → no es una entrada nueva
    C->>B: en ## Reintento manual: Visto también 2026-11-02 · code-reviewer · panel-soporte, CA-4
    Note over B: peso 2: dos tareas distintas tropezaron con lo mismo
    C->>G: commit plan(panel-soporte): done · push · PR
    end

    rect rgb(240, 255, 240)
    Note over U,G: 2026-11-16 · en main, sin tarea
    U->>B: IDEAS.md, una fila: exportar pedidos a CSV para que contabilidad cierre el mes · media · 2026-11-16
    U->>C: ¿qué del backlog conviene hacer?
    C->>B: lee IDEAS.md, PROPUESTAS.md y la tarea de origen de cada una
    C-->>U: 1. Reintento manual: peso 2, S, toca lo que se viene haciendo<br/>2. Exportar a CSV: idea tuya, M<br/>3. ... · empezá con claude -w reintento-manual y /draft backlog: Reintento manual
    Note over C: no escribe nada
    U->>C: claude -w reintento-manual · /mindstack:draft backlog: Reintento manual
    C->>C: lee el CHANGELOG de reintento-pagos y panel-soporte antes de preguntar
    C->>U: entrevista como cualquier pedido: la propuesta es una hipótesis, no un requisito
    C->>B: saca ## Reintento manual de PROPUESTAS.md
    C->>G: commit spec(reintento-manual): ronda 1 (Pedido original cita la entrada y sus dos tareas)
    end
```

## Quién escribe qué

| Archivo | Quién | Cuándo |
|---|---|---|
| `CHANGELOG › Propuestas` | developer, qa, approver | mientras trabajan, con la fecha en que lo vieron y dónde (`CA-n`, `CB-n`, `archivo:línea`) |
| `REVIEW-*.md › Propuestas` | code-reviewer, security-auditor | al revisar; no cuenta como hallazgo |
| `backlog/PROPUESTAS.md` | el orquestador | en la fase pr, con la tarea terminada y antes del push: filtra (sin "dónde se vio" no entra), deduplica (`Visto también`), máximo tres nuevas por tarea |
| `backlog/IDEAS.md` | vos | cuando quieras. Un agente que lo intente lo frena el hook |

## Cómo se ordena cuando preguntás

Primero el peso: cuántas tareas distintas vieron la misma necesidad. Después qué tan cerca está de lo último que se hizo, el tamaño y la antigüedad. Tus ideas pesan más que una propuesta vista una sola vez, y menos que una que se repite en muchas tareas.

## Lo que no pasa

- Un agente no implementa lo que propone: si lo hiciera, sería alcance que nadie pidió.
- Una tarea que termina en `blocked/` no pasa sus propuestas: quedan en su CHANGELOG hasta que llega a `4-done`.
- Una propuesta no se borra sola. Si no te sirve, la borrás vos.
