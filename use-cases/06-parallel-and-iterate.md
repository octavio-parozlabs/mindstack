# 06 · Varias tareas en paralelo e iteración sobre un PR

El modelo de uso diario: un worktree por tarea, cada uno con su sesión. El borrador lo hacés de a uno (necesita hablar con vos); los orquestadores corren en paralelo. Al final probás cada PR, y mergeás o iterás.

```mermaid
sequenceDiagram
    actor U as Vos
    participant Wa as Claude (worktree facturas-pdf)
    participant Wb as Claude (worktree pagos-timeout)
    participant M as Claude (main)
    participant G as git / GitHub

    rect rgb(255, 245, 230)
    Note over U,G: dos worktrees. El borrador de cada una, con vos
    U->>Wa: claude -w facturas-pdf · /mindstack:draft "exportar facturas a PDF"
    Wa-->>U: SPEC facturas-pdf (commit por vuelta). Leelo
    U->>Wa: /mindstack:plan
    Wa-->>U: PLAN, a 1-pending. Resumen
    U->>Wb: claude -w pagos-timeout · /mindstack:draft "los pagos con timeout se cobran dos veces"
    Wb-->>U: SPEC pagos-timeout con REPRO: integration
    U->>Wb: /mindstack:plan
    Wb-->>U: PLAN, a 1-pending. Resumen
    end

    rect rgb(230, 240, 255)
    Note over U,G: en paralelo, sin vos
    U->>Wa: /mindstack:orchestrate
    U->>Wb: /mindstack:orchestrate
    par
        Wa->>Wa: implement (loop + qa) → review ×3 → fix → review → pr → CI verde
        Wa->>G: PR #88 · url en PR.md
        Wa-->>U: PR #88 abierto · localhost:5231
    and
        Wb->>Wb: implement → review ×3 (limpia) → pr → CI verde
        Wb->>G: PR #89
        Wb-->>U: PR #89 abierto · localhost:5247
    end
    end

    rect rgb(240, 255, 240)
    Note over U,G: probás, mergeás o iterás
    U->>U: prueba #89 en localhost:5247 → está
    U->>G: merge #89
    U->>M: /mindstack:orchestrate (en main)
    M->>G: Cierre con url · 4-done/pagos-timeout · commit

    U->>U: prueba #88 → el PDF sale sin logo
    U->>Wa: /mindstack:draft "el PDF sale sin el logo de la empresa"
    Note over Wa: la tarea tiene PR → iteración: hija facturas-pdf-2
    Wa->>Wa: analyze acotado → SPEC facturas-pdf-2 (padre: facturas-pdf)
    Wa-->>U: SPEC de la iteración. Leelo
    U->>Wa: generá el plan
    Wa-->>U: PLAN de la iteración, a 1-pending. Resumen
    U->>Wa: /mindstack:orchestrate
    Wa->>Wa: toma la hija → implement → review ×3 → pr
    Wa->>G: push · gh pr comment #88 "iteración 2: logo en el PDF" · CI verde
    Wa-->>U: PR #88 actualizado
    U->>U: prueba → está
    U->>G: merge #88
    U->>M: /mindstack:orchestrate (en main)
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

Los links abren los PRs mientras GitHub exista; si un día no, la carpeta tiene todo lo que importa: qué se pidió, qué se decidió, qué dijeron los revisores, qué quedó como deuda. Un PR cerrado sin merge también se finaliza: `/orchestrate` en `main` trae la carpeta desde la rama antes de que se borre.
