---
description: Lanza qa (verificar), code-reviewer y security-auditor en paralelo sobre una tarea con TODO completo y Done verde; cada uno escribe su REVIEW-*.md. La primera ronda mueve a 3-in-review. Hace un commit por ronda solo con los REVIEW-*.md; el código sigue sin commitear. No pushea.
argument-hint: <slug>
disable-model-invocation: true
---

Slug: $ARGUMENTS

Cargá la skill `mindstack:workflow` y seguí `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/review.md` al pie de la letra: los tres `Agent` van en un solo turno. Invocar este comando es el pedido explícito de los commits que declara.
