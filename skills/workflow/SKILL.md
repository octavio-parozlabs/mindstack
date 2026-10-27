---
name: workflow
description: >-
  Cómo se trabaja una tarea de punta a punta con mindstack: una tarea es una carpeta en docs/plans/<estado>/<slug>/ y su estado es la carpeta (0-draft a 4-done); SPEC.md y PLAN.md se congelan al aprobar; TODO.md mide el avance y CHANGELOG.md es la memoria (decisiones, deuda, revisión); roles con responsabilidades separadas (analista, planificador, desarrollador, qa, revisor de código, auditor de seguridad, corrector, resolutor) que escriben solo sus archivos; consenso entre analistas antes de molestar a la persona; un orquestador opcional. Usar cuando se pregunta cómo se trabaja, qué es una tarea, un estado, un rol o un artefacto, al correr cualquier comando /mindstack:*, al escribir un agente o un hook del plugin, o al tocar docs/plans/.
---

# Flujo: de la idea al merge

El núcleo del plugin. No depende del lenguaje ni del stack: vale para una API, una app web o un script. Lo que cambia por stack (qué runner, qué linter, qué comando de cobertura) lo dice la skill del stack; acá los comandos se nombran por su rol.

La persona pide, responde la entrevista, aprueba, prueba y mergea. Los roles hacen el resto, cada uno lo suyo, y dejan escrito qué hicieron, qué vieron, qué decidieron y qué dejaron. La idea es sacar código rápido con suficientes redes de contención para que no se desmadre: artefactos congelados, roles separados, hallazgos con dueño, deuda con vencimiento.

## Una tarea es una carpeta

```
docs/plans/
├── 0-draft/          se está escribiendo: /analyze, /plan
├── 1-pending/         aprobado, SPEC y PLAN congelados, esperando
├── 2-in-progress/ el loop corre en su worktree
├── 3-in-review/       tres revisores, corrector, PR abierto
├── 4-done/        mergeado
└── <estado>/<slug>/
    ├── SPEC.md          qué se pidió: hoy/propuesto, alcance, supuestos, casos borde CB-n con diagrama, criterios
    ├── PLAN.md          cómo se hace: fechas, estado final, acoplamiento, tareas con rol, Done
    ├── TODO.md          qué se hizo: la checklist derivada del PLAN, lo único que se tacha
    ├── CHANGELOG.md     qué pasó: cambios, observaciones, decisiones, deuda, revisión, conflictos, cierre
    ├── REVIEW-qa.md     hallazgos de QA contra los CB del SPEC
    ├── REVIEW-code.md hallazgos del revisor de código
    ├── REVIEW-security.md hallazgos del auditor, zero trust
    ├── PR.md            body del PR y su número
    └── notes/           lo que se investigó para decidir. Libre
```

La carpeta donde está es su estado, y moverla es `git mv`. Se ve en `ls`, en GitHub y en cualquier editor. No hay otro estado: no hay campo que pueda desincronizarse de la carpeta. Cada movimiento es un commit propio con fecha y autor.

| Carpeta | Quién la mueve ahí | Comando |
|---|---|---|
| `0-draft/` | el analista la crea | `/mindstack:analyze <tema>` |
| `1-pending/` | la persona aprueba | `/mindstack:approve <slug>` |
| `2-in-progress/` | el loop arranca | `/mindstack:implement <slug>` |
| `3-in-review/` | la primera ronda de revisión | `/mindstack:review <slug>` |
| `4-done/` | la persona, después del merge | `/mindstack:finalize <slug>` |

## Qué se congela y qué se escribe

| Archivo | Lo escribe | Cuándo cambia | Qué responde |
|---|---|---|---|
| `SPEC.md` | analista con la persona | solo en `0-draft/`. Después, **nunca**: el hook `plan-immutable.sh` lo bloquea y CI lo verifica | ¿qué se pidió y cómo sabemos que está? |
| `PLAN.md` | planificador con la persona | solo en `0-draft/`. Después, **nunca** | ¿cómo se hace, en qué orden, con qué Done? |
| `TODO.md` | `/approve` lo deriva; el dev tacha | en cada tarea terminada | ¿qué se hizo? |
| `CHANGELOG.md` | todos los roles, cada uno su sección | en cada paso. Solo se agrega, nunca se reescribe | ¿qué pasó, qué se vio, qué se decidió y por qué, qué se dejó? |
| `REVIEW-*.md` | un rol cada uno | se reescribe entero por ronda | ¿qué está mal? (solo eso) |

