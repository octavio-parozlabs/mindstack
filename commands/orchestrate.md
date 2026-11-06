---
description: En el worktree de una tarea pendiente, no para hasta dejar el PR abierto con CI verde: implementa lanzando un developer por tarea, qa después de cada una, consenso ante ambigüedades, tres revisores, corrector, PR, CI. En main con el PR mergeado, cierra la tarea (4-done). Hace y pushea todos los commits que las fases declaran. Nunca mergea.
disable-model-invocation: true
---

Cargá la skill `mindstack:workflow`. La tarea es la de este worktree (`git branch --show-current` = `worktree-<slug>`). En `main`, es la que la persona nombre o la única en `3-in-review/` con PR mergeado. Seguí `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/orchestrate.md` al pie de la letra: detectá el estado por la carpeta y ejecutá las fases leyendo `references/<fase>.md`. Todo en un turno: parás solo en las paradas de "Un solo turno" de esa referencia. Terminar una tarea o una fase no es una parada. Invocar este comando es el pedido explícito de todos los commits y push que las fases por las que pasa declaran.
