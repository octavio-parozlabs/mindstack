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
  echo "Sesión en el checkout principal. Acá solo se cierran tareas mergeadas (/mindstack:orchestrate). Para una tarea, del borrador al PR: 'claude -w <slug>'."
else
  echo "Worktree: $(git branch --show-current 2>/dev/null). La tarea es este worktree."

fi
exit 0
