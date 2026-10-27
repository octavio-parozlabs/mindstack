# 02 · Lo que vos hacés: borrador y aprobación

Tu participación antes de delegar: `/draft` con lo que querés, comentarios sueltos, "generá el plan", más comentarios, `/approve`. Entre cada paso hay tantas vueltas como quieras, y cada vuelta que cambia un archivo es un commit. Nada avanza de etapa sin que lo pidas: el analista no genera el plan, el planificador no aprueba.

```mermaid
sequenceDiagram
    actor U as Vos
    participant C as Claude (sesión principal, main)
    participant G as git

    rect rgb(255, 245, 230)
    Note over U,G: etapa 1 · SPEC. Termina cuando VOS decís que está
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
    C-->>U: corregido. ¿Algo más, o pido el plan?
    U->>C: agregá un caso borde para facturas anuladas
    C->>C: CB-5 factura anulada, con diagrama
    C->>G: commit spec(facturas-pdf): ronda 3
    C-->>U: listo
    end

    rect rgb(230, 240, 255)
    Note over U,G: etapa 2 · PLAN. Solo porque lo pediste
    U->>C: generá el plan
    Note over C: tarea activa con SPEC y sin PLAN → fase plan
    C->>C: acoplamiento (invoices.service: 6 callers, sin test → caracterizar), tipo: feature, skills: [api-design]
    C->>G: commit plan(facturas-pdf): ronda 1
    C->>U: PLAN.md: 5 tareas con rol, fechas 2026-11-03 → 2026-11-05, Done = typecheck + lint + test + coverage:diff (lo mismo que CI). Leelo
    U->>C: la tarea 3 partila, endpoint y caché aparte
    C->>C: corrige
    C->>G: commit plan(facturas-pdf): ronda 2
    C-->>U: corregido. Cuando esté, /mindstack:approve
    U->>C: una duda del SPEC, el tope de 50 páginas ¿aplica al admin?
    C->>C: SPEC: CB-4 aclara que aplica a todos. PLAN sigue coherente
    C->>G: commit spec(facturas-pdf): ronda 4
    end

    rect rgb(240, 255, 240)
    Note over U,G: etapa 3 · aprobar y delegar
    U->>C: /mindstack:approve
    C->>C: verifica tipo, Estado final verificable, roles, Done, fechas · TODO.md · chmod a-w SPEC PLAN
    C->>G: git mv → 1-pending · commit plan(facturas-pdf): approve
    C-->>U: aprobada. claude -w facturas-pdf y /mindstack:orchestrate
    end
```

Si es un bug, en la etapa 1 el analista lanza a `qa` para reproducirlo antes de escribir el SPEC (caso 01): sin reproducción no hay tarea.

## Las tres etapas, y qué las dispara

| Etapa | La dispara | Termina | Commits |
|---|---|---|---|
| SPEC | `/mindstack:draft "<qué querés>"` | cuando vos decís que está. El analista no sigue solo | `spec(<slug>): ronda n`, uno por vuelta que cambie el archivo |
| PLAN | decís "generá el plan" en la conversación | cuando vos decís que está | `plan(<slug>): ronda n` |
| aprobar | `/mindstack:approve` | mueve a `1-pending/` y congela | `plan(<slug>): approve` |

Mientras la tarea está en `0-draft/` podés volver a cualquiera de los dos archivos con un comentario: la conversación sabe cuál es la tarea. Si cambiás el SPEC después del PLAN, el planificador revisa que el plan siga coherente y lo dice.

## Qué podés decir en el medio

Cualquier cosa. "No, el tope es 100", "agregá un caso borde para facturas anuladas", "el Done tiene que correr los tests e2e", "mostrame el diagrama de hoy otra vez". Después de `/approve` no se toca más, y lo que falte es una iteración (`generá el plan "qué falta"`, caso 06).

## Lo que no hacés

Ni implementás, ni testeás, ni revisás, ni abrís el PR. Eso es del orquestador (caso 01). Volvés a aparecer para probar en `localhost`, para desempatar si tres analistas no coinciden, y para mergear.
