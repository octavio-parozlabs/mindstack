---
description: El borrador de una tarea, en diálogo. Con texto: tarea nueva (entrevista, reproducción por qa si es un fix, SPEC.md con un diagrama por caso borde); después tus comentarios corrigen el SPEC y "generá el plan" escribe PLAN.md, lo valida y deja la tarea en 1-pending. Sin texto, en el principal: retoma la tarea activa (o la única pendiente) a borrador para corregirla. En el worktree de una tarea con PR: abre la tarea hija con lo que falta. Un commit por vuelta. No implementa.
argument-hint: <qué querés hacer> | (nada: retomar) | <qué falta>
disable-model-invocation: true
---

Pedido: $ARGUMENTS

Cargá la skill `mindstack:workflow` y mirá dónde estás (`skills/workflow/SKILL.md`, "Qué tarea es"):

- **En el worktree de una tarea que ya tiene PR**: el pedido es lo que falta. Iteración: seguí `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/iterate.md`.
- **Sin texto, en el principal**: retomar. La tarea es la activa de la conversación; si no hay, la única en `1-pending/` o `0-draft/`; si hay varias, preguntá cuál. Si está en `1-pending/`: `git mv` a `0-draft/`, `chmod u+w` a SPEC y PLAN, commit `plan(<slug>): reopen`, y decí qué quiere corregir. Si está en `0-draft/`: seguí el diálogo donde quedó.
- **Con texto**: tarea nueva. Seguí `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/analyze.md` hasta que el SPEC está escrito, y pará ahí. Desde ese momento esta es la tarea activa de la conversación: cada comentario de la persona corrige el SPEC (commit por vuelta); cuando pida el plan ("generá el plan", "dale con el plan", "planificalo"), seguí `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/plan.md`, que termina con la tarea en `1-pending/`.

Invocar este comando es el pedido explícito de los commits que declara.
