# Origin: la API solo habla con su frontend

Decisión cerrada: **todo request a la API tiene que traer un header `Origin` igual, byte a byte, al origen del frontend. Sin `Origin`, o con `Origin: null`, se rechaza antes de leer cookies, body o ruta.** Es la regla que hace cumplir la premisa de `../../architecture/SKILL.md` §8: dos subdominios se hablan entre sí, y todo lo demás, incluidos los otros subdominios del mismo dominio, es hostil.

## No negociable

Tres reglas de diseño seguro. No tienen "cuándo cambia". Un PR que las toque no se mergea; un proyecto que las necesite distintas tiene un problema de arquitectura, no de configuración.

| Regla | Qué significa en código | Lo que queda prohibido |
|---|---|---|
| **Exacto** | `ALLOWED.has(origin)`: igualdad de string completa, esquema + host + puerto, contra valores literales que vienen de config | `includes`, `startsWith`, `endsWith`, `match`, `test`, regex, comodín `*`, `*.ejemplo.com`, comparar solo el host, ignorar el puerto, ignorar el esquema, `toLowerCase()` antes de comparar |
| **Nunca `null`** | `origin === 'null'` se rechaza explícitamente, antes de mirar la lista | tratarlo como "sin origen" y dejarlo pasar; una lista mal armada donde `'null'` termina adentro |
| **Nunca ausente** | `origin === undefined` se rechaza, en todos los métodos, también `GET` | saltar el chequeo en `GET`/`HEAD`; caer a `Referer`; `if (!origin) next()` |

Y la contraparte en CORS: `origin` es el mismo valor literal, nunca `true`, nunca una función que devuelve `true`, nunca `*`.

El test que lo fuerza, obligatorio en todo proyecto, parametrizado y sin excepciones:

```ts
// apps/api/src/security/origin.test.ts
const REJECTED = [
  undefined,                              // ausente
  'null',                                 // opaco: sandbox, redirect cross-origin, file://
  'https://evil.ejemplo.com',             // hermano: mismo sitio, otro origen
  'https://app.ejemplo.com.evil.io',      // sufijo falso
  'https://evil.io/https://app.ejemplo.com', // el origen válido adentro de otro
  'http://app.ejemplo.com',               // esquema distinto
  'https://app.ejemplo.com:8443',         // puerto distinto
  'https://APP.ejemplo.com',              // mayúsculas: el browser nunca las manda; si llegan, no es un browser
  'https://app.ejemplo.com/',             // Origin no lleva path; si lo lleva, no es un browser
  'https://app.ejemplo.com, https://evil.io', // dos valores
];
it.each(REJECTED)('rechaza Origin %s en GET con cookie válida', async (origin) => {
  const res = await request(app).get('/orders').set('Cookie', validCookie).set(origin === undefined ? {} : { Origin: origin });
  expect(res.status).toBe(403);
});
it('acepta solo el exacto', async () => {
  expect((await request(app).get('/orders').set('Cookie', validCookie).set('Origin', 'https://app.ejemplo.com')).status).toBe(200);
});
```

Si una de estas filas pasa, el middleware está mal, no el test.

## Regla

```ts
// apps/api/src/security/origin.ts: primer middleware de la app, antes de cors, cookies y auth
import { config } from '@/config';

const ALLOWED: ReadonlySet<string> = new Set([config.WEB_ORIGIN]); // "https://app.ejemplo.com". Exacto: esquema, host, puerto
const EXEMPT = new Set(['/health']);                                // lo que no es para el frontend: ni cookies ni datos

export function requireOrigin(req: Request, res: Response, next: NextFunction) {
  if (EXEMPT.has(req.path)) return next();
  const origin = req.headers.origin;                                 // string | undefined. Nunca Referer: se suprime, se recorta, no es lo mismo
  if (origin === undefined) throw new ForbiddenError('missing Origin');
  if (origin === 'null') throw new ForbiddenError('opaque Origin');  // sandbox, redirect cross-origin, file://, data:
  if (!ALLOWED.has(origin)) throw new ForbiddenError(`origin ${origin} not allowed`);
  res.setHeader('Vary', 'Origin');
  next();
}
```

