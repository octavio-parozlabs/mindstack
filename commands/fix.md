---
description: Cierra la ronda de revisión actual: el corrector aplica cada hallazgo (fix, deuda con vencimiento o rechazo con motivo) y qa testea los fixes. Los fixes quedan en el working tree, sin commit. No pushea.
argument-hint: <slug>
disable-model-invocation: true
---

Slug: $ARGUMENTS

Cargá la skill `mindstack:workflow` y seguí `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/fix.md` al pie de la letra. Invocar este comando es el pedido explícito de los commits que el corrector y qa hacen.
