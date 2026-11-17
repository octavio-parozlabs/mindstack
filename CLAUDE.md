# mindstack

Plugin de Claude Code: forma de trabajo por tareas con estados, roles separados y redes de contención. Este archivo configura a quien trabaja **sobre el plugin**; los proyectos que lo usan tienen su propio `CLAUDE.md` escrito por `/mindstack:install`.

## Estructura

- `skills/workflow/` es el núcleo: `SKILL.md` (estados, artefactos, roles), `references/<fase>.md` (qué hace cada comando), `templates/` (SPEC, PLAN, TODO, CHECKLIST, CHANGELOG, REVIEW, APPROVAL, TECHNICAL_DEBT, PR, BLOCKED, IDEAS y PROPUESTAS del backlog, CLAUDE, gitignore).
- `commands/`: seis (`install`, `doctor`, `draft`, `plan`, `orchestrate`, `rebase`), sin lógica propia: apuntan a `references/<fase>.md` (`doctor`, a `scripts/doctor.sh`). Las fases implement, review, fix, pr y conflicts no son comandos: las corre el orquestador leyendo esas referencias; iterate la corre `/draft`. Si una fase necesita algo nuevo, va a la reference.
- `agents/*.md`: un rol cada uno, con `hooks:` que limita qué escribe (`hooks/write-scope.sh`). Cambiar qué escribe un rol es cambiar su regex ahí y su caso en `hooks/test.sh`.
- `hooks/`: `plan-immutable.sh` (global), `write-scope.sh` (por agente), `orchestrate-start.sh` y `orchestrate-stop.sh` (el orquestador solo termina en `4-done` con CI verde o en `blocked/`), `session-start.sh` (tablero y avisos), `worktree-create.sh`, `test.sh`.
- `skills/{qa,tdd,debugging,code-review,security,git,simplification,performance,api-design,migration,observability,documentation,ci-cd}`: prácticas agnósticas; el PLAN de cada tarea dice cuáles carga el developer (`tipo:`, `skills:`). `skills/{typescript,react,node-api,nestjs,architecture,web-security,docker-ci,auth-jwt-sessions}`: stack. `skills/design`: criterios de diseño sobre shadcn (los aplica el agente `designer` en `/draft`). `skills/recon`: describe un repo existente para auditarlo (hechos en `ARCHITECTURE.md`, pistas en `LEADS.md`).
- `config/defaults.conf`: topes de iteración, modelo y esfuerzo por agente (los agentes no llevan `model:`); un proyecto los pisa en `.claude/mindstack.conf` y `scripts/config.sh` los lee. Un tope nuevo va ahí, no como número en una reference. Si cambiás `turnos_*`, corré `scripts/sync-agents.sh`.
- `use-cases/`: diagramas de secuencia de cómo la persona interactúa con el flujo. Si cambia una fase, se actualiza el caso que la muestra.
- `PRINCIPLES.md`: lo que desempata. Toda regla nueva cita uno; si no cita ninguno, es preferencia.

## Command, agent o skill

Algo nuevo va en una de las tres carpetas según qué necesita poder hacer:

| | `commands/` | `agents/` | `skills/` |
|---|---|---|---|
| Qué es | prompt inyectado en la sesión principal al tipear `/mindstack:<nombre>` | subagente: contexto nuevo y vacío, devuelve un informe | texto que se carga en el contexto de quien lo pida |
| Lo dispara | la persona (`disable-model-invocation: true`: Claude no lo invoca solo) | la sesión principal con la tool `Agent`; la persona no puede tipearlo | "cargá la skill …" o un pedido que matchee la `description` |
| Habla con la persona | sí: `AskUserQuestion`, diálogo por turnos, ve la conversación | no | no ejecuta nada |
| Lanza agentes | sí | no | no |
| Permisos | los de la sesión | propios: `tools:`, `hooks:` (`write-scope.sh`); el modelo, de `config/defaults.conf` | ninguno |

Por eso `draft`, `plan` y `orchestrate` son commands (entrevistan, preguntan, lanzan `qa`, analistas y revisores) y `qa`, revisores, `verifier`, `approver` y `conflict-resolver` son agentes (contexto aislado y escritura acotada por hook). Un command no lleva lógica: resuelve `${CLAUDE_PLUGIN_ROOT}` y `$ARGUMENTS` y apunta a la reference; la lógica está ahí para que el modo manual y el orquestado lean lo mismo.

## Convenciones

- Castellano rioplatense, voseo, directo. Sin relleno.
- Diagramas antes que prosa: si una secuencia, decisión o ciclo se puede dibujar en Mermaid, se dibuja. Un lector que solo mira los diagramas tiene que entender.
- Frontmatter de skill: `name` igual a la carpeta, `description` con qué hace y "Usar cuando/al …". De agente: `name` igual al archivo.
- Nada se duplica entre skills: se referencia. Lo específico de un stack va en su skill; lo demás es agnóstico.
- Solo Claude Code. Sin formatos ni manifiestos para otros hosts.

## Una regla, un archivo

Cada regla vive en un solo archivo; el resto enlaza (`ver orchestrate.md › Bloquear`) o la hace cumplir (regex de un hook, valor del config). Copiar una regla es firmar una contradicción futura: cambiar la forma de trabajar tiene que ser editar un lugar.

| Qué | Dónde vive |
|---|---|
| estados, qué se congela y cuándo, el flujo entero, redes de contención | `skills/workflow/SKILL.md` |
| quién hace, quién no y qué escribe cada rol; quién invoca a quién | `references/roles-and-artifacts.md` |
| cómo se ejecuta cada fase | `references/<fase>.md` |
| cuándo una tarea va a `blocked/` | `references/orchestrate.md › Bloquear` |
| qué decide el approver y con qué criterio | `agents/approver.md` |
| qué hace un agente, qué carga, sus modos y su última línea | `agents/<rol>.md` |
| lo que todo subagente necesita saber del flujo | `references/agent-card.md` |
| commits, prefijos, push, merge, `--force` | `references/git.md` |
| formatos: severidad, tope de hallazgos, "Fuera del diff", "Cerrados", decisiones, propuestas | `templates/` |
| valores: topes, modelos, esfuerzo, turnos | `config/defaults.conf` |
| cómo se revisa código o seguridad, la escalera de reproducción | la skill de la práctica |

Los casos de uso muestran secuencias, no restatean reglas. `scripts/validate/single-source.sh` falla con las copias que ya divergieron alguna vez; si aparece una nueva, se suma su patrón ahí.

## Validar

```bash
node scripts/validate/skills.js && node scripts/validate/reference-links.js && bash hooks/test.sh && node scripts/validate/mermaid.mjs . && bash scripts/validate/single-source.sh
```

## Git

- Nunca commitear, pushear ni crear ramas por iniciativa propia; solo cuando el usuario lo pide en ese mensaje.
