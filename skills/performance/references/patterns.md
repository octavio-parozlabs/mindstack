# Patrones de optimización

Fixes desarrollados para los antipatrones que nombra el paso 3 de `mindstack:performance`. La skill da la regla y la firma para reconocerlos; acá va una implementación concreta de cada uno. Abrí la sección que necesitás después de que el paso 2 identificó el cuello de botella; no está pensado para leerse de corrido.

Los ejemplos son ilustrativos (pseudocódigo, SQL genérico); el equivalente en tu stack lo dice la skill del stack. Checklists y comandos de medición en [checklist.md](checklist.md).

## N+1

Una query o llamada remota por fila. Crece lineal con el tamaño de la lista y no aparece en desarrollo porque la lista tiene cinco elementos.

```
// MAL: N+1, una query por tarea para traer el dueño
tareas = db.tareas.buscar()
para cada tarea en tareas:
  tarea.dueño = db.usuarios.buscarPorId(tarea.dueñoId)

// BIEN: una sola query con la relación incluida (join / include / eager load)
tareas = db.tareas.buscar(incluir: [dueño])

// BIEN cuando no hay join posible (servicio remoto): batch por ids
ids = únicos(tareas.map(t => t.dueñoId))
dueños = servicioUsuarios.buscarVarios(ids)      // una llamada, no N
```

Firma en el log de queries: la misma query repetida con distinto id, una debajo de la otra.

## Datos sin cota

```
// MAL: trae todo
todas = db.tareas.buscar()

// BIEN: paginado, con límite y orden estable
tareas = db.tareas.buscar(
  límite: 20,
  desde: (página - 1) * 20,
  orden: [creadoEn: desc, id: desc],   // el desempate evita filas duplicadas entre páginas
)
```

Con tablas grandes, paginación por cursor (`WHERE (creado_en, id) < (?, ?)`) en vez de `OFFSET`: el offset recorre y descarta todas las filas anteriores.

Lo mismo para loops sobre datos externos: un archivo se lee en streaming, una cola se consume de a lotes, una API externa se pagina. Nada se carga entero "porque hoy es chico".

## Queries que ignoran su índice

"Agregá un índice" es la suposición. El plan de la query es la medición:

```sql
EXPLAIN ANALYZE
SELECT id, titulo FROM tareas
WHERE dueño_id = 42 ORDER BY creado_en DESC LIMIT 20;
```

Tres cosas en la salida deciden el fix:

| Qué ves | Qué significa |
|---|---|
| Scan secuencial sobre una tabla grande donde esperabas índice | No hay índice usable para ese predicado |
| Filas estimadas vs reales difieren en un orden de magnitud | Estadísticas viejas; el planificador decide con mala información. Actualizá estadísticas (`ANALYZE`) antes de tocar índices |
| Un nodo `Sort` arriba del scan | El índice cubre el filtro pero no el `ORDER BY` |

Indexá por la **forma de la query**, no por la columna aislada. En un índice compuesto, primero las columnas de igualdad, después la de rango u orden:

```sql
CREATE INDEX idx_tareas_dueño_creado ON tareas (dueño_id, creado_en DESC);
```

**Cuándo un índice no va a ayudar:**

| Situación | Por qué |
|---|---|
| Baja selectividad, filtrando por el valor dominante (`estado` es 95% `activo` y filtrás `activo`) | El scan secuencial es realmente más barato; el planificador va a ignorar el índice. Filtrar por el valor raro es el caso opuesto: un índice parcial lo sirve bien |
| Comodín al inicio (`LIKE '%término'`) | Un B-tree no puede buscar sin prefijo; necesita trigramas o full-text |
| Función sobre la columna (`WHERE lower(email) = ?`) | El índice de la columna no sirve; indexá la expresión |
| Tabla con muchas escrituras | Cada índice cobra en cada `INSERT`/`UPDATE`; medí el costo de escritura, no solo la ganancia de lectura |

Volvé a correr el plan después. Un índice que no cambió el plan se revierte (paso 5), y no es gratis: sigue cobrando en cada escritura.

## Pool de conexiones agotado

La firma es distintiva: **todo** se pone lento a la vez, el tiempo se va esperando una conexión y no ejecutando, y la base reporta sesiones mayormente idle.

```
// MAL: un pool por request o por módulo; en serverless se multiplica
// por la cantidad de instancias y agota el límite de conexiones de la base

// BIEN: un pool por proceso, dimensionado contra el techo de la base
pool = Pool(
  máximo: 10,                 // instancias × máximo < max_connections de la base
  timeoutIdle: 30 s,
  timeoutConexión: 5 s,       // fallar rápido en vez de encolar para siempre
)
```

