# mindstack

Plugin de Claude Code: forma de trabajo por tareas con estados, roles separados y redes de contención. Este archivo configura a quien trabaja **sobre el plugin**; los proyectos que lo usan tienen su propio `CLAUDE.md` escrito por `/mindstack:install`.

## Estructura

- `skills/workflow/` es el núcleo: `SKILL.md` (estados, artefactos, roles), `references/<fase>.md` (qué hace cada comando), `templates/` (SPEC, PLAN, TODO, CHANGELOG, REVIEW, PR, CLAUDE, gitignore).
- `commands/`: cinco (`install`, `draft`, `plan`, `orchestrate`, `rebase`), sin lógica propia: apuntan a `references/<fase>.md`. Las fases implement, review, fix, pr, conflicts, finalize e iterate no son comandos: las corre el orquestador leyendo esas referencias. Si una fase necesita algo nuevo, va a la reference.
- `agents/*.md`: un rol cada uno, con `hooks:` que limita qué escribe (`hooks/write-scope.sh`). Cambiar qué escribe un rol es cambiar su regex ahí y su caso en `hooks/test.sh`.
- `hooks/`: `plan-immutable.sh` (global), `write-scope.sh` (por agente), `session-start.sh`, `worktree-create.sh`, `test.sh`.
- `skills/{qa,tdd,debugging,code-review,security,git,simplification,performance,api-design,migration,observability,documentation,ci-cd}`: prácticas agnósticas; el PLAN de cada tarea dice cuáles carga el developer (`tipo:`, `skills:`). `skills/{typescript,react,node-api,nestjs,architecture,web-security,docker-ci,auth-jwt-sessions}`: stack.
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
| Permisos | los de la sesión | propios: `tools:`, `model:`, `hooks:` (`write-scope.sh`) | ninguno |

Por eso `draft`, `plan` y `orchestrate` son commands (entrevistan, preguntan, lanzan `qa`, analistas y revisores) y `qa`, revisores, `fixer` y `conflict-resolver` son agentes (contexto aislado y escritura acotada por hook). Un command no lleva lógica: resuelve `${CLAUDE_PLUGIN_ROOT}` y `$ARGUMENTS` y apunta a la reference; la lógica está ahí para que el modo manual y el orquestado lean lo mismo.

## Convenciones

- Castellano rioplatense, voseo, directo. Sin relleno.
- Diagramas antes que prosa: si una secuencia, decisión o ciclo se puede dibujar en Mermaid, se dibuja. Un lector que solo mira los diagramas tiene que entender.
- Frontmatter de skill: `name` igual a la carpeta, `description` con qué hace y "Usar cuando/al …". De agente: `name` igual al archivo.
- Nada se duplica entre skills: se referencia. Lo específico de un stack va en su skill; lo demás es agnóstico.
- Solo Claude Code. Sin formatos ni manifiestos para otros hosts.

## Validar

```bash
node scripts/validate/skills.js && node scripts/validate/reference-links.js && bash hooks/test.sh && node scripts/validate/mermaid.mjs .
```

## Git

- Nunca commitear, pushear ni crear ramas por iniciativa propia; solo cuando el usuario lo pide en ese mensaje.
