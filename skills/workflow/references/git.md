# Git: ramas, commits, `.gitignore`

## Ramas y commits

Con agentes trabajando en paralelo, la rama es la unidad de aislamiento y el commit es la unidad de evidencia.

| Decisión | Valor | Por qué |
|---|---|---|
| Una rama por tarea | `worktree-<slug>`, la que dice `rama:` en `PLAN.md`. La crea el hook `WorktreeCreate` o `/mindstack:implement` | dos tareas en una rama no se revisan ni se revierten por separado |
| Nadie crea ramas por iniciativa propia | un agente trabaja en la rama que le dieron | una rama inesperada es trabajo que nadie va a encontrar |
| Borradores: un commit por ronda | `spec(<slug>): ronda n`, `plan(<slug>): ronda n`, en `0-draft/` | el historial del borrador es el historial de cómo se entendió el pedido; se retoma en otra sesión |
| Código: **un solo commit, después de la revisión** | durante `/implement` y `/fix` nada se commitea; el worktree aislado guarda el trabajo. `/pr` hace `feat\|fix(<slug>): <título>` con código, tests, TODO y CHANGELOG | lo commiteado parece terminado; solo lo que tres revisores miraron lo está |
| Los movimientos de estado son commits propios | `plan(<slug>): approve` · `implementar` · `a revisión` · `PR` · `finalizar` | el historial de la carpeta es el historial de la tarea, con fecha y autor |
| Nada de `--force` | `--force-with-lease` solo el resolutor, después de un rebase, sobre la rama de la tarea | `--force` pisa lo que otro pusheó mientras tanto |
| Ningún agente mergea ni pushea a `main` | merge: persona. `main` protegida | es el único punto donde alguien ve el cambio entero |
| Rebase, no merge, para ponerse al día | el PR queda lineal; los conflictos se resuelven commit por commit | un merge commit esconde cómo se resolvió cada conflicto |
| Los comandos commitean lo que declaran, sin preguntar | cada `description` dice qué commitea; invocar el comando es pedirlo. Fuera de un comando, Claude muestra `git status` y propone el mensaje | un flujo que para a pedir permiso en cada `git mv` no termina nunca |

Prefijos de commit: `spec(<slug>): ronda n` y `plan(<slug>): ronda n` en borrador · `plan(<slug>): approve | implement | in review | PR | finalize` movimientos de estado · `review(<slug>): round n` solo con los `REVIEW-*.md` · `feat|fix(<slug>): <título>` el único commit de código, en `/pr`.

## `.gitignore`

Todo repo nace con un `.gitignore` que excluye secretos, credenciales, certificados y estado local **antes del primer commit**. El archivo está en `../templates/gitignore`; `/mindstack:install` agrega al del proyecto las líneas que falten.

Un secreto commiteado no se arregla borrándolo: queda en el historial y en cada clon. Se rota.

| Grupo | Por qué | Lo que sí se commitea |
|---|---|---|
| `.env`, `.env.*` | es el archivo con los secretos | `.env.example` con nombres y sin valores |
| claves y certificados (`*.pem`, `*.key`, `id_rsa*`…) | acceso permanente para cualquiera con el clon | nada |
| credenciales de proveedores (`*credentials*.json`, `.aws/`, `kubeconfig`…) | tokens con permisos de producción | nada |
| estado de infraestructura (`*.tfstate`, `*.tfvars`) | guarda outputs en claro | `*.tf`, el lockfile de terraform |
| overrides locales, dumps, DBs locales | "mi puerto, mi password"; datos de usuarios reales | migraciones y seeds |
| dependencias, build, logs, editor | se regeneran; un log puede tener tokens | el lockfile, siempre; la config compartida del editor |
| `.claude/settings.local.json`, `.claude/worktrees/` | lo personal y los checkouts | `.claude/settings.json`, `CLAUDE.md` |

Verificar: `git check-ignore .env certs/x.pem creds/service-account.json infra/prod.tfstate` imprime los cuatro. `git ls-files | grep -E '\.env$|\.pem$|\.key$|tfstate'` no devuelve nada. Segunda capa: un scanner de secretos en CI (`gitleaks`) mirando el diff de cada PR, y Push protection en GitHub.

Si ya se escapó algo: `git rm --cached .env`, commit, **y rotar el secreto**. Limpiar historial solo si el repo es compartido.
