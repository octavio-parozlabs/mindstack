#!/usr/bin/env bash
# Lo que el flujo da por hecho en esta máquina y este repo. No instala ni cambia nada.
# ✗ = el flujo falla sin esto · ⚠ = funciona, peor. Sale 1 si hay algún ✗.
set -u
mal=0
ok()   { echo "✓ $1"; }
falla(){ echo "✗ $1"; mal=1; }
aviso(){ echo "⚠ $1"; }

git rev-parse --show-toplevel >/dev/null 2>&1 && ok "repo git" || { falla "no es un repo git"; exit 1; }
default=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
rama=$(git branch --show-current)
[ "$rama" = "${default:-main}" ] && aviso "rama $rama: draft, plan y orchestrate necesitan otra (el PR sale de ella)" || ok "rama $rama"

if ! command -v gh >/dev/null 2>&1; then falla "gh no instalado: sin PR ni CI"
elif ! gh auth status >/dev/null 2>&1; then falla "gh sin sesión: gh auth login"
elif ! gh repo view --json name >/dev/null 2>&1; then falla "gh no ve el repo remoto: ¿hay origin en GitHub?"
else ok "gh con sesión y repo"; fi

command -v jq >/dev/null 2>&1 && ok "jq" || aviso "sin jq: los hooks usan un parseo más frágil"
command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1 && ok "node y npm" || aviso "sin node/npm: no se renderizan wireframes"

if compgen -G "docker-compose.y*ml" >/dev/null || compgen -G "compose.y*ml" >/dev/null; then
  if ! command -v docker >/dev/null 2>&1; then falla "hay compose y no hay docker"
  elif ! docker info >/dev/null 2>&1; then falla "docker no está levantado (o tu usuario no tiene acceso)"
  else ok "docker levantado"; fi
fi

[ -d todolist ] && ok "todolist/" || aviso "sin todolist/: /mindstack:install"
faltan=
for p in 'git commit' 'git push' 'git mv' 'gh pr'; do
  grep -qsF "Bash($p:*)" .claude/settings.json .claude/settings.local.json || faltan+=" $p"
done
[ -z "$faltan" ] && ok "permisos de git y gh" || aviso "sin permiso para:$faltan → el orquestador frena a preguntar (/mindstack:install paso 6b)"

exit "$mal"
