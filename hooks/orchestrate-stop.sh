#!/usr/bin/env bash
# Hook Stop global. El orquestador termina el turno solo en dos salidas:
#   - todas las tareas de la rama en todolist/4-done/ y el PR con CI verde (listo para mergear)
#   - una tarea en todolist/blocked/<slug>/ con BLOCKED.md (necesita a la persona)
# Solo actúa si orchestrate-start.sh dejó el marcador de ESTA sesión en el git dir del worktree.
# En un worktree, todolist/ tiene lo mergeado de main (4-done) más las tareas de esta rama (padre e hijas).
# Exit 2 no deja parar y el stderr vuelve al modelo como lo que le falta. Exit 0 deja parar.
set -u

input=$(cat)
if command -v jq >/dev/null 2>&1; then
  session=$(jq -r '.session_id // empty' <<<"$input")
else
  session=$(grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' <<<"$input" | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//')
fi

gitdir=$(git rev-parse --git-dir 2>/dev/null) || exit 0
marker="$gitdir/mindstack-orchestrating"
[ -f "$marker" ] || exit 0
[ -n "$session" ] && [ "$(cat "$marker")" = "$session" ] || exit 0
root=$(git rev-parse --show-toplevel)
salir() { rm -f "$marker"; exit 0; }

if compgen -G "$root/todolist/blocked/*/BLOCKED.md" >/dev/null; then salir; fi

abiertas=$(find "$root"/todolist/{1-pending,2-in-progress,3-in-review} -mindepth 1 -maxdepth 1 -type d -printf '%P(%h) ' 2>/dev/null | sed "s#$root/todolist/##g")
if [ -n "$abiertas" ]; then
  echo "mindstack: tareas sin terminar: $abiertas. El turno termina en 4-done con CI verde o en blocked/ con BLOCKED.md (orchestrate.md › Un solo turno)." >&2
  exit 2
fi

# ponytail: sin gh no se puede mirar el CI; se deja parar antes que trabar la sesión.
command -v gh >/dev/null 2>&1 || salir
if ! gh pr view >/dev/null 2>&1; then
  echo "mindstack: la tarea está en 4-done pero la rama no tiene PR. Seguí la fase pr (pr.md)." >&2
  exit 2
fi
out=$(gh pr checks 2>&1); rc=$?
if [ "$rc" -eq 0 ] || grep -qi 'no checks reported' <<<"$out"; then salir; fi
if [ "$rc" -eq 8 ]; then
  echo "mindstack: CI pendiente. Esperá con 'gh pr checks --watch' y seguí pr.md." >&2
else
  echo "mindstack: CI rojo. Seguí pr.md: fixer ci → qa → push, o blocked/ si es ajeno o la ronda 3." >&2
fi
exit 2
