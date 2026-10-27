#!/usr/bin/env bash
# Hook SessionStart. Lo que imprime va al contexto de Claude al arrancar.
# 1. Los principios, siempre en contexto: desempatan cuando dos reglas chocan.
cat "${CLAUDE_PLUGIN_ROOT}/references/PRINCIPLES.md"
echo
# 2. El tablero: una línea por estado con sus tareas.
if [ -d docs/plans ]; then
  echo "## Tareas (docs/plans)"
  for d in docs/plans/[0-4]-*/; do
    [ -d "$d" ] || continue
    estado=$(basename "$d")
    slugs=$(find "$d" -mindepth 1 -maxdepth 1 -type d -printf '%f ' 2>/dev/null)
    echo "- $estado: ${slugs:-—}"
  done
  echo
fi
# 3. Avisos del entorno.
main=$(git worktree list 2>/dev/null | head -1 | awk '{print $1}')
if [ -n "$main" ] && [ "$main" = "$(pwd)" ]; then
  activas=$(find docs/plans/1-pending docs/plans/2-in-progress -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
  if [ "$activas" -gt 0 ]; then
    echo "Sesión en el checkout principal con tareas activas. Para implementar: salir y abrir con 'claude -w <slug>'."
  fi
fi
exit 0
