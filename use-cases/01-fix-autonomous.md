# 01 · Un bug, de punta a punta, autónomo

Abrís el worktree, pedís que se arregle algo con `/draft`, leés el SPEC, `/plan`, `/orchestrate`, y no intervenís hasta que la tarea está en `4-done`: todo commiteado, PR abierto y CI verde, lista para mergear. Todo en el mismo worktree.

```mermaid
sequenceDiagram
    actor U as Vos
    participant C as Claude (worktree pagos-timeout)
    participant QA as qa
    participant DEV as developer (subagente por tarea)
    participant AN as analyst
    participant CR as code-reviewer
    participant SA as security-auditor
    participant VF as verifier
    participant AP as approver
    participant G as git / GitHub

    U->>C: claude -w pagos-timeout · /mindstack:draft "pagos con timeout se cobran dos veces"
    Note over C: worktree = tarea pagos-timeout · fase analyze

    rect rgb(255, 245, 230)
    Note over U,C: 0-draft · análisis
    C->>C: lee el flujo de pagos (grep / graphify), lista supuestos con %
    C->>QA: Agent qa: reproducir pagos-timeout · síntoma + endpoint (sin la causa)
    QA->>QA: test unitario no reproduce, integración con DB sí
    QA-->>C: REPRO: integration · notes/repro.md
    C->>C: SPEC.md: hoy/propuesto, Diagnóstico, CB-1..CB-4 con diagrama, CA-1..CA-3 (una regla por campo de POST /checkout), D-1 abierta
    C->>G: commit spec(pagos-timeout): ronda 1
    C->>U: SPEC borrador · D-1 · Estado: un pago da timeout y el proveedor sí cobró. ¿Se reintenta? a) ⭐ automático, consultando el estado antes b) con un botón
    U-->>C: D-1 ok
    C->>C: D-1 → CA-1, CB-1, tachada
    C->>G: commit spec(pagos-timeout): ronda 2
    C-->>U: SPEC listo. Leelo y, cuando esté, /mindstack:plan
    U->>U: lee el SPEC
    U->>C: /mindstack:plan
    Note over C: SPEC y sin PLAN → fase plan
    C->>C: acoplamiento, causa raíz confirmada en pagos.service:42, tipo: fix, tareas con rol, fechas, Done = CI
    C->>G: commit plan(pagos-timeout): ronda 1
    end

    C->>C: valida · TODO.md · CHECKLIST.md (CA-1..3, CB-1..4) · chmod a-w SPEC PLAN
    C->>G: git mv → 1-pending · commit plan(pagos-timeout): pending
    C-->>U: resumen: fix, 2 tareas, 2026-11-03 → 11-04, Done = CI, sin fuera de alcance nuevo. Cuando quieras: /mindstack:orchestrate

    U->>C: /mindstack:orchestrate
    Note over C: hook: marcador de la sesión · 1-pending → implement.md

    rect rgb(230, 240, 255)
    Note over C,G: 2-in-progress · implementación (en worktree)
    C->>G: git mv → 2-in-progress · commit
    C->>C: env-up.sh pagos-timeout db
    loop una línea de TODO.md por vuelta, mismo turno
        C->>QA: testear pagos-timeout 1 (rol qa): test de repro a la suite
        QA-->>C: TESTS OK 1 (el test queda en rojo a propósito: es el bug)
        C->>G: commit wip(pagos-timeout): tarea 1 (local)
        C->>QA: testear pagos-timeout 2: CB-1..CB-4 contra el SPEC
        QA-->>C: TESTS ROJOS 2
        C->>DEV: implementar pagos-timeout 2
        DEV-->>C: TASK OK 2 · fix en pagos.service, los 4 tests en verde
        C->>G: commit wip(pagos-timeout): tarea 2 (local)
    end
    C->>C: Done verde
    C->>C: env-up.sh pagos-timeout → http://localhost:5247
    C-->>U: (sigue sin esperar) entorno en localhost:5247
    end

    rect rgb(240, 255, 240)
    Note over C,G: 3-in-review · revisión y corrección
    C->>G: git mv → 3-in-review · commit
    par en un solo turno
        C->>QA: verificar ronda 1
        C->>CR: revisar ronda 1
        C->>SA: auditar ronda 1
        C->>VF: verificar ronda 1
    end
    QA-->>C: REVIEW-qa.md: 0
    CR-->>C: REVIEW-code.md: 1 media
    SA-->>C: REVIEW-security.md: 1 alta (SEC-1 idempotencia)
    VF-->>C: CHECKLIST 6/7 · CA-3 falta: sin validación de amount ≤ 0
    C->>G: commit review(pagos-timeout): round 1 (REVIEW-*.md y CHECKLIST.md)
    Note over C: hallazgos y checklist abierta → fix.md
    C->>AP: aprobar pagos-timeout ronda 1
    AP-->>C: SEC-1 arreglar (cobro doble) · CA-3 arreglar · CODE-1 deuda #45 vence 2026-12-01 · APPROVAL: fix 2
    C->>DEV: corregir pagos-timeout ronda 1: SEC-1, CA-3
    DEV-->>C: FIX OK
    C->>QA: testear pagos-timeout correcciones ronda 1
    par ronda 2
        C->>QA: verificar ronda 2
        C->>CR: revisar ronda 2
        C->>SA: auditar ronda 2
        C->>VF: verificar ronda 2
    end
    QA-->>C: 0
    CR-->>C: 0
    SA-->>C: 0
    VF-->>C: CHECKLIST 7/7
    C->>G: commit review(pagos-timeout): round 2
    end

    Note over C,G: pr.md: llegar a done
    C->>G: git mv → 4-done · Cierre · PR.md · commit plan(pagos-timeout): done
    C->>G: un solo push -u origin HEAD
    C->>G: gh pr create --body-file PR.md
    G-->>C: PR #87
    C->>G: gh pr checks 87 --watch
    G-->>C: lint ✗ (import sin usar)
    C->>DEV: ci pagos-timeout <run>
    DEV-->>C: CI-1 arreglado: import sin usar
    C->>QA: testear pagos-timeout ci <run>
    QA-->>C: suite verde
    C->>G: commit fix(pagos-timeout): CI-1 import sin usar · push
    C->>G: gh pr checks 87 --watch
    G-->>C: todo verde
    Note over C: hook de parada: 4-done y CI verde, deja terminar
    C-->>U: 4-done: PR #87 listo para mergear: https://github.com/…/pull/87

    U->>G: merge en GitHub: la carpeta llega a main ya en 4-done
    Note over U: al abrir claude en main: "mergeada sin limpiar: pagos-timeout → env-down y git worktree remove"
```