Por qué el PLAN no se tacha: si el contrato cambia debajo del loop, "está hecho" deja de significar algo. El avance va al TODO; los giros van a Decisiones con fecha, quién y principio. Así la persona sabe en todo momento por qué se tomó un camino distinto al planeado.

Por qué un changelog por tarea: la memoria de un agente termina con su sesión. QA ve un bug ajeno y no lo arregla: Observaciones. El dev elige una librería sobre otra: Decisiones, con la descartada y el principio. El corrector deja un hallazgo como deuda: Deuda técnica, con origen, vencimiento e issue. Sin eso, cada rol que entra empieza de cero y la persona que mergea no sabe qué se dejó afuera.

## El flujo entero

```mermaid
flowchart TD
    U0([persona: /analyze tema]) -->|entrevista| S0["0-draft: SPEC.md"]
    S0 -->|/plan| P0["+ PLAN.md, CHANGELOG.md"]
    P0 -->|/approve: TODO.md, git mv| S1["1-pending<br/>SPEC + PLAN congelados"]
    S1 -->|/implement en worktree| S2["2-in-progress"]
    subgraph IMPL["loop: una tarea del TODO por vuelta"]
        D[dev implementa, commit, Cambios, tacha] --> Q[qa: tests de la tarea]
        D -. DECISION .-> C[consenso: 3 analistas]
        C -. sin acuerdo .-> HU([persona decide])
    end
    S2 --> IMPL
    IMPL -->|Done verde| PRUEBA([persona prueba])
    PRUEBA -->|/review| S3["3-in-review"]
    subgraph REV["revisión: 3 agentes en un turno"]
        R1[qa verificar → REVIEW-qa]
        R2[code-reviewer → REVIEW-code]
        R3[security-auditor → REVIEW-security]
    end
    S3 --> REV --> H{¿crítica o alta?}
    H -->|sí, ronda 1| CO[/fix: corrector + qa/] --> REV
    H -->|sí, ronda 2| HU2([persona])
    H -->|no| PR[/pr: PR.md, push, gh pr create/]
    PR -->|conflicto| CF[/conflicts: rebase/] --> PR
    PR -->|persona mergea| M([merge]) -->|/finalize| S4["4-done"]
    classDef persona fill:#fc9,color:#000
    class U0,PRUEBA,HU,HU2,M persona
```

Naranja es la persona: pide, aprueba, prueba, desempata, mergea. Todo lo demás lo hacen los roles. `/mindstack:orchestrate <slug>` recorre este grafo solo y para en los nodos naranjas.

## Roles

Cada rol tiene un permiso que le impide hacer el trabajo de otro. No es desconfianza: es lo que saca el sesgo (el que implementa testea lo que pensó, no lo que el código hace) y hace que un fallo quede en un solo lugar.

| Rol | Hace | No hace | Escribe |
|---|---|---|---|
| **analista** | entrevista, supuestos, casos borde con diagrama, SPEC. En consenso: busca evidencia en historial, código o principios | decidir cómo se implementa | `SPEC.md` |
| **planificador** | acoplamiento, tajadas verticales, tareas con rol y verificación, fechas, Done | implementar, tachar | `PLAN.md`, `CHANGELOG.md` vacío |
| **desarrollador** | una tarea por vuelta, commit chico, Cambios, Decisiones, Deuda. Senior: sabe arquitectura y sabe que la perfección no es el objetivo | tests, reviews, refactors grandes, adivinar ambigüedades | código, `TODO.md`, `CHANGELOG.md` |
| **qa** | tests de cada tarea; en revisión, cruza cada CB-n del SPEC contra los tests | código de producción | tests, `REVIEW-qa.md`, `CHANGELOG.md` |
| **code-reviewer** | lógica, legibilidad, arquitectura, rendimiento | editar, elogiar | `REVIEW-code.md` |
| **security-auditor** | zero trust: toda entrada es hostil hasta que se valida | editar, bajar severidad por "poco probable" | `REVIEW-security.md` |
| **corrector** | cada hallazgo: corrige, o deuda con vencimiento, o rechaza con motivo | agregar hallazgos, tests | código, `CHANGELOG.md` |
| **conflict-resolver** | rebase, suite, `--force-with-lease` | `--force`, "el mío" entero | lo que esté en conflicto, `CHANGELOG.md` |
| **orquestador** | lee las referencias y llama a los roles en orden | lógica propia, mergear | nada propio |

