#!/usr/bin/env bash
# Hook UserPromptSubmit. Al tipear /mindstack:orchestrate, en el directorio y la rama que sea, deja el marcador que activa
# orchestrate-stop.sh para ESTA sesión: $(git rev-parse --git-dir)/mindstack-orchestrating/<session_id>,
# con el prompt adentro (el stop distingue el padre de una hija de cola: "/mindstack:orchestrate hija <slug>").
# Uno por sesión: el padre y sus hijas corren en el mismo worktree y no se pisan.
# Lo escribe el hook y no el modelo porque el modelo no conoce su session_id.
set -u
input=$(cat)
if command -v jq >/dev/null 2>&1; then
  prompt=$(jq -r '.prompt // empty' <<<"$input")
  session=$(jq -r '.session_id // empty' <<<"$input")
else
  prompt=$(grep -o '"prompt"[[:space:]]*:[[:space:]]*"[^"]*"' <<<"$input" | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//')
  session=$(grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' <<<"$input" | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//')
fi
grep -Eq '^[[:space:]]*/(mindstack:)?orchestrate\b' <<<"$prompt" || exit 0
id=$(tr -cd 'A-Za-z0-9_-' <<<"$session")
[ -n "$id" ] || exit 0
dir="$(git rev-parse --git-dir 2>/dev/null)/mindstack-orchestrating" || exit 0
[ -f "$dir" ] && rm -f "$dir" # marcador viejo (un archivo por worktree)
mkdir -p "$dir"
# Un padre nuevo limpia marcadores de hijas muertas: si no, el stop creería que hay una corriendo.
grep -Eq 'orchestrate[[:space:]]+hija' <<<"$prompt" || grep -lEs 'orchestrate[[:space:]]+hija' "$dir"/* | xargs -r rm -f
printf '%s\n' "$prompt" >"$dir/$id"
rm -f "$dir/$id.rebotes"
exit 0
