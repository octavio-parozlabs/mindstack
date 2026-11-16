# 04 · Revisión con hallazgos, corrección y conflicto con main

Lo que pasa cuando la revisión encuentra algo, cuando un hallazgo está mal, cuando falta algo de la checklist, cuando el PR choca con otro que entró antes, y cómo llega a `4-done`.

```mermaid
sequenceDiagram
    actor U as Vos
    participant C as Claude (sesión principal)
    participant QA as qa
    participant CR as code-reviewer
    participant SA as security-auditor
    participant VF as verifier
    participant AN as analyst
    participant FX as fixer
    participant RS as conflict-resolver
    participant H as hooks
    participant G as git / GitHub

    Note over C,G: 3-in-review · ronda 1 (código sin commitear, se revisa git diff main)
    par un turno
        C->>QA: verificar ronda 1 base main
        C->>CR: revisar ronda 1 base main
        C->>SA: auditar ronda 1 base main
        C->>VF: verificar ronda 1
    end
    CR->>H: Write REVIEW-qa.md (por error)
    H-->>CR: exit 2: este rol solo escribe REVIEW-code.md
    CR->>CR: Write REVIEW-code.md
    QA-->>C: QA-1 alta: CB-3 sin test
    CR-->>C: CODE-1 media, CODE-2 baja, CODE-3 alta: N+1 en el listado
    SA-->>C: SEC-1 crítica: id de factura en la URL sin verificar dueño
    VF-->>C: CHECKLIST 8/9 · CA-4 falta: GET /invoices/:id/pdf de otro usuario no tiene test
    C->>G: commit review(facturas-pdf): round 1
    C-->>C: 1 crítica, 2 altas, 1 media, 1 baja, 1 línea abierta → fase fix

    Note over C,G: fix.md · validar
    par un turno
        C->>AN: validar facturas-pdf SEC-1
        C->>AN: validar facturas-pdf QA-1
        C->>AN: validar facturas-pdf CODE-3
    end
    AN-->>C: SEC-1 real · QA-1 real · CODE-3 refutado: el listado ya hace un solo JOIN (invoices.repo.ts:30)
    C->>AN: consenso ×3: ¿CODE-3 es real?
    AN-->>C: 3/3 refutado → Revisión: refutado, con la evidencia
    C->>FX: corregir ronda 1: SEC-1, QA-1, CA-4, CODE-1, CODE-2
    FX->>FX: SEC-1: verifica dueño en el handler (sin commit)
    FX->>FX: QA-1: pide test a qa en su resumen
    FX->>FX: CODE-1: deuda #52 vence 2026-12-15 · CODE-2: deuda #53
    FX->>H: Edit todolist/3-in-review/facturas-pdf/PLAN.md
    H-->>FX: exit 2: PLAN.md es inmutable fuera de 0-draft
    FX->>FX: la nota va a CHANGELOG › Decisiones
    FX-->>C: Revisión: 1 corregido, 2 deuda, QA-1 y CA-4 para qa
    C->>QA: testear cambios del fixer + CB-3 + CA-4
    QA-->>C: tests CB-3, CA-4 y SEC-1 verdes

    Note over C,G: ronda 2
    par un turno
        C->>QA: verificar ronda 2
        C->>CR: revisar ronda 2
        C->>SA: auditar ronda 2
        C->>VF: verificar ronda 2
    end
    QA-->>C: 0
    CR-->>C: 0
    SA-->>C: 0
    VF-->>C: CHECKLIST 9/9
    C->>G: commit review(facturas-pdf): round 2
    C-->>C: limpia → fase pr

    C->>G: git mv → 4-done · Cierre · PR.md · commit done · commit feat(facturas-pdf) · un push · gh pr create
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
    C->>G: gh pr checks 88 --watch
    G-->>C: verde
    C-->>U: 4-done: PR #88 listo para mergear

    U->>G: merge: la carpeta llega a main en 4-done
```

## Qué garantiza cada red

| Red | Qué paró en este caso |
|---|---|
| `write-scope.sh` del `code-reviewer` | que escribiera el archivo de QA |
| `plan-immutable.sh` | que el `fixer` tocara el PLAN |
| validar antes de corregir | CODE-3 estaba mal: el corrector no tocó un listado que andaba |
| `verifier` y `CHECKLIST.md` | CA-4 (otro usuario no ve tu PDF) no tenía test aunque el código lo cubría; ahora lo tiene |
| crítica y alta no pueden ser deuda | SEC-1 se corrigió; QA-1 se testeó |
| tope de cinco rondas | si la ronda 5 hubiera seguido abierta, `blocked/` con los IDs como motivo |
| rebase y `--force-with-lease`, nunca `--force` | el resolutor no pisó lo que otro pusheó |
| nadie mergea | el merge fue tuyo |
