# Docker

Decisión cerrada: **todo proyecto corre entero con `docker compose up`, y la observabilidad viene en el mismo archivo bajo un profile.** Entrar a un proyecto es clonar, copiar `.env.example` y levantar. Nada de "instalá Postgres, después Redis, después pedile a alguien el dashboard".

| Decisión | Valor | Por qué | Cuándo cambia |
|---|---|---|---|
| Un `Dockerfile` por app, multi-stage | build con dependencias de desarrollo, imagen final sin ellas y sin root | la imagen que corre en producción es la misma que buildea el CI. Sin devDeps pesa un tercio y expone menos | nunca |
| Imagen base | un stage `base` por imagen externa; los demás `FROM base`. Nunca en un `ARG`, nunca repetida | un solo lugar para el pin, y los bots solo leen `FROM` literal: Dependabot no expande `ARG` | nunca. `docker-base-stage.md` |
| Versión de la imagen | tag exacto + `@sha256:<digest>` | un tag es un puntero que se mueve, incluso uno exacto; el digest es el contenido. Es el criterio de OpenSSF Scorecard | nunca. `docker-pin-digest.md` |
| Quién mueve el pin | Dependabot: `docker`, `github-actions` y el ecosistema del lenguaje (`../../workflow/examples/github/dependabot.yml`) | un pin sin bot se congela y se vuelve vulnerable en silencio. Pin y bot van juntos o no va ninguno | Renovate si hace falta `ARG` o agrupar PRs. `docker-updates-bot.md` |
| Runtime que corre | CI compara `--version` del runner y de la imagen contra el archivo de versión; Trivy sobre la imagen, `HIGH,CRITICAL` con fix rechaza el PR | el setup y Docker usan cache; "pasó CI" sin el check no dice qué versión corrió. Dependabot no sabe de CVEs de imágenes: el scanner sí | nunca. `docker-runtime-verified.md` |
| Un `docker-compose.yml` en la raíz | DB + apps en el profile default; observabilidad en `observability` | un solo archivo para levantar todo, y lo pesado no arranca si no se pide | si la observabilidad va a un host aparte, se mueve a su propio compose |
| Día a día | `docker compose up db` + el dev server del stack en el host | hot reload del host es más rápido que montar volúmenes en el contenedor | nunca para dev; CI y deploy usan la imagen |
| Varios entornos a la vez | puertos y nombre de DB por env, nunca fijos. Un `.env` por worktree | dos worktrees con `3000` fijo no pueden correr juntos. Con env, Compose ya aísla el resto solo (proyecto = carpeta) | nunca |
| Logs | Pino en JSON a stdout. Nunca a archivo | Docker ya captura stdout; Promtail lo lee del socket. Un archivo de log es un volumen más y un rotado que alguien olvida | nunca |
| Logs: dónde se consultan | Loki vía Grafana, `{container="api"} \| json` | buscar por `requestId` a través de api y web en una query | nunca |
| Métricas de host y contenedores | node-exporter + cAdvisor → Prometheus | CPU, memoria, red, disco por contenedor sin tocar la app | nunca |
| Métricas de aplicación | ninguna por defecto. Rate, latencia y errores HTTP se deducen de los logs en Loki | 10 líneas de `prom-client` son fáciles; mantener dashboards de negocio no. Se agrega cuando hay una pregunta que los logs no contestan | cuando "¿qué endpoint está lento?" tarda más de un minuto en responderse con Loki |
| Tracing | no | un solo backend no tiene saltos que trazar | cuando hay más de un servicio en una request |
| `restart` | `unless-stopped` en todo lo que sirve; `"no"` en lo que corre una vez (migraciones, setup) | un reinicio del host levanta todo solo. Un job con `unless-stopped` se reejecuta en loop | nunca |
| Logs de Docker con tope | `logging: json-file` con `max-size` y `max-file` en **cada** servicio, por ancla YAML | sin tope, el log de un contenedor llena el disco del servidor en una semana de errores. Promtail ya los copió; el archivo local es un buffer, no un archivo | nunca. Los tamaños sí: 5m para jobs, 50m para front, 300m para la API |
| Migraciones | un servicio `migrator` que corre una vez; la API depende de él con `service_completed_successfully` | la API nunca arranca contra un esquema viejo, y la migración no corre N veces si hay N réplicas | nunca |
| Imágenes por target | un `Dockerfile` multi-stage con un `target` por servicio (`api`, `migrator`, `web`); `image: ${X_IMAGE:-x:local}` | CI construye y etiqueta la misma imagen que corre local. Dos servicios con la misma imagen la comparten, no la buildean dos veces en paralelo | nunca |
| Variables públicas del front | `build.args`, no `environment` | lo `PUBLIC_*` se hornea en el bundle al buildear. En runtime ya es tarde | nunca |
| Mismo `.env` para host y compose | `env_file: .env` y en `environment:` se pisan solo las URLs internas (`DATABASE_URL` con host `db`) | el `.env` sirve para el dev server en el host y para el contenedor. Un solo archivo, dos contextos | nunca |
| Puertos de infra | `127.0.0.1:${PORT}:5432`: DB, Redis y bucket publicados solo en loopback. Solo api, web y proxy se publican a todas las interfaces | en una VPS, `5432:5432` es Postgres abierto a internet con la password de `.env`. En loopback lo ves desde `psql` local y nadie más | nunca |
| Credenciales de infra | de `.env`, con default de dev: `${DB_PASSWORD:-dev}` | el mismo compose levanta dev sin configurar nada y prod con el `.env` real. Sin default, dev pide un `.env` para empezar; sin env, prod corre con `developer` | nunca |
| Redis y bucket | profiles `redis` y `bucket`, opt-in. Redis con `--appendonly yes` y `--requirepass` | no todo proyecto los usa; el que los usa los enciende con un flag. Redis sin password en una red compartida es un cache que cualquiera escribe | nunca |
| Bucket aislado | el object storage vive solo en `bucket-net`; un Caddy puente es el único en las dos redes y expone **solo** el puerto S3 con el alias `bucket`. Un `setup` que corre una vez crea el bucket | el filer y el master del storage no tienen auth. Si la api puede resolverlos, un SSRF en la api es acceso total al storage. Con el puente, la api solo llega al S3, que autentica con SigV4 | cuando el storage es un servicio externo (S3 real): el profile sobra |
| Retención | Prometheus `--storage.tsdb.retention.time=15d`; Loki `retention_period: 15d` con compactor; Promtail con `positions` en volumen | sin retención, los dos crecen hasta llenar el disco, igual que los logs de Docker sin `max-size`. Las posiciones persistidas evitan reenviar todo el historial en cada reinicio | el número, según disco. 15 días cubre un incidente del viernes mirado el lunes siguiente |
| Red de observabilidad | `observability-net` propia; solo Grafana se publica al host, y solo el proxy entra a las dos redes | Loki, Prometheus y los exporters no tienen auth. Si la api está en su red, un SSRF lee métricas y logs de todo. Promtail no necesita la red de la app: lee del socket | nunca |
| Grafana | admin de `.env` con default `admin/admin`, `GF_USERS_ALLOW_SIGN_UP=false`, datasources y dashboards provisionados desde archivos | sin provisioning, el dashboard vive en el volumen de una máquina. Con sign-up abierto, cualquiera con el puerto se hace cuenta | nunca |
| Un solo archivo de compose | profiles, no `-f` con archivos sueltos. Si se parte, `include:` desde el raíz | `docker compose -f observability.yml up` crea un **segundo proyecto**: otra red, `container_name` que chocan, `down` que no ve al otro. `include:` lo mete en el mismo proyecto | cuando el archivo pasa de 300 líneas: `include:`, nunca `-f` |
| Proxy perimetral | profile `proxy`: Caddy con TLS automático, un `reverse_proxy` por dominio | una VPS con dominio real no necesita nginx a mano ni certbot. Opt-in: el dev local no lo toca | cuando hay un balanceador o CDN adelante, el TLS termina ahí y el profile sobra |