**Más grande no es más rápido.** Un pool mayor a lo que la base puede ejecutar en paralelo solo mueve la cola de tu app a la base, donde se ve menos. Antes de redimensionar, buscá qué retiene conexiones: transacciones largas, un `await` que falta, clientes que no se devuelven al pool. Con instancias sin cota (serverless, autoscaling), el fix es un proxy que multiplexe conexiones (pgbouncer, RDS Proxy), no un `máximo` más alto.

## Caché

Cacheá lo que es caro de producir y se lee mucho más de lo que cambia. Cachear una query que ya era rápida agrega un salto de red, un bug de datos viejos y una política de desalojo que mantener, a cambio de nada.

**Elegí la capa a propósito:**

| Capa | La ve | Usar cuando | Costo |
|---|---|---|---|
| En proceso (mapa, LRU) | Una instancia | Chico, caliente, y es aceptable que cada instancia tenga datos distintos | Cada instancia deriva por su lado; la invalidación llega a una sola |
| Compartida (Redis, Memcached) | Todas las instancias | Las instancias tienen que coincidir, o el valor es caro de recomputar | Un salto de red y otro servicio que operar y monitorear |
| CDN / borde | Todos, por URL | Respuestas públicas e idénticas para una clave | Invalidar es lo difícil; asumí que no podés retirar rápido una respuesta mala |

```
// Ilustrativo: caché en proceso con TTL
TTL = 5 min
configCacheada = null
vence = 0

función configApp():
  si configCacheada y ahora() < vence: devolver configCacheada
  configCacheada = db.config.primera()
  vence = ahora() + TTL
  devolver configCacheada

// Caché HTTP para estáticos con hash en el nombre: un año, inmutable
Cache-Control: public, max-age=31536000, immutable

// Caché HTTP para una respuesta de API pública
Cache-Control: public, max-age=300
```

**La clave decide la corrección.** Toda entrada que cambia la respuesta va en la clave: tenant, usuario, idioma, permisos, feature flags. Una clave que omite al usuario es cómo se le sirven a uno los datos de otro, y entra como "mejora de rendimiento".

**Una estrategia de invalidación, no tres:**

| Estrategia | Compromiso |
|---|---|
| TTL | La más simple. Aceptás datos viejos hasta el TTL; escribí la ventana aceptable, no la dejes implícita |
| Por evento o etiqueta | Fresco al escribir, pero ahora quien escribe tiene que conocer la topología del caché |
| Claves versionadas (`usuario:42:perfil:v7`) | Nunca invalidás, dejás de leer las claves viejas. Cuesta memoria hasta el desalojo |

**Patrones de lectura y escritura:**

| Patrón | Cómo funciona | Usar cuando | Cuidado con |
|---|---|---|---|
| **Cache-aside** | La app consulta el caché; si falla, lee el origen y lo guarda | Opción por defecto; lecturas intensivas que toleran el primer miss | Cada miss pega en el origen: necesita protección contra estampida |
| **Read-through** | La capa de caché carga sola en el miss | Querés el camino de carga en un solo lugar | Esconde la latencia del origen; un origen lento parece un caché lento |
| **Write-through** | La escritura va al caché y al origen, sincrónica | Las lecturas nunca pueden ver un valor viejo después de escribir | Suma la latencia del caché a cada escritura |
| **Write-behind** | La escritura pega en el caché; el origen se actualiza asíncrono | Escrituras intensivas y el origen es el cuello de botella | Ventana de pérdida de datos si el caché muere antes del flush |

**Protegé contra la estampida.** Una clave caliente vence, todos los requests concurrentes fallan juntos y el origen recibe toda la carga de golpe: así un caché se convierte en una caída en vez de evitarla. Serví el valor viejo mientras un solo request recomputa (`stale-while-revalidate`), o unificá los misses concurrentes detrás de una sola promesa en vuelo:

```
enVuelo = Mapa<clave, Promesa>

función cargarUnaVez(clave, cargador):
  si enVuelo tiene clave: devolver enVuelo[clave]
  p = cargador().alTerminar(() => enVuelo.borrar(clave))
  enVuelo[clave] = p
  devolver p
```

Con un caché compartido, la misma idea necesita un lock distribuido, o `stale-while-revalidate` para que los que esperan sirvan el valor viejo en vez de bloquearse.

**Caché negativo.** Cacheá también la ausencia de resultado. Una clave que falla en cada lookup (un id inexistente consultado en loop, un recurso 404) manda cada request al origen: un caché que solo protege el camino feliz. Guardá un centinela "no existe" con un TTL **más corto** que el de los positivos, y nunca conviertas un *error* del origen en entrada negativa, o un minuto de falla se vuelve muchos.

