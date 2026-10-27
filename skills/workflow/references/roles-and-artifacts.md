# Roles y artefactos

```mermaid
classDiagram
    class Tarea {
        +estado: la carpeta, 0-draft a 4-done
        +slug: nombre de carpeta, rama y worktree
    }
    class SPEC {
        +pedido original
        +hoy / propuesto: diagramas
        +qué se hace / qué no
        +supuestos
        +casos borde CB-n, uno por diagrama
        +criterios de aceptación
        congelado desde 1-pending
    }
    class PLAN {
        +fechas planificadas
        +estado final
        +acoplamiento
        +tareas: rol + verificación
        +done: comandos
        congelado desde 1-pending
    }
    class TODO {
        +checklist derivada del PLAN
        se tacha
    }
    class CHANGELOG {
        +cambios
        +observaciones
        +decisiones: con principio
        +deuda: origen, vence, issue
        +revisión: por hallazgo
        +conflictos
        +cierre: fechas reales
        solo se agrega
    }
    class REVIEW {
        +uno por rol: qa, codigo, seguridad
        +solo hallazgos, con severidad y CB
        se reescribe por ronda
    }
    class PR {
        +body desde PR.md
        +número
    }

    Tarea "1" *-- "1" SPEC
    Tarea "1" *-- "1" PLAN
    Tarea "1" *-- "1" TODO
    Tarea "1" *-- "1" CHANGELOG
    Tarea "1" *-- "3" REVIEW
    Tarea "1" *-- "0..1" PR
    PLAN ..> SPEC : implementa
    TODO ..> PLAN : derivado al aprobar
```

```mermaid
classDiagram
    class Persona {
        pide, responde la entrevista
        aprueba SPEC y PLAN
        prueba la feature
        decide cuando no hay consenso
        mergea
    }
    class Analista {
        sesión principal: entrevista, SPEC
        subagente opus: consenso, solo lee
    }
    class Planificador {
        sesión principal: PLAN, CHANGELOG vacío
    }
    class Desarrollador {
        ralph-loop en worktree
        implementa, commitea
        no testea, no revisa
        DECISION cuando no puede decidir
    }
    class QA {
        sonnet
        testear: tests de una tarea
        verificar: CB-n vs tests, REVIEW-qa
        solo tests, REVIEW-qa, CHANGELOG
    }
    class RevisorCodigo {
        opus, sin Edit
        lógica, legibilidad, arquitectura, rendimiento
        solo REVIEW-code
    }
    class AuditorSeguridad {
        opus, sin Edit
        zero trust
        solo REVIEW-security
    }
    class Corrector {
        opus
        aplica cada hallazgo o lo justifica
        no agrega hallazgos, no testea
    }
    class Resolutor {
        opus
        rebase, suite, force-with-lease
    }
    class Orquestador {
        sesión principal
        lee las referencias, llama a los roles
        para en los nodos de la persona
    }

    Persona ..> Analista : responde
    Persona ..> Planificador : corrige
    Orquestador ..> Desarrollador : implementar
    Orquestador ..> QA : testear, verificar
    Orquestador ..> RevisorCodigo : revisar
    Orquestador ..> AuditorSeguridad : auditar
    Orquestador ..> Corrector : corregir
    Orquestador ..> Resolutor : conflictos
    Desarrollador ..> QA : testear cada tarea
    Desarrollador ..> Analista : consenso ×3
    Orquestador ..> Persona : AskUserQuestion
```

## Quién invoca a quién

Los roles no se llaman entre sí: los invoca la sesión principal (un comando o `/mindstack:orchestrate`), que es la única que puede lanzar `Agent` y hablar con la persona. Claude Code elige la skill por su `description` (por eso toda description dice "Usar cuando …"); los agentes se eligen por nombre, acá:

