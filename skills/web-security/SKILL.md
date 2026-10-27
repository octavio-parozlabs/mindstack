---
name: web-security
description: >-
  Seguridad de una SPA y una API en subdominios, como decisiones cerradas: JWT en cookies httpOnly con refresh rotativo y detección de reuso, Origin exacto y nunca null ni ausente, CORS a un solo origen literal con credenciales, body solo application/json y token CSRF atado a la sesión, CSP con nonce por request, headers de seguridad, config leída una vez y validada. Usar al escribir o revisar login, sesiones, tokens, cookies, CORS, CSRF, CSP, headers, middlewares de app.ts o main.ts, config o variables de entorno.
paths:
  - "**/auth/**"
  - "**/*auth*"
  - "**/session*/**"
  - "**/cors*"
  - "**/origin*"
  - "**/*csrf*"
  - "**/*content-type*"
  - "**/*cookie*"
  - "**/*upload*"
  - "**/middleware*/**"
  - "**/security/**"
  - "**/*csp*"
  - "**/helmet*"
  - "**/*headers*"
  - "**/nginx*"
  - "**/Caddyfile*"
  - "**/app.ts"
  - "**/main.ts"
  - "**/config.*"
  - "**/vite.config.*"
  - "**/.env*"
  - "**/*.html"
---

# Seguridad web: dos orígenes, y el resto es hostil

La premisa (`../architecture/SKILL.md` §8): hay **dos** orígenes legítimos, `app.ejemplo.com` y `api.ejemplo.com`. Todo lo demás, incluidos los subdominios hermanos (`blog.`, `admin.`, `staging.`), es hostil: un XSS en un hermano o un subdominio abandonado es un atacante con cookies del dominio. Cada capa de abajo asume eso. Las decisiones son cerradas: se cumplen o se cambian por PR a este plugin, nunca en la tarea.

## Decisiones cerradas

Cada fila es una decisión. La referencia tiene el por qué, el ejemplo bueno y malo, "qué pasa si no" y los tests que tienen que existir. Leerla **antes** de tocar ese tema, no después.

| Tema | Decisión | No negociable | Referencia |
|---|---|---|---|
| Tokens | dos tokens, los dos en cookies `httpOnly`: access JWT corto (10 min, sin PII ni roles), refresh opaco (30 días deslizantes, hasheado en DB) con rotación y detección de reuso que revoca toda la familia; gracia de 10 s tras rotar. El front no sabe cuándo vence el access: `401 TOKEN_EXPIRED` → refresh → reintento, con lock entre pestañas. Tiempo en UTC en las dos puntas | tokens nunca donde JS llegue (`localStorage`, body, `Authorization: Bearer` desde el browser) | `references/jwt.md` |
| Cookies | `httpOnly`, `Secure`, `SameSite=Strict` (`Lax` solo en una cookie que reciba navegaciones externas; `None` nunca), host-only de `api.ejemplo.com`, `Max-Age` igual a la vida del token, prefijos `__Host-`/`__Secure-` en producción. `Secure` se decide por `WEB_ORIGIN` (`http://localhost…` o no), nunca por `NODE_ENV` | nada de `domain=.ejemplo.com` | `references/cookies.md` |
| Quién llama | `Origin` igual byte a byte a `config.WEB_ORIGIN`, en todos los métodos incluido GET. `null` o ausente = rechazo. Primer middleware. Sin `includes`, `startsWith`, regex ni comodín. Sin fallback a `Referer` | exactitud byte a byte; nunca `null`, nunca ausente | `references/origin.md` |
| Quién lee | CORS a un solo origen literal de config, `credentials: true`, `allowedHeaders: Content-Type, X-CSRF-Token`, `maxAge: 600`, registrado **después** de `requireOrigin`. CORS protege lectura, no entrada | nunca `origin: true`, `'*'`, regex ni función | `references/cors.md` |
| Qué body entra | solo `application/json` exacto (415 si falta o es otro; 400 `INVALID_BODY` si está roto). `urlencoded`/`multipart` solo por ruta con `requireCsrf`. Token CSRF = `HMAC-SHA256(CSRF_SECRET, sid)`: uno por sesión, nunca en URL ni logs. GET/HEAD nunca cambian estado | el token va atado a la sesión, nunca a userId ni email | `references/content-type.md` |
| CSP | nonce por request, siempre: `default-src 'none'`, `script-src 'nonce-…' 'strict-dynamic'` sin `'self'`, `style-src 'self' 'nonce-…'` sin `'unsafe-inline'`, `style-src-attr 'none'`, `frame-ancestors 'none'`, `base-uri 'none'`, `object-src 'none'`. Nunca por `<meta>`. Quién inyecta el nonce: quien sirve el HTML (el proxy o el back); el bundler deja el placeholder. Se despliega primero en `Report-Only`; en dev no se aplica. Una librería que inyecta `<style>` sin tomar nonce no entra | `frame-ancestors 'none'` | `references/csp.md` |
| Headers | nadie iframea: `frame-ancestors 'none'` + `X-Frame-Options: DENY`. HSTS con `includeSubDomains`, `nosniff`, `Referrer-Policy`, `Permissions-Policy`, COOP y CORP `same-origin`, `Cache-Control: no-store` en todo lo que tiene datos de usuario. En **todas** las respuestas: HTML, assets, JSON y errores (el proxy no hereda headers entre bloques) | nadie iframea | `references/headers.md` |
| Config | el entorno se lee **una vez** al arrancar, en el módulo `config`, contra un schema; se congela; se exporta tipado. Ningún otro archivo toca el entorno. Decisiones de seguridad por el valor concreto, nunca por el "modo". `.env.example` con exactamente las claves del schema | un solo lugar que lee el entorno | `references/config.md` |

