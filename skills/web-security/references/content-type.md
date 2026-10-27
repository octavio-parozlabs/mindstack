# Content-Type: el body se parsea como el cliente dice, o no se parsea

Decisión cerrada: **la API habla JSON. Un body se parsea solo si el request declara exactamente el `Content-Type` que ese endpoint acepta; sin `Content-Type`, con uno desconocido, o con un body que no es lo que el header dice, se rechaza antes de llegar al handler. `application/x-www-form-urlencoded` y `multipart/form-data` se aceptan solo en los endpoints que los piden, y esos endpoints exigen token CSRF.**

## Regla

| Request | Respuesta |
|---|---|
| `Content-Type: application/json` (con o sin `; charset=utf-8`) y body JSON válido | se parsea, se valida con el schema del contrato (`../../architecture/SKILL.md` §4) |
| `application/json` y body que no es JSON | `400 INVALID_BODY`. El parser falla; no se intenta otra cosa |
| sin `Content-Type` y con body | `415 UNSUPPORTED_MEDIA_TYPE` |
| `text/plain`, `application/octet-stream`, cualquier otro | `415`. Aunque el body "parezca" JSON. Sobre todo si parece JSON |
| `application/x-www-form-urlencoded` o `multipart/form-data` en un endpoint que no los pidió | `415` |
| `urlencoded` o `multipart` en un endpoint que sí los pide, sin token CSRF válido | `403 CSRF_REQUIRED` |
| `charset` distinto de `utf-8` | `415` |
| `GET`, `HEAD`, `DELETE` con body | se ignora el body, no se parsea. Un body en un `GET` no es un error, es ruido |
| respuesta | siempre `application/json; charset=utf-8`, también los errores. Nunca una página HTML del framework |

Y dos reglas que van con esta: **`GET` y `HEAD` nunca cambian estado** (un endpoint que lo haga es un `POST`, y mientras no lo sea, es un bug de seguridad, no de estilo), y **el token CSRF nunca va en la URL ni a un log** (query string, `Referer` y Loki lo verían; `pino` con `redact` para `x-csrf-token` y `_csrf`).

Los parsers se montan **por tipo y por ruta**, nunca un "parseá lo que venga" global:

```ts
// apps/api/src/app.ts (Express)
app.use(requireContentType(['application/json']));                 // default de toda la API: solo JSON
app.use(express.json({ type: 'application/json', limit: '100kb', strict: true }));   // strict: solo objetos y arrays, no "null" ni números sueltos

// lo que acepta forms lo dice en su ruta, y paga el CSRF:
router.post('/uploads',
  requireContentType(['multipart/form-data']),
  requireCsrf,
  upload.single('file'),                                           // multer, con limits
  uploadHandler);
```

```ts
// apps/api/src/security/content-type.ts
export function requireContentType(allowed: readonly string[]) {
  return (req: Request, _res: Response, next: NextFunction) => {
    if (!hasBody(req)) return next();                               // GET/HEAD, o POST sin body: nada que parsear
    const ct = req.headers['content-type'];
    if (!ct) throw new UnsupportedMediaTypeError('missing Content-Type');
    const { type, charset } = parseContentType(ct);                 // 'application/json', 'utf-8' | undefined
    if (!allowed.includes(type)) throw new UnsupportedMediaTypeError(`${type} not accepted here`);
    if (charset && charset.toLowerCase() !== 'utf-8') throw new UnsupportedMediaTypeError(`charset ${charset}`);
    next();
  };
}

const hasBody = (req: Request) =>
  !['GET', 'HEAD'].includes(req.method) && (Number(req.headers['content-length']) > 0 || 'transfer-encoding' in req.headers);
```

En Fastify esto es el default: solo registra parser para `application/json` y `text/plain`, y responde `415` (`FST_ERR_CTP_INVALID_MEDIA_TYPE`) a lo demás. Lo único que hay que hacer es sacar el de `text/plain` (`fastify.removeContentTypeParser('text/plain')`) y registrar `@fastify/multipart` o `@fastify/formbody` solo donde haga falta, con el hook de CSRF en esas rutas.

```ts
// mal: lo que esta regla prohíbe
app.use(express.json({ type: '*/*' }));              // parsea cualquier cosa como JSON: text/plain incluido
app.use(express.urlencoded({ extended: true }));     // forms en toda la API, sin CSRF
app.use(express.text());                              // y después un JSON.parse(req.body) a mano en el handler
```

## Por qué

