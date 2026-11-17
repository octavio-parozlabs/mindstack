---
description: Revisa que esta máquina y este repo tengan lo que el flujo da por hecho (gh con sesión, docker levantado si hay compose, node, jq, permisos para no frenar, tablero). No instala ni cambia nada.
disable-model-invocation: true
---

Corré `bash ${CLAUDE_PLUGIN_ROOT}/scripts/doctor.sh` y mostrá la salida tal cual. Debajo, por cada `✗` y cada `⚠`, una línea con el comando que lo arregla. No instales ni cambies nada: lo arregla la persona. Si no hay `✗`: "Listo para `/mindstack:orchestrate`".
