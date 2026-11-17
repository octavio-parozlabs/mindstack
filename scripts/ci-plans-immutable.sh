#!/usr/bin/env bash
# Check de CI para el proyecto que usa mindstack: ningún PR modifica SPEC.md, PLAN.md ni wireframes/ fuera de 0-draft/.
# Uso: ci-plans-immutable.sh [base]   (default origin/main). Exit 1 si hay violaciones.
# Commit por commit y no base...HEAD: una tarea nueva no existe en la base, y el diff total la mostraría como A
# en 1-pending/ o 4-done/. Por commit, sacarla de 0-draft es un R100 (git mv) y editarla después es un M.
# Sin pathspec a propósito: con pathspec el git mv desde 0-draft aparece como A y esconde ediciones.
set -u
base="${1:-origin/main}"
violaciones=$(for c in $(git rev-list --no-merges "$base"..HEAD); do
  git diff-tree -r --no-commit-id --name-status -M100% "$c^" "$c" \
    | awk -v c="${c:0:7}" '$NF ~ /todolist\/([1-4]-[^\/]+|blocked)\/[^\/]+\/((PLAN|SPEC)\.md|wireframes\/.+)$/ && $1 !~ /^(R100|D)$/ {print c, $0}'
done)
if [ -n "$violaciones" ]; then
  echo "mindstack: SPEC.md/PLAN.md/wireframes modificados fuera de 0-draft/:" >&2
  echo "$violaciones" >&2
  exit 1
fi
echo "plans-immutable: ok"