- **`text/plain` es el bypass clásico de CSRF para APIs JSON.** Un `<form enctype="text/plain">` en el sitio del atacante puede mandar un body que es JSON válido (`{"amount":1000,"to":"x","_":"`…`"}`) con la cookie de la víctima, **sin preflight**, porque `text/plain` es un "simple request". Si el parser acepta `text/plain` como JSON, o hace `JSON.parse` sin mirar el header, el `POST /transfer` se ejecuta. Parsear solo lo que dice `application/json` cierra eso: ningún `<form>` puede declarar `application/json`, y un `fetch` con ese header desde otro origen dispara preflight, que CORS rechaza y el request nunca sale.
- **Un parser que adivina es un parser que se equivoca.** "Si no hay `Content-Type`, probemos JSON" termina parseando un body de un cliente mal configurado como vacío, el schema valida `{}` y el handler hace algo con datos que no existen. Explícito antes que implícito: el cliente dice qué manda, y si no lo dice, no se parsea.
- **Forms son requests simples: el browser los manda sin preguntar.** `urlencoded` y `multipart` son los tres `Content-Type` que un `<form>` puede producir desde cualquier sitio, con cookies, sin preflight. `origin.md` ya los rechaza por `Origin`, y ese es el control principal. El token CSRF es la segunda capa para exactamente los endpoints donde el riesgo existe: si un día alguien afloja el chequeo de `Origin` "para que ande un webhook", los uploads siguen protegidos.
- **Congruencia entre header y body.** Un `multipart` parseado como `urlencoded`, o un JSON parseado como string, no es un error de formato: es un body que el handler va a interpretar distinto de como lo mandaron. Lo que se declara es lo que se parsea; si no coincide, `400` y a mirar el cliente.
- **Los errores también en JSON.** Un `415` o un `400` que devuelve la página HTML por defecto del framework filtra versión y stack, y el front no lo puede parsear. El error handler responde `{ code, message }` siempre (`../../architecture/SKILL.md` §5).

## El token CSRF, cuando hace falta

Solo para endpoints `urlencoded`/`multipart`. Un JSON no lo necesita: no hay forma de mandarlo cross-site sin preflight.

**No negociable: el token está atado a la sesión del usuario.** Se deriva del `sid` del access token (`jwt.md`: el id de la familia de refresh), que es nuevo en cada login y muere con la sesión. Consecuencias que el diseño tiene que cumplir y los tests verificar:

| Propiedad | Qué significa |
|---|---|
| uno por sesión, no por usuario | dos dispositivos del mismo usuario tienen tokens distintos. El de uno no sirve en el otro |
| cambia en cada login | cerrar sesión y volver a entrar da otro token. Un token capturado antes no sirve después |
| muere con la sesión | revocar la sesión (logout, reuso, cierre desde otro dispositivo) invalida el token sin hacer nada más: la validación necesita el `sid` autenticado, y ya no hay |
| no se deriva de nada estático | nunca `HMAC(userId)`, nunca `HMAC(email)`: serían el mismo token en todas las sesiones del usuario, para siempre |
| no se guarda | `HMAC(secret, sid)` se recalcula en cada validación. Sin columna, sin cache, sin rotación por request |

| Qué | Cómo |
|---|---|
| valor | `HMAC-SHA256(CSRF_SECRET, sid)` en base64url. Sin estado: se recalcula del `sid` del access; no se guarda |
| cómo lo recibe el front | en el body de `POST /auth/login` y `GET /auth/me`, campo `csrfToken`. No es un token de sesión: no sirve para autenticarse |
| dónde lo guarda el front | en memoria. Se pierde al recargar y `me` lo trae de nuevo |
| cómo lo manda | header `X-CSRF-Token` en los requests `multipart`/`urlencoded`. Un form HTML clásico sin JS lo manda en un campo `_csrf` del body |
| cómo se valida | `requireCsrf`: recalcula el HMAC del `sid` del access y compara con `timingSafeEqual`. Falta o no coincide → `403 CSRF_REQUIRED` |
| por qué no double-submit cookie | con la premisa de `../../architecture/SKILL.md` §8, un subdominio hermano comprometido puede setear cookies para `ejemplo.com` que la API recibe. El HMAC del `sid` no depende de ninguna cookie que otro pueda escribir |

```ts
// apps/api/src/security/csrf.ts
export const csrfTokenFor = (sid: string) => createHmac('sha256', config.CSRF_SECRET).update(sid).digest('base64url');

export function requireCsrf(req: Request, _res: Response, next: NextFunction) {
  const presented = req.headers['x-csrf-token'] ?? req.body?._csrf;          // header (SPA) o campo (form clásico)
  const expected = csrfTokenFor(req.user.sid);                                // req.user lo puso el middleware de auth
  if (typeof presented !== 'string' || presented.length !== expected.length ||
      !timingSafeEqual(Buffer.from(presented), Buffer.from(expected))) throw new CsrfRequiredError();
  next();
}
```

