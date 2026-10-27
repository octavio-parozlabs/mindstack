---
description: En el worktree de una tarea aprobada, no para hasta dejar el PR abierto con CI verde: implementa con ralph-loop, qa después de cada tarea, consenso ante ambigüedades, tres revisores, corrector, PR, CI. En main con el PR mergeado, cierra la tarea (4-done). Hace y pushea todos los commits que las fases declaran. Nunca mergea.
disable-model-invocation: true
---

Cargá la skill `mindstack:workflow`. La tarea es la del worktree en que estás (rama `worktree-<slug>`); en `main`, la que la persona nombre o la única en `3-in-review/` con PR mergeado (`skills/workflow/SKILL.md`, "Qué tarea es"). Seguí `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/orchestrate.md` al pie de la letra: detectá el estado por la carpeta y ejecutá las fases leyendo `references/<fase>.md`. Parás solo donde esa referencia dice que hace falta la persona. Invocar este comando es el pedido explícito de todos los commits y push que las fases por las que pasa declaran.
