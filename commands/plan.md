---
description: Genera el plan de la tarea de este worktree a partir de su SPEC.md (acoplamiento, tipo, tareas con rol, fechas, Done igual a CI), lo valida, deriva TODO.md y deja la tarea en 1-pending con un resumen de cinco líneas. Equivale a decir "generá el plan" en la conversación de /mindstack:draft. Commits: plan(<slug>): ronda n y pending.
disable-model-invocation: true
---

Cargá la skill `mindstack:workflow`. La tarea es la de este worktree (`git branch --show-current` = `worktree-<slug>`); requiere `docs/plans/0-draft/<slug>/SPEC.md`. Si la tarea está en `1-pending/`, primero volvela a borrador como hace `/mindstack:draft` sin texto, y replanificá. Seguí `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/plan.md` al pie de la letra. Invocar este comando es el pedido explícito de los commits que declara.
