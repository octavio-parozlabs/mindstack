#!/usr/bin/env bash
# Copia turnos_<agente> de config/defaults.conf al maxTurns del frontmatter de agents/<agente>.md.
# Claude Code no deja pasar maxTurns al lanzar el Agent: por eso se escribe en el archivo.
# Uso: sync-agents.sh          → escribe
#      sync-agents.sh --check  → sale 1 si alguno difiere (lo corre hooks/test.sh)
set -u
cd "$(dirname "$0")/.."
mal=0
for f in agents/*.md; do
  a=$(basename "$f" .md)
  n=$(grep -E "^turnos_$a=" config/defaults.conf | cut -d= -f2 | sed 's/[[:space:]]*#.*//; s/[[:space:]]*$//')
  [ -n "$n" ] || { echo "falta turnos_$a en config/defaults.conf"; mal=1; continue; }
  grep -qx "maxTurns: $n" "$f" && continue
  if [ "${1:-}" = --check ]; then echo "$f: maxTurns distinto de turnos_$a=$n"; mal=1
  else sed -i "s/^maxTurns: .*/maxTurns: $n/" "$f"; echo "$f → $n"; fi
done
exit "$mal"
