#!/usr/bin/env bash
# Hook PreToolUse global (Edit|Write|MultiEdit|NotebookEdit|Bash).
# Red de contención: SPEC.md y PLAN.md no se editan fuera de docs/plans/0-draft/.
# Exit 2 bloquea la herramienta y el mensaje de stderr vuelve al modelo. Exit 0 deja pasar.
# Recibe por stdin el JSON del hook: { tool_name, tool_input: { file_path | command }, agent_type? ... }
set -u

input=$(cat)

if command -v jq >/dev/null 2>&1; then
  tool=$(jq -r '.tool_name // empty' <<<"$input")
  file=$(jq -r '.tool_input.file_path // empty' <<<"$input")
  cmd=$(jq -r '.tool_input.command // empty' <<<"$input")
  agent=$(jq -r '.agent_type // empty' <<<"$input")
else
  # ponytail: sin jq, extracción por grep; alcanza para los campos planos que miramos.
  tool=$(grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' <<<"$input" | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//')
  file=$(grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' <<<"$input" | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//')
  cmd=$(grep -o '"command"[[:space:]]*:[[:space:]]*"\([^"\\]\|\\.\)*"' <<<"$input" | head -1 | sed 's/^"command"[[:space:]]*:[[:space:]]*"//; s/"$//')
  agent=$(grep -o '"agent_type"[[:space:]]*:[[:space:]]*"[^"]*"' <<<"$input" | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//')
fi

CONGELADO='docs/plans/[1-4]-[^/ ]+/[^/ ]+/(PLAN|SPEC)\.md'
REVIEW='docs/plans/[0-4]-[^/ ]+/[^/ ]+/REVIEW-(qa|code|security)\.md'
MSG_CONGELADO='mindstack: PLAN.md y SPEC.md son inmutables fuera de 0-draft/. Lo que cambia va a CHANGELOG.md › Decisiones, o es otra tarea.'

case "$tool" in
  Edit|Write|MultiEdit|NotebookEdit)
    if grep -Eq "$CONGELADO" <<<"$file"; then
      echo "$MSG_CONGELADO" >&2
      exit 2
    fi
    # REVIEW-*.md: solo su rol. Si el hook trae agent_type, se verifica; si no lo trae (sesión principal
    # o versión sin el campo), se deja pasar y la contención queda en el prompt y en write-scope.sh del agente.
    if [ -n "$agent" ] && grep -Eq "$REVIEW" <<<"$file"; then
      rol=$(sed -E 's#.*/REVIEW-(qa|code|security)\.md#\1#' <<<"$file")
      case "$rol:$agent" in
        qa:qa|code:code-reviewer|security:security-auditor) ;;
        *) echo "mindstack: REVIEW-$rol.md lo escribe solo su rol, no '$agent'." >&2; exit 2 ;;
      esac
    fi
    ;;
  Bash)
    # Heurística: el comando nombra un archivo congelado Y contiene un operador que lo escribe.
    # `git mv` de la carpeta pasa porque no nombra PLAN.md/SPEC.md; `cat`/`grep` pasan porque no escriben.
    if grep -Eq "$CONGELADO" <<<"$cmd" && grep -Eq '(>>?|\btee\b|\bsed\b[^|]*-i|\bperl\b[^|]*-i|\brm\b|\bmv\b|\bcp\b|\btruncate\b|\bchmod\b[^|]*\+w)' <<<"$cmd"; then
      echo "$MSG_CONGELADO" >&2
      exit 2
    fi
    ;;
esac
exit 0
