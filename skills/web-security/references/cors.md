# CORS: un origen literal, con credenciales, y nada más

Decisión cerrada: **la API responde CORS a un solo origen, el del frontend, escrito literal desde config, con `credentials: true`. Sin comodines, sin regex, sin función que decida, sin reflejar lo que llega. CORS viene después de `origin.md`, nunca en su lugar.**

## Qué es CORS y qué no

CORS no protege a la API. Protege al **usuario** de que un sitio ajeno lea respuestas de la API con sus cookies. Es el browser el que decide si le entrega la respuesta al script que la pidió, según lo que la API contestó en `Access-Control-Allow-Origin`.

| CORS sí | CORS no |
|---|---|
| decide si el script de `app.ejemplo.com` puede **leer** la respuesta de `api.ejemplo.com` | impide que el request **llegue** a la API: un `POST` con form desde otro sitio se ejecuta igual, solo que el atacante no ve la respuesta |
| hace que un `fetch` JSON cross-origin pase por preflight (`OPTIONS`) y, si la API no lo autoriza, el browser no manda el request real | protege de nada que no sea un browser: `curl` no hace CORS |
| con `credentials: true`, obliga a nombrar el origen: `*` no vale | reemplaza al chequeo de `Origin` del servidor: eso es `origin.md` |

Por eso el orden: `requireOrigin` rechaza al ajeno en el servidor; `cors` le dice al browser del frontend legítimo que puede leer. Dos preguntas distintas, dos capas.

## Las decisiones

| Opción | Valor | Por qué | Cuándo cambia |
|---|---|---|---|
| `origin` | `config.WEB_ORIGIN`, literal: `https://app.ejemplo.com` | un string exacto. El mismo valor que `origin.md` compara | un segundo frontend legítimo: un array de literales, cada uno exacto. Nunca una función ni un patrón |
| `credentials` | `true` | las cookies viajan y el browser entrega la respuesta. Sin esto, `withCredentials` del cliente no sirve | nunca |
| `methods` | `GET, POST, PUT, PATCH, DELETE` | lo que la API usa. `OPTIONS` lo maneja `cors` solo | los que use la API |
| `allowedHeaders` | `Content-Type, X-CSRF-Token` | lo que el front manda. Sin `Authorization`: la sesión va en cookie (`jwt.md`) | un header nuevo del front entra acá, con el por qué |
| `exposedHeaders` | ninguno | el front lee el body, no headers. Un header expuesto es un canal más | si el front necesita leer uno (`Retry-After`, `X-Request-Id`), ese y solo ese |
| `maxAge` | `600` | el browser cachea el preflight 10 min: un `OPTIONS` por endpoint cada 10 min, no uno por request | nunca más de 86400: Chrome lo capa ahí |
| `Vary: Origin` | siempre | si un cache intermedio guarda una respuesta con `Allow-Origin` para un origen y se la sirve a otro, el browser del otro la lee | lo pone `cors` solo |
| preflight fallido | `204` sin headers `Access-Control-*` | el browser bloquea solo: no hace falta un `403` en el `OPTIONS`. Y `requireOrigin` ya lo rechazó antes | nunca |
| developer | `WEB_ORIGIN=http://localhost:5173` en `.env` | mismo código, otro literal. `localhost:5173` y `localhost:3000` son dos orígenes: CORS aplica igual que en prod | nunca un `if (dev) origin: true` |

```ts
// apps/api/src/security/cors.ts
import cors from 'cors';
import { config } from '@/config';

export const corsPolicy = cors({
  origin: config.WEB_ORIGIN,                 // literal. Nunca true, nunca '*', nunca una función, nunca un RegExp
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
  allowedHeaders: ['Content-Type', 'X-CSRF-Token'],
  maxAge: 600,
});

// apps/api/src/app.ts: el orden importa
app.use(requireOrigin);        // origin.md: rechaza al ajeno. También rechaza el OPTIONS ajeno
app.use(corsPolicy);           // contesta el preflight del frontend y marca las respuestas
app.use(securityHeaders);      // headers.md
// ...parsers, auth, rutas
```

`@fastify/cors` tiene las mismas opciones con los mismos nombres. Hono: `cors({ origin, credentials, allowMethods, allowHeaders, maxAge })`.

```ts
// mal: lo que esta regla prohíbe
cors({ origin: true, credentials: true });                              // refleja cualquier origen con cookies: CSRF con lectura
cors({ origin: '*', credentials: true });                               // el browser lo rechaza; y sin credentials, la sesión no viaja
cors({ origin: /\.ejemplo\.com$/, credentials: true });                 // todos los hermanos leen la API: la premisa de §8 rota
cors({ origin: (o, cb) => cb(null, o?.endsWith('.ejemplo.com')) });     // lo mismo, con más código
cors({ origin: config.WEB_ORIGIN });                                    // sin credentials: el front no puede mandar la cookie
app.use(cors()); /* y después */ app.use(requireOrigin);                // el preflight ajeno recibe Allow-Origin antes del rechazo
```

## Por qué