`requireCsrf` va **después** de auth (necesita el `sid`) y **antes** del parser de multipart cuando el token viene en header, para no procesar el archivo de un request que se va a rechazar. Si viene en el body (`_csrf` de un form), el parser corre primero; es el único caso.

## Cuándo cambia

- Webhooks de terceros que mandan `urlencoded` (algunos proveedores de pagos viejos): router aparte, autenticado por firma, sin cookies, sin CSRF. No pasan por auth y no son esta regla; son `origin.md` § Qué queda afuera.
- Un endpoint que recibe `application/octet-stream` (subida cruda de un binario): se declara en su ruta con `requireContentType(['application/octet-stream'])` y `express.raw({ limit })`. Mismo criterio: explícito, por ruta, con límite.
- `limit`: 100 kB para JSON es generoso para una API; subirlo solo en la ruta que lo necesita, no global. Multipart: `limits.fileSize` por ruta.

## Qué pasa si no

| Atajo | Lo que cuesta |
|---|---|
| `express.json({ type: '*/*' })` o `JSON.parse(req.body)` a mano | el form `text/plain` de otro sitio ejecuta transferencias con la cookie de la víctima. Es el CSRF que "no puede pasar con JSON" |
| `express.urlencoded()` global "por si acaso" | toda la API acepta forms de cualquier sitio. Con `Origin` bien, no entra; el día que alguien afloje `Origin`, entra todo |
| parsear sin `Content-Type` "para ser tolerante" | clientes rotos que mandan body sin header pasan la validación con `{}` y el handler opera sobre nada |
| aceptar `charset=latin1` | un body que el schema valida como string llega con bytes que el front no esperaba; y es un vector de bypass de validadores que miran UTF-8 |
| errores en HTML | el front hace `JSON.parse('<!DOCTYPE html>')` y muestra "error inesperado"; el stack trace del framework va al cliente |
| CSRF por double-submit cookie | un subdominio hermano setea la cookie `csrf=x` con `Domain=ejemplo.com` y manda `X-CSRF-Token: x`. Validación pasada |

## Qué pedirle a Claude

> "Antes de agregar un endpoint con body, decime qué `Content-Type` acepta y por qué. Si no es `application/json`, dónde va `requireCsrf`."

## Tests que tienen que existir

- `POST /auth/login` con `Content-Type: text/plain` y body JSON válido → `415`. El cuerpo del `415` es JSON con `code: UNSUPPORTED_MEDIA_TYPE`.
- `POST /auth/login` sin `Content-Type` y con body → `415`. Sin body ni header → sigue al handler y falla por validación (`400`), no por `415`.
- `POST /auth/login` con `application/json` y body `{"email":` → `400 INVALID_BODY`, no `500`.
- `POST /auth/login` con `application/x-www-form-urlencoded` → `415`: ese endpoint no acepta forms.
- Si hay uploads: `POST /uploads` multipart sin `X-CSRF-Token` → `403 CSRF_REQUIRED` **antes** de leer el archivo (test con un stream que falla si se lee). Con el token del `me` → `201`.
- `POST /uploads` con el token de **otra** sesión del **mismo** usuario → `403`. Es el test de "atado a la sesión, no al usuario".
- Después de `POST /auth/logout` y un login nuevo, el token del `me` es distinto al anterior, y el anterior → `403`.
- `csrfTokenFor(sidA) !== csrfTokenFor(sidB)` y `csrfTokenFor(sidA) === csrfTokenFor(sidA)`: unit, sin HTTP.
- Todas las respuestas de error llevan `Content-Type: application/json; charset=utf-8`, incluidas `404` y `415`.

## Fuentes

- [OWASP, CSRF Prevention Cheat Sheet, "Employing custom request headers" y "Content-Type"](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html): por qué JSON con header explícito no es forjable desde un form, y el caso `text/plain`.
- [MDN, CORS, simple requests](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS#simple_requests): los tres `Content-Type` que un form puede mandar sin preflight.
- [PortSwigger, CSRF with JSON, `enctype="text/plain"`](https://portswigger.net/web-security/csrf): el bypass con form `text/plain`.
- [Express, `express.json` opciones `type` y `strict`](https://expressjs.com/en/api.html#express.json): el parser solo corre si el `Content-Type` coincide.
- [Fastify, Content-Type parser](https://fastify.dev/docs/latest/Reference/ContentTypeParser/): `415` por defecto para tipos no registrados.
- [RFC 9110 §15.5.16, 415 Unsupported Media Type](https://www.rfc-editor.org/rfc/rfc9110#name-415-unsupported-media-type).
