# Checklist de observabilidad

Referencia rápida para instrumentar código que va a producción. Se usa junto con la skill `observability`. Agnóstica al lenguaje y al backend: OpenTelemetry aparece como referencia de conceptos, no como obligación.

## Índice

- [Preguntas de guardia (empezar acá)](#preguntas-de-guardia-empezar-acá)
- [Logs estructurados](#logs-estructurados)
- [Errores](#errores)
- [Métricas](#métricas)
- [Trazas distribuidas](#trazas-distribuidas)
- [Alertas](#alertas)
- [Dashboards](#dashboards)
- [Verificar la telemetría](#verificar-la-telemetría)
- [Compuerta previa al lanzamiento](#compuerta-previa-al-lanzamiento)

## Preguntas de guardia (empezar acá)

Telemetría sin pregunta es ruido. Antes de instrumentar nada:

- [ ] Hay 2 a 4 preguntas escritas que va a hacer quien esté de guardia sobre esta feature
- [ ] Cada señal de abajo responde a una de esas preguntas
- [ ] Cada pregunta tiene su tipo de señal: las métricas dicen **que** algo está mal, las trazas **dónde**, los logs **por qué**

## Logs estructurados

- [ ] Los logs son estructurados (JSON) con nombres de evento estables, no strings libres
- [ ] Cada línea lleva un id de correlación, generado o aceptado en la frontera del sistema
- [ ] El id de correlación se propaga en cada llamada saliente y cada frontera asíncrona (cabeceras HTTP, metadata de cola)
- [ ] Todo log escrito por más de un punto de entrada (scheduler, endpoint de reproceso, corrida manual) lleva un campo de punto de entrada, fijado donde arranca la corrida y propagado junto al id
- [ ] Los niveles son consistentes: `error` = invariante roto, alguien puede actuar; `warn` = degradado pero manejado; `info` = evento de negocio relevante; `debug` = apagado en producción
- [ ] Ningún secreto, token, contraseña ni dato personal sin redactar en ninguna línea (regla dura de `mindstack:security`)
- [ ] Los campos están en allowlist: nunca bodies completos de request o response, nunca cabeceras de autenticación
- [ ] Las llamadas a servicios externos se loguean con metadata solamente: endpoint, status, latencia, intento, identificadores saneados
- [ ] La salida real se revisó a ojo: campos estructurados, no `[object Object]`

## Errores

- [ ] Ningún `catch` vacío ni que solo loguea `err.message`
- [ ] Cada error capturado se maneja (con log en `warn` del fallback aplicado) o se relanza con causa; nunca a medias
- [ ] Cada log de error lleva evento, id de correlación y contexto suficiente para reproducir
- [ ] Los errores que llegan al usuario tienen un id que se puede buscar en los logs

## Métricas

- [ ] **RED** en cada endpoint y cada dependencia externa: Rate, Errors, Duration
- [ ] **USE** en cada recurso (colas, pools, hosts): Utilización, Saturación, Errores
- [ ] La latencia es un histograma; p50/p95/p99 consultables, nunca un promedio
- [ ] Todos los labels salen de conjuntos chicos y fijos (plantilla de ruta, clase de status, nombre del proveedor)
- [ ] Ningún label sin cota: nada de ids de usuario, ids de tenant, emails, URLs crudas, ids de request ni texto de error
- [ ] Los códigos de status se agrupan por clase (`5xx`, no `503`)
- [ ] Profundidad de cola y duración de procesamiento medidas para cada worker o cola

## Trazas distribuidas

- [ ] El SDK de trazas (OpenTelemetry o equivalente) se inicializa al arrancar el servicio, antes del resto de los imports
- [ ] Auto-instrumentación activa para HTTP, gRPC y clientes de base de datos
- [ ] El contexto de traza se propaga en cada llamada saliente (`traceparent`/`tracestate` de W3C) y se extrae de cada request entrante
- [ ] El contexto sobrevive las fronteras asíncronas: los mensajes de cola llevan metadata de traza
- [ ] Spans manuales solo alrededor de unidades de trabajo con sentido, con los atributos por los que va a filtrar la guardia
- [ ] Ningún secreto ni dato personal como atributo de span
- [ ] Muestreo bajo por defecto en la cabecera; 100% de los errores si hay muestreo de cola

## Alertas

- [ ] Cada alerta es por síntoma (tasa de error, p99 de latencia, antigüedad de cola); las causas (CPU, disco, reinicios) van a dashboards, no al pager
- [ ] Cada alerta es accionable; las de "ignorala, se arregla sola" se borran
- [ ] Cada alerta linkea a un runbook de al menos tres líneas: qué significa, primera consulta a correr, a quién escalar
- [ ] Umbrales y duraciones justificados por un SLO o datos históricos, no por corazonadas
- [ ] Dos severidades nada más: **page** (afecta usuarios, actuar ya) y **ticket** (degradación, actuar esta semana)
- [ ] Cada alerta nueva se disparó una vez de prueba: llegó al canal correcto y el link al runbook funciona
- [ ] Ninguna alerta salta todos los días y se reconoce sin actuar
- [ ] Los runbooks se actualizan al cerrar cada incidente en que se usaron

## Dashboards

- [ ] Existe un dashboard de salud del servicio: tasa de error, p99 de latencia, tráfico, saturación
- [ ] Hay un panel de salud de dependencias con tasa de error y latencia por servicio
- [ ] El dashboard responde las preguntas de guardia del inicio, no "todo menos la respuesta"
- [ ] El rango de tiempo por defecto es razonable (1 h a 6 h, no 30 días)

## Verificar la telemetría

La instrumentación es código; puede estar mal:

- [ ] Se forzó un error en staging → se encontró en los logs por id de correlación
- [ ] Se mandó tráfico de prueba → las series de métricas aparecen con los labels esperados y valores razonables
- [ ] Se siguió una request de punta a punta en la UI de trazas → sin spans rotos
- [ ] Una falla inducida se diagnosticó con telemetría sola, sin leer el código

## Compuerta previa al lanzamiento

Antes de que una feature salga a producción, todo esto es cierto:

- [ ] Los logs estructurados fluyen al agregador
- [ ] Las métricas RED de cada endpoint y dependencia nuevos se ven en los dashboards
- [ ] Hay al menos una alerta por síntoma configurada, con runbook y disparada de prueba
- [ ] Una request se puede trazar a través de cada servicio que toca
- [ ] La guardia sabe dónde están los runbooks
- [ ] En el flujo mindstack: el "Estado final" del PLAN dice qué se loguea y qué métrica lo mide, y lo no verificable quedó en `CHANGELOG.md › Deuda técnica`
