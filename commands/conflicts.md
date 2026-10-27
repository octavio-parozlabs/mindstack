---
description: Lanza al resolutor de conflictos sobre la rama de una tarea o un PR: rebase sobre main, suite, push --force-with-lease, decisiones en CHANGELOG › Conflictos.
argument-hint: <slug | #pr>
disable-model-invocation: true
---

Tarea o PR: $ARGUMENTS

Cargá la skill `mindstack:workflow` y seguí `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/conflicts.md`: lanzá el agente `conflict-resolver` con el slug o el número de PR. Invocar este comando es el pedido explícito del push con `--force-with-lease` que hace.
