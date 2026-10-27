# Patrones de endurecimiento

Una implementación concreta de cada regla de la skill `seguridad`. Abrí la sección cuando llegás a ese código; no está pensado para leerse de corrido. Los ejemplos son pseudocódigo neutro: traducilos al stack con lo que ya tenés instalado, no agregues una dependencia para lo que resuelven diez líneas.

Lo específico de web (headers, CSP, cookies de sesión, CORS, CSRF) está en `mindstack:web-security`. La checklist por superficie está en [checklist.md](checklist.md).

## Inyección

```text
MAL   query = "SELECT * FROM users WHERE id = '" + userId + "'"
MAL   exec("convert " + nombreArchivo + " salida.png")

BIEN  db.query("SELECT * FROM users WHERE id = $1", [userId])
BIEN  orm.users.find({ id: userId })
BIEN  spawn("convert", [nombreArchivo, "salida.png"])   // argv, sin shell
```

Vale para SQL, NoSQL, LDAP, shell, templates y paths: el dato viaja como parámetro, nunca como parte del texto que se interpreta. Si el lenguaje ofrece una API "sin shell" para procesos, es la única que se usa con entrada.

Salida hacia HTML: el auto-escape del motor de templates. Si hay que renderizar HTML ajeno, sanitizar con allowlist de tags antes, nunca después.

## Validación por esquema

```text
EsquemaCrearTarea = {
  titulo:      string, 1..200, trim
  descripcion: string?, ..2000
  prioridad:   enum(baja, media, alta) = media
  vence:       fecha ISO?
}

handler crearTarea(req):
  r = EsquemaCrearTarea.parse(req.body)
  si r falla: responder 422 { code: VALIDATION_ERROR, details: r.errores }
  tarea = servicio.crear(r.valor)     // r.valor es tipado; req.body no se vuelve a tocar
  responder 201 tarea
```

Reglas: allowlist de campos (lo que no está en el esquema se descarta), longitudes y rangos explícitos, formatos con la librería del stack (no regex propias para email o URL). La validación vive en la frontera: una sola vez, en el handler, y lo de adentro confía en el tipo.

## Archivos subidos

```text
TIPOS_PERMITIDOS = { image/jpeg, image/png, image/webp }
TAMANO_MAX = 5 MiB

validarSubida(archivo):
  si archivo.mime ∉ TIPOS_PERMITIDOS: rechazar
  si archivo.tamano > TAMANO_MAX: rechazar
  si importa: leer los primeros bytes y comparar con la firma del tipo declarado
  nombre de destino: generado por el servidor (uuid + extensión del tipo verificado), nunca el original
```

La extensión y el `Content-Type` los manda el cliente: son entrada hostil. Guardar fuera del árbol servido; servir con el tipo que verificaste vos.

## SSRF: fetch de URLs ajenas

Cada vez que el servidor hace fetch de una URL que el usuario influyó (webhooks, "importar desde URL", proxies de imágenes, previews de links), un atacante puede apuntarla a servicios internos: metadata de la nube (`169.254.169.254`), `localhost`, IPs privadas.

```text
MAL   fetch(req.body.webhookUrl)

HOSTS_PERMITIDOS = { hooks.ejemplo.com }

urlSegura(cruda):
  url = parsear(cruda)
  si url.esquema != https: rechazar
  si url.host ∉ HOSTS_PERMITIDOS: rechazar
  direcciones = resolverDNS(url.host, todas = true)
  si alguna dirección no es unicast público (loopback, link-local, privada, unique-local, IPv4 e IPv6): rechazar
  devolver url

fetch(urlSegura(req.body.webhookUrl), redirecciones = ninguna)
```

**Queda una ventana (check/use).** El cliente HTTP vuelve a resolver DNS después de la verificación; con un TTL corto el atacante cambia el registro a una IP interna entre medio. Para superficies de alto riesgo: resolver una vez y conectar a la IP fijada, o poner un agente de filtrado por delante.

## Operaciones destructivas sobre paths derivados

Un borrado, movimiento o sobreescritura es tan seguro como el valor que nombra su destino. Que el valor venga del kernel, de un payload de job o de un servicio hermano prueba de dónde *llegó*, no quién lo *escribió*: el `argv` de otro proceso es tan hostil como un formulario. Una verificación de forma ("path absoluto, al menos un directorio") prueba que está bien formado y se confunde con autorización; así es como una rutina de limpieza borra la raíz en vez de la hoja.

Antes de la llamada, exigí las tres:

1. El destino **resuelto** (symlinks seguidos) está bajo una **raíz permitida**. Comparar después de resolver, nunca sobre el string crudo.
2. Está al menos **un nivel por debajo** de esa raíz: una raíz nunca es destino.
3. Lleva **evidencia de que es tuyo**, leída *antes* de operar y antes de cualquier teardown que la borre; si no, "ausente" y "no es mío" son indistinguibles.

