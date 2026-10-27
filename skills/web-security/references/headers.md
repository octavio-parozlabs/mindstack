# Headers de seguridad: los que van con CSP

Decisión cerrada: **toda respuesta, HTML o JSON, lleva el conjunto completo de headers de seguridad de abajo. Se mandan todos, siempre, aunque el browser del usuario no entienda alguno: un header desconocido se ignora, y el que sí entiende es el que lo protege.** CSP (`csp.md`) es la capa principal contra XSS; estos cierran lo que CSP no cubre o lo cubren en browsers que no la soportan.

## No negociable

**Nadie embebe este sitio en un iframe.** Ni otro sitio, ni un subdominio hermano, ni nosotros mismos "para el preview del admin". Se declara dos veces, para que lo entienda todo browser:

```
Content-Security-Policy: ...; frame-ancestors 'none'
X-Frame-Options: DENY
```

`frame-ancestors` es la forma moderna y manda cuando el browser la entiende; `X-Frame-Options` es lo que entienden los que no. Un browser que soporta `frame-ancestors` ignora `X-Frame-Options` cuando están los dos, así que no se contradicen. Sin "cuándo cambia": si un producto nuestro necesita embeber a otro producto nuestro, es un origen exacto en `frame-ancestors` por PR al core, con el por qué, y `X-Frame-Options` desaparece de esa respuesta porque no puede expresar un origen.

## Los headers

| Header | Valor | Qué evita | Funciona desde (aprox.) | Relación con CSP |
|---|---|---|---|---|
| `Content-Security-Policy` | `csp.md` | XSS, clickjacking, exfiltración | Chrome 25, Firefox 23, Safari 7 (2013) | es CSP |
| `X-Frame-Options` | `DENY` | clickjacking en browsers sin `frame-ancestors` | todos, desde IE8 | fallback de `frame-ancestors 'none'` |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` | que un `http://` tipeado o un link viejo llegue al servidor en claro; SSL stripping | Chrome 4, Firefox 4, Safari 7 | independiente. `upgrade-insecure-requests` de CSP cubre los recursos de la página; HSTS cubre la navegación |
| `X-Content-Type-Options` | `nosniff` | que el browser ejecute como script o estilo un archivo cuyo `Content-Type` dice otra cosa; que un upload "imagen" corra como JS | todos | complementa `script-src`: sin `nosniff`, un archivo con nonce pero tipo equivocado podría ejecutar igual |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | que la URL completa, con IDs, tokens de reset o búsquedas, viaje a terceros en el `Referer`. Cross-origin solo va el origen; por HTTP, nada | Chrome 56, Firefox 50, Safari 11.1; es el default del browser desde 2020, se setea igual | independiente |
| `Permissions-Policy` | `camera=(), microphone=(), geolocation=(), payment=(), usb=(), fullscreen=(self)` | que un script inyectado, o un iframe que se coló, prenda cámara, micrófono o pida ubicación | Chrome 88 (antes `Feature-Policy`), Firefox parcial, Safari parcial | CSP decide qué ejecuta; esto decide qué puede hacer lo que ejecuta |
| `Cross-Origin-Opener-Policy` | `same-origin` | que una ventana abierta desde otro sitio, o que nos abrió, conserve una referencia a la nuestra (`window.opener`): tabnabbing, ataques de aislamiento de proceso | Chrome 83, Firefox 79, Safari 15.2 | independiente. Rompe `window.open` + `postMessage` con terceros (algunos flujos de OAuth en popup): ahí `same-origin-allow-popups` |
| `Cross-Origin-Resource-Policy` | `same-origin` | que otro origen cargue nuestras respuestas como `<img>`, `<script>`, `<video>` sin CORS: hotlinking y lectura por side-channel | Chrome 73, Firefox 74, Safari 12 | independiente. Los `fetch` con CORS no pasan por acá: la SPA sigue leyendo la API |
| `Cross-Origin-Embedder-Policy` | **no se manda** | aislaría la página exigiendo CORP a todo lo que embebe; habilita `SharedArrayBuffer` | Chrome 83, Firefox 79, Safari 15.2 | se activa solo si se usa `SharedArrayBuffer`; rompe iframes y recursos de terceros sin CORP |
| `Origin-Agent-Cluster` | `?1` | que un subdominio relaje el same-origin con `document.domain` y comparta JS con el nuestro | Chrome 88, Firefox 106, Safari 16.4; Chrome lo asume por defecto desde 115 | la premisa de `../../architecture/SKILL.md` §8 en el browser: los hermanos no comparten nada |
| `Cache-Control` | `no-store` en el HTML con nonce y en toda respuesta de la API con datos de usuario; `public, max-age=31536000, immutable` en assets con hash | que un proxy, un CDN o el botón "atrás" sirvan una respuesta de otro usuario o un nonce repetido | todos | el nonce de `csp.md` depende de esto |
| `X-XSS-Protection` | `0` | el "auditor" de XSS de browsers viejos, que introducía vulnerabilidades propias y fue retirado | Chrome lo quitó en 78; Safari en 2022 | CSP lo reemplaza. Se manda `0` para apagarlo donde quede |
| `X-Permitted-Cross-Domain-Policies` | `none` | que Flash o lectores de PDF viejos lean respuestas cross-domain por `crossdomain.xml` | legacy | legacy; costo cero |
| `X-DNS-Prefetch-Control` | `off` | que el browser resuelva DNS de links de la página antes de que el usuario los toque: filtra a qué hosts mira | Chrome, Firefox | menor; costo cero |
| `Reporting-Endpoints` | `csp="https://…"` | nada: es donde CSP, COOP y demás mandan los reportes de violación | Chrome 96, Firefox parcial | `report-to` de CSP apunta acá |
| `Server`, `X-Powered-By` | **se quitan** | nombre y versión del servidor y del framework en cada respuesta: es la primera búsqueda de un scanner | | |

