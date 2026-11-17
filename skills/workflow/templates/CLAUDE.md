# <nombre del proyecto>

<!-- Lo escribe /mindstack:install. Completar "Este proyecto", "Stack" y "Comandos"; el resto es la forma de trabajo y se cambia en el plugin, no acá. -->

## Este proyecto

<!-- Completar. Tres líneas alcanzan. -->
- Qué es:
- Apps y paquetes:
- Entrypoints:

## Cómo se trabaja

La forma de trabajo es el plugin `mindstack`: skill `mindstack:workflow` (estados, artefactos, roles, commits) y sus hooks, que la hacen cumplir. Se respeta; si algo no cierra, PR al plugin, no un atajo en la tarea. Las reglas viven en el plugin y no se copian acá: así una actualización del plugin las cambia en todos los proyectos.

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