## Con qué

```
repo/
├── docker-compose.yml
├── .dockerignore                 dependencias, build, coverage, .env, .git
├── apps/api/Dockerfile
├── apps/web/Dockerfile
└── observability/
    ├── loki.yml                  retención 15d
    ├── promtail.yml
    ├── prometheus.yml
    ├── Caddyfile                 solo con --profile proxy
    └── grafana/
        ├── provisioning/datasources/datasources.yml
        └── dashboards/           JSON exportados; se provisionan solos
```

El `Dockerfile` lo trae el stack: `../../node-api/examples/Dockerfile` es el de una API en Node, multi-stage, con la imagen final sin dependencias de desarrollo y sin root, y la imagen base una sola vez, pineada por digest (`docker-base-stage.md`, `docker-pin-digest.md`).

```yaml
# docker-compose.yml
#   dev:    docker compose up db                       + dev server en el host
#   todo:   docker compose up --build
#   +obs:   docker compose --profile observability up
#   +tls:   docker compose --profile proxy up          (VPS con dominio; requiere PROXY_* en .env)
#   +infra: --profile redis, --profile bucket          (solo si el proyecto los usa)
x-logging: &log-small { driver: json-file, options: { max-size: "5m", max-file: "1" } }
x-logging-app: &log-app { driver: json-file, options: { max-size: "300m", max-file: "1" } }

services:
  db:
    image: postgres:16
    environment: { POSTGRES_USER: "${DB_USER:-postgres}", POSTGRES_PASSWORD: "${DB_PASSWORD:-dev}", POSTGRES_DB: "${DB_NAME:-app}" }
    ports: ["127.0.0.1:${DB_PORT:-5432}:5432"]     # solo loopback: psql local sí, internet no
    volumes:
      - db:/var/lib/postgresql/data
      - ./.seed:/docker-entrypoint-initdb.d:ro   # vacío en tu checkout; env-up.sh deja ahí un dump de tu DB
    healthcheck: { test: ["CMD-SHELL", "pg_isready -U ${DB_USER:-postgres} -d ${DB_NAME:-app}"], interval: 5s }
    restart: unless-stopped
    logging: *log-small

  migrator:                                   # corre una vez y termina; la api espera a que termine bien
    build: { context: ., dockerfile: apps/api/Dockerfile, target: migrator }
    image: "${MIGRATOR_IMAGE:-app-migrator:local}"
    env_file: .env
    environment: { DATABASE_URL: "postgres://${DB_USER:-postgres}:${DB_PASSWORD:-dev}@db:5432/${DB_NAME:-app}" }   # el mismo .env sirve en el host; acá se pisa la URL interna
    depends_on: { db: { condition: service_healthy } }
    restart: "no"
    logging: *log-small

  api:
    build: { context: ., dockerfile: apps/api/Dockerfile, target: api }
    image: "${API_IMAGE:-app-api:local}"      # CI la etiqueta; local queda :local
    env_file: .env
    environment: { DATABASE_URL: "postgres://${DB_USER:-postgres}:${DB_PASSWORD:-dev}@db:5432/${DB_NAME:-app}", LOG_LEVEL: info }
    ports: ["${API_PORT:-3000}:3000"]
    depends_on:
      migrator: { condition: service_completed_successfully }
      db: { condition: service_healthy }
    restart: unless-stopped
    logging: *log-app

  web:
    build:
      context: .
      dockerfile: apps/web/Dockerfile
      args: { PUBLIC_API_URL: "${PUBLIC_API_URL:-http://localhost:3000}" }   # se hornea en el bundle
    image: "${WEB_IMAGE:-app-web:local}"
    ports: ["${WEB_PORT:-5173}:80"]
    depends_on: [api]
    restart: unless-stopped
    logging: *log-small

  # ---- redis: docker compose --profile redis up ----
  redis:
    image: redis:7
    profiles: [redis]
    command: ["redis-server", "--appendonly", "yes", "--requirepass", "${REDIS_PASSWORD:-dev}"]
    ports: ["127.0.0.1:${REDIS_PORT:-6379}:6379"]
    volumes: [redis:/data]
    restart: unless-stopped
    logging: *log-small

  # ---- bucket S3 aislado: docker compose --profile bucket up ----
  # El storage vive SOLO en bucket-net. La api lo alcanza como `bucket:9000` a través del puente,
  # y no puede resolver `storage`: el filer (8888) y el master (9333), que no tienen auth, quedan fuera de su alcance.
  storage:
    image: chrislusf/seaweedfs
    profiles: [bucket]
    command: ["server", "-s3", "-s3.port=9000", "-dir=/data"]
    environment: { AWS_ACCESS_KEY_ID: "${BUCKET_USER:-dev}", AWS_SECRET_ACCESS_KEY: "${BUCKET_PASSWORD:-devdevdev}" }
    volumes: [storage:/data]
    networks: [bucket-net]
    healthcheck: { test: ["CMD-SHELL", "wget -q -O /dev/null http://$(hostname -i):9333/cluster/status"], interval: 10s, timeout: 5s, retries: 5 }
    restart: unless-stopped
    logging: *log-small

  storage-setup:                                   # el storage no crea buckets solo; esto corre una vez
    image: chrislusf/seaweedfs
    profiles: [bucket]
    depends_on: { storage: { condition: service_healthy } }
    networks: [bucket-net]
    entrypoint: ["/bin/sh", "-c", "sleep 5; echo 's3.bucket.create -name ${BUCKET_NAME:-app}' | weed shell -master=storage:9333; exit 0"]
    restart: "no"
    logging: *log-small

  bucket:                                          # puente: único contenedor en las dos redes
    image: caddy:2-alpine
    profiles: [bucket]
    command: ["caddy", "reverse-proxy", "--from", ":9000", "--to", "storage:9000"]
    ports: ["127.0.0.1:${BUCKET_PORT:-9000}:9000"]
    depends_on: { storage: { condition: service_healthy } }
    networks:
      default: { aliases: [bucket] }
      bucket-net: {}
    restart: unless-stopped
    logging: *log-small

  # ---- proxy perimetral con TLS: docker compose --profile proxy up ----
  proxy:
    image: caddy:2-alpine
    profiles: [proxy]
    ports: ["80:80", "443:443", "443:443/udp"]
    environment: { PROXY_ACME_EMAIL: "${PROXY_ACME_EMAIL}", API_DOMAIN: "${API_DOMAIN}", WEB_DOMAIN: "${WEB_DOMAIN}", GRAFANA_DOMAIN: "${GRAFANA_DOMAIN:-}" }
    volumes:
      - ./observability/Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy-data:/data
      - caddy-config:/config
    networks: [default, observability-net]                    # el único que ve a grafana y a la api
    restart: unless-stopped
    logging: *log-small

  # ---- observabilidad: docker compose --profile observability up ----
  # Solo grafana se publica al host. Todo lo demás vive en observability-net, sin auth, fuera del alcance de la api.
  loki:
    image: grafana/loki:3.3.2
    profiles: [observability]
    command: ["-config.file=/etc/loki/loki.yml"]
    volumes:
      - ./observability/loki.yml:/etc/loki/loki.yml:ro
      - loki:/loki
    networks: [observability-net]
    restart: unless-stopped
    logging: *log-small

  promtail:
    image: grafana/promtail:3.3.2
    profiles: [observability]
    command: ["-config.file=/etc/promtail/config.yml"]
    volumes:
      - ./observability/promtail.yml:/etc/promtail/config.yml:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro          # docker_sd: descubre contenedores y rutas de log
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - promtail:/promtail                                     # positions.yaml: reinicio sin reenviar todo
    depends_on: [loki]
    networks: [observability-net]
    restart: unless-stopped
    logging: *log-small

  node-exporter:
    image: quay.io/prometheus/node-exporter:v1.8.2
    profiles: [observability]
    command: ["--path.procfs=/host/proc", "--path.sysfs=/host/sys", "--path.rootfs=/rootfs"]   # evita el rslave en /, que falla en algunos hosts
    pid: host
    volumes: ["/proc:/host/proc:ro", "/sys:/host/sys:ro", "/:/rootfs:ro"]
    networks: [observability-net]
    restart: unless-stopped
    logging: *log-small

  cadvisor:
    image: ghcr.io/google/cadvisor:0.56.2
    profiles: [observability]
    command: ["--docker_only=true"]                            # solo contenedores Docker: menos cgroups, nombres limpios
    privileged: true
    devices: ["/dev/kmsg:/dev/kmsg"]
    volumes: ["/:/rootfs:ro", "/var/run:/var/run:ro", "/sys:/sys:ro", "/var/lib/docker/:/var/lib/docker:ro", "/dev/disk/:/dev/disk:ro"]
    networks: [observability-net]
    restart: unless-stopped
    logging: *log-small

  prometheus:
    image: prom/prometheus:v2.55.1
    profiles: [observability]
    command: ["--config.file=/etc/prometheus/prometheus.yml", "--storage.tsdb.path=/prometheus", "--storage.tsdb.retention.time=15d", "--web.enable-lifecycle"]
    volumes:
      - ./observability/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus:/prometheus
    depends_on: [node-exporter, cadvisor]
    networks: [observability-net]
    restart: unless-stopped
    logging: *log-small

  grafana:
    image: grafana/grafana:11.3.1
    profiles: [observability]
    ports: ["${GRAFANA_PORT:-3010}:3000"]                     # 3000 lo usa la api
    environment:
      GF_SECURITY_ADMIN_USER: "${GRAFANA_ADMIN_USER:-admin}"
      GF_SECURITY_ADMIN_PASSWORD: "${GRAFANA_ADMIN_PASSWORD:-admin}"
      GF_USERS_ALLOW_SIGN_UP: "false"
    volumes:
      - ./observability/grafana/provisioning:/etc/grafana/provisioning:ro
      - ./observability/grafana/dashboards:/etc/grafana/dashboards:ro
      - grafana:/var/lib/grafana
    depends_on: [loki, prometheus]
    networks: [observability-net]
    restart: unless-stopped
    logging: *log-small

volumes: { db: {}, redis: {}, storage: {}, loki: {}, promtail: {}, prometheus: {}, grafana: {}, caddy-data: {}, caddy-config: {} }
networks: { bucket-net: {}, observability-net: {} }   # default la crea compose; estas dos son las aisladas
```

