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
    # IDEAS.md: un "- " sin sangría por idea (los subítems van sangrados); PROPUESTAS.md, un ## por propuesta.
    ideas=$(grep -cs '^- ' todolist/backlog/IDEAS.md)
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
rama=$(git branch --show-current 2>/dev/null)
default=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
if [ -n "$main" ] && [ "$main" = "$(pwd)" ] && [ "$rama" = "${default:-main}" ]; then
  # En la rama default, 4-done llegó por merge: si su worktree sigue vivo, falta limpiar.
  for d in todolist/4-done/*/; do
    [ -d "$d" ] || continue
    slug=$(basename "$d")
    # La rama se llama como su primera tarea (último tramo, sin worktree-): claude -w, orca o a mano.
    # ponytail: una cola se detecta por su primera tarea; las siguientes viajan en la misma rama.
    # --porcelain: la columna de la rama no se corre con "locked" o "prunable". El principal nunca se propone.
    wt=$(git worktree list --porcelain 2>/dev/null | awk -v s="$slug" -v m="$main" '/^worktree /{p=substr($0,10)} /^branch /{b=$2; sub(/^refs\/heads\//,"",b); sub(/.*\//,"",b); sub(/^worktree-/,"",b); if (b == s && p != m) print p}')
    [ -n "$wt" ] && avisos+="mergeada sin limpiar: $slug → (cd $wt && ${CLAUDE_PLUGIN_ROOT}/scripts/env-down.sh $(basename "$wt")); git worktree remove $wt"$'\n'
  done
fi
# Deuda vencida: en las tareas de esta rama (o las mergeadas, en la default), filas de TECHNICAL_DEBT.md con Vence < hoy.
hoy=$(date +%F)
vencidas=$(for f in todolist/*/*/TECHNICAL_DEBT.md; do
  [ -f "$f" ] || continue
  slug=$(basename "$(dirname "$f")")
  awk -F'|' -v h="$hoy" -v s="$slug" '$7 ~ /[0-9]{4}-[0-9]{2}-[0-9]{2}/ { gsub(/ /,"",$7); gsub(/^ +| +$/,"",$4); if ($7 < h) print "deuda vencida: " s " — " $4 " (venció " $7 ")" }' "$f"
done)
if [ -n "$vencidas" ]; then
  avisos+="$(head -5 <<<"$vencidas")"$'\n'
  n=$(wc -l <<<"$vencidas"); [ "$n" -gt 5 ] && avisos+="… y $((n - 5)) más (todolist/*/*/TECHNICAL_DEBT.md)"$'\n'
fi
[ -n "$avisos" ] && printf '\n## Avisos\n%s' "$avisos"
if [ "$rama" = "${default:-main}" ]; then
  echo "Rama $rama: acá no corre ningún comando del flujo. Una rama por PR (claude -w <slug>, orca o a mano)."
else
  echo "Rama: $rama. Las tareas de esta rama viajan en su PR."
fi
exit 0
