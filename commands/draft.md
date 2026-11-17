---
description: El borrador de la tarea de esta rama, en diálogo. Con texto: tarea nueva (entrevista, reproducción por qa si es un fix, propuesta de UX/UI por designer si toca la interfaz, SPEC.md con un diagrama por caso borde); después tus comentarios corrigen el SPEC y "generá el plan" (o /mindstack:plan) escribe PLAN.md, lo valida y deja la tarea en 1-pending. Sin texto: retoma la tarea a borrador para corregirla. Si la tarea ya tiene PR: abre la iteración con lo que falta. Un commit por vuelta. No implementa.
argument-hint: <qué querés hacer> | (nada: retomar) | <qué falta>
disable-model-invocation: true
---

Pedido: $ARGUMENTS

Cargá la skill `mindstack:workflow`. Trabajás sobre este directorio y su rama, sin mirar cómo se llama ni si es un worktree. En la rama default (`main`) pará: el PR necesita una rama propia. Según las tareas de esta rama en `todolist/` (las que trae la rama respecto de la base: `git diff --name-only origin/main...HEAD -- todolist/`; las de `4-done/` que vinieron de `main` no cuentan):

- **No hay ninguna tarea y hay texto**: tarea nueva, slug según `analyze.md › Slug`. Seguí `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/analyze.md` hasta que el SPEC está escrito, y pará ahí. Desde entonces cada comentario de la persona corrige el SPEC (commit por vuelta); cuando pida el plan, en palabras ("generá el plan", "planificalo") o con `/mindstack:plan`, seguí `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/plan.md`, que termina con la tarea en `1-pending/`.
- **El texto empieza con `backlog:`**: tarea nueva desde una entrada del backlog; `analyze.md › Si sale del backlog`.
- **Hay una en `0-draft/`**: el texto es un comentario sobre ella; seguí el diálogo donde quedó. Si la persona dice que es otra tarea, primero esa termina en `1-pending/`.
- **Todas en `1-pending/` o más adelante, ninguna con PR, y hay texto**: otra tarea para la cola de esta rama, con su propio slug (`analyze.md › Slug`); viajará en el mismo PR (`orchestrate.md › Cola`).
- **Hay en `1-pending/` y no hay texto**: retomar; si son varias, preguntá cuál. `git mv` a `0-draft/`, `chmod u+w` a SPEC y PLAN, commit `plan(<slug>): reopen`, y preguntá qué quiere corregir.
- **La rama ya tiene PR (`gh pr view`) y hay texto**: lo que falta. Iteración: seguí `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/iterate.md`.

Invocar este comando es el pedido explícito de los commits que declara.