```yaml
# observability/loki.yml: monolítico local, filesystem, retención 15 días. Sin esto Loki crece sin tope.
auth_enabled: false
server: { http_listen_port: 3100 }
common:
  path_prefix: /loki
  storage: { filesystem: { chunks_directory: /loki/chunks, rules_directory: /loki/rules } }
  replication_factor: 1
  ring: { kvstore: { store: inmemory } }
schema_config:
  configs:
    - from: "2024-01-01"
      store: tsdb
      object_store: filesystem
      schema: v13
      index: { prefix: index_, period: 24h }
compactor:
  working_directory: /loki/compactor
  retention_enabled: true
  delete_request_store: filesystem
limits_config:
  retention_period: 15d
```

```yaml
# observability/promtail.yml: un stream por contenedor, etiqueta `container`
server: { http_listen_port: 9080 }
positions: { filename: /promtail/positions.yaml }   # volumen: un reinicio no reenvía el historial
clients: [{ url: http://loki:3100/loki/api/v1/push }]
scrape_configs:
  - job_name: docker
    docker_sd_configs: [{ host: unix:///var/run/docker.sock, refresh_interval: 5s }]
    relabel_configs:
      - { source_labels: [__meta_docker_container_name], regex: "/(.*)", target_label: container }
```

```yaml
# observability/prometheus.yml
global: { scrape_interval: 15s }
scrape_configs:
  - { job_name: prometheus, static_configs: [{ targets: ["localhost:9090"] }] }
  - { job_name: node, static_configs: [{ targets: ["node-exporter:9100"] }] }
  - { job_name: cadvisor, static_configs: [{ targets: ["cadvisor:8080"] }] }
```

