---
description: Ejecuta una tarea de 1-pending en su worktree con ralph-loop, una tarea del TODO por vuelta, qa después de cada una, consenso ante ambigüedades. Mueve a 2-in-progress y hace un commit por tarea. No abre el PR, no pushea.
argument-hint: <slug>
disable-model-invocation: true
---

Slug: $ARGUMENTS

Cargá la skill `mindstack:workflow` y seguí `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/implement.md` al pie de la letra, incluido el bloque "Dónde estás" y el `/ralph-loop` con su prompt. Rol del dev: `${CLAUDE_PLUGIN_ROOT}/agents/developer.md`. Consenso: `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/consensus.md`. Invocar este comando es el pedido explícito de los commits que el loop hace en la rama de la tarea.
