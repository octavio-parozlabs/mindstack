#!/usr/bin/env bash
# Hook PreToolUse global (Edit|Write|MultiEdit|NotebookEdit|Bash).
# Red de contención: SPEC.md, PLAN.md y wireframes/ no se editan fuera de todolist/0-draft/ (tampoco en blocked/).
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
agent=${agent##*:} # un agente de plugin puede venir como mindstack:verifier

CONGELADO='todolist/([1-4]-[^/ ]+|blocked)/[^/ ]+/((PLAN|SPEC)\.md|wireframes/)'
REVIEW='todolist/([0-4]-[^/ ]+|blocked)/[^/ ]+/REVIEW-(qa|code|security)\.md'
CHECKLIST='todolist/([0-4]-[^/ ]+|blocked)/[^/ ]+/CHECKLIST\.md'
BACKLOG='todolist/backlog/'
MSG_CONGELADO='mindstack: PLAN.md, SPEC.md y wireframes/ son inmutables fuera de 0-draft/. Lo que cambia va a CHANGELOG.md › Decisiones, o es otra tarea.'

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
    # CHECKLIST.md: la genera /plan (sesión principal, sin agent_type) y la tacha solo verifier.
    if [ -n "$agent" ] && [ "$agent" != verifier ] && grep -Eq "$CHECKLIST" <<<"$file"; then
      echo "mindstack: CHECKLIST.md la tacha solo verifier, no '$agent'." >&2
      exit 2
    fi
    # backlog/: IDEAS.md es de la persona y PROPUESTAS.md lo filtra el orquestador. Un agente propone en
    # CHANGELOG › Propuestas o REVIEW-*.md › Propuestas, nunca acá.
    if [ -n "$agent" ] && grep -q "$BACKLOG" <<<"$file"; then
      echo "mindstack: todolist/backlog/ no lo escribe un agente. Proponé en CHANGELOG.md › Propuestas." >&2
      exit 2
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
