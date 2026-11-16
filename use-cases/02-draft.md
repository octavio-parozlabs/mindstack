# 02 · Lo que vos hacés: el borrador

Tu participación antes de delegar es una sola conversación en el worktree de la tarea (`claude -w facturas-pdf`): `/draft` con lo que querés, comentarios sueltos hasta que el SPEC dice lo que querés, y "generá el plan" (o `/mindstack:plan`, es lo mismo). Con eso la tarea queda pendiente. Cada vuelta que cambia un archivo es un commit. El plan no se aprueba: es la checklist del orquestador; vos leés un resumen de cinco líneas y, si algo no cierra, `/draft` sin texto la devuelve a borrador.

```mermaid
sequenceDiagram
    actor U as Vos
    participant C as Claude (worktree facturas-pdf)
    participant D as designer
    participant G as git

    rect rgb(255, 245, 230)
    Note over U,G: SPEC. Termina cuando VOS pedís el plan
    U->>C: claude -w facturas-pdf · /mindstack:draft "exportar facturas a PDF"
    Note over C: worktree = tarea facturas-pdf
    C->>C: lee el módulo de facturas, lista supuestos con %
    Note over C: hay un botón que vos ves → toca la interfaz → designer, siempre
    C->>D: Agent designer: proponer facturas-pdf + pedido + /invoices/:id
    D->>D: copia el patrón del detalle de pedido · wireframes/*.wireloom → render
    D-->>C: notes/ux.md · SCR-1 detalle de factura · SCR-2 error de páginas · 1 duda
    C->>C: SPEC borrador: supuestos, CB-1 a CB-4, SCR-1 y SCR-2, Dudas D-1 a D-3
    C->>G: commit spec(facturas-pdf): ronda 1 (con wireframes/ y rendered/*.svg)
    C->>U: SPEC escrito, mirá los SVG. Faltan 3 decisiones
    Note over C,U: D-1 · Estado: factura #88 emitida, el cliente pide el PDF dos veces en un minuto. ¿Se genera cada vez? a) ⭐ al pedirlo y se cachea b) al emitir y se guarda c) cada vez<br/>D-2 · Estado: un contador con permiso de lectura abre #88. ¿Puede bajarlo? a) ⭐ sí b) solo dueño y admin<br/>D-3 · Estado: factura de 300 páginas. ¿Qué pasa? a) ⭐ se genera igual b) tope de 50 y error claro
    U-->>C: D-1 ok · D-2 ok · D-3 b
    C->>C: D-1 → CA-2, CB-3 · D-2 → CA-5, CB-2 · D-3 → CB-4, CA-6, texto de SCR-2 · las tres tachadas en Dudas
    C->>G: commit spec(facturas-pdf): ronda 2
    U->>U: mira los dos dibujos, lee los CB
    U->>C: el botón "Descargar PDF" va arriba, al lado del estado, no en el menú ⋯
    C->>C: corrige factura-detalle.wireloom · node scripts/wireframes.mjs → SVG nuevo
    C->>G: commit spec(facturas-pdf): ronda 3
    U->>C: agregá un caso borde para facturas anuladas
    C->>C: CB-5 factura anulada, con diagrama
    C->>G: commit spec(facturas-pdf): ronda 4
    end

    rect rgb(230, 240, 255)
    Note over U,G: PLAN. Una frase tuya, y la tarea queda pendiente
    U->>C: generá el plan
    Note over C: SPEC y sin PLAN → fase plan
    C->>C: acoplamiento (invoices.service: 6 callers, sin test → caracterizar), tipo: feature, skills: [api-design]
    C->>U: empate sin principio: ¿la caché en Redis, que ya está, o en disco? historial dice Redis
    U-->>C: Redis
    C->>G: commit plan(facturas-pdf): ronda 1
    C->>C: valida tipo, estado final, roles, Done = CI, fechas, cada SCR-n con su .wireloom y render verde · TODO.md · CHECKLIST.md · chmod a-w SPEC PLAN
    C->>G: git mv → 1-pending · commit plan(facturas-pdf): pending
    C-->>U: resumen: feature · 6 tareas · 2026-11-03 → 11-05 · Done = typecheck+lint+test+coverage:diff · fuera de alcance agregado: PDF firmado · riesgo: invoices.service sin test, se caracteriza primero
    end

    rect rgb(240, 255, 240)
    Note over U,G: ¿algo no cierra? volvés. Si cierra, delegás
    U->>C: /mindstack:draft
    Note over C: sin texto, tarea en 1-pending → reopen
    C->>G: git mv → 0-draft · chmod u+w · commit plan(facturas-pdf): reopen
    C->>U: ¿qué corrijo?
    U-->>C: el PDF firmado sí entra, era parte del pedido
    C->>C: SPEC: lo saca de "qué no se hace", CB-6 firma inválida · PLAN: tarea 7
    C->>G: commit spec(facturas-pdf): ronda 5 · commit plan(facturas-pdf): ronda 2
    C->>G: valida · git mv → 1-pending · commit plan(facturas-pdf): pending
    C-->>U: resumen actualizado. Cuando quieras: /mindstack:orchestrate
    end
```

Si es un bug, antes de escribir el SPEC el analista lanza a `qa` para reproducirlo (caso 01): sin reproducción no hay plan. Si toca la interfaz (algo que vos ves, o un archivo de front), lanza a `designer`, siempre: propone flujo, estados y textos en `notes/ux.md` y dibuja cada pantalla en `wireframes/<nombre>.wireloom`. El SPEC linkea los SVG (`![SCR-1](wireframes/rendered/…svg)`), que es lo que mirás; los agentes leen la fuente. Sus dudas entran a `SPEC › Dudas` con las del analista, numeradas `D-n`, y las contestás por número. Un plan que toca el front sin wireframes no pasa a pendiente.

## Las etapas, y qué las dispara

| Etapa | La dispara | Termina | Commits |
|---|---|---|---|
| SPEC | `/mindstack:draft "<qué querés>"` | cuando vos pedís el plan. El analista no sigue solo | `spec(<slug>): ronda n`, uno por vuelta que cambie el archivo |
| PLAN | `/mindstack:plan`, o "generá el plan" en la conversación | en el mismo turno: valida, deriva `TODO.md`, congela, mueve a `1-pending/`, resumen | `plan(<slug>): ronda n` y `plan(<slug>): pending` |
| volver | `/mindstack:draft` sin texto | cuando pedís el plan otra vez (`/plan` también reabre y replanifica de una) | `plan(<slug>): reopen`, y de nuevo los de arriba |

El planificador te pregunta solo lo que un principio no decide (un empate real, una pregunta abierta del SPEC que cambie el plan). No pregunta "¿está bien el plan?".

## Qué podés decir en el medio

Cualquier cosa. "No, el tope es 100", "agregá un caso borde para facturas anuladas", "el Done tiene que correr los tests e2e", "mostrame el diagrama de hoy otra vez". La tarea es el worktree: no hace falta nombrarla. Cuando ya está pendiente, `/draft` sin texto la trae de vuelta; mientras no abriste el worktree, no corrió nada.

## Lo que no hacés

Ni implementás, ni testeás, ni revisás, ni abrís el PR. Eso es del orquestador (caso 01). Volvés a aparecer para probar en `localhost`, para desempatar si tres analistas no coinciden, y para mergear.
