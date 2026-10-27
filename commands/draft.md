---
description: Borrador de una tarea nueva, en diálogo: entrevista, reproducción por qa si es un fix, SPEC.md con un diagrama por caso borde. Después la conversación sigue sola: tus comentarios corrigen el SPEC, y cuando pedís el plan se genera PLAN.md. En el worktree de una tarea con PR, abre la tarea hija con lo que falta. Un commit por vuelta. No aprueba, no implementa.
argument-hint: <qué querés hacer>
disable-model-invocation: true
---

Pedido: $ARGUMENTS

Cargá la skill `mindstack:workflow` y mirá dónde estás (`skills/workflow/SKILL.md`, "Qué tarea es"):

- **En el worktree de una tarea que ya tiene PR**: el pedido es lo que falta. Iteración: seguí `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/iterate.md`.
- **Si no**: tarea nueva. Seguí `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/analyze.md` hasta que el SPEC está escrito, y pará ahí. Desde ese momento esta es la tarea activa de la conversación: cada comentario de la persona corrige el SPEC (commit por vuelta); cuando pida el plan ("generá el plan", "dale con el plan", "planificalo"), seguí `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/plan.md`; después sus comentarios corrigen SPEC o PLAN según lo que diga, hasta que corra `/mindstack:approve`.

Invocar este comando es el pedido explícito de los commits por vuelta que declara.
