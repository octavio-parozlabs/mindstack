---
description: Recorre el flujo entero de una tarea desde el estado en que está (analizar → planificar → aprobar → implementar → revisar ↔ corregir → pr) y para donde hace falta la persona. Hace y pushea los commits que cada fase declara. Nunca mergea ni finaliza.
argument-hint: <slug | tema>
disable-model-invocation: true
---

Tarea: $ARGUMENTS

Cargá la skill `mindstack:workflow` y seguí `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/orchestrate.md` al pie de la letra: detectá el estado por la carpeta y ejecutá las fases leyendo `references/<fase>.md`, exactamente como lo haría cada comando. Invocar este comando es el pedido explícito de todos los commits y push que las fases por las que pasa declaran.
