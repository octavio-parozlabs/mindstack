#!/usr/bin/env bash
# Hook PreToolUse (Edit|Write|MultiEdit|Bash) para el frontmatter `hooks:` de un agente.
# Uso: write-scope.sh '<regex extendida>'   → lo que escribe tiene que matchear, si no exit 2.
# Uso: write-scope.sh --no '<regex>'         → lo que escribe NO tiene que matchear (developer).
# Es la red de contención del rol: QA solo tests, revisores solo su REVIEW, dev nada de tests/SPEC/PLAN/REVIEW.
# En Bash mira los destinos de escritura comunes (>, >>, tee, sed -i, perl -i, cp, mv, rm, truncate, touch).
# ponytail: heurística, igual que plan-immutable.sh; un script hecho para esquivarla pasa. Atrapa el atajo, no al atacante.
set -u
modo=si
if [ "${1:-}" = "--no" ]; then modo=no; shift; fi
regex="${1:?regex}"
input=$(cat)
if command -v jq >/dev/null 2>&1; then
  file=$(jq -r '.tool_input.file_path // empty' <<<"$input")
  cmd=$(jq -r '.tool_input.command // empty' <<<"$input")
else
  file=$(grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' <<<"$input" | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//')
  cmd=$(grep -o '"command"[[:space:]]*:[[:space:]]*"\([^"\\]\|\\.\)*"' <<<"$input" | head -1 | sed 's/^"command"[[:space:]]*:[[:space:]]*"//; s/"$//')
fi

# Destinos que escribe un comando de shell, uno por línea.
destinos() {
  sed -E 's/(&&|\|\||;|\|)/\n/g' <<<"$1" | while IFS= read -r seg; do
    grep -oE '[0-9&]?>>?[[:space:]]*[^[:space:]&|;<>]+' <<<"$seg" | sed -E 's/^[0-9&]?>>?[[:space:]]*//'
    read -r -a w <<<"$seg"
    [ "${#w[@]}" -gt 0 ] || continue
    case "${w[0]}" in
      tee|rm|truncate|touch) for a in "${w[@]:1}"; do [[ $a == -* ]] || echo "$a"; done ;;
      cp|mv) echo "${w[-1]}" ;;
      sed|perl) [[ " ${w[*]} " == *" -i"* ]] && echo "${w[-1]}" ;;
    esac
  done | tr -d "\"'" | grep -vE '^(/dev/|/tmp/|$)|\$\('
}

viola() { # viola <ruta> → 0 si la ruta rompe el alcance del rol
  local f=$1; [[ $f == /* ]] || f="$PWD/$f"
  if [ "$modo" = si ]; then ! grep -Eq "$regex" <<<"$f"; else grep -Eq "$regex" <<<"$f"; fi
}

if [ -n "$file" ]; then rutas=$file
elif [ -n "$cmd" ]; then rutas=$(destinos "$cmd")
else exit 0; fi
while IFS= read -r r; do
  [ -n "$r" ] || continue
  if viola "$r"; then
    if [ "$modo" = si ]; then echo "mindstack: este rol solo escribe archivos que matchean: $regex ('$r' no)." >&2
    else echo "mindstack: este rol no escribe archivos que matchean: $regex ('$r'). Pedilo en tu respuesta." >&2; fi
    exit 2
  fi
done <<<"$rutas"
exit 0
