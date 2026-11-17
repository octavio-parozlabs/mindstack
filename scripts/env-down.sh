#!/usr/bin/env bash
# Baja el entorno de una rama y borra sus volúmenes. Uso, desde su worktree: scripts/env-down.sh <entorno>
# <entorno> = basename del worktree. Nunca en el checkout principal: ahí el proyecto de compose es tu entorno de dev.
set -euo pipefail
entorno=$1
if [ "$(git rev-parse --show-toplevel)" = "$(git worktree list | head -1 | awk '{print $1}')" ]; then
  echo "env-down: esto es el checkout principal; el entorno por rama vive en un worktree" >&2; exit 1
fi
docker compose -p "$entorno" down -v --remove-orphans
rm -f .seed/00-dev.sql
echo "entorno '$entorno' bajado"