```
# observability/Caddyfile: un bloque por dominio. Caddy pide y renueva el TLS solo.
{
  email {$PROXY_ACME_EMAIL}
}
{$API_DOMAIN} {
  reverse_proxy api:3000
}
{$WEB_DOMAIN} {
  reverse_proxy web:80
}
{$GRAFANA_DOMAIN} {
  reverse_proxy grafana:3000
}
```

```yaml
# observability/grafana/provisioning/datasources/datasources.yml
apiVersion: 1
datasources:
  - { name: Loki, type: loki, url: "http://loki:3100" }
  - { name: Prometheus, type: prometheus, url: "http://prometheus:9090", isDefault: true }
```

Dashboards: importar desde Grafana con el ID de grafana.com. `1860` (Node Exporter Full) y uno de cAdvisor. Nada específico del producto hasta que haya métricas de aplicación.

Comandos:

```bash
docker compose up db                              # dev: solo la DB, apps con el dev server del stack
docker compose up                                 # todo, como en producción
docker compose --profile observability up         # todo + Grafana en localhost:3010 (admin/admin)
docker compose --profile observability down -v    # borrar también los volúmenes
```

Query típica en Grafana, Explore > Loki:

```
{container="api"} | json | level >= 50                 # errores (pino: 50 error, 60 fatal)
{container=~"api|web"} | json | requestId = "abc123"   # una request a través de las dos apps
```

