---
description: El borrador de la tarea de este worktree, en diálogo. Con texto: tarea nueva (entrevista, reproducción por qa si es un fix, SPEC.md con un diagrama por caso borde); después tus comentarios corrigen el SPEC y "generá el plan" (o /mindstack:plan) escribe PLAN.md, lo valida y deja la tarea en 1-pending. Sin texto: retoma la tarea a borrador para corregirla. Si la tarea ya tiene PR: abre la tarea hija con lo que falta. Un commit por vuelta. No implementa.
argument-hint: <qué querés hacer> | (nada: retomar) | <qué falta>
disable-model-invocation: true
---

Pedido: $ARGUMENTS

Cargá la skill `mindstack:workflow`. Estás en un worktree (`git branch --show-current` = `worktree-<slug>`); si no, pará: el borrador se hace en el worktree de la tarea (`claude -w <slug>`). La tarea es la de este worktree:

- **No existe la carpeta y hay texto**: tarea nueva, slug = el del worktree. Seguí `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/analyze.md` hasta que el SPEC está escrito, y pará ahí. Desde entonces cada comentario de la persona corrige el SPEC (commit por vuelta); cuando pida el plan, en palabras ("generá el plan", "planificalo") o con `/mindstack:plan`, seguí `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/plan.md`, que termina con la tarea en `1-pending/`.
- **Está en `0-draft/`**: seguí el diálogo donde quedó.
- **Está en `1-pending/` y no hay texto**: retomar. `git mv` a `0-draft/`, `chmod u+w` a SPEC y PLAN, commit `plan(<slug>): reopen`, y preguntá qué quiere corregir.
- **Está en `3-in-review/` con PR y hay texto**: lo que falta. Iteración: seguí `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/iterate.md`.

Invocar este comando es el pedido explícito de los commits que declara.
