# 01 · Un bug, de punta a punta, autónomo

Pedís que se arregle algo con `/draft`, leés el SPEC, decís "generá el plan", lo leés, aprobás, y no intervenís hasta que hay un PR con CI verde. Tres comandos tuyos, una frase, y el merge.

```mermaid
sequenceDiagram
    actor U as Vos
    participant C as Claude (sesión principal)
    participant QA as qa
    participant DEV as developer (ralph-loop)
    participant AN as analyst ×3
    participant CR as code-reviewer
    participant SA as security-auditor
    participant FX as fixer
    participant G as git / GitHub

    U->>C: /mindstack:draft "pagos con timeout se cobran dos veces"
    Note over C: fase analyze

    rect rgb(255, 245, 230)
    Note over U,C: 0-draft · análisis
    C->>C: lee el flujo de pagos (grep / graphify), lista supuestos con %
    loop una pregunta por vez
        C->>U: ¿el reintento es automático? creo que sí (60%)
        U-->>C: sí, sin botón
    end
    C->>QA: Agent qa: reproducir pagos-timeout · síntoma + endpoint (sin la causa)
    QA->>QA: test unitario no reproduce, integración con DB sí
    QA-->>C: REPRO: integration · notes/repro.md
    C->>C: SPEC.md: hoy/propuesto, Diagnóstico, CB-1..CB-4 con diagrama, criterios
    C->>G: commit spec(pagos-timeout): ronda 1
    C-->>U: SPEC listo. Leelo y, cuando esté, pedime el plan
    U->>U: lee el SPEC
    U->>C: generá el plan
    Note over C: tarea activa con SPEC y sin PLAN → fase plan
    C->>C: acoplamiento, causa raíz confirmada en pagos.service:42, tipo: fix, tareas con rol, fechas, Done = CI
    C->>G: commit plan(pagos-timeout): ronda 1
    C-->>U: PLAN listo. Leelo y después /mindstack:approve
    U->>U: lee el PLAN
    end

    U->>C: /mindstack:approve
    C->>C: TODO.md, chmod a-w SPEC PLAN
    C->>G: git mv → 1-pending · commit plan(pagos-timeout): approve
    C-->>U: aprobada. claude -w pagos-timeout y /mindstack:orchestrate ahí

    U->>C: claude -w pagos-timeout · /mindstack:orchestrate
    Note over C: worktree pagos-timeout, 1-pending → implement.md

    rect rgb(230, 240, 255)
    Note over C,G: 2-in-progress · implementación (en worktree)
    C->>G: git mv → 2-in-progress · commit
    C->>C: env-up.sh pagos-timeout db
    C->>DEV: /ralph-loop con agents/developer.md
    loop una línea de TODO.md por vuelta, sin commit
        DEV->>QA: tarea 1 (rol qa): test de repro a la suite → rojo
        DEV->>DEV: tarea 2: fix en pagos.service
        DEV->>QA: Agent qa: testear pagos-timeout 2
        QA-->>DEV: 4 tests, CB-1..CB-4 verdes
        DEV->>DEV: [x] en TODO, fila en Cambios
    end
    DEV-->>C: PLAN DONE · Done verde
    C->>C: env-up.sh pagos-timeout → http://localhost:5247
    C-->>U: (sigue sin esperar) entorno en localhost:5247
    end

    rect rgb(240, 255, 240)
    Note over C,G: 3-in-review · revisión y corrección
    C->>G: git mv → 3-in-review · commit
    par en un solo turno
        C->>QA: verificar ronda 1 base main
        C->>CR: revisar ronda 1 base main
        C->>SA: auditar ronda 1 base main
    end
    QA-->>C: REVIEW-qa.md: 0
    CR-->>C: REVIEW-code.md: 1 media
    SA-->>C: REVIEW-security.md: 1 alta (SEC-1 idempotencia)
    C->>G: commit review(pagos-timeout): round 1 (solo REVIEW-*.md)
    Note over C: hay alta → fix.md
    C->>FX: corregir ronda 1
    FX->>FX: SEC-1 corregido, CODE-1 a deuda #45 vence 2026-12-01
    FX-->>C: Revisión en CHANGELOG
    C->>QA: testear cambios del fixer
    par ronda 2
        C->>QA: verificar ronda 2
        C->>CR: revisar ronda 2
        C->>SA: auditar ronda 2
    end
    QA-->>C: 0
    CR-->>C: 0
    SA-->>C: 0
    C->>G: commit review(pagos-timeout): round 2
    end

    Note over C,G: pr.md
    C->>G: git add -A · commit fix(pagos-timeout): reintento idempotente
    C->>G: PR.md · commit · push -u origin HEAD
    C->>G: gh pr create --body-file PR.md
    G-->>C: PR #87
    C->>G: pr: 87 · url en PR.md · commit · push
    C->>G: gh pr checks 87 --watch
    G-->>C: lint ✗ (import sin usar)
    C->>FX: ci pagos-timeout <run>
    FX-->>C: CI-1 corregido
    C->>G: commit fix(pagos-timeout): CI-1 import sin usar · push
    C->>G: gh pr checks 87 --watch
    G-->>C: todo verde
    C-->>U: PR #87 abierto y verde: https://github.com/…/pull/87. Mergeá y corré /mindstack:orchestrate en main

    U->>G: merge en GitHub
    U->>C: /mindstack:orchestrate (en main, PR mergeado → fase finalize)
    C->>C: Cierre: fechas reales, PR #87, deuda #45
    C->>C: env-down.sh pagos-timeout
    C->>G: git mv → 4-done · commit plan(pagos-timeout): finalize
```

## Dónde para y por qué

| Parada | Por qué no se puede saltear |
|---|---|
| aprobar (`/approve`, tuyo) | es el contrato. Lo que no está en SPEC/PLAN no se hace; lo que está, se congela. El orquestador no arranca sin eso |
| consenso sin acuerdo (caso 03) | tres analistas no coincidieron: la decisión es tuya |
| ronda 2 con crítica o alta | dos rondas que no cierran son un desacuerdo, no un bug |
| `BLOCKED:` o tres fallos en la misma tarea | algo externo o una ambigüedad que el consenso no resolvió |
| CI rojo tres veces, o rojo por algo ajeno al cambio | el orquestador itera con el log hasta tres rondas; más es el entorno, no el código |
| merge | ningún agente mergea |

"Probar" no es parada: la URL queda impresa y en `CHANGELOG › Cambios`; probás cuando querés.

## Qué quedó en la carpeta

```
docs/plans/4-done/pagos-timeout/
├── SPEC.md          Diagnóstico con REPRO: integration, CB-1..CB-4
├── PLAN.md          tipo: fix · causa raíz confirmada · tareas 1 (qa) y 2 (dev)
├── TODO.md          [x] [x]
├── CHANGELOG.md     Cambios, Decisiones, Deuda (#45), Revisión (2 rondas), Cierre
├── REVIEW-qa.md     ronda 2, vacío
├── REVIEW-code.md   ronda 2, vacío
├── REVIEW-security.md ronda 2, vacío
├── PR.md            pr: 87
└── notes/repro.md
```
