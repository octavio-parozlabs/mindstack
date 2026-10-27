---
description: Aprueba la tarea activa de la conversación (la que se está borrando con /mindstack:draft): congela SPEC.md y PLAN.md, deriva TODO.md y la mueve de 0-draft a 1-pending. Un commit. No pushea.
disable-model-invocation: true
---

Cargá la skill `mindstack:workflow`. La tarea es la activa de esta conversación (`skills/workflow/SKILL.md`, "Qué tarea es"); si no hay una y en `docs/plans/0-draft/` hay exactamente una, es esa; si hay varias, preguntá cuál. Seguí `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/approve.md` al pie de la letra. Invocar este comando es el pedido explícito del commit que hace.
