# Revisar: cuatro roles, cuatro archivos, un turno

Lo corre el orquestador (fase review). Requiere `TODO.md` completo y Done verde. El código todavía no está commiteado: se revisa el working tree contra `main` (`git diff main`), no un rango de commits. La primera ronda mueve la carpeta a `3-in-review/`; las siguientes la encuentran ahí. Termina con `REVIEW-qa.md`, `REVIEW-code.md`, `REVIEW-security.md` y `CHECKLIST.md` escritos y commiteados.

```mermaid
flowchart LR
    C[working tree vs main] --> Q[Agent qa\nmodo verificar]
    C --> R[Agent code-reviewer]
    C --> S[Agent security-auditor]
    C --> V[Agent verifier]
    Q --> FQ[REVIEW-qa.md]
    R --> FR[REVIEW-code.md]
    S --> FS[REVIEW-security.md]
    V --> FV[CHECKLIST.md tachada]
    FQ & FR & FS & FV --> K["commit review(slug): round n"]
    K --> T{¿crítica, alta o\nlínea sin tachar?}
    T -- no --> PR["fase pr"]
    T -- "sí, ronda < 5" --> CO["fase fix"]
    T -- "sí, ronda 5" --> BL([blocked/])
```

Por qué cuatro agentes y no uno: un revisor que mira todo mira todo por encima. Tres miran **cómo** está hecho (tests, código, seguridad) y uno mira **si** está hecho: el `verifier` recorre la checklist línea por línea y no tacha sin código, test y evidencia. Por qué en un solo turno: corren en paralelo, no se leen entre sí, y lo que escriben no se pisa porque cada uno tiene su archivo y el hook se lo garantiza.

## Precondiciones

- Carpeta en `2-in-progress/` (ronda 1) o `3-in-review/` (ronda ≥ 2). Si está en otra, pará.
- Todas las líneas de `TODO.md` con `[x]`. Si no, volvé a `implement.md`: la revisión es de la tarea entera.
- Done de `PLAN.md` pasa ahora. Si no, volvé a `implement.md` con el log como una tarea más.
- Ronda = filas de rondas en `CHANGELOG › Revisión` desde la última vez que la tarea salió de `blocked/`, + 1; sin filas, 1.

## Pasos

1. Ronda 1: `git mv todolist/2-in-progress/<slug> todolist/3-in-review/<slug>`, commit propio `plan(<slug>): in review`.
2. Lo que se revisa es `git diff main` (working tree contra la base), más `git status --short` para ver qué archivos nuevos hay. Cada revisor lo recibe como `base main`.
3. **Un solo turno con cuatro `Agent`**, cada uno con `subagent_type` del rol y este prompt mínimo:
   - `qa`: "verificar <slug> ronda <n> base main. Por cada CB-n de SPEC.md: ¿hay un test que lo nombra y lo cubre? Un hallazgo por CB sin test o con test que no lo reproduce. Escribí REVIEW-qa.md. No escribas tests."
   - `code-reviewer`: "revisar <slug> ronda <n> base main. Lógica, legibilidad, arquitectura, rendimiento. Escribí REVIEW-code.md."
   - `security-auditor`: "auditar <slug> ronda <n> base main. Zero trust. Escribí REVIEW-security.md."
   - `verifier`: "verificar <slug> ronda <n>. Tachá CHECKLIST.md con evidencia."
4. Cuando los cuatro terminan: un commit `review(<slug>): round <n>` **solo con los tres `REVIEW-*.md` y `CHECKLIST.md`** (`git add` de esos archivos, nada más). El código sigue sin commitear.
5. Veredicto:
   - ninguna crítica ni alta, y `CHECKLIST` completa: fase pr (`pr.md`). Media y baja pasan al corrector solo si hay otra cosa que corregir; si no, quedan como deuda en el CHANGELOG.
   - alguna crítica o alta, o una línea sin tachar, en ronda 1 a 4: fase fix (`fix.md`). Una línea sin tachar cuenta como hallazgo alto.
   - lo mismo en la ronda 5: `blocked` (`orchestrate.md › Bloquear`), con cada ID o línea abierta como motivo.

## Qué no

- Correr los agentes de a uno. Pierden independencia y tiempo.
- Un revisor que escribe el archivo de otro, o alguien que no es `verifier` tachando la checklist. El hook lo bloquea; si pasa, es un bug del hook.
- Corregir nada en esta fase. Lo que se encontró se valida y se corrige en la fase fix.
