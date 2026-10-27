---
description: Entrevista a la persona sobre un pedido y escribe docs/plans/0-draft/<slug>/SPEC.md con alcance, supuestos y un diagrama por caso borde. Un commit por ronda de entrevista (spec(<slug>): ronda n). No planifica.
argument-hint: <tema o pedido>
disable-model-invocation: true
---

Tema: $ARGUMENTS

Cargá la skill `mindstack:workflow` y seguí `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/analyze.md` al pie de la letra. Plantilla: `${CLAUDE_PLUGIN_ROOT}/skills/workflow/templates/SPEC.md`. Si faltan las cinco carpetas de estado en `docs/plans/`, crealas con `.gitkeep`.
