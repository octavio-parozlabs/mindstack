# 06 · Varias tareas en paralelo e iteración sobre un PR

El modelo de uso diario: un worktree por tarea, cada uno con su sesión. El borrador lo hacés de a uno (necesita hablar con vos); los orquestadores corren en paralelo. Cada tarea termina en `4-done` (PR verde, lista para mergear) o en `blocked/`. Probás cada PR, y mergeás o iterás.

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
        Wa->>Wa: implement (loop + qa) → review ×4 → approver y fix → review → 4-done → CI verde
        Wa->>G: PR #88
        Wa-->>U: 4-done: PR #88 listo para mergear · localhost:5231
    and
        Wb->>Wb: implement → review ×4 (limpia) → 4-done → CI verde
        Wb->>G: PR #89
        Wb-->>U: 4-done: PR #89 listo para mergear · localhost:5247
    end
    end

    rect rgb(240, 255, 240)
    Note over U,G: probás, mergeás o iterás
    U->>U: prueba #89 en localhost:5247 → está
    U->>G: merge #89: 4-done/pagos-timeout llega a main
    Note over M: al abrir claude en main: "mergeada sin limpiar: pagos-timeout"

    U->>U: prueba #88 → el PDF sale sin logo
    U->>Wa: /mindstack:draft "el PDF sale sin el logo de la empresa"
    Note over Wa: la tarea tiene PR → iteración: hija facturas-pdf-2 · PR #88 a draft
    Wa->>Wa: analyze acotado → SPEC facturas-pdf-2 (padre: facturas-pdf)
    Wa-->>U: SPEC de la iteración. Leelo
    U->>Wa: generá el plan
    Wa-->>U: PLAN de la iteración, a 1-pending. Resumen
    U->>Wa: /mindstack:orchestrate
    Wa->>Wa: toma la hija → implement → review ×4 → 4-done
    Wa->>G: un push · gh pr comment #88 "iteración 2: logo en el PDF" · gh pr ready · CI verde
    Wa-->>U: 4-done: PR #88 actualizado y listo para mergear
    U->>U: prueba → está
    U->>G: merge #88: facturas-pdf y facturas-pdf-2 llegan a main en 4-done
    end
```

## Por qué una tarea hija y no "arreglalo"

| Si fuera "arreglalo en la sesión" | Con tarea hija |
|---|---|
| el cambio no tiene SPEC: nadie sabe qué se pidió | `SPEC.md` propio, acotado a lo que falta, con `padre:` |
| el PLAN del padre dice una cosa y el código otra | el PLAN del padre sigue intacto y verdadero; la hija tiene el suyo |
| sin revisión: lo que entra al PR después de la revisión nadie lo miró | pasa por los cuatro revisores igual |
| el CHANGELOG mezcla dos pedidos | cada una con su memoria; el Cierre del padre lista las iteraciones |

## Qué queda cuando termina

```
todolist/4-done/
├── facturas-pdf/      SPEC, PLAN, TODO, CHECKLIST, CHANGELOG (Cierre, iteración facturas-pdf-2), REVIEW-*, PR.md
├── facturas-pdf-2/    SPEC (padre: facturas-pdf), PLAN, TODO, CHECKLIST, CHANGELOG, REVIEW-*, PR.md
└── pagos-timeout/     …
```

El PR de cada tarea se encuentra desde la rama o en el historial de GitHub; la carpeta tiene todo lo que importa: qué se pidió, qué se decidió, qué dijeron los revisores, qué quedó como deuda. Un PR cerrado sin merge deja la carpeta solo en su rama.