Lo que **no**:

- `X-Frame-Options: SAMEORIGIN` "por si algún día". Es `DENY` o un origen exacto en `frame-ancestors`. `SAMEORIGIN` permite que una página nuestra con XSS nos embeba.
- `ALLOW-FROM`: nunca funcionó en Chrome ni Safari. `frame-ancestors` es la única forma de permitir un origen.
- `Strict-Transport-Security` sin `includeSubDomains`. Con la premisa de subdominios hostiles, un `http://blog.ejemplo.com` en claro es un lugar desde donde setear cookies para `ejemplo.com`. Y `preload` solo cuando **todos** los subdominios ya sirven HTTPS: la lista de preload no se deshace.
- `Referrer-Policy: no-referrer` en el frontend. Rompe el chequeo de `Origin` de `origin.md`? No: `Origin` no depende de `Referer`. Pero rompe analytics propios y los `Referer` same-origin que algunos frameworks usan. `strict-origin-when-cross-origin` alcanza.
- Headers por `<meta http-equiv>`. Solo CSP y `Referrer-Policy` tienen forma `<meta>`, y las dos son peores que el header. Siempre header.

## Dónde se mandan

| Respuesta | Quién los pone | Cuáles |
|---|---|---|
| HTML de la SPA (`app.ejemplo.com`) | nginx o Caddy, en el bloque de `index.html` (`csp.md` § Con qué) | todos, con la CSP con nonce |
| assets con hash (`/assets/*.js`, `.css`) | el mismo servidor | `nosniff`, `CORP`, `Cache-Control: immutable`. CSP no aplica a un `.js` |
| API (`api.ejemplo.com`), JSON | `helmet` | todos salvo `Permissions-Policy` (no hay página) y con la CSP mínima `default-src 'none'; frame-ancestors 'none'` |
| errores de la API | el error handler, que pasa por `helmet` igual | los mismos |

```ts
// apps/api/src/security/headers.ts (Express; @fastify/helmet tiene las mismas opciones)
import helmet from 'helmet';

export const securityHeaders = helmet({
  contentSecurityPolicy: { directives: { defaultSrc: ["'none'"], frameAncestors: ["'none'"] } },   // la API no sirve HTML
  frameguard: { action: 'deny' },                                    // X-Frame-Options: DENY
  strictTransportSecurity: { maxAge: 31536000, includeSubDomains: true, preload: false },
  noSniff: true,                                                     // X-Content-Type-Options: nosniff
  referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
  crossOriginOpenerPolicy: { policy: 'same-origin' },
  crossOriginResourcePolicy: { policy: 'same-origin' },
  crossOriginEmbedderPolicy: false,                                  // solo con SharedArrayBuffer
  originAgentCluster: true,                                          // Origin-Agent-Cluster: ?1
  xXssProtection: false,                                             // helmet manda "0" igual: apaga el auditor
  xPermittedCrossDomainPolicies: { permittedPolicies: 'none' },
  xDnsPrefetchControl: { allow: false },
  hidePoweredBy: true,
});
// Cache-Control: no-store va en el handler de cada respuesta con datos de usuario, o en un middleware para todo /api.
// `Server` lo quita el proxy (Caddy no lo manda; nginx: server_tokens off y más_clear_headers si hace falta).
```

```nginx
# apps/web/nginx.conf: lo que se suma al bloque de csp.md. `always`: también en respuestas de error.
add_header X-Frame-Options "DENY" always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "camera=(), microphone=(), geolocation=(), payment=(), usb=(), fullscreen=(self)" always;
add_header Cross-Origin-Opener-Policy "same-origin" always;
add_header Cross-Origin-Resource-Policy "same-origin" always;
add_header Origin-Agent-Cluster "?1" always;
add_header X-Permitted-Cross-Domain-Policies "none" always;
server_tokens off;
```