## Dónde para y por qué

| Parada | Por qué no se puede saltear |
|---|---|
| pedir el plan (`/plan` o "generá el plan", tuyo) | es el contrato. Lo que no está en el SPEC no se hace; con el plan hecho, los dos se congelan. El orquestador no arranca sin eso |
| `blocked/` (motivos: `orchestrate.md › Bloquear`) | necesita una decisión tuya. Lo dice `BLOCKED.md`, lo muestra el aviso al abrir `claude`, y el PR vuelve a draft |
| `4-done` | lista para mergear: probás y mergeás, o `/draft` lo que falta |
| merge | ningún agente mergea |

"Probar" no es parada: la URL queda impresa y en `CHANGELOG › Cambios`; probás cuando querés.

## Qué quedó en la carpeta

```
todolist/4-done/pagos-timeout/
├── SPEC.md          Diagnóstico con REPRO: integration, CB-1..CB-4
├── PLAN.md          tipo: fix · causa raíz confirmada · tareas 1 (qa) y 2 (dev)
├── TODO.md          [x] [x]
├── CHECKLIST.md     CA-1..3, CB-1..4, todas tachadas con evidencia
├── CHANGELOG.md     Cambios, Decisiones, CI-1, Cierre
├── APPROVAL.md      2 rondas de decisiones del approver
├── TECHNICAL_DEBT.md CODE-1 (#45)
├── REVIEW-qa.md     ronda 2, vacío
├── REVIEW-code.md   ronda 2, vacío
├── REVIEW-security.md ronda 2, vacío
├── PR.md            body del PR #87
└── notes/repro.md
```
