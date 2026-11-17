#!/usr/bin/env bash
# Hook Stop global. El orquestador termina el turno solo en dos salidas:
#   - las tareas de la rama (o las de la cola) en todolist/4-done/ y el PR con CI verde (listo para mergear)
#   - una tarea en todolist/blocked/<slug>/ con BLOCKED.md (necesita a la persona)
# Una hija de cola ("/mindstack:orchestrate hija <slug>") termina antes: su tarea en 4-done con commit local, sin push.
# Solo actúa si orchestrate-start.sh dejó el marcador de ESTA sesión en el git dir del worktree.
# Exit 2 no deja parar y el stderr vuelve al modelo como lo que le falta. Exit 0 deja parar.
set -u

input=$(cat)
if command -v jq >/dev/null 2>&1; then
  session=$(jq -r '.session_id // empty' <<<"$input")
else
  session=$(grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' <<<"$input" | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//')
fi
id=$(tr -cd 'A-Za-z0-9_-' <<<"$session")
[ -n "$id" ] || exit 0
gitdir=$(git rev-parse --git-dir 2>/dev/null) || exit 0
marker="$gitdir/mindstack-orchestrating/$id"
[ -f "$marker" ] || exit 0
root=$(git rev-parse --show-toplevel)
cola="$gitdir/mindstack-cola"

# No deja parar y le dice al modelo qué falta. Cuenta los rebotes seguidos sin avance (mismo HEAD, mismo
# git status, mismo motivo): a los rebotes_exige_blocked le exige blocked/; a los rebotes_deja_parar deja parar
# para no quemar tokens en un loop (config/defaults.conf, o .claude/mindstack.conf del proyecto).
rebote() {
  local f n=0 prev= exige parar
  exige=$("$(dirname "$0")/../scripts/config.sh" rebotes_exige_blocked); parar=$("$(dirname "$0")/../scripts/config.sh" rebotes_deja_parar)
  f=$( { git rev-parse HEAD; git status --porcelain; echo "$1"; } 2>/dev/null | cksum | cut -d' ' -f1)
  { read -r n prev <"$marker.rebotes"; } 2>/dev/null
  if [ "$prev" = "$f" ]; then n=$((n + 1)); else n=1; fi
  echo "$n $f" >"$marker.rebotes"
  if [ "$n" -ge "${parar:-10}" ]; then
    echo "mindstack: $n intentos de parar sin avance; se deja parar. Quedó: $1" >&2
    rm -f "$marker" "$marker.rebotes"; exit 0
  fi
  if [ "$n" -ge "${exige:-5}" ]; then
    echo "mindstack: $n intentos de parar sin avance. Pasá la tarea a blocked/ con BLOCKED.md, motivo: no avanza ($1). orchestrate.md › Bloquear." >&2
  else
    echo "mindstack: $1" >&2
  fi
  exit 2
}

# Hija de una cola: termina con su tarea en 4-done (commit local) o en blocked/. El push y el PR son del padre.
hija=$(sed -nE 's/.*orchestrate[[:space:]]+hija[[:space:]]+([^[:space:]]+).*/\1/p' "$marker" | head -1)
if [ -n "$hija" ]; then
  if [ -d "$root/todolist/4-done/$hija" ] || [ -f "$root/todolist/blocked/$hija/BLOCKED.md" ]; then rm -f "$marker" "$marker.rebotes"; exit 0; fi
  rebote "'$hija' termina en 4-done con commit local, sin push, o en blocked/ con BLOCKED.md (orchestrate.md › Cola)."
fi

salir() { rm -f "$marker" "$marker.rebotes" "$cola"; exit 0; }

# Padre esperando a una hija: deja parar. El fin del proceso en segundo plano lo despierta.
# ponytail: una hija muerta sin limpiar deja su marcador; el padre lo borra al despertar (orchestrate.md › Cola).
for m in "$gitdir"/mindstack-orchestrating/*; do
  [ "$m" != "$marker" ] && [ "${m%.rebotes}" = "$m" ] && grep -Eqs 'orchestrate[[:space:]]+hija' "$m" && exit 0
done

if compgen -G "$root/todolist/blocked/*/BLOCKED.md" >/dev/null; then salir; fi

abiertas=$(find "$root"/todolist/{2-in-progress,3-in-review} -mindepth 1 -maxdepth 1 -type d -printf '%P(%h) ' 2>/dev/null | sed "s#$root/todolist/##g")
# Pendientes: las de la cola si el padre la escribió; si no, todas las de la rama.
if [ -s "$cola" ]; then
  while read -r s; do [ -n "$s" ] && [ -d "$root/todolist/1-pending/$s" ] && abiertas+="$s(1-pending) "; done <"$cola"
else
  abiertas+=$(find "$root"/todolist/1-pending -mindepth 1 -maxdepth 1 -type d -printf '%P(1-pending) ' 2>/dev/null)
fi
if [ -n "$abiertas" ]; then
  rebote "tareas sin terminar: $abiertas. El turno termina en 4-done con CI verde o en blocked/ con BLOCKED.md (orchestrate.md › Un solo turno)."
fi

# ponytail: sin gh no se puede mirar el CI; se deja parar antes que trabar la sesión.
command -v gh >/dev/null 2>&1 || salir
if ! gh pr view >/dev/null 2>&1; then
  rebote "las tareas están en 4-done pero la rama no tiene PR. Seguí la fase pr (pr.md)."
fi
out=$(gh pr checks 2>&1); rc=$?
if [ "$rc" -eq 0 ] || grep -qi 'no checks reported' <<<"$out"; then salir; fi
[ "$rc" -eq 8 ] && rebote "CI pendiente. Esperá con 'gh pr checks --watch' y seguí pr.md."
rebote "CI rojo. Seguí pr.md: developer ci → qa → push, o blocked/ si es ajeno o la última ronda (rondas_ci)."
