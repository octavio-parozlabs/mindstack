# 06 · Varias tareas en paralelo e iteración sobre un PR

El modelo de uso diario: lo que necesita hablar con vos pasa en el checkout principal; lo que no, corre en paralelo en worktrees. Al final probás cada PR, y mergeás o iterás.

```mermaid
sequenceDiagram
    actor U as Vos
    participant M as Claude (principal, main)
    participant Wa as Claude (worktree a)
    participant Wb as Claude (worktree b)
    participant G as git / GitHub

    rect rgb(255, 245, 230)
    Note over U,M: en el principal: entender y aprobar, una tarea tras otra
    U->>M: /mindstack:draft "exportar facturas a PDF"
    M-->>U: SPEC facturas-pdf (commit por vuelta). Leelo
    U->>M: generá el plan
    M-->>U: PLAN facturas-pdf. Leelo
    U->>M: /mindstack:approve
    M->>G: 1-pending/facturas-pdf · commit
    U->>M: /mindstack:draft "los pagos con timeout se cobran dos veces"
    M-->>U: SPEC pagos-timeout con REPRO: integration
    U->>M: generá el plan
    M-->>U: PLAN pagos-timeout
    U->>M: /mindstack:approve
    M->>G: 1-pending/pagos-timeout · commit
    end

    rect rgb(230, 240, 255)
    Note over U,G: en paralelo: un worktree y un orquestador por tarea, sin vos
    U->>Wa: claude -w facturas-pdf · /mindstack:orchestrate
    U->>Wb: claude -w pagos-timeout · /mindstack:orchestrate
    par
        Wa->>Wa: implement (loop + qa) → review ×3 → fix → review → pr
        Wa->>G: PR #88 · url en PR.md
        Wa-->>U: PR #88 abierto · localhost:5231
    and
        Wb->>Wb: implement → review ×3 (limpia) → pr
        Wb->>G: PR #89
        Wb-->>U: PR #89 abierto · localhost:5247
    end
    end

    rect rgb(240, 255, 240)
    Note over U,G: probás, mergeás o iterás
    U->>U: prueba #89 en localhost:5247 → está
    U->>G: merge #89
    U->>M: /mindstack:orchestrate (en main → finalize)
    M->>G: Cierre con url · 4-done/pagos-timeout · commit

    U->>U: prueba #88 → el PDF sale sin logo
    U->>Wa: /mindstack:draft "el PDF sale sin el logo de la empresa"
    Wa->>Wa: analyze acotado → SPEC facturas-pdf-2 (padre: facturas-pdf)
    Wa-->>U: SPEC de la iteración. Leelo
    U->>Wa: generá el plan
    Wa-->>U: PLAN de la iteración
    U->>Wa: /mindstack:approve
    Wa->>G: 1-pending/facturas-pdf-2 · commit (en la rama)
    U->>Wa: /mindstack:orchestrate
    Wa->>Wa: implement → review ×3 → pr
    Wa->>G: push · gh pr comment #88 "iteración 2: logo en el PDF"
    Wa-->>U: PR #88 actualizado
    U->>U: prueba → está
    U->>G: merge #88
    U->>M: /mindstack:orchestrate (en main → finalize, padre e hija)
    M->>G: Cierre con url e iteraciones · 4-done/facturas-pdf y facturas-pdf-2 · commit
    end
```

## Por qué una tarea hija y no "arreglalo"

| Si fuera "arreglalo en la sesión" | Con tarea hija |
|---|---|
| el cambio no tiene SPEC: nadie sabe qué se pidió | `SPEC.md` propio, acotado a lo que falta, con `padre:` |
| el PLAN del padre dice una cosa y el código otra | el PLAN del padre sigue intacto y verdadero; la hija tiene el suyo |
| sin revisión: lo que entra al PR después de la revisión nadie lo miró | pasa por los tres revisores igual |
| el CHANGELOG mezcla dos pedidos | cada una con su memoria; el Cierre del padre lista las iteraciones |

## Qué queda cuando termina

```
docs/plans/4-done/
├── facturas-pdf/      SPEC, PLAN, TODO, CHANGELOG (Cierre: PR #88, url, iteración facturas-pdf-2), REVIEW-*, PR.md (pr: 88, url)
├── facturas-pdf-2/    SPEC (padre: facturas-pdf), PLAN, TODO, CHANGELOG, REVIEW-*, PR.md (pr: 88, url)
└── pagos-timeout/     …, PR.md (pr: 89, url)
```

Los links abren los PRs mientras GitHub exista; si un día no, la carpeta tiene todo lo que importa: qué se pidió, qué se decidió, qué dijeron los revisores, qué quedó como deuda. Un PR cerrado sin merge también se finaliza: `fase finalize` trae la carpeta desde la rama antes de que se borre.
