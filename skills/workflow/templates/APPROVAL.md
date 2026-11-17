# Aprobación: <título>

<!-- Lo escribe solo el approver (hook). Una sección por ronda, se agrega abajo y nunca se reescribe: lo decidido no se rediscute.
developer y qa leen solo "Para corregir" de la ronda en curso. El PR toma de acá los riesgos aceptados y los descartes. -->

## Ronda 1 de <rondas_revision> · AAAA-MM-DD · APPROVAL: fix 2

### Para corregir

Lo único que developer y qa tocan en esta ronda. Nada fuera de esta lista.

| ID | Quién | Arreglo |
|---|---|---|
| CODE-1 | developer | validar `productId` contra el repositorio, no contra la cache (`orders.service.ts:48`) |
| CA-3 | qa | test que nombre CA-3: `amount ≤ 0` → 400 |

### Decisiones

Una fila por hallazgo de los `REVIEW-*.md` y por línea sin tachar de `CHECKLIST.md`. Decisión: `arreglar` · `deuda #issue` · `riesgo aceptado` · `descartado` · `bloqueado`. Lo que no es `arreglar` lleva un motivo que se pueda discutir al mergear.

| Rol | ID | Severidad | Decisión | Motivo |
|---|---|---|---|---|
| code-reviewer | CODE-1 | alta | arreglar | crea el pedido con un producto borrado (rompe CA-2) |
| verifier | CA-3 | — | arreglar | sin test |
| security-auditor | SEC-2 | media | riesgo aceptado | rate limit en un endpoint solo de admins internos detrás de VPN; Práctico antes que puro |
| code-reviewer | CODE-3 | alta | descartado | pide paginar; SPEC › Qué no se hace: "paginación, otra tarea" |
| code-reviewer | CODE-4 | baja | deuda #52 | nombre engañoso en un helper interno; vence 2026-12-15 (fila en TECHNICAL_DEBT.md) |