## Varios entornos a la vez

Trabajar con worktrees (`../../workflow/references/worktree.md`) significa dos o tres stacks corriendo en la misma máquina. No hace falta replicar nada pesado: Compose usa el nombre de la carpeta como nombre de proyecto, así que cada worktree ya tiene su red, sus volúmenes y sus contenedores. Lo único que choca son los puertos publicados al host, y por eso van por env.

| Recurso | Cómo se aísla | Costo |
|---|---|---|
| contenedores, red, volúmenes | solo, por nombre de carpeta del worktree. O `COMPOSE_PROJECT_NAME` | nada: la imagen se buildea una vez, las capas se comparten |
| puertos | `API_PORT`, `WEB_PORT`, `DB_PORT` en el `.env` del worktree | nada |
| Postgres | default: un contenedor `db` por worktree, lo levanta el compose solo. Alternativa: no levantar `db` y apuntar `DATABASE_URL` al del checkout principal con otra `DB_NAME` | 50 MB idle por contenedor. Compartido: nada |
| Redis, si hay | una instancia, índice por worktree: `redis://localhost:6379/3` | nada |
| observabilidad | una sola, en el checkout principal. En worktrees no se levanta | la única parte pesada, y no se replica |

```bash
# .env del worktree feature-x (el .worktreeinclude copia el .env base; estos valores lo pisan)
API_PORT=3001
WEB_PORT=5174
DB_PORT=5433
DB_NAME=app_feature_x
```

