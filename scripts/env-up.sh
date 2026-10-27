#!/usr/bin/env bash
# Levanta el entorno de un plan, aislado, con una copia de la DB de desarrollo.
# Uso (desde el worktree del plan):
#   scripts/env-up.sh <slug> db     solo la DB, al arrancar el loop: tests y dev server del host pegan acá
#   scripts/env-up.sh <slug>        db + api + web buildeados desde la rama, para probar lo que va a producción
# Idempotente: correrlo de nuevo rebuildea api/web y no toca la DB. Bajarlo: scripts/env-down.sh <slug>
set -euo pipefail

slug=$1
what=${2:-all}
n=$(( $(printf '%s' "$slug" | cksum | cut -d' ' -f1) % 100 ))   # puertos estables por slug; colisión improbable, no imposible

# El .env del worktree es una copia (la hizo el hook): se le pisan los puertos y la URL de la DB.
# Compose lo lee por env_file y pisa DATABASE_URL con host `db`; el host (tests, dev server) usa esta.
set -a; [ -f .env ] && . ./.env; set +a
db_url="postgres://${DB_USER:-postgres}:${DB_PASSWORD:-dev}@localhost:$((5500 + n))/${DB_NAME:-app}"
for kv in "API_PORT=$((3100 + n))" "WEB_PORT=$((5200 + n))" "DB_PORT=$((5500 + n))" "GRAFANA_PORT=$((3300 + n))" "DATABASE_URL=$db_url"; do
  k=${kv%%=*}
  grep -q "^$k=" .env 2>/dev/null && sed -i "s|^$k=.*|$kv|" .env || echo "$kv" >> .env
done

# Seed: dump de la DB del checkout principal (tu DB de dev, no una limpia).
# Postgres lo corre solo la primera vez que inicializa el volumen: docker-entrypoint-initdb.d.
main=$(git worktree list | head -1 | awk '{print $1}')
dev_project=$(basename "$main")
mkdir -p .seed
if docker compose -p "$dev_project" ps db --status running -q >/dev/null 2>&1; then
  docker compose -p "$dev_project" exec -T db pg_dump -U "${DB_USER:-postgres}" --clean --if-exists "${DB_NAME:-app}" > .seed/00-dev.sql
else
  echo "db de dev no corre en el proyecto '$dev_project': el stack arranca con DB vacía" >&2
fi

if [ "$what" = db ]; then
  docker compose -p "$slug" up -d db
  echo "db '$slug': $db_url  (ya en .env del worktree)"
  exit 0
fi

docker compose -p "$slug" up -d --build db api web

echo "entorno '$slug':"
echo "  web  http://localhost:$((5200 + n))"
echo "  api  http://localhost:$((3100 + n))"
echo "  db   $db_url"
