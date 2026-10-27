#!/usr/bin/env bash
# Check de CI para el proyecto que usa mindstack: ningún PR modifica SPEC.md ni PLAN.md fuera de 0-draft/.
# Uso: ci-plans-immutable.sh [base]   (default origin/main). Exit 1 si hay violaciones.
# Sin pathspec a propósito: con pathspec el git mv desde 0-draft aparece como A y esconde ediciones.
set -u
base="${1:-origin/main}"
violaciones=$(git diff --name-status -M100% "$base"...HEAD \
  | awk '$NF ~ /docs\/plans\/[1-4]-[^\/]+\/[^\/]+\/(PLAN|SPEC)\.md$/ && $1 !~ /^(R100|D)$/')
if [ -n "$violaciones" ]; then
  echo "mindstack: SPEC.md/PLAN.md modificados fuera de 0-draft/:" >&2
  echo "$violaciones" >&2
  exit 1
fi
echo "plans-immutable: ok"
