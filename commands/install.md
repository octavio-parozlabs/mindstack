---
description: Deja un proyecto trabajando con mindstack: tablero docs/plans/, bloque en CLAUDE.md, .gitignore, plugins necesarios. No commitea.
disable-model-invocation: true
---

Sos la sesión principal. La persona te pidió instalar la forma de trabajo en este proyecto. Cargá la skill `mindstack:workflow`. Cada paso termina con una verificación; si falla, pará y decí qué falta.

Principio: **el plugin no copia nada al proyecto** salvo lo que el proyecto necesita como archivo propio y versionado (tablero, `CLAUDE.md`, `.gitignore`). Skills, comandos, agentes y hooks viajan en el plugin.

1. Precondiciones: `git rev-parse --show-toplevel` es la raíz y estás en el checkout principal. `claude plugin list` muestra `mindstack` habilitado. Hay `jq` y `gh`. Si falta `ralph-wiggum` (necesario para `/mindstack:implement`), decí cómo habilitarlo.
2. Tablero: `docs/plans/{0-draft,1-pending,2-in-progress,3-in-review,4-done}/`, cada una con `.gitkeep`.
3. `.gitignore`: agregá al final las líneas de `${CLAUDE_PLUGIN_ROOT}/skills/workflow/templates/gitignore` que no estén. No borres nada. Verificación: `git check-ignore .env .claude/worktrees/x` responde los dos.
4. `CLAUDE.md`: si no existe, escribilo desde `${CLAUDE_PLUGIN_ROOT}/skills/workflow/templates/CLAUDE.md` completando "Este proyecto", "Stack" (qué skills `mindstack:*` aplican, leyendo `package.json`, `pyproject.toml`, `go.mod`) y "Comandos" (los scripts reales: typecheck, lint, test, cobertura). Si existe, agregá las secciones que falten sin pisar las existentes y mostrá el diff.
5. Si hay `package.json`: compará sus scripts con lo que el Done de un PLAN necesita (typecheck, lint, test, cobertura del diff). Listá lo que falta; **preguntá antes de instalar nada**.
6. Si hay `.github/workflows/`: proponé un step con `bash <ruta al plugin>/scripts/plans-immutable.sh origin/${{ github.base_ref }}` en el CI de PRs, y mostrá el diff. Es la red de contención de CI para SPEC y PLAN.
6b. Permisos para que el flujo no frene: en `.claude/settings.json` del proyecto, agregá (mergeando si existe, mostrando el diff) `permissions.allow` con `Bash(git add:*)`, `Bash(git commit:*)`, `Bash(git mv:*)`, `Bash(git status:*)`, `Bash(git diff:*)`, `Bash(git log:*)`, `Bash(git push:*)`, `Bash(git fetch:*)`, `Bash(git rebase:*)`, `Bash(gh pr:*)`, `Bash(gh issue:*)`, `Bash(chmod:*)`, y los comandos de test/lint/typecheck del stack. Sin esto, `/mindstack:orchestrate` pide confirmación en cada paso y no termina solo.
7. Si existe `graphify` y no hay `graphify-out/graph.json`: sugerí `/graphify`. No es obligatorio.
8. Reporte: `git status --short`, lo que quedó pendiente de la persona, y el mensaje de commit sugerido: `chore: install mindstack`. No commitees.

Terminá con: "Próximo paso: `/mindstack:analyze <tema>`".
