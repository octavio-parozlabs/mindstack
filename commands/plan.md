---
description: Lee el SPEC de una tarea en 0-draft y el código que toca, y escribe PLAN.md (acoplamiento, tareas con rol, fechas, Done) y el CHANGELOG.md vacío. No implementa, no commitea.
argument-hint: <slug>
disable-model-invocation: true
---

Slug: $ARGUMENTS

Cargá la skill `mindstack:workflow` y seguí `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/plan.md` al pie de la letra. Plantillas: `${CLAUDE_PLUGIN_ROOT}/skills/workflow/templates/PLAN.md` y `CHANGELOG.md`. Principios: `${CLAUDE_PLUGIN_ROOT}/references/PRINCIPLES.md`.