Cuánto hace falta de verdad: los tests unitarios no levantan nada. Los de integración usan la database del worktree. El stack completo es para e2e o probar a mano, y eso pasa en uno o dos worktrees a la vez, no en diez agentes a la vez.

Si aislar un entorno obliga a tocar código, el código tenía un valor hardcodeado que ya era un bug. Se saca a `config.ts` y listo.

Levantar uno de estos con un comando, con puertos derivados del nombre y una copia de tu DB de dev: `../../../scripts/env-up.sh <slug>` del plugin (`${CLAUDE_PLUGIN_ROOT}/scripts/env-up.sh`). Es lo que usa `/mindstack:orchestrate (fase implement)` para dejarte la feature corriendo.

## Qué pasa si no

| Atajo | Lo que cuesta |
|---|---|
| README con "instalá Postgres 16 y Redis" | cada persona nueva pierde medio día y termina con una versión distinta |
| Logs a archivo "por si Docker los pierde" | un volumen más, un rotado que nadie configura, y Promtail igual lee stdout |
| `console.log` con texto | `| json` no parsea nada. Buscar un `requestId` es `grep` a mano |
| Observabilidad "después, cuando haga falta" | hace falta en el primer incidente, que es justo cuando no hay tiempo de montarla |
| Compose de observabilidad en otro repo | se desactualiza respecto de las apps. Un profile en el mismo archivo no |
| Puertos fijos en el compose | el segundo worktree no levanta. Se termina trabajando de a uno, y el paralelismo de los agentes se pierde en el entorno |
| DB publicada en `5432:5432` | en una VPS es Postgres abierto a internet. Shodan lo encuentra antes que vos |
| La api en la misma red que el admin del storage | un SSRF en un endpoint que hace `fetch(url)` llega al filer sin auth y lee o borra todo el bucket |
| Observabilidad sin retención | Loki y Prometheus llenan el disco más despacio que un log sin tope, pero lo llenan igual. En dos meses |
| Sin `logging.max-size` | un loop de errores a las 3am llena el disco a las 5. Postgres deja de escribir. Todo cae por un log |
| Sin `restart` | el host reinicia por un parche del kernel y nadie levanta los contenedores hasta que alguien mira |
| Migraciones dentro del arranque de la API | con dos réplicas corren dos veces a la vez. Con una, un deploy roto deja la API caída en vez de solo la migración |
| Variables públicas del front por `environment` | el bundle ya está buildeado con el valor de otro entorno. "Funciona local, apunta a staging en prod" |
| `FROM imagen:24` flotante, "así se actualiza solo" | se actualiza cuando el registry quiere. Un día antes del parche corrés la vulnerable sin forma de saberlo, y el cache de Docker puede no volver a mirar |
| Digest pineado y nadie que lo mueva | una versión congelada. Es cómo un runtime termina seis meses después de su EOL en todos los proyectos que copiaron la plantilla |
| La imagen en un `ARG` "para no repetirla" | Dependabot deja de verla y no avisa. Parece cubierto y no lo está |

