# Detección por ecosistema

Cómo **reconocer** cada cosa en el código. Las skills de stack (`typescript`, `node-api`, `react`, …) dicen cómo escribirla; esta dice cómo encontrarla en un repo ajeno. Los patrones son puntos de partida para `grep`: un match se lee en contexto antes de anotarlo, y una búsqueda sin matches es la evidencia de un "no" solo si cubre el ecosistema detectado.

## Índice

- [Manifiestos y lockfiles](#manifiestos-y-lockfiles)
- [Rutas y auth por framework](#rutas-y-auth-por-framework)
- [Parsers de body](#parsers-de-body)
- [SQL y NoSQL](#sql-y-nosql)
- [Superficies por categoría](#superficies-por-categoría)
- [Estado y transiciones](#estado-y-transiciones)
- [Políticas e infra](#políticas-e-infra)

## Manifiestos y lockfiles

| Ecosistema | Manifiesto | Lockfile (versión resuelta) | Tipo de `purl` |
|---|---|---|---|
| Node | `package.json` | `package-lock.json`, `npm-shrinkwrap.json`, `pnpm-lock.yaml`, `yarn.lock`, `bun.lockb` | `pkg:npm/<nombre>@<versión>` (scope: `pkg:npm/%40scope/nombre@v`) |
| Python | `pyproject.toml`, `requirements*.txt`, `setup.py`, `Pipfile` | `poetry.lock`, `Pipfile.lock`, `uv.lock`, `requirements.txt` con `==` | `pkg:pypi/<nombre>@<versión>` |
| Java/Kotlin | `pom.xml`, `build.gradle(.kts)` | `gradle.lockfile`; en Maven, la versión del `pom` si es fija | `pkg:maven/<grupo>/<artefacto>@<versión>` |
| PHP | `composer.json` | `composer.lock` | `pkg:composer/<vendor>/<nombre>@<versión>` |
| Ruby | `Gemfile` | `Gemfile.lock` | `pkg:gem/<nombre>@<versión>` |
| Go | `go.mod` | `go.sum` (las versiones de `go.mod` ya son exactas) | `pkg:golang/<módulo>@<versión>` |
| .NET | `*.csproj`, `Directory.Packages.props` | `packages.lock.json` | `pkg:nuget/<nombre>@<versión>` |
| Rust | `Cargo.toml` | `Cargo.lock` | `pkg:cargo/<nombre>@<versión>` |
| Docker | `Dockerfile`, `docker-compose*.yml` | el tag o digest del `FROM`/`image:` | `pkg:docker/<imagen>@<tag>` |
| GitHub Actions | `.github/workflows/*.yml` | el `@ref` de cada `uses:` | `pkg:githubactions/<owner>/<repo>@<ref>` |

Runtimes: `.nvmrc`, `.node-version`, `engines` en `package.json`, `.python-version`, `.tool-versions`, `go` en `go.mod`, `java.version` en `pom.xml`, `FROM` del `Dockerfile`.

## Rutas y auth por framework

| Framework | Cómo declara rutas | Dónde está la auth | Exenciones |
|---|---|---|---|
| Express / Koa / Fastify | `app.get/post/…`, `router.<método>`, `fastify.route`, `app.use('/x', router)` | middleware en `app.use` o por ruta | orden de `app.use`: lo registrado antes del middleware de auth queda afuera |
| NestJS | `@Controller` + `@Get/@Post/…`; `RouterModule` | `@UseGuards`, `APP_GUARD` global | `@Public()` o metadata propia leída por el guard |
| Next.js | `app/**/route.ts`, `pages/api/**`, server actions (`'use server'`), `middleware.ts` | `middleware.ts` con `matcher`, chequeo en cada handler o action | rutas fuera del `matcher` |
| Nuxt / SvelteKit / Remix | `server/api/**`; `+server.ts` y `actions` en `+page.server.ts`; `loader`/`action` | `server/middleware`, `hooks.server.ts`, chequeo en el loader | lo que el hook no cubre |
| Django / DRF | `urls.py` con `path`/`include`, `routers.register` | `@login_required`, `permission_classes`, `DEFAULT_PERMISSION_CLASSES` | `AllowAny`, `@csrf_exempt` |
| Flask / FastAPI | `@app.route`, `Blueprint`; `@app.get`, `APIRouter` | decoradores, `before_request`; `Depends(...)` | rutas sin el decorador o la dependencia |
| Spring | `@RequestMapping`, `@GetMapping`, … | `SecurityFilterChain`, `@PreAuthorize`, `@Secured` | `permitAll()`, `web.ignoring()`; `useSuffixPatternMatch` y matchers por path |
| Rails | `config/routes.rb` (`resources`, `get`, `namespace`) | `before_action :authenticate_user!`, Pundit/CanCan | `skip_before_action` |
| Laravel | `routes/web.php`, `routes/api.php` | middleware `auth`, `Gate`, policies | rutas fuera del grupo `auth` |
| ASP.NET | `[Route]`, `[HttpGet]`, minimal APIs `app.MapGet` | `[Authorize]`, políticas | `[AllowAnonymous]` |
| Go (net/http, chi, gin, echo) | `HandleFunc`, `r.Get`, `router.GET`, `e.GET` | middleware en el router o el grupo | rutas registradas fuera del grupo |
| GraphQL | schema SDL o code-first; resolvers | directivas (`@auth`), guards por resolver, contexto | resolvers sin chequeo |
| WebSockets | `socket.io` `io.on('connection')`, `ws` `on('upgrade')`, `@WebSocketGateway`, Django Channels | en el handshake o por evento | eventos sin chequeo |

Autorización por recurso: buscar, en el handler o el service, una comparación del dueño del recurso contra el usuario de la sesión (`ownerId === user.id`, `where: { id, userId }`, policies). Si el recurso se busca solo por id, es `ninguna detectada`.

## Parsers de body

| Framework | Qué buscar | Laxo si… |
|---|---|---|
| Express | `express.json()`, `express.urlencoded()`, `express.text()`, `bodyParser.*`, `multer` | `type: '*/*'` o una función que acepta todo; `urlencoded` global |
| Fastify | `addContentTypeParser` | parser para `*` |
| NestJS | el de Express o Fastify debajo, `rawBody` | igual |
| Django | `request.POST` (form), `request.body` + `json.loads` | `json.loads(request.body)` sin mirar `Content-Type` |
| Flask / FastAPI | `request.get_json(force=True)`, `request.form` | `force=True` |
| Spring | `@RequestBody` + `consumes` | sin `consumes` acepta lo que el converter entienda |
| Rails | `params` mezcla query, form y JSON | siempre: se mira si las acciones con estado verifican CSRF |

## SQL y NoSQL

| ORM / driver | Seguro (crudo parametrizado) | Inseguro (interpolado) |
|---|---|---|
| Prisma | `$queryRaw` y `$executeRaw` con tagged template, `Prisma.sql` | `$queryRawUnsafe`, `$executeRawUnsafe`, `Prisma.raw` con input |
| TypeORM | `query(sql, [params])`, `where('x = :x', { x })` | `query(\`… ${x}\`)`, `where(\`x = ${x}\`)`, `orderBy(input)` |
| Sequelize | `query(sql, { replacements \| bind })` | `query('…' + x)`, `literal(input)` |
| Knex | `raw('? ', [x])`, `whereRaw('x = ?', [x])` | `raw(\`${x}\`)`, `whereRaw(\`x = ${x}\`)` |
| Drizzle | `` sql`… ${x}` `` | `sql.raw(input)` |
| node-postgres / mysql2 | `query(sql, [params])`, `execute` | `query(\`… ${x}\`)` |
| SQLAlchemy | `text('… :x')` con `params`, ORM | `text(f'… {x}')`, `execute(f'…')`, `%` o `.format` |
| Django | ORM, `raw(sql, [params])`, `cursor.execute(sql, [params])` | `raw(f'…')`, `extra(where=[…input…])`, `RawSQL` con input |
| JDBC / JPA | `PreparedStatement` con `?`, `:param` en JPQL | `Statement` con `+`, `createQuery("…" + x)`, `createNativeQuery` con concatenación |
| MyBatis | `#{x}` | `${x}` |
| ActiveRecord | `where('x = ?', x)`, `where(x: x)` | `where("x = #{x}")`, `order(params[:x])`, `find_by_sql` interpolado |
| Laravel | Eloquent, `DB::select('?', [x])` | `DB::raw($x)`, `whereRaw("x = $x")`, `orderByRaw($x)` |
| Go `database/sql` | `Query(sql, args…)` con `$1` o `?` | `fmt.Sprintf` en la query |
| Mongo (Mongoose, driver) | filtros con valores casteados o validados por schema | `find({ x: req.body.x })` sin castear (operator injection), `$where`, `mapReduce`, `$function`, `JSON.parse` del input al filtro |

`ORDER BY`, nombres de columna y de tabla no se parametrizan: un `orderBy(input)` es interpolado aunque el ORM sea seguro.

## Superficies por categoría

| Categoría | Node / TS | Python | Java | PHP | Ruby | Go | .NET |
|---|---|---|---|---|---|---|---|
| Sinks de HTML (server) | `res.send` con HTML armado, `<%-` (EJS), `{{{ }}}` (Handlebars), `!=` (Pug) | `\|safe`, `Markup(`, `mark_safe`, `autoescape false`, `render_template_string` | `th:utext` (Thymeleaf), `?no_esc` (FreeMarker) | `echo` sin `htmlspecialchars`, `{!! !!}` (Blade), `\|raw` (Twig) | `html_safe`, `raw`, `<%==` | `template.HTML(` | `Html.Raw` |
| Sinks de HTML (front) | `dangerouslySetInnerHTML`, `v-html`, `[innerHTML]`, `bypassSecurityTrust*`, `{@html}`, `innerHTML`, `outerHTML`, `insertAdjacentHTML`, `document.write`, `$(…).html(`, `$(input)` | | | | | | |
| Sinks del DOM | `eval(`, `new Function(`, `setTimeout('`, `location =`, `location.href =`, `window.open(`, `document.cookie =`, `addEventListener('message'`, `postMessage(`, `\|\| {}` sobre `window.`, `ng-app` | | | | | | |
| Procesos | `child_process` (`exec`, `execSync`, `spawn` con `shell`, `fork`), `execa`, `shelljs` | `subprocess` con `shell=True`, `os.system`, `os.popen` | `Runtime.exec`, `ProcessBuilder` | `exec`, `system`, `shell_exec`, `passthru`, `popen`, backticks | `system`, `exec`, `%x`, backticks, `Open3` | `exec.Command` con `sh -c` | `Process.Start` |
| Disco | `fs.readFile/writeFile/createReadStream`, `res.sendFile`, `res.download`, `path.join` con input, `require(` dinámico | `open(`, `send_file`, `send_from_directory`, `os.path.join` con input | `new File(`, `Files.`, `FileInputStream` | `file_get_contents`, `fopen`, `include`/`require` con variable, `readfile` | `File.read`, `send_file`, `File.open` | `os.Open`, `http.ServeFile`, `filepath.Join` con input | `File.`, `PhysicalFile` |
| Uploads | `multer`, `busboy`, `formidable`, `express-fileupload` | `request.files`, `UploadFile`, `FileField` | `MultipartFile` | `$_FILES`, `move_uploaded_file` | `ActiveStorage`, `CarrierWave` | `FormFile` | `IFormFile` |
| Procesado de archivos | `sharp`, `jimp`, `gm`/`imagemagick`, `adm-zip`, `unzipper`, `pdf-lib`, `libreoffice-convert` | `PIL`, `Wand`, `zipfile`, `tarfile` | `ImageIO`, `ZipInputStream` | `Imagick`, `ZipArchive` | `MiniMagick`, `rubyzip` | `archive/zip` | `ZipArchive` |
| Requests salientes | `fetch`, `axios`, `got`, `node-fetch`, `undici`, `request`, `http.get` | `requests`, `httpx`, `urllib`, `aiohttp` | `HttpClient`, `RestTemplate`, `WebClient`, `URL.openConnection` | `curl_*`, `file_get_contents('http`, Guzzle | `Net::HTTP`, `HTTParty`, `open-uri` | `http.Get`, `http.NewRequest` | `HttpClient` |
| Redirects | `res.redirect(`, `Location` | `redirect(`, `HttpResponseRedirect` | `sendRedirect`, `redirect:` | `header('Location`, `redirect()` | `redirect_to` | `http.Redirect` | `Redirect(` |
| Mails | `nodemailer`, `@sendgrid/mail`, `resend`, SES | `send_mail`, `smtplib` | `JavaMailSender` | `mail(`, `PHPMailer`, `Mail::` | `ActionMailer` | `net/smtp` | `SmtpClient` |
| XML | `xml2js`, `libxmljs` (`noent`), `fast-xml-parser`, `xmldom`, `sax`, `saml2-js`, `passport-saml` | `lxml` (`resolve_entities`), `xml.etree`, `minidom`, `defusedxml` (seguro) | `DocumentBuilderFactory`, `SAXParserFactory`, `XMLInputFactory` sin deshabilitar DTD | `simplexml_load_string`, `DOMDocument` con `LIBXML_NOENT` | `Nokogiri` con `NOENT` | `encoding/xml` | `XmlDocument`, `XmlReader` con `DtdProcessing.Parse` |
| Deserialización | `node-serialize`, `serialize-javascript` con `eval`, `funcster`, `js-yaml` `load` en v3 | `pickle`, `yaml.load` sin `SafeLoader`, `marshal`, `shelve`, `jsonpickle` | `ObjectInputStream`, `readObject`, `XMLDecoder`, `XStream`, Jackson con default typing | `unserialize`, `phar://` | `Marshal.load`, `YAML.load` | `encoding/gob` | `BinaryFormatter`, `NetDataContractSerializer`, `TypeNameHandling` |
| Templates (SSTI) | `ejs`, `pug`, `handlebars`, `nunjucks`, `lodash.template`, compilar desde string | `jinja2` (`Template(input)`, `render_template_string`), `mako`, `tornado` | FreeMarker, Velocity, Thymeleaf con expresiones | Twig, Smarty, Blade | ERB, `ERB.new(input)`, Liquid | `text/template` | Razor |
| Headless y conversores | `puppeteer`, `playwright`, `wkhtmltopdf`, `html-pdf` | `pyppeteer`, `weasyprint`, `pdfkit` | | `dompdf`, `wkhtmltopdf` | `grover`, `wicked_pdf` | `chromedp` | |
| Merge profundo | `_.merge`, `_.mergeWith`, `_.set`, `_.defaultsDeep`, `deepmerge`, `merge-deep`, `$.extend(true`, `Object.assign` recursivo propio, `obj[a][b] =`, `qs` con `allowPrototypes` | | | | | | |
| Mass assignment | `Object.assign(model, req.body)`, `{ ...req.body }` a `create`/`update`, `Model.create(req.body)` | `Model(**data)`, `serializer` con `fields = '__all__'` | `@ModelAttribute`, binding sin `@InitBinder` | `$fillable`/`$guarded = []`, `fill($request->all())` | `permit!`, `update(params[:x])` | decode JSON al struct del modelo | binding al modelo de EF |
| JWT | `jsonwebtoken` (`verify` vs `decode`, `algorithms`), `jose`, `express-jwt`, `passport-jwt` | `PyJWT` (`decode` con `verify_signature: False`, `algorithms`) | `jjwt`, `nimbus-jose-jwt`, `java-jwt` | `firebase/php-jwt`, `lcobucci/jwt` | `ruby-jwt` | `golang-jwt` | `System.IdentityModel.Tokens.Jwt` |
| GraphQL | `apollo-server`, `graphql-yoga`, `mercurius`, `@nestjs/graphql`, `introspection:` | `graphene`, `strawberry`, `ariadne` | `graphql-java`, Spring GraphQL | `webonyx/graphql-php`, Lighthouse | `graphql-ruby` | `gqlgen` | Hot Chocolate |
| WebSockets | `socket.io`, `ws`, `@WebSocketGateway`, `uWebSockets` | `channels`, `websockets`, `flask-socketio` | `@ServerEndpoint`, STOMP | Ratchet, Laravel Reverb | ActionCable | `gorilla/websocket` | SignalR |
| Cripto | `crypto.createHash('md5'\|'sha1')`, `createCipheriv` con IV fijo, `aes-*-ecb`, `Math.random`, `===` sobre tokens (vs `timingSafeEqual`) | `hashlib.md5`, `random.` (vs `secrets`), `==` sobre tokens (vs `hmac.compare_digest`) | `MessageDigest.getInstance("MD5")`, `new Random()`, `ECB` | `md5(`, `sha1(`, `rand(`, `mt_rand(`, `==` (vs `hash_equals`) | `Digest::MD5`, `rand` | `math/rand`, `md5.` | `MD5.Create`, `new Random()` |
| Regex con input | `new RegExp(input)` | `re.compile(input)` | `Pattern.compile(input)` | `preg_match($input` | `Regexp.new(input)` | `regexp.MustCompile(input)` | `new Regex(input)` |
| Exports | `csv-stringify`, `json2csv`, `exceljs`, `xlsx` | `csv.writer`, `openpyxl`, `pandas.to_csv` | Apache POI, OpenCSV | `fputcsv`, PhpSpreadsheet | `CSV.generate` | `encoding/csv` | `CsvHelper` |
| Logs | `console.log(req`, `logger.*(req.headers`, tokens o `password` en logs | `logging.*(request` | `log.*(request` | `error_log(` | `Rails.logger` con params | `log.Printf` | `ILogger` con request |
| LLM | `openai`, `@anthropic-ai/sdk`, `langchain`, `ai` (Vercel), tools/functions | `openai`, `anthropic`, `langchain`, `llama_index` | Spring AI, LangChain4j | `openai-php` | `ruby-openai` | `go-openai` | Semantic Kernel |

## Estado y transiciones

| Qué | Cómo se ve |
|---|---|
| Enums de estado | Prisma `enum`, TypeORM `@Column({ type: 'enum' })`, Django `choices`, `models.TextChoices`, Rails `enum status:`, JPA `@Enumerated` |
| Máquinas declaradas | XState, `javascript-state-machine`, `aasm`, `statesman`, `django-fsm`, Spring Statemachine |
| Escrituras del campo | `status =`, `{ status: … }` en `update`/`save`, `update_column(:status`, `UPDATE … SET status` |
| Guardias | `if (x.status !== …) throw`, `where: { id, status: … }`, `@transition(source=…)` |
| Métodos seguros que escriben | handler de `get`/`@Get`/`@GetMapping`/`def get`/`methods=['GET']` que llama `create`/`update`/`save`/`delete`/`INSERT`/`UPDATE`, `sendMail`, `queue.add`, `req.session.… =`; rutas para cualquier método: `app.all`, `router.use(path, handler)`, `@RequestMapping` sin `method`, vista de Django sin `@require_POST`/`@require_http_methods`, Rails `match … via: :all`, Flask `methods` con GET y POST que lee `request.values` |
| Atomicidad | `$transaction`, `transaction.atomic`, `@Transactional`, `SELECT … FOR UPDATE`, update condicional con `WHERE` sobre el estado |

## Políticas e infra

| Qué | Dónde buscar |
|---|---|
| CORS | `cors(`, `enableCors`, `CORS_ALLOWED_ORIGINS`, `@CrossOrigin`, `add_header Access-Control-Allow-Origin`, `headers` en `next.config.*` o `vercel.json` |
| CSP y headers | `helmet(`, `Content-Security-Policy`, `add_header` en nginx, `header` en Caddy, `headers()` en `next.config.*`, `_headers` (Netlify), `<meta http-equiv` |
| Framing | `frameguard`, `X-Frame-Options`, `frame-ancestors`, `if (top !== self)` |
| Cookies | `res.cookie(`, `cookie-session`, `express-session`, `SESSION_COOKIE_*`, `set_cookie(`, `ResponseCookie` |
| Rate limit | `express-rate-limit`, `@nestjs/throttler`, `rate-limiter-flexible`, `django-ratelimit`, `slowapi`, `Rack::Attack`, `limit_req` en nginx |
| `trust proxy` | `app.set('trust proxy'`, `trustProxy`, `ProxyFix`, `USE_X_FORWARDED_HOST`, `server.forward-headers-strategy`, `ForwardedHeaders` |
| Proxy y cache | `nginx.conf`, `proxy_pass`, `proxy_cache`, `Caddyfile`, `traefik.yml`, `vercel.json`, `netlify.toml`, `cloudflare`, `varnish`, ingress de k8s |
| CI | `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`, `.circleci/` |
| Contenedores e IaC | `Dockerfile`, `docker-compose*.yml`, `*.tf`, `k8s/`, `helm/`, `serverless.yml`, `cdk` |
