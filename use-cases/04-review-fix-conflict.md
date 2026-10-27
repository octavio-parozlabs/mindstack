# 04 · Revisión con hallazgos, corrección y conflicto con main

Lo que pasa cuando la revisión encuentra algo, cuando el PR choca con otro que entró antes, y cómo se cierra.

```mermaid
sequenceDiagram
    actor U as Vos
    participant C as Claude (sesión principal)
    participant QA as qa
    participant CR as code-reviewer
    participant SA as security-auditor
    participant FX as fixer
    participant RS as conflict-resolver
    participant H as hooks
    participant G as git / GitHub

    Note over C,G: 3-in-review · ronda 1 (código sin commitear, se revisa git diff main)
    par un turno
        C->>QA: verificar ronda 1 base main
        C->>CR: revisar ronda 1 base main
        C->>SA: auditar ronda 1 base main
    end
    CR->>H: Write REVIEW-qa.md (por error)
    H-->>CR: exit 2: este rol solo escribe REVIEW-code.md
    CR->>CR: Write REVIEW-code.md
    QA-->>C: QA-1 alta: CB-3 sin test
    CR-->>C: CODE-1 media, CODE-2 baja
    SA-->>C: SEC-1 crítica: id de factura en la URL sin verificar dueño
    C->>G: commit review(facturas-pdf): round 1
    C-->>C: 1 crítica, 1 alta, 1 media, 1 baja → fase fix

    Note over C,G: fix.md
    C->>FX: corregir ronda 1
    FX->>FX: SEC-1: verifica dueño en el handler (sin commit)
    FX->>FX: QA-1: pide test a qa en su resumen
    FX->>FX: CODE-1: deuda #52 vence 2026-12-15 · CODE-2: deuda #53
    FX->>H: Edit docs/plans/3-in-review/facturas-pdf/PLAN.md
    H-->>FX: exit 2: PLAN.md es inmutable fuera de 0-draft
    FX->>FX: la nota va a CHANGELOG › Decisiones
    FX-->>C: Revisión: 1 corregido, 2 deuda, 1 para qa
    C->>QA: testear cambios del fixer + CB-3
    QA-->>C: test CB-3 y test de SEC-1 verdes

    Note over C,G: ronda 2
    par un turno
        C->>QA: verificar ronda 2
        C->>CR: revisar ronda 2
        C->>SA: auditar ronda 2
    end
    QA-->>C: 0
    CR-->>C: 0
    SA-->>C: 0
    C->>G: commit review(facturas-pdf): round 2
    C-->>C: limpia → fase pr

        C->>G: commit feat(facturas-pdf): … · PR.md · push · gh pr create
    G-->>C: PR #88 · mergeable: CONFLICTING
    Note over C: mergeable CONFLICTING → fase conflicts, sin parar
    C->>RS: resolver
    RS->>G: git fetch · git rebase origin/main
    G-->>RS: conflicto en invoices/service.ts
    RS->>RS: lee PLAN y Decisiones de la rama + git log main -5 -- invoices/service.ts
    RS->>RS: resuelve cumpliendo las dos intenciones
    RS->>RS: suite verde
    RS->>G: push --force-with-lease
    RS->>RS: CHANGELOG › Conflictos: archivo, decisión · gh pr comment
    RS-->>C: rebase ok, 1 archivo
    C-->>U: PR #88 mergeable

    U->>G: merge
    U->>C: /mindstack:orchestrate (en main → fase finalize)
    C->>C: Cierre: inicio/fin reales, PR #88, deuda abierta #52 #53
    C->>G: env-down · git mv → 4-done · commit
```

## Qué garantiza cada red

| Red | Qué paró en este caso |
|---|---|
| `write-scope.sh` del `code-reviewer` | que escribiera el archivo de QA |
| `plan-immutable.sh` | que el `fixer` tocara el PLAN |
| crítica y alta no pueden ser deuda | SEC-1 se corrigió; QA-1 se testeó |
| tope de dos rondas | si la ronda 2 hubiera traído otra crítica, parada para vos |
| rebase y `--force-with-lease`, nunca `--force` | el resolutor no pisó lo que otro pusheó |
| nadie mergea | el merge fue tuyo |