```ts
// mal: lo que esta regla reemplaza
if (['GET', 'HEAD', 'OPTIONS'].includes(req.method)) return next();            // un GET con cookie devuelve datos: también se valida
const origin = req.headers.origin ?? new URL(req.headers.referer ?? 'null:').origin;  // Referer no es Origin
app.use(cors({ origin: true, credentials: true }));                              // refleja cualquier origen: es apagar la regla
```

El orden importa: `requireOrigin` → `cors` → `cookieParser` → auth → rutas. Un request de otro origen no llega a tocar la cookie ni a parsear el body.

## Por qué

- **`SameSite` no protege de los subdominios hermanos.** "Sitio" es el dominio registrable: `blog.ejemplo.com` y `api.ejemplo.com` son el **mismo sitio**. Una cookie `SameSite=Strict` de la API viaja en un `fetch` hecho desde el blog. Un XSS en cualquier subdominio, un WordPress con un plugin viejo, un landing de marketing, un subdominio olvidado que apunta a un bucket ajeno, puede hacer requests autenticados a la API en nombre del usuario que tenga sesión. `cookies.md` cierra el robo de la cookie; esta regla cierra su uso desde otro origen.
- **Esta regla es la primera capa; `content-type.md` es la segunda.** `Origin` rechaza el request de un sitio ajeno. Si algún día ese chequeo se afloja, los únicos requests que un `<form>` ajeno puede fabricar son `urlencoded`, `multipart` y `text/plain`; `content-type.md` hace que la API no los parsee salvo donde se piden, y ahí exige token CSRF.
- **CORS no frena el request, frena la respuesta.** Sin `Access-Control-Allow-Origin` para el blog, el browser le oculta el body al script del blog. Pero un "simple request" (`GET`, `POST` con form, sin headers raros) **se ejecuta igual en el servidor**: el `POST /orders` se creó, el `DELETE` por `POST` con `_method` se ejecutó. Lo único que frena el request es que el servidor lo rechace al ver el `Origin`.
- **El browser siempre manda `Origin` cuando el frontend habla con la API.** Front y API son orígenes distintos, así que cada `fetch`/axios es un request CORS, y los requests CORS llevan `Origin` sin excepción, también los `GET`. Exigirlo no rompe nada del frontend. Lo que no lo trae es lo que no es el frontend: `curl`, un script, una navegación de primer nivel a la API, un bot.
- **El browser no deja falsificar `Origin`.** Es un header prohibido: ningún script, de ningún origen, puede setearlo. Es la única señal de "quién me llama" que el servidor puede creer sin firmar nada. `Referer` no: lo recorta `Referrer-Policy`, lo suprimen extensiones y navegación privada, y falta en un tercio de los requests reales.
- **Si un proxy adelante quita `Origin`, la regla falla cerrada.** Un CDN o un WAF que borre headers `Origin`/`Sec-*` deja a la API respondiendo `403` a todo, no aceptando todo. Es el comportamiento correcto: se nota en el primer deploy, no en el primer incidente. El Caddy de `../../docker-ci/references/docker.md` no los toca.
- **`Sec-Fetch-Site` no reemplaza esto.** Fetch Metadata distingue `same-origin`, `same-site`, `cross-site` y `none`. Con la premisa de §8, nuestro frontend es `same-site` respecto de la API, igual que un hermano hostil: no los separa. `Origin` exacto sí. Se puede sumar como capa (rechazar `cross-site` y `none` en métodos no seguros), pero no cambia ninguna decisión de este archivo.
- **`null` es un origen, y es el peor.** Lo mandan los iframes con `sandbox`, los requests después de una redirección cross-origin, las páginas abiertas desde `file://` y `data:`. Un atacante consigue `Origin: null` sin esfuerzo con un iframe sandboxeado en su sitio. Un allowlist que no lo rechaza explícitamente y compara con `includes` o con un regex permisivo lo deja pasar.

## Qué queda afuera de la regla, a propósito

| Caso | Qué se hace |
|---|---|
| health check del balanceador | `EXEMPT`. Responde `200` sin leer nada. No devuelve datos ni acepta cookies |
| webhooks de terceros (Stripe, GitHub) | router aparte, bajo `/webhooks`, autenticado por **firma** del proveedor. Sin cookies, sin `Origin`. No es el frontend y no se trata como tal |
| app nativa, CLI, servicio a servicio | no son el frontend y no usan cookies. Un router aparte con `Authorization: Bearer` o API key, y ese router no pasa por `requireOrigin`. Es una decisión explícita del proyecto, no un hueco |
| dev local | `WEB_ORIGIN=http://localhost:5173` en el `.env` de dev. Mismo código, mismo `Set`, otro valor. Nunca un `if (dev) skip` |
| preflight `OPTIONS` | también trae `Origin`: pasa por la misma regla. `cors` lo contesta después, solo si el origen es el permitido |

