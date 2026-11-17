# Tarjeta del agente

Lo mínimo que un subagente necesita del flujo. La lee cada agente al empezar, en vez de `SKILL.md` (que es para la persona y los comandos). Lo propio de tu rol está en tu `agents/<rol>.md`.

## La tarea

Es una carpeta, `todolist/<estado>/<slug>/`, y su estado es la carpeta: `0-draft` → `1-pending` → `2-in-progress` → `3-in-review` → `4-done`, o `blocked/`. Adentro:

| Archivo | Qué es |
|---|---|
| `SPEC.md` | qué se pidió: criterios `CA-n`, casos borde `CB-n`. Congelado desde `1-pending` |
| `PLAN.md` | cómo se hace: tareas con rol y verificación, el Done. Congelado |
| `TODO.md` | las tareas del PLAN; se tachan |
| `CHECKLIST.md` | una línea por `CA-n`, `CB-n` y `EF-n`; la tacha solo el verifier |
| `CHANGELOG.md` | solo se agrega: Cambios (con evidencia), Observaciones (lo ajeno), Propuestas (lo que sumaría, con dónde se vio), Decisiones (con el principio), CI, Conflictos, Cierre |
| `REVIEW-<rol>.md` | hallazgos de un revisor, uno por ronda (`templates/REVIEW.md`) |
| `APPROVAL.md` | lo que decidió el approver, una sección por ronda; "Para corregir" es lo único que tocan developer y qa |
| `TECHNICAL_DEBT.md` | lo que se dejó a propósito, con vencimiento e issue |
| `wireframes/*.wireloom` | las pantallas `SCR-n`; nunca abras `rendered/` |

## IDs

`CA-n` criterio · `CB-n` caso borde · `EF-n` estado final del PLAN · `D-n` duda del borrador · `SCR-n` pantalla · `QA-n`, `CODE-n`, `SEC-n` hallazgos (se renumeran en cada ronda; entre rondas se citan con la ronda: `R1 CODE-3`) · `CI-n` fallo de CI.

## Reglas que valen para todos

- Escribís solo tus archivos: te lo frena un hook (`roles-and-artifacts.md`). Si necesitás que otro cambie algo, decilo en tu respuesta.
- No commiteás ni pusheás: lo hace el orquestador.
- Nada sin evidencia: lo que afirmás que pasa, lo corriste (comando y salida).
- Lo que no es de tu tarea no lo arreglás: Observaciones o Propuestas.
- Cuando dos reglas chocan, deciden los principios: `${CLAUDE_PLUGIN_ROOT}/PRINCIPLES.md`.
- Terminás con la última línea que pide tu `agents/<rol>.md`: es lo único que lee el orquestador para seguir.
