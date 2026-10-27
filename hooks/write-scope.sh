#!/usr/bin/env bash
# Hook PreToolUse (Edit|Write|MultiEdit) para el frontmatter `hooks:` de un agente.
# Uso: write-scope.sh '<regex extendida>'   → el file_path tiene que matchear, si no exit 2.
# Uso: write-scope.sh --no '<regex>'         → el file_path NO tiene que matchear (dev, corrector).
# Es la red de contención del rol: QA solo tests, revisores solo su REVIEW, dev nada de tests/SPEC/PLAN/REVIEW.
set -u
modo=si
if [ "${1:-}" = "--no" ]; then modo=no; shift; fi
regex="${1:?regex}"
input=$(cat)
if command -v jq >/dev/null 2>&1; then
  file=$(jq -r '.tool_input.file_path // empty' <<<"$input")
else
  file=$(grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' <<<"$input" | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//')
fi
[ -z "$file" ] && exit 0
if [ "$modo" = si ]; then
  grep -Eq "$regex" <<<"$file" && exit 0
  echo "mindstack: este rol solo escribe archivos que matchean: $regex" >&2
  exit 2
else
  grep -Eq "$regex" <<<"$file" || exit 0
  echo "mindstack: este rol no escribe archivos que matchean: $regex. Pedilo en tu respuesta." >&2
  exit 2
fi