- **`origin: true` es apagar la protección.** Refleja el `Origin` que llegue en `Allow-Origin`. Cualquier sitio hace `fetch(api, { credentials: 'include' })` y lee la respuesta con la cookie de la víctima. Es exactamente lo que CORS existe para impedir. Con `requireOrigin` adelante no entra, pero el día que alguien afloje `requireOrigin` "para un webhook", `origin: true` convierte el agujero en lectura completa.
- **Regex y sufijos confían en los hermanos.** `/\.ejemplo\.com$/` deja leer la API a `blog.ejemplo.com`. Un XSS ahí, o un subdominio abandonado apuntando a un bucket ajeno, lee todo lo del usuario. Es la premisa de `../../architecture/SKILL.md` §8: los hermanos son hostiles. OWASP lo dice con las mismas palabras: no permitir CORS a todos los subdominios con una regex.
- **`credentials: true` fuerza el literal.** El browser rechaza `Access-Control-Allow-Origin: *` cuando hay credenciales. No es una opción de diseño, es la spec haciendo cumplir la regla.
- **El preflight es un favor del browser, no un control.** Un browser con un bug, un cliente que no es browser, o un "simple request" (form, `text/plain`) no lo hacen. Por eso `origin.md` y `content-type.md` existen: CORS es la capa de lectura, no la de entrada.
- **`Vary: Origin` es por los caches.** Un CDN o un proxy que cachee `GET /me` con `Allow-Origin: https://app.ejemplo.com` y lo sirva a un request con otro `Origin` le entregaría la respuesta a ese otro. `Vary` hace que el cache sea por origen. La API además manda `Cache-Control: no-store` en todo lo que tiene datos de usuario (`headers.md`).

## Relación con los otros headers

| Header | Qué hace frente a CORS |
|---|---|
| `Cross-Origin-Resource-Policy: same-origin` (`headers.md`) | bloquea cargas **sin** CORS desde otro origen (`<img src=api/...>`, `<script src=api/...>`). Un `fetch` con CORS no pasa por CORP: el frontend sigue leyendo |
| `Cross-Origin-Opener-Policy` | no interactúa. Es sobre ventanas, no sobre requests |
| `Content-Type` (`content-type.md`) | `application/json` no es "simple": todo `fetch` JSON cross-origin hace preflight. Es lo que hace que el preflight sirva de algo |

## Qué pasa si no

| Atajo | Lo que cuesta |
|---|---|
| `origin: true` "porque en dev el puerto cambia" | en prod también refleja. Cualquier sitio lee la API con la sesión del usuario |
| `*` con credenciales | el browser lo rechaza en silencio: "a veces no carga" en soporte. Y se termina poniendo `true` |
| regex de subdominios | el hermano hostil lee todo |
| `cors` antes de `requireOrigin` | el `OPTIONS` ajeno recibe `Allow-Origin` del frontend (no coincide con el suyo, así que el browser bloquea), pero el request real ya pasó por un middleware que no debía verlo. Orden roto, difícil de notar |
| sin `maxAge` | un `OPTIONS` por cada request no-simple. Dobla la latencia de cada mutación |
| `allowedHeaders: '*'` | cualquier header custom pasa el preflight. Lo que mañana sea una señal de "esto vino del front" ya no lo es |

## Qué pedirle a Claude

> "Mostrame la config de CORS y el orden de los middlewares en `app.ts`. `origin` tiene que ser un literal de config y `requireOrigin` tiene que estar antes."

## Tests que tienen que existir

- `OPTIONS /orders` con `Origin: https://app.ejemplo.com` y `Access-Control-Request-Method: POST` → `204`, `Access-Control-Allow-Origin: https://app.ejemplo.com` (literal, no `*`), `Access-Control-Allow-Credentials: true`, `Access-Control-Max-Age: 600`, `Vary: Origin`.
- `OPTIONS /orders` con `Origin: https://evil.ejemplo.com` → `403` de `requireOrigin`, sin ningún header `Access-Control-*`.
- `GET /orders` con cookie y `Origin: https://app.ejemplo.com` → `200` con `Access-Control-Allow-Origin` exacto y `Allow-Credentials: true`.
- Un test que lea `app._router.stack` (Express) o el orden de `register` (Fastify) y falle si `cors` está antes que `requireOrigin`.
- `grep -rn "origin: true\|origin: '\*'\|origin: /" apps/api/src` vacío. Es un check de CI, no un test: está en `../../docker-ci/references/ci.md` como scanner de patrones prohibidos, al lado de gitleaks.

## Fuentes

- [MDN, CORS](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS): simple requests, preflight, credenciales y `*`.
- [OWASP, CSRF Prevention Cheat Sheet, "Disallowing simple requests"](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html): "allow only origins you fully control", no regex de subdominios.
- [expressjs/cors](https://github.com/expressjs/cors#configuration-options): las opciones y qué header pone cada una.
- [Fetch Standard, CORS protocol](https://fetch.spec.whatwg.org/#cors-protocol): por qué `*` con credenciales falla.