## Tests que tienen que existir

- CI buildea el `Dockerfile` de cada app en cada PR (`ci.md`). Un `COPY` que falta se entera ahí.
- CI compara la versión del runtime en el runner y en la imagen contra el archivo de versión, y escanea la imagen (`docker-runtime-verified.md`). Un PR que cambie solo el archivo de versión tiene que ponerse rojo.
- Insights → Dependabot en GitHub lista el `Dockerfile` y los workflows. Si no están, el bot no los mira (`docker-updates-bot.md`).
- `docker compose config` en CI: valida el YAML y los profiles sin levantar nada.
- Un smoke local, una vez: `--profile observability up`, abrir Grafana, correr `{container="api"}`. Si no hay líneas, Promtail no llega al socket.

## Fuentes

- [Docker Compose, profiles](https://docs.docker.com/compose/how-tos/profiles/): servicios opt-in en un solo archivo.
- [Docker Compose, `include`](https://docs.docker.com/compose/how-tos/multiple-compose-files/include/): partir el archivo sin crear un segundo proyecto.
- [Docker Compose, control startup order](https://docs.docker.com/compose/how-tos/startup-order/): `service_healthy` y `service_completed_successfully`.
- [Docker, `json-file` logging driver](https://docs.docker.com/engine/logging/drivers/json-file/): `max-size` y `max-file`.
- [Docker, multi-stage builds](https://docs.docker.com/build/building/multi-stage/): un `target` por servicio.
- [Grafana Loki, retention](https://grafana.com/docs/loki/latest/operations/storage/retention/): compactor y `retention_period`.
- [Prometheus, storage](https://prometheus.io/docs/prometheus/latest/storage/): `--storage.tsdb.retention.time`.
