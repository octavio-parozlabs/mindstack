---
description: Corre las tareas pendientes de este directorio, en su rama. Una: no para hasta dejarla en 4-done (todo commiteado, PR abierto, CI verde, lista para mergear) o en blocked/ con BLOCKED.md: implementa lanzando un developer por tarea, qa después de cada una, consenso ante ambigüedades, cuatro revisores (con verifier sobre la checklist), un approver que decide qué se arregla, correcciones, PR, CI. Varias: pregunta cuáles (si no las nombrás) y las corre en cola, en orden, cada una en una sesión nueva, todas en un solo PR. Sobre una tarea en blocked/, pregunta los motivos y sigue. Hace y pushea todos los commits que las fases declaran. Nunca mergea.
argument-hint: (nada) | <slug> [<slug> …] | hija <slug>
disable-model-invocation: true
---

Pedido: $ARGUMENTS

Cargá la skill `mindstack:workflow`. Las tareas son las de `todolist/` de este directorio, en la rama actual, se llame como se llame. En la rama default (`main`) pará: el PR necesita una rama propia. Sin argumentos: una tarea en curso o bloqueada, esa; una sola pendiente, esa; varias pendientes, cola (§ Cola). Con slugs: esos, en ese orden, en cola. `hija <slug>`: sos una hija de cola, corrés solo esa tarea, sin preguntar, y terminás con commit local en `4-done` o en `blocked/`, sin push. Seguí `${CLAUDE_PLUGIN_ROOT}/skills/workflow/references/orchestrate.md` al pie de la letra: detectá el estado por la carpeta y ejecutá las fases leyendo `references/<fase>.md`. Todo en un turno: terminás solo en `4-done/` con CI verde o en `blocked/` con `BLOCKED.md` ("Un solo turno" de esa referencia; un hook de parada lo verifica). Terminar una tarea o una fase no es una parada. Invocar este comando es el pedido explícito de todos los commits y push que las fases por las que pasa declaran.