| Quién invoca | A quién | Cuándo | Con qué |
|---|---|---|---|
| `/draft (analyze)` | `qa` (`reproducir`) | la tarea es un fix | síntoma + punto de entrada; sin la causa |
| `fase implement` (ralph-loop) | `qa` (`testear`) | después de cada tarea del TODO | slug + número de tarea |
| `fase implement` (ralph-loop) | `analyst` ×3 | el dev devolvió `DECISION:` | la pregunta, las opciones, un ángulo cada uno |
| `fase review` | `qa` (`verificar`), `code-reviewer`, `security-auditor` | TODO completo y Done verde | slug, ronda, base `main` (working tree sin commitear); los tres en un turno |
| `fase fix` | `fixer`, después `qa` (`testear`) | hay `REVIEW-*.md` con hallazgos | slug, ronda |
| `fase conflicts` | `conflict-resolver` | el PR está en conflicto | slug o #pr |
| `/orchestrate` | todos los anteriores, en ese orden | la persona delega el flujo, normalmente desde `1-pending` en un worktree | lee `references/<fase>.md` |
| `/draft "qué falta" (en el worktree)` | `qa` (`reproducir`) si lo que falta es un bug | probaste el PR y falta algo | crea la tarea hija; después `/orchestrate` en el mismo worktree |

## Iteración por fase

El loop no es solo de implementación. Cada fase itera hasta su condición de salida, y la condición es verificable, no "parece que está":

| Fase | Itera | Hasta que |
|---|---|---|
| analizar | pregunta → respuesta → supuestos y casos borde | no queda ambigüedad que cambie el SPEC; en un fix, además `REPRO` ≠ `NO` |
| planificar | plan → corrección de la persona | la persona dice que está y cada tarea tiene rol y verificación |
| implementar | una tarea del TODO por vuelta, `qa` después | TODO completo y Done verde; para en `BLOCKED:` o tres fallos seguidos |
| consenso | tres analistas en paralelo | 3/3 misma opción; si no, la persona |
| revisar ↔ corregir | tres revisores → corrector → tres revisores | sin hallazgos críticos ni altos; máximo dos rondas |
| pr ↔ conflictos | rebase → suite → push | el PR es mergeable |

## Skills externas

Todos los agentes tienen la herramienta `Skill`: pueden cargar cualquier skill instalada en la máquina, de este plugin o de otro (`ponytail`, `caveman`, la que sea). Mindstack no limita el catálogo; el `CLAUDE.md` del proyecto dice cuáles aplican y cada agente carga además las que su trabajo pide. Lo único cerrado es qué archivos escribe cada rol.

Cada rol tiene un permiso que le impide hacer el trabajo de otro: QA no toca producción; los revisores no tienen Edit; el corrector no agrega hallazgos; el dev no escribe tests ni reviews; nadie edita SPEC ni PLAN después de aprobados; ningún agente mergea. No es desconfianza: es lo que hace que un fallo quede en un solo lugar y que el changelog diga quién vio qué.

| Rol | Dónde corre | Modelo | Escribe |
|---|---|---|---|
| analista (entrevista) | sesión principal | el de la sesión | `SPEC.md` en `0-draft/` |
| analista (consenso) | subagente | opus | nada |
| planificador | sesión principal | el de la sesión | `PLAN.md`, `CHANGELOG.md` en `0-draft/` |
| desarrollador | sesión principal (ralph-loop) o subagente | opus | código, `TODO.md`, `CHANGELOG.md`; nunca tests, SPEC, PLAN, REVIEW |
| qa | subagente | sonnet | tests, `REVIEW-qa.md`, `CHANGELOG.md` |
| code-reviewer | subagente | opus | `REVIEW-code.md` |
| security-auditor | subagente | opus | `REVIEW-security.md` |
| corrector | subagente | opus | código, `CHANGELOG.md`; nunca tests, SPEC, PLAN, REVIEW |
| conflict-resolver | subagente | opus | lo que esté en conflicto, `CHANGELOG.md` |