## CORS, que viene después

Es lo que le permite al frontend **leer** la respuesta. Se configura con el mismo literal, `credentials: true`, y se registra después de `requireOrigin`. Está en `cors.md`.

## Cuándo cambia

- Dos frontends legítimos (`app.` y `admin.`): dos entradas en el `Set`, desde config, cada uno con su valor exacto. Nunca un patrón `*.ejemplo.com`: eso vuelve a confiar en los hermanos.
- Un subdominio nuevo que "necesita" hablar con la API: es un frontend nuevo (entra al `Set` y se audita como tal) o no habla con la API. No hay tercera opción.

## Qué pasa si no

| Atajo | Lo que cuesta |
|---|---|
| validar solo en `POST`/`PUT`/`DELETE` | un `GET /me`, `GET /orders` desde el subdominio comprometido devuelve los datos del usuario con sesión. El `GET` también es un request autenticado |
| caer a `Referer` cuando falta `Origin` | `Referrer-Policy` lo recorta al origen o lo quita; un `<meta name="referrer" content="no-referrer">` en la página del atacante lo quita del todo. Se termina aceptando requests sin saber de dónde vienen |
| no contemplar `null` | `<iframe sandbox src="https://api.ejemplo.com/…">` desde cualquier sitio manda `Origin: null`. Si el chequeo es `!origin || allowed.includes(origin)` con `allowed` mal armado, pasa |
| `cors({ origin: true })` o una función que devuelve `true` | la API contesta "sí, podés leer" a cualquier origen con credenciales. Es CSRF con lectura de respuesta incluida |
| allowlist por sufijo (`endsWith('.ejemplo.com')`) | `https://ejemplo.com.atacante.io` no matchea, pero `https://evil.ejemplo.com` sí, y ese es exactamente el caso del que se protege la regla |
| saltear la regla en dev con `if (NODE_ENV !== 'production')` | staging corre con `NODE_ENV=development` y sin regla. Y el código que corre en prod no es el que se probó |

## Qué pedirle a Claude

> "Antes de agregar un endpoint o un cliente nuevo de la API, decime si pasa por `requireOrigin` y por qué. Si no pasa, qué lo autentica."

## Tests que tienen que existir

- `GET /orders` con cookie válida y **sin** `Origin` → `403 FORBIDDEN`. El `GET`, no solo el `POST`.
- `GET /orders` con `Origin: null` → `403`.
- `POST /orders` con `Origin: https://evil.ejemplo.com` (mismo sitio, otro origen) y cookie válida → `403`, y el pedido **no** se creó.
- `OPTIONS /orders` con `Origin: https://app.ejemplo.com` → `Access-Control-Allow-Origin: https://app.ejemplo.com` y `Access-Control-Allow-Credentials: true`. Con otro origen, ninguno de los dos headers.
- `GET /health` sin `Origin` → `200`.
- Cada rechazo de `requireOrigin` deja una línea de log con `origin`, método, ruta y `sid` si hay cookie, sin el valor de ninguna cookie. Un pico de rechazos desde un origen concreto es un intento de CSRF o un deploy roto, y se tiene que poder ver en Loki.
- El middleware está registrado antes que `cookieParser` y que cualquier router: un test que inspecciona `app._router.stack` (Express) o el orden de `register` (Fastify), o un test de integración donde un request sin `Origin` a una ruta inexistente devuelve `403`, no `404`.

## Contra la cheat sheet de CSRF de OWASP

Auditoría de las reglas del core contra [la cheat sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html), sección por sección. "Más estricto" significa que OWASP admite una alternativa y el core no.

