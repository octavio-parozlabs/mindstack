# Seguridad

Lo que se hace siempre, en los dos lados. No es una lista de "buenas prácticas": es lo que Claude tiene que aplicar sin que se lo pidan y señalar cuando ve que falta.

## Frontend

| Riesgo | Mitigación | Nunca |
|---|---|---|
| XSS por HTML de datos | `DOMPurify.sanitize(html)` antes de `dangerouslySetInnerHTML`. Mejor: texto plano en JSX, que escapa solo | `dangerouslySetInnerHTML={{ __html: data }}` sin sanitizar, `innerHTML =` |
| XSS que igual entró | CSP en todo HTML con nonce por request: `default-src 'none'`, `script-src 'nonce-…' 'strict-dynamic'`, `style-src` sin `'unsafe-inline'` (`../../web-security/references/csp.md`) | sin CSP "porque las cookies son httpOnly"; `'self'` o allowlist de hosts para scripts; `'unsafe-inline'` en estilos |
| XSS por URLs | validar `href` y `src` que vienen de datos: solo `http(s):` y relativas | `javascript:` en un `href` armado con datos |
| robo de token | sesión en cookie `httpOnly` + `Secure` + `SameSite`. `withCredentials: true` en axios. Flujo y atributos: `../../web-security/references/jwt.md` y `../../web-security/references/cookies.md` | tokens en `localStorage` o `sessionStorage` |
| secretos en el bundle | solo URLs y flags públicos en `VITE_*` / `NEXT_PUBLIC_*` | API keys, secrets, credenciales de terceros en env del front |
| dependencias comprometidas | lockfile commiteado, `npm ci`, `npm audit` en CI | `npm install` en CI, ignorar `high`/`critical` |
| CSRF del lado del cliente | la URL, el `hash` y los query params nunca arman la URL ni el body de un request a la API: los endpoints son constantes en `api/`, los parámetros se validan con el schema antes de mandar. El token CSRF se adjunta solo en las rutas multipart, nunca como default global de axios | `http.post(location.hash.slice(1))`, `axios.defaults.headers['X-CSRF-Token'] = …` |

## Backend

| Riesgo | Mitigación | Nunca |
|---|---|---|
| inyección (SQL, comando, path) | queries parametrizadas o el ORM; `path.join` + chequeo de que el resultado está dentro de la carpeta permitida; nunca armar un comando con input | template strings en SQL, `exec(\`cmd ${input}\`)`, `fs.readFile(userPath)` |
| input malicioso | validar **todo** con el schema del contrato al entrar (`../../node-api/references/backend.md`). Lo que no está en el schema, no entra | confiar en que "el front ya validó" |
| auth y autorización | auth en un middleware, autorización en el service (¿este usuario puede tocar **este** recurso?). Tokens según `../../web-security/references/jwt.md` | chequear solo "está logueado" y devolver cualquier `orderId` que pidan |
| body con `Content-Type` ajeno | parsear solo `application/json` por defecto; `415` sin header o con otro; `urlencoded`/`multipart` solo en la ruta que los pide, con `requireCsrf` (`../../web-security/references/content-type.md`) | `express.json({ type: '*/*' })`, `express.urlencoded()` global, `JSON.parse(req.body)` a mano, aceptar `text/plain` |
| CSRF y subdominios hermanos | `SameSite=Strict` + `Origin` exacto exigido en **todo** request, ausente y `null` rechazados (`../../web-security/references/origin.md`) | `SameSite=None`, `origin: true` en CORS con credenciales, validar solo en `POST`, caer a `Referer` |
| fuga de datos | DTO explícito por entidad: `toOrderDto()`. Nunca devolver la fila de la DB | `res.json(user)` con `passwordHash` adentro |
| secretos | env validado en `config.ts`; `.env` ignorado; `.env.example` sin valores. `.gitignore` y scanner en CI: `../../workflow/references/git.md` | secretos en el código, en logs, en mensajes de error. Un secreto commiteado se rota, no se borra |
| errores que cuentan de más | el error handler devuelve `{ code, message }` genérico para `INTERNAL`; el stack va al log, no al cliente | `res.status(500).json({ error: err.stack })` |
| rate limit y tamaño | límite de requests por IP/usuario en endpoints de auth y escritura; límite de tamaño de body | un `POST /login` sin límite |
| CORS | un literal de config, `credentials: true`, `allowedHeaders` explícitos, `maxAge`, después de `requireOrigin` (`../../web-security/references/cors.md`) | `origin: true`, `'*'`, regex, función; `cors()` antes de `requireOrigin` |
| clickjacking y headers | `helmet` con la config de `../../web-security/references/headers.md`: `frame-ancestors 'none'` + `X-Frame-Options: DENY`, HSTS con `includeSubDomains`, `nosniff`, `Referrer-Policy`, COOP, CORP, `Origin-Agent-Cluster`, sin `X-Powered-By`; en el host del front, el bloque nginx del mismo archivo en **cada** `location` | servir HTML sin headers; `X-Frame-Options: SAMEORIGIN`; `add_header` solo en `location /` |
| logs | nunca loguear body completo de requests con datos sensibles, tokens ni passwords | `logger.info({ body: req.body })` en `/login` |
| uploads | solo en su ruta, `multipart` con `requireCsrf` antes de leer el archivo y `limits.fileSize` (`../../web-security/references/content-type.md`). Tipo por contenido (magic bytes, `file-type`), no por extensión ni por el `Content-Type` del cliente; allowlist de tipos. Nombre generado (`randomUUID()` + extensión del tipo detectado), nunca el del cliente. Guardado fuera del webroot o en object storage; servido con `nosniff` y `Content-Disposition: attachment`, nunca como script (`../../web-security/references/csp.md`, `headers.md`) | `upload.single('file')` global, `path.join(dir, file.originalname)`, servir `/uploads` como estático sin headers |
| SSRF: la API pide una URL que vino del usuario (webhook, avatar por URL, import) | allowlist de hosts exactos en config; si tiene que ser abierto, resolver el host y rechazar rangos privados y loopback (`10/8`, `172.16/12`, `192.168/16`, `127/8`, `169.254/16`, `::1`, `fc00::/7`), solo `http(s):`, sin seguir redirects (`redirect: 'manual'`), `AbortSignal.timeout` | `fetch(req.body.url)`, un `GET /proxy?url=` |
| comparación de secretos y tokens | `crypto.timingSafeEqual` sobre buffers del mismo largo, para tokens CSRF, API keys, firmas de webhook | `token === expected` |
| ReDoS | sin regex construidas con input del usuario; las fijas sin cuantificadores anidados (`(a+)+`); validar largo antes de matchear | `new RegExp(req.query.q)` |

## Qué pedirle a Claude

> "Antes de dar por terminado, revisá este diff contra `seguridad.md` y decime qué falta."

Y antes de un PR que toque auth, uploads, queries o cualquier endpoint nuevo: `/security-review`.
