---
description: Cierra la ronda de revisión actual: el corrector aplica cada hallazgo (fix, deuda con vencimiento o rechazo con motivo) y qa testea los fixes. Hace un commit por hallazgo. No pushea.
argument-hint: <slug>
disable-model-invocation: true
---

Slug: $ARGUMENTS

Cargá la skill `mindstack:workflow` y seguí `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/fix.md` al pie de la letra. Invocar este comando es el pedido explícito de los commits que el corrector y qa hacen.