El detalle de cada uno, con modelo y herramientas: `references/roles-and-artifacts.md` y `agents/*.md` del plugin.

## Redes de contención, de adentro hacia afuera

1. El prompt del rol dice qué no hace.
2. `hooks/write-scope.sh` en cada agente: Edit/Write fuera de sus archivos → bloqueado.
3. `hooks/plan-immutable.sh` global: Edit/Write/Bash sobre `SPEC.md` o `PLAN.md` fuera de `0-draft/` → bloqueado.
4. `chmod a-w` local al aprobar: frena un `>` distraído.
5. `scripts/plans-immutable.sh` en el CI del proyecto: un PR que modifique SPEC o PLAN fuera de `0-draft/` no entra.
6. Dos rondas de revisión como máximo; después, la persona.
7. Nadie mergea.

## El detalle, por referencia

| Referencia | Qué tiene | Cuándo leerla |
|---|---|---|
| `references/analyze.md` | la entrevista, supuestos con confianza, casos borde, mapa de capacidades, qué va al SPEC | `/analyze` |
| `references/plan.md` | acoplamiento, caracterizar, tajadas verticales, tareas con rol, Done, fechas, empates | `/plan` |
| `references/approve.md` | verificaciones, TODO derivado, congelar, mover | `/approve` |
| `references/implement.md` | precondiciones, el prompt del ralph-loop, reglas del loop, qué hacer al terminar | `/implement` |
| `references/consensus.md` | el protocolo `DECISION:` → tres analistas → persona | el dev encuentra una ambigüedad |
| `references/review.md` | tres agentes en un turno, rondas, veredicto | `/review` |
| `references/fix.md` | corrector por severidad, deuda con origen y vencimiento, qa después | `/fix` |
| `references/pr.md` | precondiciones, body, push, `gh pr create` | `/pr` |
| `references/conflicts.md` | rebase, dos intenciones, suite, `--force-with-lease` | `/conflicts` |
| `references/finalize.md` | Cierre con fechas reales, mover, `env-down` | `/finalize` |
| `references/orchestrate.md` | detección de estado, el grafo con sus paradas | `/orchestrate` |
| `references/roles-and-artifacts.md` | diagramas de clases: artefactos y roles, modelo y permisos | al escribir o cambiar un agente |
| `references/worktree.md` | qué arma el hook `WorktreeCreate` y por qué | al abrir una sesión, al tocar el hook |
| `references/git.md` | ramas, commits, prefijos, `.gitignore` | al tocar ramas, commits, `.gitignore` |
| `templates/` | `SPEC.md`, `PLAN.md`, `TODO.md`, `CHANGELOG.md`, `REVIEW.md`, `PR.md`, `CLAUDE.md`, `gitignore` | cada comando que crea un archivo |

## Qué pasa si no

| Atajo | Lo que cuesta |
|---|---|
| Implementar sin SPEC | el dev decide el alcance. Lo que la persona quería y no dijo no existe; lo que no quería, sí |
| Un SPEC sin casos borde con diagrama | QA no sabe qué reproducir y testea el camino feliz. Lo que rompe en producción es siempre un borde |
| Editar el PLAN durante la ejecución | el Done cambia debajo del loop. "Está hecho" deja de significar algo |
| El dev escribe sus tests | los tests prueban lo que el dev pensó. Lo que no pensó no tiene test, y es justo lo que rompe |
| Un solo revisor para todo | mira todo por encima. Tres con un encargo cada uno encuentran lo suyo |
| Hallazgos positivos en la revisión | ruido. "Está bien" no genera ninguna acción; un archivo de revisión vacío ya lo dice |
| Deuda sin issue ni vencimiento | olvido para siempre. Cada vencimiento vencido es una alarma que alguien ve |
| Adivinar una ambigüedad para no interrumpir | código que nadie pidió, descubierto en revisión, que cuesta una ronda entera |
| Preguntar cada ambigüedad a la persona | veinte interrupciones por tarea. El consenso resuelve las que ya tienen respuesta en el repo |
| Sin tope de rondas | dos modelos discutiendo un `media` hasta que se acaba el presupuesto |
| Un refactor "de paso" | la tarea crece, el diff no se puede revisar, y el refactor queda a medias. Es otra tarea con su SPEC |
| Trabajar en el checkout principal | la tarea en curso y "una cosita" comparten `git status`. Uno commitea lo del otro |
| Agente que mergea | se pierde el único punto donde una persona ve el cambio entero y lee el changelog |
