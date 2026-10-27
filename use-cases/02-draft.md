# 02 · Lo que vos hacés: el borrador

Tu participación antes de delegar es una sola conversación: `/draft` con lo que querés, comentarios sueltos hasta que el SPEC dice lo que querés, y "generá el plan". Con eso la tarea queda pendiente. Cada vuelta que cambia un archivo es un commit. El plan no se aprueba: es la checklist del orquestador; vos leés un resumen de cinco líneas y, si algo no cierra, `/draft` sin texto la devuelve a borrador.

```mermaid
sequenceDiagram
    actor U as Vos
    participant C as Claude (sesión principal, main)
    participant G as git

    rect rgb(255, 245, 230)
    Note over U,G: SPEC. Termina cuando VOS pedís el plan
    U->>C: /mindstack:draft "exportar facturas a PDF"
    C->>C: lee el módulo de facturas, lista supuestos con %
    C->>U: ¿el PDF se genera al pedirlo o se guarda al emitir? creo que al pedirlo (70%)
    U-->>C: al pedirlo, y se cachea
    C->>U: ¿quién puede pedirlo? asumo dueño de la factura y admin (85%), lo afirmo salvo que digas
    U-->>C: también contadores con permiso de lectura
    C->>C: CB-1 factura sin ítems · CB-2 contador sin permiso · CB-3 caché vencida · CB-4 PDF de 300 páginas
    C->>G: commit spec(facturas-pdf): ronda 1
    C-->>U: SPEC.md escrito. Leelo, comentá, y cuando esté pedime el plan
    U->>U: lee el SPEC con calma
    U->>C: el CB-4 no, tope de 50 páginas y error claro
    C->>C: corrige CB-4
    C->>G: commit spec(facturas-pdf): ronda 2
    U->>C: agregá un caso borde para facturas anuladas
    C->>C: CB-5 factura anulada, con diagrama
    C->>G: commit spec(facturas-pdf): ronda 3
    end

    rect rgb(230, 240, 255)
    Note over U,G: PLAN. Una frase tuya, y la tarea queda pendiente
    U->>C: generá el plan
    Note over C: tarea activa con SPEC y sin PLAN → fase plan
    C->>C: acoplamiento (invoices.service: 6 callers, sin test → caracterizar), tipo: feature, skills: [api-design]
    C->>U: empate sin principio: ¿la caché en Redis, que ya está, o en disco? historial dice Redis
    U-->>C: Redis
    C->>G: commit plan(facturas-pdf): ronda 1
    C->>C: valida tipo, estado final, roles, Done = CI, fechas · TODO.md · chmod a-w SPEC PLAN
    C->>G: git mv → 1-pending · commit plan(facturas-pdf): pending
    C-->>U: resumen: feature · 6 tareas · 2026-11-03 → 11-05 · Done = typecheck+lint+test+coverage:diff · fuera de alcance agregado: PDF firmado · riesgo: invoices.service sin test, se caracteriza primero
    end

    rect rgb(240, 255, 240)
    Note over U,G: ¿algo no cierra? volvés. Si cierra, delegás
    U->>C: /mindstack:draft
    Note over C: sin texto, tarea activa en 1-pending → reopen
    C->>G: git mv → 0-draft · chmod u+w · commit plan(facturas-pdf): reopen
    C->>U: ¿qué corrijo?
    U-->>C: el PDF firmado sí entra, era parte del pedido
    C->>C: SPEC: lo saca de "qué no se hace", CB-6 firma inválida · PLAN: tarea 7
    C->>G: commit spec(facturas-pdf): ronda 4 · commit plan(facturas-pdf): ronda 2
    C->>G: valida · git mv → 1-pending · commit plan(facturas-pdf): pending
    C-->>U: resumen actualizado. claude -w facturas-pdf y /mindstack:orchestrate ahí
    end
```

Si es un bug, antes de escribir el SPEC el analista lanza a `qa` para reproducirlo (caso 01): sin reproducción no hay plan.

## Las etapas, y qué las dispara

| Etapa | La dispara | Termina | Commits |
|---|---|---|---|
| SPEC | `/mindstack:draft "<qué querés>"` | cuando vos pedís el plan. El analista no sigue solo | `spec(<slug>): ronda n`, uno por vuelta que cambie el archivo |
| PLAN | "generá el plan" en la conversación | en el mismo turno: valida, deriva `TODO.md`, congela, mueve a `1-pending/`, resumen | `plan(<slug>): ronda n` y `plan(<slug>): pending` |
| volver | `/mindstack:draft` sin texto | cuando pedís el plan otra vez | `plan(<slug>): reopen`, y de nuevo los de arriba |

El planificador te pregunta solo lo que un principio no decide (un empate real, una pregunta abierta del SPEC que cambie el plan). No pregunta "¿está bien el plan?".

## Qué podés decir en el medio

Cualquier cosa. "No, el tope es 100", "agregá un caso borde para facturas anuladas", "el Done tiene que correr los tests e2e", "mostrame el diagrama de hoy otra vez". Mientras la tarea está en borrador, la conversación sabe cuál es. Cuando ya está pendiente, `/draft` sin texto la trae de vuelta; mientras no abriste el worktree, no corrió nada.

## Lo que no hacés

Ni implementás, ni testeás, ni revisás, ni abrís el PR. Eso es del orquestador (caso 01). Volvés a aparecer para probar en `localhost`, para desempatar si tres analistas no coinciden, y para mergear.