## El orden de los middlewares

Es la tabla de arriba en código: cada capa responde una pregunta distinta y va en este orden.

```ts
// apps/api/src/app.ts
app.use(requireOrigin);      // ¿quién llama?  origin.md: rechaza al ajeno, también el OPTIONS ajeno
app.use(corsPolicy);         // ¿quién lee?    cors.md: contesta el preflight del frontend legítimo
app.use(securityHeaders);    // headers.md + csp.md
app.use(requireJson);        // ¿qué entra?    content-type.md: 415 si no es application/json
// ...auth (jwt.md, cookies.md), rutas
```

Exenciones, y solo estas: `/health`, webhooks verificados por firma, clientes que no son browser en un router aparte con su propia auth.

## Qué pasa si no

| Atajo | Lo que cuesta |
|---|---|
| `origin: true` "porque en dev el puerto cambia" | cualquier sitio lee la API con la sesión del usuario |
| `Origin` con `endsWith('.ejemplo.com')` | el hermano hostil entra: la premisa entera rota |
| aceptar `text/plain` o `urlencoded` global | CSRF clásico por `<form>`, sin preflight |
| `'unsafe-inline'` en `script-src`, o CSP por `<meta>` | el XSS que entró ejecuta |
| `secure: process.env.NODE_ENV === 'production'` | staging con el modo equivocado manda la sesión por HTTP |
| `process.env` leído donde se usa | un string sin validar que falla en el request que lo tocó, en producción |

`scripts/check.sh` (skill `verify`) atrapa los que se escriben en una línea: `origin: true`, `origin: '*'`, `origin: /`, `type: '*/*'`, `express.urlencoded()` global, `secure: process.env.NODE_ENV`, `process.env` fuera de `config`.

## Tests que tienen que existir

Resumen; el detalle está en cada referencia.

- `Origin` ausente, `null`, hermano, prefijo, sufijo, mayúsculas, con path, con barra final, con puerto distinto: todos `403`. Un test parametrizado con los diez.
- `OPTIONS` del frontend: `204` con `Allow-Origin` literal, `Allow-Credentials: true`, `Max-Age: 600`, `Vary: Origin`. Del ajeno: `403` sin headers `Access-Control-*`.
- `POST` sin `Content-Type`, con `text/plain`, con `charset` raro: `415`. JSON roto: `400 INVALID_BODY`.
- Refresh dos veces con el mismo token fuera de la gracia: `401 SESSION_REVOKED` y la sesión revocada. Access vencido: `401 TOKEN_EXPIRED`.
- Toda respuesta HTML lleva `Content-Security-Policy` con un nonce distinto por request; ningún `'unsafe-inline'` en `script-src`.
- Arrancar sin una variable obligatoria: el proceso sale con código distinto de 0 y nombra la variable. `.env.example` tiene exactamente las claves del schema.

## Con qué, en cada stack

Esta skill no nombra librerías. Cómo se implementa en TypeScript: `../typescript/references/config.md` (schema, congelado, el lint que prohíbe `process.env`) y `../typescript/references/security.md` (XSS, inyección, sanitizado, headers). Una implementación completa de login, sesiones por dispositivo y refresh, lista para adaptar: la skill `auth-jwt-sessions`.

## Qué pedirle a Claude

> "Mostrame el orden de los middlewares en `app.ts` y la config de CORS. `requireOrigin` primero, `origin` literal de config, y el body solo JSON."