```text
RAICES_PERMITIDAS = [ /var/lib/app/sesiones ]   // allowlist, no patrón
PROFUNDIDAD_MIN = 1

resolverBorrable(candidato, duenoEsperado):
  destino = realpath(candidato)                    // symlinks resueltos ANTES de comparar
  dentro = alguna raíz tal que:
      rel = relativo(raiz, destino)
      rel no vacío, rel no empieza con "../", rel no absoluto   // "..cache" es un hijo legítimo
      y profundidad(rel) >= PROFUNDIDAD_MIN
  si no dentro: log("rechazado: fuera de raíces", destino); abortar
  dueno = leer(destino + "/.owner") o null
  si dueno != duenoEsperado: log("rechazado: dueño no probado", destino); abortar
  devolver destino
```

Si se rechaza, se loguea el destino y se para: una limpieza que cae a un path por defecto más amplio es exactamente el fallo que esto evita.

Dos límites, porque la verificación parece más fuerte de lo que es:

- **El marcador es auto-atestación.** Cualquiera que pueda escribir dentro de la raíz puede escribir `.owner`. `duenoEsperado` tiene que salir de estado autenticado, y el marcador necesita protección de integridad (ownership restrictivo, o un MAC) para contar como autorización y no solo como verificación de consistencia.
- **Devolver un path deja una carrera check/use.** Donde un proceso ajeno puede cambiar un ancestro entre la verificación y la llamada, operá sobre un descriptor con no-follow y semántica "debajo de la raíz", o garantizá que la jerarquía no cambia mientras dura la operación.

## Salida de un LLM

```text
MAL   sql = llm.generar("escribí SQL para: " + pregunta); db.query(sql)     // ejecución arbitraria
MAL   contenedor.innerHTML = llm.responder(mensaje)                           // XSS vía el modelo

BIEN  crudo = llm.responderJson(mensaje)
      intencion = EsquemaComando.parse(json.parse(crudo))   // si falla cualquiera: error de validación
      ejecutarAccionPermitida(intencion.accion, intencion.params)   // allowlist de acciones
      contenedor.textContent = llm.responder(mensaje)
```

La salida del modelo es un dato: parsear a la defensiva, validar contra esquema, codificar. Los permisos de las herramientas que el modelo puede invocar se aplican en código con mínimo privilegio; las acciones destructivas piden confirmación; tokens, tasa y profundidad de recursión tienen tope. Secretos, datos de otros tenants y el system prompt completo no entran al contexto: todo lo que entra puede salir.

## Autenticación

```text
RONDAS = 12
hash   = bcrypt.hash(contrasena, RONDAS)        // o scrypt / argon2
valido = bcrypt.compare(contrasena, hash)       // comparación en tiempo constante

token de sesión / JWT:
  secreto desde el entorno, nunca del código
  verificar en cada uso: firma, expiración, emisor, audiencia
  vida acotada; refresh con rotación

token de reset de contraseña:
  aleatorio, de un solo uso, expira en <= 1 hora, se invalida al usarse o al cambiar la contraseña
```

El detalle de cookies de sesión (`httpOnly`, `secure`, `sameSite`) está en `mindstack:web-security`.

## Control de acceso (IDOR)

```text
handler PATCH /tareas/:id  [autenticado]:
  tarea = servicio.buscar(req.params.id)
  si tarea es null o tarea.ownerId != req.usuario.id:
    responder 403 { code: FORBIDDEN }          // o 404, para no revelar existencia
  actualizada = servicio.actualizar(tarea.id, cuerpoValidado)
  responder actualizada
```

Autenticar dice quién es; esto dice si puede tocar *este* recurso. Va en cada handler que recibe un id, no en un middleware por ruta. La forma más barata de probarlo: con la sesión del usuario 2, pedir el id del usuario 1.

## Rate limiting

```text
limite general:   100 requests / 15 min por IP o por cuenta
limite de auth:    10 intentos / 15 min por IP + por cuenta, en login, reset y verificación
respuesta:        429, sin pista de si la cuenta existe
```

**Contar en un store compartido en cuanto hay más de un proceso.** Un limitador en memoria detrás de un balanceador tiene un contador por instancia, así que el límite efectivo es `max × instancias`; en serverless cada invocación arranca en cero y el límite de auth puede no dispararse nunca. Usá el store compartido del stack (Redis o equivalente) con ventana deslizante.

## Secretos

```text
.env.example   → commiteado, placeholders
.env           → NO commiteado
.env.*.local   → NO commiteado

.gitignore:
  .env
  .env.local
  .env.*.local
  *.pem
  *.key
```

Antes de commitear:

