---
description: Congela SPEC.md y PLAN.md de una tarea, deriva TODO.md y la mueve de 0-draft a 1-pending. Hace un commit (plan(<slug>): approve). No pushea.
argument-hint: <slug>
disable-model-invocation: true
---

Slug: $ARGUMENTS

Cargá la skill `mindstack:workflow` y seguí `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/approve.md` al pie de la letra. Plantilla: `${CLAUDE_PLUGIN_ROOT}/skills/workflow/templates/TODO.md`. Invocar este comando es el pedido explícito del commit que hace.
