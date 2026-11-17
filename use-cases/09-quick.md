# 09 · Un cambio chico: camino quick

Un pedido chico y sin riesgo no pasa por todo el ritual. `/draft` lo detecta solo, escribe un SPEC corto y la revisión es de dos agentes. Las reglas: `skills/workflow/references/analyze.md › Camino`.

```mermaid
sequenceDiagram
    actor U as Vos
    participant C as Claude
    participant QA as qa
    participant DEV as developer
    participant CR as code-reviewer (+ seguridad)
    participant VF as verifier
    participant G as git / GitHub

    U->>C: /mindstack:draft "la paginación muestra página 0 al entrar"
    C->>C: diff estimado ~5 líneas, sin auth, plata, datos ni contratos nuevos → camino: quick
    C->>G: commit spec(paginacion-cero): ronda 1 · SPEC corto: CA-1, CB-1
    C-->>U: SPEC listo (quick). Leelo y pedí el plan
    U->>C: generá el plan
    C->>G: PLAN corto · TODO · CHECKLIST · git mv → 1-pending · commit
    U->>C: /mindstack:orchestrate
    C->>QA: testear paginacion-cero 1
    QA-->>C: TESTS ROJOS 1
    C->>DEV: implementar paginacion-cero 1
    DEV-->>C: TASK OK 1
    C->>G: commit wip(paginacion-cero): tarea 1 (local)
    par revisión quick
        C->>CR: revisar ronda 1 (con pasada de seguridad)
        C->>VF: verificar ronda 1
    end
    CR-->>C: 0 hallazgos
    VF-->>C: CHECKLIST 2/2
    Note over C: quick, sin hallazgos y checklist completa: sin approver
    C->>G: 4-done · un push · gh pr create · CI verde
    C-->>U: PR listo para mergear
```

Si el pedido llega con el PR ya abierto y no cambia ningún `CA-n` ni `CB-n` ("renombrá esta variable"), es un retoque: `/draft` deja SPEC y PLAN en el mismo turno y vos solo corrés `/mindstack:orchestrate`.