| OWASP dice | El core | Dónde |
|---|---|---|
| `Origin` presente: verificar que coincida con el origen objetivo, completo, no por prefijo (`example.org.attacker.com` no pasa) | igualdad de string, esquema + host + puerto; `includes`, sufijos y regex prohibidos; test con diez orígenes que deben fallar | este archivo, § No negociable |
| `Origin` ausente: caer al `Referer`; si tampoco, exigir token. "Missing headers and `Origin: null` are not evidence of a same-origin request" | **más estricto**: ausente y `null` se rechazan siempre, sin fallback a `Referer` ni a token. Nada se salta "por compatibilidad" | este archivo |
| el origen objetivo sale de config confiable, no de `Host`/`X-Forwarded-Host` | `WEB_ORIGIN` de `config`, literal | este archivo, `cookies.md` |
| `SameSite` es defensa en profundidad, no única: "scoped to the registrable domain, not the origin"; hermanos pueden hacer requests same-site | exactamente la premisa de `../../architecture/SKILL.md` §8: `Strict` como capa, `Origin` como control | `cookies.md` |
| no setear cookies para el dominio padre; `__Host-` para evitar sobreescritura desde subdominios | host-only sin `Domain`, prefijos `__Host-`/`__Secure-` | `cookies.md` |
| APIs JSON: rechazar `form-urlencoded`, `multipart`, `text/plain`; muchas aceptan `text/plain` y quedan expuestas | solo `application/json` por defecto, `415` a lo demás; forms solo por ruta y con token | `content-type.md` |
| custom header como defensa, pero "don't rely on it alone"; CORS con credenciales nunca `*` ni regex de subdominios | no se usa header custom para JSON: el `Content-Type` ya fuerza preflight, y `Origin` exacto es la capa que no depende del preflight. CORS con un literal, sin función, sin regex | este archivo, `content-type.md` |
| token: generado en servidor, ligado a la sesión, HMAC con secreto, nunca validado solo desde cookie, comparación constante, no rotar por request, sin timestamp como expiración, nunca en URL ni logs | `HMAC-SHA256(secret, sid)` por sesión, leído de header o campo, `timingSafeEqual`, sin rotación, sin timestamp; nunca en query string ni en logs | `content-type.md` § El token CSRF |
| double-submit "naive" es inseguro: quien escribe cookies en el dominio (un hermano) lo rompe | descartado por eso mismo | `content-type.md` |
| no usar `GET` para cambiar estado; `SameSite=Lax` no lo cubre | `GET` y `HEAD` nunca cambian estado; su body se ignora; y la verificación de `Origin` corre también en `GET` | `content-type.md`, este archivo |
| login CSRF: el atacante loguea a la víctima en su cuenta; renovar sesión al loguear | el login pasa por `requireOrigin` como todo; cada login crea una sesión nueva (`sid` nuevo), no hay pre-sesión que fijar | este archivo, pre-plan `auth-jwt-sessions` |
| operaciones críticas: re-autenticación o token de un solo uso; "Do NOT use CAPTCHA" | cambio de password exige la password actual; sin CAPTCHA | pre-plan `auth-jwt-sessions` |
| client-side CSRF: inputs controlados por el atacante (hash de la URL) que arman requests; no adjuntar tokens por defaults globales | el front no arma URLs ni bodies de la API desde la URL o el hash; el token CSRF se adjunta solo en las rutas multipart, no en un default de axios | `../../typescript/references/security.md` |
| HTTPS en toda la aplicación | HSTS con `includeSubDomains` | `headers.md` |
| XSS derrota toda defensa CSRF | CSP con nonce, nada inline | `csp.md` |
| Fetch Metadata (`Sec-Fetch-Site`) como señal, con fallback obligatorio a `Origin` | no se usa como control: `same-site` no distingue nuestro frontend de un hermano. `Origin` es el control | este archivo, § Por qué |
| al menos una mitigación de defensa en profundidad | cuatro: `SameSite=Strict`, `Content-Type` restringido, token en forms, CSP | |

## Fuentes

- [MDN, `Origin` header](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Origin): cuándo se manda, cuándo es `null`, por qué es forbidden header.
- [MDN, Forbidden request headers](https://developer.mozilla.org/en-US/docs/Glossary/Forbidden_request_header): `Origin` no se puede setear desde JS.
- [OWASP, CSRF Prevention Cheat Sheet, "Verifying Origin With Standard Headers"](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html#verifying-origin-with-standard-headers): la verificación de `Origin` como defensa, y el caso `null`.
- [web.dev, Understanding "same-site" and "same-origin"](https://web.dev/articles/same-site-same-origin): por qué `blog.` y `api.` son el mismo sitio.
- [MDN, CORS, simple requests](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS#simple_requests): los requests que se ejecutan aunque CORS oculte la respuesta.
