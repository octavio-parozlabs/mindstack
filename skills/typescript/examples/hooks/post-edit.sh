#!/usr/bin/env bash
# Hook PostToolUse (Edit|Write): formatea y lintea el archivo recién tocado.
# Biome formatea siempre. ESLint con --fix; lo que no se arregla solo vuelve a Claude por stderr (exit 2).
set -u

file=$(jq -r '.tool_input.file_path // empty')
case "$file" in
  *.ts | *.tsx | *.mts | *.cts) ;;
  *) exit 0 ;;
esac

npx biome format --write "$file" >/dev/null
out=$(npx eslint --cache --fix "$file" 2>&1) && exit 0

echo "ESLint en $file:" >&2
echo "$out" | tail -30 >&2
exit 2
