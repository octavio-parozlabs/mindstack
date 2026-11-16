#!/usr/bin/env bash
# Hook SessionStart. Lo que imprime va al contexto de Claude al arrancar.
# 1. Los principios, siempre en contexto: desempatan cuando dos reglas chocan.
cat "${CLAUDE_PLUGIN_ROOT}/PRINCIPLES.md"
echo
# 2. El tablero: una línea por estado con sus tareas.
if [ -d todolist ]; then
  echo "## Tareas (todolist)"
  for d in todolist/[0-4]-*/ todolist/blocked/; do
    [ -d "$d" ] || continue
    estado=$(basename "$d")
    slugs=$(find "$d" -mindepth 1 -maxdepth 1 -type d -printf '%f ' 2>/dev/null)
    echo "- $estado: ${slugs:-—}"
  done
  echo
fi
# 3. El marco, para una sesión que no corre ningún comando.
echo "Marco de trabajo: skill mindstack:workflow (estados, artefactos, roles). Cada rol hace solo su fase; el resto es contexto."
# 4. Avisos. Las carpetas de las tareas en curso viven en la rama de cada worktree: se miran ahí.
main=$(git worktree list 2>/dev/null | head -1 | awk '{print $1}')
avisos=""
while read -r wt; do
  for b in "$wt"/todolist/blocked/*/BLOCKED.md; do
    [ -f "$b" ] || continue
    slug=$(basename "$(dirname "$b")")
    motivo=$(grep -m1 -E '^[0-9]+\. ' "$b" | sed -E 's/^[0-9]+\. //; s/\*\*//g')
    avisos+="⚠ bloqueada: $slug — ${motivo:-ver BLOCKED.md} (retomar: /mindstack:orchestrate en $wt)"$'\n'
  done
done < <(git worktree list 2>/dev/null | awk '{print $1}')
if [ -n "$main" ] && [ "$main" = "$(pwd)" ]; then
  # En main, 4-done llegó por merge: si su worktree sigue vivo, falta limpiar.
  for d in todolist/4-done/*/; do
    [ -d "$d" ] || continue
    slug=$(basename "$d")
    wt=$(git worktree list 2>/dev/null | awk -v b="[worktree-$slug]" '$NF == b {print $1}')
    [ -n "$wt" ] && avisos+="mergeada sin limpiar: $slug → (cd $wt && ${CLAUDE_PLUGIN_ROOT}/scripts/env-down.sh $slug); git worktree remove $wt"$'\n'
  done
fi
[ -n "$avisos" ] && printf '\n## Avisos\n%s' "$avisos"
if [ -n "$main" ] && [ "$main" = "$(pwd)" ]; then
  echo "Sesión en el checkout principal. Una tarea, del borrador al PR listo para mergear: 'claude -w <slug>'."
else
  echo "Worktree: $(git branch --show-current 2>/dev/null). La tarea es este worktree."
fi
exit 0
