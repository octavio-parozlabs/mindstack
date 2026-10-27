#!/usr/bin/env bash
# Hook Stop: Claude no termina el turno con tipos, lint o tests rotos.
# Sale 0 si no hay cambios en el working tree, tampoco archivos nuevos (sesiones de solo lectura).
set -u

[ -z "$(git status --porcelain)" ] && exit 0

fail() {
  echo "No terminaste: $1. Arreglalo antes de parar." >&2
  echo "$2" | tail -40 >&2
  exit 2
}

out=$(npm run --silent typecheck 2>&1) || fail "hay errores de tipos" "$out"
out=$(npm run --silent lint 2>&1)      || fail "lint falla" "$out"
out=$(npx vitest run --reporter=dot 2>&1) || fail "hay tests rojos" "$out"

exit 0
