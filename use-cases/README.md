# Casos de uso

Cómo interactuás con mindstack, de punta a punta, con diagramas de secuencia. Actores:

| Actor | Qué es |
|---|---|
| **Vos** | la persona. Pedís, pedís el plan, probás cuando querés, desempatás, mergeás |
| **Claude** | la sesión de Claude Code en el worktree de la tarea. Corre los comandos `/mindstack:*`, lanza agentes, te pregunta |
| **agentes** | `analyst`, `designer`, `researcher`, `developer`, `qa`, `code-reviewer`, `security-auditor`, `verifier`, `fixer`, `conflict-resolver`. Subagentes con permisos acotados |
| **hooks** | `plan-immutable.sh`, `write-scope.sh`: bloquean lo que un rol no puede escribir; `orchestrate-stop.sh`: el orquestador no termina fuera de `4-done` o `blocked/` |
| **git / GitHub** | commits, worktree, PR |

| Caso | Qué muestra |
|---|---|
| [01 · Un bug, de punta a punta, autónomo](01-fix-autonomous.md) | `/draft` entrevista y reproduce el bug → `/plan` → `/orchestrate`: implementa, revisa (con la checklist), corrige, deja la tarea en `4-done` con el PR en CI verde. Vos: dos comandos, una frase y el merge |
| [02 · Lo que vos hacés: el borrador](02-draft.md) | `/draft` (SPEC, varias vueltas) → `/plan` o "generá el plan" (PLAN validado, tarea pendiente) → `/draft` sin texto si querés volver → delegar con `/orchestrate` en el worktree |
| [03 · El dev no puede decidir](03-decision-consensus.md) | `DECISION:` → tres analistas → acuerdo, o `blocked/` y te pregunta al retomar |
| [04 · Revisión con hallazgos, corrección y conflicto](04-review-fix-conflict.md) | ronda 1 con hallazgos y una línea de checklist abierta → validar (uno refutado) → `fixer` → ronda 2 limpia → `4-done` → conflicto con main → rebase → CI verde → merge |
| [05 · Variantes por tipo de tarea](05-task-types.md) | qué cambia en el flujo según `tipo:` del PLAN: refactor, migración, performance, docs, ci |
| [06 · Varias tareas en paralelo e iteración sobre un PR](06-parallel-and-iterate.md) | dos tareas pendientes → dos worktrees → dos orquestadores → dos PRs; probás uno, falta algo → `/draft "qué falta"` → mismo PR → merge |
| [07 · El backlog](07-backlog.md) | qa propone algo en una tarea → viaja en su PR → otra tarea lo vuelve a ver (peso 2) → preguntás qué conviene → `/draft backlog: <unas palabras>` |
| [08 · Una cola para el fin de semana](08-queue.md) | tres tareas en un worktree → `/orchestrate` las corre en orden, una sesión nueva por tarea → un push, un PR, CI verde. Si una se bloquea: frena, PR draft con lo hecho, retomás |

## La respuesta corta a "¿cómo lo uso?"

```
claude -w pagos-timeout                                         # el worktree ES la tarea; vos elegís el nombre
/mindstack:draft "los pagos con timeout se cobran dos veces"   # te entrevista, reproduce, escribe el SPEC. Para.
(comentarios sueltos)                                           # corrigen el SPEC, commit por vuelta
/mindstack:plan                                                 # o "generá el plan": PLAN validado, tarea pendiente, resumen
/mindstack:orchestrate                                          # te sentás a esperar: 4-done o blocked/
/mindstack:draft backlog: <unas palabras>                        # otro día: una idea o propuesta del backlog como pedido
```

De ahí no para hasta `4-done`: implementa, testea, revisa con cuatro agentes (uno verifica la checklist línea por línea), valida los hallazgos, corrige, vuelve a revisar, commitea, abre el PR, espera CI verde y te deja el link. Si algo necesita una decisión tuya, la tarea va a `blocked/` con un `BLOCKED.md` corto, y el aviso al abrir `claude` te lo muestra. Probás en localhost: si está, mergeás; si falta algo, `/mindstack:draft "qué falta"` y otra vuelta sobre el mismo PR.

Para varias tareas a la vez: un worktree por tarea, cada uno con su sesión; el borrador lo hacés de a uno, los orquestadores corren en paralelo, un PR cada una (caso 06). Si dependen entre sí o no hay apuro: todas en un worktree, `/orchestrate` las corre en cola, un PR para todas (caso 08).

Cinco comandos en total, ninguno con el nombre de la tarea: `/install` una vez por proyecto; `/draft`, `/plan` y `/orchestrate` en el día a día (el plan también se pide en palabras); `/rebase` para un PR colgado. Las fases internas (implement, review, fix, pr, conflicts) no son comandos: las corre el orquestador. Caso 02 muestra tu parte.
