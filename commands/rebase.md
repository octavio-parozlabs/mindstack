---
description: Destraba el PR colgado de la rama actual: rebase sobre main, conflictos resueltos cumpliendo las dos intenciones, suite verde, CI verde, push con --force-with-lease, decisiones en CHANGELOG › Conflictos.
disable-model-invocation: true
---

Cargá la skill `mindstack:workflow`. La tarea es la de la rama actual, la del PR (`gh pr view`). Seguí `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/conflicts.md`: lanzá el agente `conflict-resolver`, y después el paso de CI de `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/pr.md` hasta que los checks pasen. Invocar este comando es el pedido explícito del push con `--force-with-lease` y los commits de corrección que hace.
