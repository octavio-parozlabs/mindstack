#!/usr/bin/env bash
# Baja el stack de un plan y borra sus volúmenes. Uso: scripts/env-down.sh <slug>
set -euo pipefail
slug=$1
docker compose -p "$slug" down -v --remove-orphans
rm -f ".env.$slug" .seed/00-dev.sql
echo "entorno '$slug' bajado"
