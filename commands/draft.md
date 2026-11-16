---
description: El borrador de la tarea de este worktree, en diálogo. Con texto: tarea nueva (entrevista, reproducción por qa si es un fix, propuesta de UX/UI por designer si toca la interfaz, SPEC.md con un diagrama por caso borde); después tus comentarios corrigen el SPEC y "generá el plan" (o /mindstack:plan) escribe PLAN.md, lo valida y deja la tarea en 1-pending. Sin texto: retoma la tarea a borrador para corregirla. Si la tarea ya tiene PR: abre la tarea hija con lo que falta. Un commit por vuelta. No implementa.
argument-hint: <qué querés hacer> | (nada: retomar) | <qué falta>
disable-model-invocation: true
---

Pedido: $ARGUMENTS

Cargá la skill `mindstack:workflow`. Estás en un worktree (`git branch --show-current` = `worktree-<slug>`); si no, pará: el borrador se hace en un worktree (`claude -w <slug>`). Según lo que ya hay en este worktree:

- **No hay ninguna tarea y hay texto**: tarea nueva, slug = el del worktree. Seguí `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/analyze.md` hasta que el SPEC está escrito, y pará ahí. Desde entonces cada comentario de la persona corrige el SPEC (commit por vuelta); cuando pida el plan, en palabras ("generá el plan", "planificalo") o con `/mindstack:plan`, seguí `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/plan.md`, que termina con la tarea en `1-pending/`.
- **El texto empieza con `backlog:`**: tarea nueva desde una entrada del backlog; `analyze.md › Si sale del backlog`.
- **Hay una en `0-draft/`**: el texto es un comentario sobre ella; seguí el diálogo donde quedó. Si la persona dice que es otra tarea, primero esa termina en `1-pending/`.
- **Todas en `1-pending/` o más adelante, ninguna con PR, y hay texto**: otra tarea para la cola de este worktree, con su propio slug (`analyze.md › Slug`); viajará en el mismo PR (`orchestrate.md › Cola`).
- **Hay en `1-pending/` y no hay texto**: retomar; si son varias, preguntá cuál. `git mv` a `0-draft/`, `chmod u+w` a SPEC y PLAN, commit `plan(<slug>): reopen`, y preguntá qué quiere corregir.
- **La rama ya tiene PR (`gh pr view`) y hay texto**: lo que falta. Iteración: seguí `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/iterate.md`.

Invocar este comando es el pedido explícito de los commits que declara.
