---
description: Abre el PR de una tarea en 3-in-review sin hallazgos críticos ni altos abiertos: hace el único commit del código (feat|fix(<slug>): título), escribe PR.md, push de la rama y gh pr create. No mergea.
argument-hint: <slug>
disable-model-invocation: true
---

Slug: $ARGUMENTS

Cargá la skill `mindstack:workflow` y seguí `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/pr.md` al pie de la letra. Plantilla: `${CLAUDE_PLUGIN_ROOT}/skills/workflow/templates/PR.md`. Invocar este comando es el pedido explícito del commit y el push que hace.
