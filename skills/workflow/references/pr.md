# PR: llegar a done

Lo corre el orquestador (fase pr). Requiere la carpeta en `3-in-review/`, la última ronda sin crítica ni alta abierta y `CHECKLIST.md` completa. Es el único punto donde el código se commitea: hasta acá vivió en el working tree. Termina con la tarea en `4-done/`: **todo commiteado, PR abierto y CI verde. Lista para mergear.** No mergea.

```mermaid
flowchart TD
    V{"última ronda limpia y\nCHECKLIST completa"} -- no --> STOP([volver a fase fix])
    V -- sí --> D[Done local verde]
    D --> MV["git mv a 4-done · Cierre · PR.md"]
    MV --> CC["commits locales: plan(slug): done · feat|fix(slug): título"]
    CC --> P["UN push: git push -u origin HEAD"]
    P --> G{¿la rama ya tiene PR?}
    G -- no --> NEW[gh pr create --body-file PR.md]
    G -- "sí: iteración" --> IT[gh pr comment + gh pr ready]
    NEW & IT --> X{¿mergeable?}
    X -- CONFLICTING --> CF[conflicts.md] --> W
    X -- sí --> W["gh pr checks --watch"]
    W -- verde --> OK([4-done: listo para mergear. Fin del turno])
    W -- "rojo, del cambio, ronda < 3" --> F["fixer ci → qa → Done local\ncommit fix(slug): CI-n · push"] --> W
    W -- "rojo ajeno, o ronda 3" --> BL([blocked/: orchestrate.md › Bloquear])
```

## Pasos

Si la carpeta ya está en `4-done/` (se retomó de `blocked/`, o CI quedó pendiente en otra sesión), el código ya está commiteado y pusheado: seguí desde el paso 6.

1. Verificá: carpeta en `todolist/3-in-review/<slug>/`; `CHANGELOG › Revisión` con al menos una ronda y ninguna crítica ni alta sin `corregido`; todas las líneas de `CHECKLIST.md` con `[x]`. Si no, volvé a `fix.md`.
2. Done de `PLAN.md` pasa ahora. Si no, volvé a `fix.md` con el log como hallazgo.
3. **La carpeta llega a done antes del push**, en el working tree:
   - `git mv todolist/3-in-review/<slug> todolist/4-done/<slug>`.
   - `CHANGELOG › Cierre`: inicio real (fecha del commit `plan(<slug>): implement`), fin real (hoy), al lado las planificadas; rondas de revisión; qué quedó distinto de lo planeado (dos o tres líneas de Decisiones); deuda abierta con issue y vencimiento.
   - `PR.md` desde `../templates/PR.md`: Objetivo en pasado, la `CHECKLIST` con su evidencia, cómo probar cada CB, resumen de rondas, lo que la persona tiene que mirar.
4. Commits, todos locales: `plan(<slug>): done` con `git add todolist/` (la carpeta movida con `TODO.md`, `CHANGELOG.md` y `PR.md`), y `feat(<slug>): <title del PLAN>` (o `fix(`) con `git add -A`: el código y los tests. El de código es el primero de la rama: todo lo anterior fueron docs. Si preferís commits por tarea para leer el historial, no: la unidad revisada es el conjunto.
5. **Un solo push**: `git push -u origin HEAD`. CI corre una vez por push, no por commit; por eso nada se commitea entre abrir el PR y que CI termine.
6. ¿La rama ya tiene un PR (`gh pr view`)?
   - No: `gh pr create --title "<title del PLAN>" --body-file todolist/4-done/<slug>/PR.md --base main`.
   - Sí, es una iteración (`iterate.md`): `gh pr comment` con el resumen de la iteración y `gh pr ready` (la iteración lo había pasado a draft).
   El número y el link del PR no se escriben en ningún archivo: salen de `gh pr view` sobre la rama. Escribirlos sería un commit más, y otra corrida de CI.
7. `gh pr view --json mergeable`: si dice `CONFLICTING`, `conflicts.md` (se corre solo en modo orquestado; a mano, `/mindstack:rebase`). Conflicto con intenciones incompatibles → `blocked`.
8. **CI verde es parte de done**: `gh pr checks --watch`.
   - Verde: fin. La tarea está en `4-done/` y el turno termina con el link.
   - Rojo, y el log muestra que es del cambio: `Agent fixer` con `ci <slug> <run>` → `Agent qa` sobre lo que cambió → Done local → commit `fix(<slug>): CI-n <qué>` → push → volver a mirar. La carpeta no se mueve: ya está en `4-done` y el commit del arreglo dispara CI igual.
   - Rojo por algo ajeno al cambio (infra, secreto que falta, test inestable de otro módulo), o tercera ronda de CI roja: `blocked` (`orchestrate.md › Bloquear`). Es el único caso en que la carpeta sale de `4-done`.

Reglas del paso 8:
- Cada fallo es un hallazgo `CI-n` en `CHANGELOG › Revisión` (rol `ci`), con resultado `corregido` o `bloqueado: motivo`.
- Si CI falló por algo que el Done de `PLAN.md` no corre, fila en Observaciones: "Done incompleto: CI corre X y el plan no".
- El `fixer` corrige lo que el log dice, nada más. No se relanzan los revisores por un fix de CI: ya vieron el código. Si el fix toca más que el check que falló, sí: la carpeta vuelve a `3-in-review` y `review.md`, ronda nueva.
- Tope: tres rondas de CI. Si el Done local es igual a CI, un tercer rojo seguido es el entorno, no el código.

Terminá con el link del PR y "CI verde: listo para mergear". El merge lo hace la persona; no hay nada que correr después. La limpieza del entorno y del worktree la sugiere el aviso de sesión cuando la tarea ya está mergeada.

## Qué queda si el PR desaparece

Un PR en GitHub no se borra: se cierra. Lo que puede desaparecer es la rama. La carpeta de la tarea vive en la rama hasta el merge:

| Caso | Código | SPEC, PLAN, CHANGELOG, REVIEWs |
|---|---|---|
| mergeado | en `main` | en `main`, en `todolist/4-done/<slug>/` |
| cerrado sin merge, rama viva | en la rama | en la rama |
| cerrado sin merge, rama borrada | perdido | perdido; el PR cerrado sigue en GitHub con su diff, que incluye la carpeta |

## Qué no

- Mergear, ni con `--auto`. El merge es el único punto donde una persona ve el cambio entero.
- Commitear algo después de abrir el PR que no sea un arreglo de CI. Cada push es una corrida más.
- `[skip ci]` en un commit: si el repo tiene checks obligatorios, quedan pendientes para siempre y el PR no se puede mergear.
- Abrir un segundo PR sobre la misma rama.
- Terminar con CI rojo o pendiente. El hook de parada no lo deja.