**No cachees:** nada cuya antigüedad sea un bug de corrección (saldos, permisos, stock al momento de pagar), ni datos por usuario bajo una clave que no identifica al usuario. Checklist en [checklist.md](checklist.md#caché).

## Memoria

La memoria que crece sin bajar tiene tres causas habituales:

```
// MAL: listener/timer que nunca se da de baja; cada instancia suma uno
alIniciar: bus.suscribir("evento", manejar)
// BIEN: la baja va junto al alta
alIniciar: baja = bus.suscribir("evento", manejar)
alDestruir: baja()

// MAL: caché sin cota: es una fuga con nombre de optimización
caché = Mapa()
// BIEN: tamaño máximo y política de desalojo (LRU), o TTL
caché = LRU(máximo: 1000)

// MAL: cargar todo para procesar de a uno
líneas = leerArchivoEntero(ruta).separar("\n")
para cada línea en líneas: procesar(línea)
// BIEN: streaming
para cada línea en leerLíneas(ruta): procesar(línea)
```

Confirmá con dos snapshots de heap separados por carga: lo que crece entre uno y otro y no debería es la fuga. Un reinicio periódico "porque la memoria sube" es un síntoma tapado, no un fix.

## Concurrencia

```
// MAL: llamadas independientes en serie; la latencia es la suma
usuario = servicioUsuarios.obtener(id)
pedidos = servicioPedidos.listar(id)
saldo   = servicioCuentas.saldo(id)

// BIEN: en paralelo; la latencia es la mayor
[usuario, pedidos, saldo] = esperarTodas([
  servicioUsuarios.obtener(id),
  servicioPedidos.listar(id),
  servicioCuentas.saldo(id),
])

// MAL: paralelismo sin límite sobre una lista grande: agota pool, sockets o memoria
esperarTodas(ids.map(id => procesar(id)))
// BIEN: con límite de concurrencia
esperarConLímite(ids, concurrencia: 10, procesar)
```

**Cómputo pesado en el camino caliente.** Generar un PDF, redimensionar imágenes, un cálculo de minutos: fuera del handler, a una cola con workers. El request devuelve un id de trabajo o un 202; el resultado se consulta o se notifica.

**Locks.** Un lock global donde alcanza uno por clave serializa todo el sistema por un conflicto que casi nunca ocurre. Lock por recurso (fila, cuenta, clave), con timeout, y el trabajo adentro del lock lo más corto posible. Si el perfil bajo carga muestra esperas de lock, el fix es achicar la sección crítica, no agregar hilos.

## Web

Lo específico del navegador. Aplica después del proceso general, cuando el cuello de botella está en la carga o en la interacción.

### Imágenes

```html
<!-- MAL: sin dimensiones, sin formato moderno, sin prioridad -->
<img src="/hero.jpg" />

<!-- BIEN: imagen principal (LCP): formatos modernos, tamaños por pantalla, prioridad alta -->
<picture>
  <source srcset="/hero-800.avif 800w, /hero-1600.avif 1600w"
          sizes="(max-width: 1200px) 100vw, 1200px" type="image/avif" />
  <source srcset="/hero-800.webp 800w, /hero-1600.webp 1600w"
          sizes="(max-width: 1200px) 100vw, 1200px" type="image/webp" />
  <img src="/hero.jpg" width="1200" height="600" fetchpriority="high" alt="..." />
</picture>

<!-- BIEN: imagen debajo del pliegue: carga diferida y decodificación asíncrona -->
<img src="/contenido.webp" width="800" height="400" loading="lazy" decoding="async" alt="..." />
```

`width` y `height` siempre (evitan CLS). La imagen LCP nunca con `loading="lazy"`.

### Bundle grande

Los bundlers modernos hacen tree-shaking de los imports con nombre solos, si la dependencia publica ESM. Perfilá antes de cambiar estilos de import: la ganancia real está en dividir por ruta y cargar diferido lo pesado y poco usado.

```
// BIEN: import dinámico para una feature pesada y poco usada
Gráficos = cargarDiferido(() => import('./Gráficos'))

// BIEN: división por ruta, con un fallback mientras carga
PáginaAjustes = cargarDiferido(() => import('./páginas/Ajustes'))
```

### Re-renders innecesarios

Un objeto o función creado en el render es una referencia nueva cada vez, y re-renderiza a todo hijo que lo reciba.

```
// MAL: objeto nuevo en cada render
función ListaTareas():
  devolver <Filtros opciones={{ ordenarPor: 'fecha', orden: 'desc' }} />

// BIEN: referencia estable, fuera del render
OPCIONES_DEFAULT = { ordenarPor: 'fecha', orden: 'desc' }
función ListaTareas():
  devolver <Filtros opciones={OPCIONES_DEFAULT} />
```

Memoización de componentes y de cómputos solo donde el perfil muestra que el trabajo es caro: memoizar todo tiene su propio costo y es tan antipatrón como no memoizar nada. Para listas largas, virtualización.

### Hilo principal bloqueado

Tareas de más de 50 ms bloquean la respuesta a la interacción (INP). Partí los loops largos cediendo al hilo principal entre tramos (`scheduler.yield()` donde exista), mandá cómputo pesado a un Web Worker, y sacá del handler del evento lo que no es urgente (analytics, logging).
