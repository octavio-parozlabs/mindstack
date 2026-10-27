# Checklist de rendimiento

Referencia rápida para usar junto a `mindstack:performance`. Los fixes desarrollados están en [patterns.md](patterns.md).

## Contenido

- [Medición](#medición)
- [Base de datos](#base-de-datos)
- [Caché](#caché)
- [API y servicios](#api-y-servicios)
- [Memoria y concurrencia](#memoria-y-concurrencia)
- [Infraestructura](#infraestructura)
- [Web](#web)
- [Antipatrones comunes](#antipatrones-comunes)

## Medición

- [ ] Línea base tomada **antes** del cambio, con números y condiciones (comando, datos, repeticiones, caché fría o caliente)
- [ ] Medición sintética (benchmark, profiler, plan de la query) y de campo (APM, p95/p99 en producción) cuando las dos existen
- [ ] Datos y hardware representativos, no la máquina de desarrollo con una tabla de diez filas
- [ ] Variación entre corridas conocida, para saber qué diferencia es real
- [ ] El después se midió exactamente igual que el antes
- [ ] Cada intento registrado con su veredicto, también los revertidos

Herramientas habituales (la skill del stack dice cuáles usa el repo): profiler de CPU y de heap del runtime, log de queries lentas de la base, `EXPLAIN ANALYZE`, una herramienta de carga (k6, wrk, ab o equivalente), trazas distribuidas y métricas del APM.

## Base de datos

### Queries
- [ ] Sin N+1: relaciones con join, include o batch por ids
- [ ] Endpoints de listado paginados, con orden estable y límite máximo
- [ ] Paginación por cursor en tablas grandes, no `OFFSET`
- [ ] Solo las columnas necesarias, no `SELECT *` en caminos calientes
- [ ] Log de queries lentas habilitado con umbral
- [ ] Operaciones masivas en lote, no loops de escrituras de a una

### Plan de la query
- [ ] `EXPLAIN ANALYZE` capturado **antes** del fix, no solo después: es la línea base
- [ ] Todo scan secuencial sobre una tabla grande explicado: índice faltante, inusable, o realmente no vale la pena
- [ ] Filas estimadas vs reales dentro de un orden de magnitud (si no, actualizar estadísticas antes de tocar índices)
- [ ] Ningún nodo `Sort` que un índice compuesto podría absorber
- [ ] Plan re-verificado después del cambio; un índice que no cambió el plan se revierte

### Índices
- [ ] Orden de columnas en el compuesto: igualdad primero, después rango u orden
- [ ] El índice cubre la forma de la query (filtro + orden), no una columna aislada
- [ ] Índice cubriente considerado para lecturas calientes (evita ir a la tabla)
- [ ] No se indexan columnas de baja selectividad *para el valor dominante*; un índice parcial sirve al valor raro
- [ ] Índice de expresión donde la query aplica una función (`lower(email)`)
- [ ] Full-text o trigramas para búsqueda con comodín al inicio, no un B-tree
- [ ] Costo de escritura medido en tablas con muchas escrituras
- [ ] Índices sin uso o duplicados eliminados: cuestan escrituras y no compran nada

### Pool de conexiones
- [ ] Un pool por proceso, no por request ni por módulo
- [ ] `instancias × máximo del pool` por debajo del límite de conexiones de la base
- [ ] Timeout de conexión configurado: el agotamiento falla rápido en vez de encolar para siempre
- [ ] Agotamiento diagnosticado antes de redimensionar: qué retiene conexiones (transacciones largas, `await` faltante, clientes no devueltos)
- [ ] Serverless o autoscaling detrás de un proxy que multiplexe, no de un pool más grande

## Caché

- [ ] La llamada cacheada se midió como cara primero (cachear algo rápido agrega un salto y no compra nada)
- [ ] La relación lectura/escritura justifica el caché (se lee mucho más de lo que se escribe)
- [ ] La clave incluye toda entrada de la que varía la respuesta: tenant, usuario, idioma, permisos, feature flags
- [ ] Ningún dato por usuario bajo una clave que no identifica al usuario
- [ ] Una sola estrategia de invalidación (TTL, evento/etiqueta o claves versionadas), no una mezcla accidental
- [ ] Ventana de datos viejos aceptable escrita, no implícita en el TTL que se tipeó
- [ ] Protección contra estampida en claves calientes (unificar misses, lock o `stale-while-revalidate`)
- [ ] Resultados negativos cacheados con TTL más corto; errores del origen nunca cacheados
- [ ] Política de desalojo y techo de memoria configurados (un caché sin cota es una fuga)
- [ ] Tasa de aciertos monitoreada: un caché que nadie mide es una suposición, y una tasa baja es puro costo
- [ ] Nada cacheado cuya antigüedad sea un bug de corrección (saldos, permisos, stock al pagar)

## API y servicios

- [ ] Tiempo de respuesta dentro del presupuesto del SPEC (p95, no promedio)
- [ ] Sin cómputo pesado y sincrónico en handlers de requests; lo largo va a una cola o worker
- [ ] Llamadas remotas independientes en paralelo, con límite de concurrencia
- [ ] Timeouts en toda llamada saliente; una dependencia lenta no cuelga el sistema
- [ ] Compresión de respuestas (gzip/brotli) para payloads de texto
- [ ] Payloads sin campos que el cliente no usa
- [ ] Respuestas cacheables marcadas como tales (`Cache-Control`, ETag) cuando corresponde

## Memoria y concurrencia

- [ ] Listeners, timers y suscripciones con su baja emparejada
- [ ] Archivos y colecciones grandes procesados en streaming o por lotes, no cargados enteros
- [ ] Sin objetos grandes creados en cada iteración o cada request de un camino caliente
- [ ] Dos snapshots de heap bajo carga comparados cuando la memoria crece
- [ ] Locks por recurso, no globales; sección crítica mínima; con timeout
- [ ] Paralelismo con cota: ni serie innecesaria ni `todas a la vez` sobre una lista sin límite
- [ ] Trabajo en segundo plano con cola acotada y backpressure

## Infraestructura

- [ ] CDN para estáticos
- [ ] Servidor o borde cerca de los usuarios
- [ ] Escalado horizontal configurado si la carga lo pide; el cuello de botella compartido (base, caché) dimensionado para eso
- [ ] Health check para el balanceador
- [ ] Presupuesto de rendimiento verificado en CI (benchmark, tamaño de artefacto, cantidad de queries por request)
- [ ] Alerta sobre p75/p95 en producción para la métrica que importa

## Web

### Core Web Vitals

| Métrica | Bien | A mejorar | Mal |
|---|---|---|---|
| LCP | ≤ 2,5 s | ≤ 4,0 s | > 4,0 s |
| INP | ≤ 200 ms | ≤ 500 ms | > 500 ms |
| CLS | ≤ 0,1 | ≤ 0,25 | > 0,25 |

Medir: datos de campo primero (`web-vitals`, CrUX), después el panel Performance del navegador grabando la interacción lenta, y en hardware medio o con CPU limitada (4×–6×): muchos problemas de INP solo aparecen ahí.

### TTFB lento (> 800 ms)
- [ ] DNS lento → `dns-prefetch` / `preconnect` para orígenes conocidos
- [ ] TCP/TLS lento → HTTP/2 o HTTP/3, keep-alive, despliegue en el borde
- [ ] Servidor lento → perfilar backend: queries, caché (el proceso general de la skill)

### Imágenes
- [ ] Formatos modernos (WebP, AVIF) con `<picture>`
- [ ] `srcset` y `sizes` para el tamaño por pantalla
- [ ] `width` y `height` explícitos en `<img>` y `<source>` (evitan CLS)
- [ ] Debajo del pliegue: `loading="lazy"` y `decoding="async"`
- [ ] Imagen LCP: `fetchpriority="high"` y nunca diferida

### JavaScript
- [ ] Bundle inicial por debajo del presupuesto (típico: 200 KB comprimido)
- [ ] División por ruta y `import()` dinámico para features pesadas
- [ ] Tree-shaking efectivo (la dependencia publica ESM y declara `sideEffects: false`)
- [ ] Sin scripts bloqueantes en `<head>` (`defer` o `async`)
- [ ] Tareas largas (> 50 ms) partidas cediendo al hilo principal (`scheduler.yield()` donde exista)
- [ ] Cómputo pesado en Web Workers
- [ ] Trabajo no urgente fuera de los handlers de eventos (analytics, logging) y en `requestIdleCallback`
- [ ] Scripts de terceros con `async`/`defer`, auditados por tamaño, con fachada si son pesados
- [ ] Memoización de componentes y cómputos solo donde el perfil la justifica

### CSS y fuentes
- [ ] CSS crítico inline o precargado; el resto no bloquea el render
- [ ] Sin costo de CSS-in-JS en runtime en producción
- [ ] Pocas familias y pesos de fuente; WOFF2; alojadas en el mismo origen
- [ ] Fuentes críticas para el LCP precargadas; `font-display: swap` u `optional`
- [ ] Subconjuntos con `unicode-range`; fuente variable si hacen falta varios pesos
- [ ] Métricas de la fuente de respaldo ajustadas (`size-adjust`, `ascent-override`) para reducir CLS
- [ ] Stack de fuentes del sistema considerado antes de cualquier fuente propia

### Red y render
- [ ] Estáticos con `max-age` largo + hash en el nombre
- [ ] HTTP/2 o HTTP/3; `preconnect` a orígenes conocidos; sin redirecciones de más
- [ ] `fetchpriority` en recursos críticos que no son imágenes (preloads clave, scripts sobre el pliegue)
- [ ] Sin layout thrashing: lecturas del DOM en lote, después escrituras en lote
- [ ] Animaciones con `transform` y `opacity`
- [ ] Listas largas virtualizadas
- [ ] Secciones fuera de pantalla con `content-visibility: auto` y `contain-intrinsic-size`
- [ ] Sin handlers de `unload` ni `Cache-Control: no-store` en el HTML (preserva el bfcache)

## Antipatrones comunes

| Antipatrón | Impacto | Fix |
|---|---|---|
| N+1 | Carga de la base crece lineal con la lista | Join, include o batch por ids |
| Queries sin cota | Memoria agotada, timeouts | Paginar siempre, `LIMIT` |
| Índices faltantes | Lecturas cada vez más lentas con el volumen | Índice por la forma de la query, justificado por el plan |
| Indexar sin leer el plan | Costo de escritura pagado, ganancia de lectura no probada | Plan antes y después; revertir si no cambió |
| Índices redundantes o sin uso | Cada escritura los paga | Auditar uso, borrar lo que nadie lee |
| Pool por request | Agota las conexiones de la base bajo carga | Un pool por proceso; proxy en serverless |
| Clave de caché sin el usuario | Los datos de uno se le sirven a otro | Clave con tenant, usuario, idioma, permisos |
| Caché sin cota | Fuga de memoria disfrazada de optimización | Política de desalojo y techo de memoria |
| Estampida en una clave caliente | El origen recibe toda la carga al vencer | Unificar misses o `stale-while-revalidate` |
| Llamadas independientes en serie | Latencia = suma en vez de máximo | Paralelizar con límite de concurrencia |
| Cómputo pesado en el handler | Requests bloqueados, latencia alta para todos | Cola y workers; el request devuelve 202 |
| Lock global | Todo serializado por un conflicto raro | Lock por recurso, sección crítica mínima |
| Fugas de memoria | Memoria creciente, caída eventual | Dar de baja listeners, timers, referencias |
| Imágenes sin optimizar | LCP lento, ancho de banda desperdiciado | Formato moderno, tamaños, carga diferida |
| Bundle grande | Interactividad tardía | Dividir por ruta, tree-shaking, auditar dependencias |
| Hilo principal bloqueado | INP malo, UI que no responde | Partir tareas largas, Web Workers |
| Layout thrashing | Jank, frames perdidos | Lecturas del DOM en lote, después escrituras |
