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
  # El backlog no es un estado: solo cuántas hay. Se lee cuando la persona quiere.
  if [ -d todolist/backlog ]; then
    # IDEAS.md es una tabla (una fila por idea, después del separador); PROPUESTAS.md, un ## por propuesta.
    ideas=$(awk '/^\|[-| ]+\|$/{t=1;next} t&&/^\|/{n++} END{print n+0}' todolist/backlog/IDEAS.md 2>/dev/null)
    props=$(grep -cs '^## ' todolist/backlog/PROPUESTAS.md)
    echo "- backlog: ${ideas:-0} ideas tuyas · ${props:-0} propuestas de agentes (todolist/backlog/)"
  fi
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
    # La rama se llama como su primera tarea (último tramo, sin worktree-): claude -w, orca o a mano.
    # ponytail: una cola se detecta por su primera tarea; las siguientes viajan en la misma rama.
    wt=$(git worktree list 2>/dev/null | awk -v s="$slug" '{b=$NF; gsub(/[][]/,"",b); sub(/.*\//,"",b); sub(/^worktree-/,"",b)} b == s {print $1}')
    [ -n "$wt" ] && avisos+="mergeada sin limpiar: $slug → (cd $wt && ${CLAUDE_PLUGIN_ROOT}/scripts/env-down.sh $(basename "$wt")); git worktree remove $wt"$'\n'
  done
fi
[ -n "$avisos" ] && printf '\n## Avisos\n%s' "$avisos"
rama=$(git branch --show-current 2>/dev/null)
default=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
if [ "$rama" = "${default:-main}" ]; then
  echo "Rama $rama: acá no corre ningún comando del flujo. Una rama por PR (claude -w <slug>, orca o a mano)."
else
  echo "Rama: $rama. Las tareas de esta rama viajan en su PR."
fi
exit 0
