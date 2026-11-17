---
description: El borrador de la tarea de esta rama, en diálogo. Con texto: tarea nueva (entrevista, reproducción por qa si es un fix, propuesta de UX/UI por designer si toca la interfaz, SPEC.md con un diagrama por caso borde); después tus comentarios corrigen el SPEC y "generá el plan" (o /mindstack:plan) escribe PLAN.md, lo valida y deja la tarea en 1-pending. Sin texto: retoma la tarea a borrador para corregirla. Si la tarea ya tiene PR: abre la iteración con lo que falta. Un commit por vuelta. No implementa.
argument-hint: <qué querés hacer> | (nada: retomar) | <qué falta>
disable-model-invocation: true
---

Pedido: $ARGUMENTS

Cargá la skill `mindstack:workflow` y seguí `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/analyze.md`, empezando por su sección "Entrada": según lo que ya hay en la rama, es una tarea nueva, un comentario, otra tarea de la cola, retomar o una iteración.

Invocar este comando es el pedido explícito de los commits que declara.
