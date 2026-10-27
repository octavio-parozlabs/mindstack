# <nombre del proyecto>

<!-- Lo escribe /mindstack:install. Completar "Este proyecto", "Stack" y "Comandos"; el resto es la forma de trabajo y se cambia en el plugin, no acá. -->

## Este proyecto

<!-- Completar. Tres líneas alcanzan. -->
- Qué es:
- Apps y paquetes:
- Entrypoints:

## Cómo se trabaja

La forma de trabajo es el plugin `mindstack`. Se respeta; si algo no cierra, PR al plugin, no un atajo en la tarea.

- Una tarea es una carpeta en `docs/plans/<estado>/<slug>/`; la carpeta es el estado. Skill `mindstack:workflow` tiene el detalle. Resumen: `/mindstack:analyze <tema>` (SPEC) → `/mindstack:plan <slug>` (PLAN) → `/mindstack:approve <slug>` → `claude -w <slug>` y `/mindstack:implement <slug>` → probás → `/mindstack:review <slug>` → `/mindstack:fix <slug>` → `/mindstack:pr <slug>` → mergeás → `/mindstack:finalize <slug>`. O `/mindstack:orchestrate <slug>` y te llama cuando te necesita.
- `SPEC.md` y `PLAN.md` no se editan después de aprobados: el hook lo bloquea. Lo que cambia va a `CHANGELOG.md › Decisiones`, o es otra tarea.
- Cada rol escribe sus archivos: el dev no escribe tests ni reviews; QA no toca producción; los revisores no editan código. Invocar `/mindstack:approve`, `implementar`, `revisar`, `corregir`, `pr`, `conflictos`, `finalizar` u `orquestar` es el pedido explícito de los commits y push que cada uno declara.
- Cuando dos reglas chocan o ninguna aplica, deciden los principios que el plugin pone en contexto al arrancar. Si no deciden, preguntar.
- **Nada está listo sin evidencia.** Cada `[x]` en `TODO.md` tiene su fila en `CHANGELOG.md › Cambios` con comando y salida.
- Un refactor grande es otra tarea. En esta, el código entra como está y la deuda queda anotada con issue y vencimiento.
- Leer antes de tocar: `graphify query` si hay grafo, `grep` si no, para saber quién depende de lo que vas a cambiar.

## Stack

<!-- /mindstack:install lo completa: una línea por skill que aplica. -->
- `mindstack:typescript`
- <!-- `mindstack:react` · `mindstack:node-api` · `mindstack:nestjs` -->

## Comandos

<!-- /mindstack:install los completa con los del package.json o equivalente. El Done de cada PLAN.md los usa. -->
```bash
```

## Qué no hacer

- No cambiar el gestor de paquetes, el runner de tests, el formateador ni nada que esté en la tabla "Con qué" de una skill del stack.
- No desactivar reglas de lint o del compilador para que pase. Arreglar la causa.
- No modificar un test para que pase. Si el test estaba mal, decirlo y cambiarlo en un commit aparte, con fila en Decisiones.
- No editar `SPEC.md` ni `PLAN.md` fuera de `0-draft/`. No escribir un `REVIEW-*.md` que no sea de tu rol.
- El código de una tarea no se commitea hasta que la revisión pasa: `/mindstack:pr` hace el único commit de código. Los borradores y los movimientos de estado sí se commitean, uno por ronda.
- No commitear ni pushear fuera de lo que un comando del flujo declara. Nunca crear una rama por iniciativa propia. Nada de `--force`: solo el resolutor, con `--force-with-lease`, sobre la rama de la tarea.
- No trabajar en el checkout principal: cada tarea en su worktree (`claude -w <slug>`).
