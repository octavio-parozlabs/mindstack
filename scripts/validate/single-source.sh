#!/usr/bin/env bash
# Una regla, un archivo (CLAUDE.md › Una regla, un archivo). Falla si reaparece una copia de las que ya divergieron:
# un tope escrito como número, la escala de severidad o la tabla de roles fuera de su dueño.
# ponytail: lista de patrones a mano; cuando una copia nueva diverja, se suma su patrón acá.
set -u
cd "$(dirname "$0")/../.."
mal=0
check() { # check "<qué>" "<regex>" <dueño permitido...>
  local que=$1 rx=$2; shift 2
  local excl=(); for d in "$@"; do excl+=(":!$d"); done
  local hits; hits=$(git grep -niIE "$rx" -- '*.md' "${excl[@]}" ':!use-cases/*' 2>/dev/null)
  [ -z "$hits" ] || { echo "✗ $que fuera de $*:"; echo "$hits" | sed 's/^/    /'; mal=1; }
}
check "tope de rondas como número" '([0-9]+|tres|cinco|ocho) rondas (de revisión|de CI)' config/defaults.conf
check "tope de hallazgos como número" '[Mm]áximo 15|máx\. ?3 ' config/defaults.conf
check "escala de severidad" 'explotable por un usuario autenticado|bug en el camino principal' skills/workflow/templates/REVIEW.md
check "tabla de roles" '^\| (Rol|Agente) \| .*Escribe' skills/workflow/references/roles-and-artifacts.md
check "motivos de bloqueo" '^\| Desde \| Motivo \|' skills/workflow/references/orchestrate.md
[ "$mal" -eq 0 ] && echo "single-source: ok"
exit "$mal"
