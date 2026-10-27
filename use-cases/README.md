# Casos de uso

Cómo interactuás con mindstack, de punta a punta, con diagramas de secuencia. Actores:

| Actor | Qué es |
|---|---|
| **Vos** | la persona. Pedís, pedís el plan, probás cuando querés, desempatás, mergeás |
| **Claude** | la sesión de Claude Code en el worktree de la tarea. Corre los comandos `/mindstack:*`, lanza agentes, te pregunta |
| **agentes** | `analyst`, `developer`, `qa`, `code-reviewer`, `security-auditor`, `fixer`, `conflict-resolver`. Subagentes con permisos acotados |
| **hooks** | `plan-immutable.sh`, `write-scope.sh`: bloquean lo que un rol no puede escribir |
| **git / GitHub** | commits, worktree, PR |

| Caso | Qué muestra |
|---|---|
| [01 · Un bug, de punta a punta, autónomo](01-fix-autonomous.md) | `/draft` entrevista y reproduce el bug → `/plan` → `/orchestrate`: implementa, revisa, corrige, abre el PR con CI verde. Vos: dos comandos, una frase y el merge |
| [02 · Lo que vos hacés: el borrador](02-draft.md) | `/draft` (SPEC, varias vueltas) → `/plan` o "generá el plan" (PLAN validado, tarea pendiente) → `/draft` sin texto si querés volver → delegar con `/orchestrate` en el worktree |
| [03 · El dev no puede decidir](03-decision-consensus.md) | `DECISION:` → tres analistas → acuerdo, o te preguntan |
| [04 · Revisión con hallazgos, corrección y conflicto](04-review-fix-conflict.md) | ronda 1 con una crítica → `fixer` → ronda 2 limpia → PR → conflicto con main → rebase → merge → finalize |
| [05 · Variantes por tipo de tarea](05-task-types.md) | qué cambia en el flujo según `tipo:` del PLAN: refactor, migración, performance, docs, ci |
| [06 · Varias tareas en paralelo e iteración sobre un PR](06-parallel-and-iterate.md) | dos tareas pendientes → dos worktrees → dos orquestadores → dos PRs; probás uno, falta algo → `/draft "qué falta"` → mismo PR → merge → finalize |

## La respuesta corta a "¿cómo lo uso?"

```
claude -w pagos-timeout                                         # el worktree ES la tarea; vos elegís el nombre
/mindstack:draft "los pagos con timeout se cobran dos veces"   # te entrevista, reproduce, escribe el SPEC. Para.
(comentarios sueltos)                                           # corrigen el SPEC, commit por vuelta
/mindstack:plan                                                 # o "generá el plan": PLAN validado, tarea pendiente, resumen
/mindstack:orchestrate                                          # te sentás a esperar el PR
```

De ahí no para hasta el PR: implementa, testea, revisa con tres agentes, corrige, vuelve a revisar, abre el PR, espera CI verde y te deja el link. Probás en localhost: si está, mergeás y `/mindstack:orchestrate` en `main` cierra la tarea; si falta algo, `/mindstack:draft "qué falta"` y otra vuelta sobre el mismo PR.

Para varias tareas a la vez: un worktree por tarea, cada uno con su sesión; el borrador lo hacés de a uno, los orquestadores corren en paralelo. Caso 06.

Cinco comandos en total, ninguno con el nombre de la tarea: `/install` una vez por proyecto; `/draft`, `/plan` y `/orchestrate` en el día a día (el plan también se pide en palabras); `/rebase` para un PR colgado. Las fases internas (implement, review, fix, pr, conflicts, finalize) no son comandos: las corre el orquestador. Caso 02 muestra tu parte.
