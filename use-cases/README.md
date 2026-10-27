# Casos de uso

Cómo interactuás con mindstack, de punta a punta, con diagramas de secuencia. Actores:

| Actor | Qué es |
|---|---|
| **Vos** | la persona. Pedís, aprobás, probás cuando querés, desempatás, mergeás |
| **Claude** | la sesión principal de Claude Code. Corre los comandos `/mindstack:*`, lanza agentes, te pregunta |
| **agentes** | `analyst`, `developer`, `qa`, `code-reviewer`, `security-auditor`, `fixer`, `conflict-resolver`. Subagentes con permisos acotados |
| **hooks** | `plan-immutable.sh`, `write-scope.sh`: bloquean lo que un rol no puede escribir |
| **git / GitHub** | commits, worktree, PR |

| Caso | Qué muestra |
|---|---|
| [01 · Un bug, de punta a punta, autónomo](01-fix-autonomous.md) | `/draft` entrevista y reproduce el bug → `/approve` → `/orchestrate`: implementa, revisa, corrige, abre el PR con CI verde. Vos: tres comandos y el merge |
| [02 · Lo que vos hacés: borrador y aprobación](02-draft-and-approve.md) | `/draft` (SPEC, varias vueltas) → "generá el plan" (PLAN, varias vueltas) → `/approve` → delegar con `/orchestrate` en el worktree |
| [03 · El dev no puede decidir](03-decision-consensus.md) | `DECISION:` → tres analistas → acuerdo, o te preguntan |
| [04 · Revisión con hallazgos, corrección y conflicto](04-review-fix-conflict.md) | ronda 1 con una crítica → `fixer` → ronda 2 limpia → PR → conflicto con main → rebase → merge → finalize |
| [05 · Variantes por tipo de tarea](05-task-types.md) | qué cambia en el flujo según `tipo:` del PLAN: refactor, migración, performance, docs, ci |
| [06 · Varias tareas en paralelo e iteración sobre un PR](06-parallel-and-iterate.md) | dos tareas aprobadas → dos worktrees → dos orquestadores → dos PRs; probás uno, falta algo → `/draft "qué falta" (en el worktree)` → mismo PR → merge → finalize |

## La respuesta corta a "¿cómo lo uso?"

```
/mindstack:draft "los pagos con timeout se cobran dos veces"   # te entrevista, reproduce, escribe el SPEC. Para.
(comentarios sueltos)                                           # corrigen el SPEC, commit por vuelta
generá el plan                                                  # una frase. Leés, comentás.
/mindstack:approve                                              # el ok
claude -w pagos-timeout                                         # el worktree; el slug lo inventó el analista
/mindstack:orchestrate                                          # te sentás a esperar el PR
```

De ahí no para hasta el PR: implementa, testea, revisa con tres agentes, corrige, vuelve a revisar, abre el PR, espera CI verde y te deja el link. Probás en localhost: si está, mergeás y `/mindstack:orchestrate` en `main` cierra la tarea; si falta algo, `/mindstack:draft "qué falta"` y otra vuelta sobre el mismo PR.

Para varias tareas a la vez: analizás, planificás y aprobás cada una en el principal; abrís un worktree por tarea y corrés `/mindstack:orchestrate` en cada uno. Caso 06.

Cinco comandos en total, ninguno con el nombre de la tarea: `/install` una vez por proyecto; `/draft`, `/approve` y `/orchestrate` en el día a día; `/rebase` para un PR colgado. Las fases internas (implement, review, fix, pr, conflicts, finalize) no son comandos: las corre el orquestador. Caso 02 muestra tu parte.