Ojo con nginx: `add_header` **no se hereda** si el bloque `location` define su propio `add_header`. Los headers van en un `include` que cada `location` carga, o se repiten. Es el error más común: el HTML tiene todos y los assets ninguno.

## Por qué todos, aunque el browser no los entienda

Un header que el browser no conoce no hace nada: ni protege ni rompe. Mandarlo cuesta unos bytes. No mandarlo cuesta la protección en el browser que sí lo entiende. Por eso la regla no mira versiones de browser: se mandan todos y cada browser toma los que puede. La columna "funciona desde" está para saber qué espera cada capa, no para decidir si se manda.

Lo que sí mira versiones: el **fallback**. `X-Frame-Options` existe porque hubo browsers sin `frame-ancestors`; `X-XSS-Protection: 0` existe porque hubo browsers con un auditor roto. Cuando el último browser soportado por el proyecto entienda la forma moderna, el fallback se puede ir; hasta entonces, cuesta cero.

## Qué pasa si no

| Atajo | Lo que cuesta |
|---|---|
| sin `X-Frame-Options`, "CSP ya tiene `frame-ancestors`" | un browser viejo, un webview embebido en una app de terceros, o un bot que renderiza, no lo entiende. Clickjacking ahí |
| `SAMEORIGIN` | nuestra propia página con un XSS nos embebe y superpone un botón |
| HSTS sin `includeSubDomains` | un subdominio en HTTP setea cookies para el dominio padre. Con la premisa de §8, es el hermano hostil escribiendo en nuestra sesión |
| sin `nosniff` | un "avatar" `.png` que es JS, servido con tipo equivocado, se ejecuta como script en un browser que adivina |
| sin `Referrer-Policy` en un browser viejo | `https://app.ejemplo.com/reset?token=abc` viaja entero en el `Referer` a cualquier link externo de esa página |
| sin COOP | un sitio que nos abre con `window.open` conserva `opener` y puede navegarnos a un phishing idéntico |
| sin `Cache-Control: no-store` en la API | un proxy corporativo sirve el `GET /me` de un usuario a otro; el botón "atrás" muestra datos después del logout |
| `X-Powered-By: Express` | el scanner ya sabe qué CVEs probar |
| headers solo en el `location /` de nginx | el HTML va protegido, los `/assets` sin `nosniff` ni `CORP` |

## Qué pedirle a Claude

> "Mostrame los headers de una respuesta de `/` y de una de `/api/me` con `curl -I`. Compará con la tabla de `headers.md` y decime cuál falta y por qué."

## Tests que tienen que existir

- `GET /` del front y `GET /me` de la API devuelven, literal, `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Strict-Transport-Security` con `includeSubDomains`, `Referrer-Policy`, `Cross-Origin-Opener-Policy: same-origin`, `Cross-Origin-Resource-Policy: same-origin`, `Origin-Agent-Cluster: ?1`. Y **no** devuelven `X-Powered-By` ni `Server` con versión.
- `GET /assets/<hash>.js` del front devuelve `nosniff`, `Cross-Origin-Resource-Policy` y `Cache-Control: immutable`. Es el test que atrapa el `add_header` no heredado.
- `GET /me` de la API devuelve `Cache-Control: no-store`.
- Un `404` de la API lleva los mismos headers que un `200`.
- Playwright: una página en otro origen con `<iframe src="https://app.ejemplo.com">`; el iframe queda vacío y hay un evento `securitypolicyviolation` con `violatedDirective: frame-ancestors`. Es el test de "nadie nos embebe".

## Fuentes

- [MDN, HTTP headers: security](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers#security): cada header con su tabla de compatibilidad.
- [MDN, `X-Frame-Options`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/X-Frame-Options) y [`frame-ancestors`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy/frame-ancestors): precedencia cuando están los dos.
- [OWASP, HTTP Headers Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/HTTP_Headers_Cheat_Sheet.html): la lista de referencia y los valores recomendados.
- [web.dev, Security headers quick reference](https://web.dev/articles/security-headers): COOP, CORP, COEP explicados con casos.
- [helmet](https://helmetjs.github.io/): qué header pone cada opción y sus defaults.
- [hstspreload.org](https://hstspreload.org/): requisitos de `preload` y por qué no se deshace.
- [nginx, `add_header` y herencia](https://nginx.org/en/docs/http/ngx_http_headers_module.html#add_header): "These directives are inherited from the previous configuration level if and only if there are no add_header directives defined on the current level".
