#!/usr/bin/env bash
# Lee la configuración de mindstack: .claude/mindstack.conf del proyecto pisa a config/defaults.conf del plugin.
# Uso: config.sh <clave>   → el valor (sale 1 si no está o está vacío)
#      config.sh           → todas las claves con su valor efectivo
set -u
defaults="$(dirname "$0")/../config/defaults.conf"
proyecto="$(git rev-parse --show-toplevel 2>/dev/null)/.claude/mindstack.conf"
valor() { local v f fuentes=("$proyecto" "$defaults")
  [[ $1 == turnos_* ]] && fuentes=("$defaults") # maxTurns vive en agents/*.md: el proyecto no lo pisa
  for f in "${fuentes[@]}"; do
  grep -qE "^$1=" "$f" 2>/dev/null || continue # el primero que tiene la clave manda, aunque la deje vacía
  v=$(grep -E "^$1=" "$f" | tail -1 | cut -d= -f2- | sed 's/[[:space:]]*#.*//; s/[[:space:]]*$//')
  [ -n "$v" ] && echo "$v"; [ -n "$v" ]; return
done; return 1; }
if [ $# -gt 0 ]; then valor "$1"; exit; fi
for k in $(grep -oE '^[a-z_-]+=' "$defaults" | tr -d =); do echo "$k=$(valor "$k")"; done