```bash
git diff --cached | grep -iE "password|secret|api[_-]?key|token|BEGIN (RSA|EC|OPENSSH) PRIVATE"
```

En código, el secreto se lee del entorno y la ausencia falla rápido:

```text
API_KEY = env("PAGOS_API_KEY") o abortar("PAGOS_API_KEY no configurada")
```

**Si un secreto llegó a un remoto, está comprometido.** Rotar primero (revocar y emitir uno nuevo), después purgar historia. Borrar la línea o reescribir la rama no alcanza.

## Exposición de datos

```text
// Allowlist de campos en cada respuesta: lo que no está, no sale
usuarioPublico(u) = { id: u.id, nombre: u.nombre, email: u.email }
// nunca: passwordHash, resetToken, mfaSecret, ids internos de pago

// Error hacia afuera: genérico. Detalle: al log del servidor con el id de correlación
responder 500 { code: INTERNAL_ERROR, message: "Algo falló", requestId }
log.error({ requestId, err, stack, query })     // nunca en la respuesta
```

Logs: contraseñas, tokens, tarjetas completas y datos de salud no se loguean ni enmascarados a medias. Si un campo es sensible, el logger lo redacta por nombre antes de serializar.

## Clasificación de datos

Clasificá cada campo personal al agregarlo, para que un pedido de exportación o borrado lo encuentre después:

| Clase | Ejemplos | Trato |
|---|---|---|
| No personal | agregados, conteos anonimizados | normal |
| Personal | nombre, email, IP, ids de dispositivo o usuario | minimizar, controlar acceso, incluir en exportar/borrar |
| Sensible | salud, finanzas, ubicación, biometría, documentos, cualquier cosa de menores | base explícita para recolectar, acceso más estricto, cifrado y log de auditoría |

Cada store de datos personales tiene retención (TTL) y un camino de borrado que incluye backups, caches, índices de búsqueda y copias en analytics. El esquema se diseña para que los datos de un usuario sean encontrables y borrables, no desparramados de forma irreversible.

## Triaje de auditoría de dependencias

La auditoría del gestor reporta advisories conocidos; no prueba que un paquete sea confiable ni que el código vulnerable sea alcanzable.

```text
La auditoría nativa reporta una vulnerabilidad
├── crítica o alta
│   ├── ¿el código vulnerable se ejecuta en runtime, build, test o deploy?
│   │   ├── SÍ  → corregir ya (actualizar, parchear o reemplazar)
│   │   └── NO (confirmado en todos esos caminos) → corregir pronto, no bloquea
│   └── ¿hay fix?
│       ├── SÍ  → actualizar a la versión parcheada
│       └── NO  → workaround, reemplazar, o diferir con motivo y fecha de revisión
├── media
│   ├── alcanzable en producción → próximo release
│   └── solo dev → cuando convenga, en el backlog
└── baja
    └── en la próxima actualización regular
```

Preguntas clave: ¿la función vulnerable se llama en tu camino? ¿es dependencia de runtime o solo de dev? ¿es explotable en tu contexto (una vulnerabilidad de servidor en una app solo cliente no lo es)?

Nunca una remediación forzada automática (`audit fix --force` o equivalente): puede cruzar rangos declarados. Previsualizar, leer changelogs, probar cada upgrade. Cada diferimiento documentado con motivo y fecha.

Para una dependencia **nueva**, la auditoría no dice nada: revisá dueño, mantenimiento, edad del release, procedencia, grafo transitivo y que el nombre sea el correcto (`cross-env` vs `crossenv`). Verificá firmas del registro si el gestor lo soporta; su ausencia es señal para investigar, no prueba de compromiso.

## Idempotencia y carreras

```text
MAL   resultado = gateway.cobrar(orden)          // timeout → el cliente reintenta → cobra dos veces

BIEN  clave = "cobro:" + orden.id
      previo = store.get(clave)
      si previo: devolver previo                 // mismo resultado, sin volver a cobrar
      resultado = gateway.cobrar(orden, idempotencyKey = clave)
      store.set(clave, resultado)
```

Toda operación con efecto que se puede reintentar (cobros, envíos, creaciones, borrados, llamadas a terceros) lleva una clave de idempotencia derivada de la intención, o consulta el estado antes de repetir.

```text
MAL   saldo = leer(cuenta); si saldo >= monto: escribir(cuenta, saldo - monto)   // dos requests pasan el if

BIEN  UPDATE cuentas SET saldo = saldo - $monto WHERE id = $id AND saldo >= $monto   // condición atómica
      si filas afectadas == 0: rechazar
```

Leer-decidir-escribir se hace en una transacción con el aislamiento correcto, o con una escritura condicional atómica. Lo mismo para "verificar que no existe y crear": constraint único en la base, no un `find` previo.
