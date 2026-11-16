#!/usr/bin/env bash
# Hook UserPromptSubmit. Al tipear /mindstack:orchestrate en el worktree de una tarea, deja el marcador
# que activa orchestrate-stop.sh para ESTA sesión: $(git rev-parse --git-dir)/mindstack-orchestrating.
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
[ -n "$session" ] || exit 0
case "$(git branch --show-current 2>/dev/null)" in worktree-*) ;; *) exit 0 ;; esac
echo "$session" >"$(git rev-parse --git-dir)/mindstack-orchestrating"
exit 0
