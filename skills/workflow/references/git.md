# Git: ramas, commits, `.gitignore`

## Ramas y commits

Con agentes trabajando en paralelo, la rama es la unidad de aislamiento y el commit es la unidad de evidencia.

| Decisión | Valor | Por qué |
|---|---|---|
| Una rama por PR | la que dice `rama:` en `PLAN.md`: la actual al planificar, se llame como se llame. La abre la persona (`claude -w`, orca o a mano); el flujo no crea ramas | dos tareas en una rama no se revisan ni se revierten por separado |
| Nadie crea ramas por iniciativa propia | un agente trabaja en la rama que le dieron | una rama inesperada es trabajo que nadie va a encontrar |
| Borradores: un commit por ronda | `spec(<slug>): ronda n`, `plan(<slug>): ronda n`, en `0-draft/` | el historial del borrador es el historial de cómo se entendió el pedido; se retoma en otra sesión |
| Código: **commits WIP locales, squash al mergear** | `wip(<slug>): tarea n` después de cada tarea del TODO y `wip(<slug>): ronda n` después de cada corrección; nada se pushea hasta la fase pr. El PR se mergea con *squash*: a `main` entra un commit, el revisado | el trabajo no se pierde con un crash o un `checkout .`; `main` no ve estados intermedios |
| **Un solo push hasta CI verde** | la fase pr deja la carpeta en `4-done` y commitea todo antes del push; en una cola, las hijas commitean local y el padre pushea una vez al final; después solo se pushean arreglos de CI, conflictos y movimientos a `blocked/` y de vuelta. El número del PR no se escribe en archivos | CI corre por push: un commit de estado después de abrir el PR es otra corrida para nada |
| Los movimientos de estado son commits propios | prefijo `plan(<slug>): <estado>` (lista abajo) | el historial de la carpeta es el historial de la tarea, con fecha y autor |
| Nada de `--force` | `--force-with-lease` solo el resolutor, después de un rebase, sobre la rama de la tarea | `--force` pisa lo que otro pusheó mientras tanto |
| Ningún agente mergea ni pushea a `main` | merge: persona. `main` protegida | es el único punto donde alguien ve el cambio entero |
| Rebase, no merge, para ponerse al día | el PR queda lineal; los conflictos se resuelven commit por commit | un merge commit esconde cómo se resolvió cada conflicto |
| Los comandos commitean lo que declaran, sin preguntar | cada `description` dice qué commitea; invocar el comando es pedirlo. Fuera de un comando, Claude muestra `git status` y propone el mensaje | un flujo que para a pedir permiso en cada `git mv` no termina nunca |

Prefijos de commit: `spec(<slug>): ronda n` y `plan(<slug>): ronda n` en borrador · `plan(<slug>): pending | reopen | implement | in review | done | blocked | unblocked` movimientos de estado · `review(<slug>): round n` solo con los `REVIEW-*.md` y `CHECKLIST.md` · `approval(<slug>): ronda n` solo con `APPROVAL.md` y `TECHNICAL_DEBT.md` · `wip(<slug>): tarea n | ronda n | done local` código y tests, locales · `feat|fix(<slug>): <título>` lo que quede sin commitear al llegar a la fase pr · `fix(<slug>): CI-n <qué>` arreglos de CI · `plan(<slug>): conflicts` las filas de `CHANGELOG › Conflictos`, antes del `--force-with-lease`.

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
