# Sesiones por dispositivo en Postgres: diseño

Qué guarda la tabla, cómo rota, cómo se cierra una sesión desde otro dispositivo, y por qué así. Respalda las dos decisiones del plan que se apartan de `../../web-security/references/jwt.md`: una fila por sesión (no por rotación) y revocación del access en menos de un minuto (no "se aceptan los 10").

## La idea en una línea

**La sesión es la familia de `jwt.md`, y es una fila.** Guarda el hash del refresh vigente y lo que el usuario necesita ver: qué dispositivo, desde dónde, desde cuándo, última vez. Rotar es reemplazar el hash. Reuso es presentar cualquier otro. Cerrar es poner `revoked_at`.

## El token

```
__Secure-refresh = <sid>.<secret>
                    uuid     32 bytes aleatorios, base64url
```

El `sid` viaja en claro dentro del refresh para que la API sepa qué fila mirar sin un índice por hash. El `secret` es lo que se hashea y compara. Un token sin punto, o con un `sid` que no es uuid, se rechaza antes de tocar la DB. En el access, `sid` es el mismo valor, igual que en `jwt.md`.

## Tabla

```sql
CREATE TYPE session_revocation AS ENUM ('user', 'reuse', 'password_change', 'admin');

CREATE TABLE sessions (
  id            uuid PRIMARY KEY,                       -- el sid del access y del refresh
  user_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  refresh_hash  text NOT NULL,                          -- sha256 del secret vigente
  prev_hash     text,                                   -- el anterior, aceptado solo durante la gracia
  rotated_at    timestamptz NOT NULL DEFAULT now(),     -- cuándo se rotó por última vez
  created_at    timestamptz NOT NULL DEFAULT now(),
  last_seen_at  timestamptz NOT NULL DEFAULT now(),     -- se mueve al rotar: granularidad de 10 min, suficiente
  expires_at    timestamptz NOT NULL,                   -- deslizante: now() + 30d en cada rotación
  revoked_at    timestamptz,
  revoked_by    session_revocation,
  ua            text NOT NULL,                          -- User-Agent crudo, para re-parsear si el parser mejora
  device        jsonb NOT NULL,                         -- {"browser":"Chrome 130","os":"Linux","type":"desktop"}
  ip            inet NOT NULL                           -- del cliente real, vía trust proxy
);

CREATE INDEX sessions_user_active ON sessions (user_id) WHERE revoked_at IS NULL;   -- la lista de dispositivos
```

Una fila por login. Un usuario con tres dispositivos tiene tres filas vivas. Una rotación no crea filas: actualiza una.

## Las operaciones

| Operación | SQL | Cuándo |
|---|---|---|
| login | `INSERT INTO sessions (id, user_id, refresh_hash, expires_at, ua, device, ip) VALUES (...)` | `POST /auth/login` |
| rotate | el `UPDATE` de abajo | `POST /auth/refresh` |
| ¿revocada? | `SELECT revoked_at IS NOT NULL OR expires_at < now() FROM sessions WHERE id = $sid` | middleware de auth, con cache de 60 s |
| listar | `SELECT id, device, ip, created_at, last_seen_at FROM sessions WHERE user_id = $uid AND revoked_at IS NULL AND expires_at > now() ORDER BY last_seen_at DESC` | `GET /auth/sessions` |
| cerrar una | `UPDATE sessions SET revoked_at = now(), revoked_by = 'user' WHERE id = $sid AND user_id = $uid AND revoked_at IS NULL` | `DELETE /auth/sessions/:id`, logout |
| cerrar las demás | `... WHERE user_id = $uid AND id <> $current AND revoked_at IS NULL` | `DELETE /auth/sessions` |
| cerrar todas | `... SET revoked_by = 'password_change' WHERE user_id = $uid AND revoked_at IS NULL` | cambio de password |
| purga | `DELETE FROM sessions WHERE coalesce(revoked_at, expires_at) < now() - interval '90 days'` | job diario |

`WHERE ... AND user_id = $uid` en el cierre es lo que hace que un usuario no pueda cerrar la sesión de otro aunque adivine el `sid`: 0 filas → `404`.

## La rotación

Una sola sentencia. La condición lleva todo lo que había que chequear, y el row lock del `UPDATE` hace que dos refresh concurrentes con el mismo token no ganen los dos:

```sql
UPDATE sessions
SET prev_hash    = refresh_hash,
    refresh_hash = $next,
    rotated_at   = now(),
    last_seen_at = now(),
    expires_at   = now() + interval '30 days'
WHERE id = $sid
  AND (refresh_hash = $presented
       OR (prev_hash = $presented AND rotated_at > now() - interval '10 seconds'))   -- gracia: dos pestañas, dos procesos
  AND revoked_at IS NULL
  AND expires_at > now()
RETURNING user_id;
```

La segunda rama del `OR` es la ventana de gracia: el refresh **anterior** rota de nuevo si se presenta dentro de los 10 s de la última rotación. Es el tiempo de una respuesta en vuelo. Un token robado que se usa 10 s tarde sigue siendo reuso. Entre pestañas del browser esto casi nunca llega a usarse porque `navigator.locks` lo evita antes (`jwt.md` § Varias pestañas); cubre a los clientes que no comparten cookies.

| Resultado | Qué pasó | API | Front |
|---|---|---|---|
| 1 fila | era el vigente | `204`, access nuevo, refresh nuevo `sid.secretNuevo` | reintenta el request original una vez |
| 0 filas, y `SELECT` muestra la sesión viva con otro hash, fuera de la gracia | **reuso**: alguien ya rotó este token hace más de 10 s | `UPDATE ... SET revoked_at = now(), revoked_by = 'reuse'`; `401 SESSION_REVOKED`, borra cookies | `/login` |
| 0 filas, y no existe, o revocada, o vencida | logout previo, cierre desde otro dispositivo, expiró | `401 SESSION_REVOKED`, borra cookies | `/login` |
| error de conexión | DB caída | `503`, **no** toca cookies | muestra error, reintenta después |

El segundo `SELECT` solo corre en el camino de 0 filas, que es raro: no cuesta nada en el camino feliz.

Dos refresh concurrentes con el mismo `presented`: el primero toma el lock, rota, commitea. El segundo espera el lock, re-evalúa el `WHERE` con la fila nueva, `refresh_hash` ya no coincide, 0 filas, reuso, revoca. Es exactamente lo que hacía el script Lua en la versión de Redis, sin script.

## Revocar el access en menos de un minuto

El access es un JWT: el servidor no lo tiene y no lo puede borrar. `jwt.md` acepta que siga valiendo hasta `exp`, 10 minutos. Con una pantalla donde el usuario cierra "mi teléfono", 10 minutos de teléfono andando es un bug visible. Se cierra así:

```ts
// apps/api/src/auth/session-cache.ts: ¿esta sesión sigue viva? Una consulta por sesión por minuto, no por request.
const TTL_MS = 60_000;
const MAX = 10_000;                                      // ponytail: Map acotado; LRU real si hay más sesiones activas por instancia
const cache = new Map<string, { alive: boolean; until: number }>();

export async function sessionAlive(sid: string, now = Date.now()): Promise<boolean> {
  const hit = cache.get(sid);
  if (hit && hit.until > now) return hit.alive;
  const alive = !(await sessions.isRevoked(sid));       // SELECT por PK; lanza si la DB no responde → 503 en el handler
  if (cache.size >= MAX) cache.delete(cache.keys().next().value!);
  cache.set(sid, { alive, until: now + TTL_MS });
  return alive;
}

export function forget(sid: string) { cache.delete(sid); }   // la instancia que revocó no espera los 60 s
```

```ts
// apps/api/src/auth/auth.middleware.ts (la parte nueva)
const { userId, sessionId } = await verifyAccess(token);   // firma y exp: TOKEN_EXPIRED o UNAUTHORIZED
if (!(await sessionAlive(sessionId))) {
  clearSession(res);
  throw new SessionRevokedError();                          // 401 SESSION_REVOKED: el front va al login
}
req.user = { id: userId, sid: sessionId };
```

| | Sin check (core) | Con check + cache 60 s | Con Redis deny list |
|---|---|---|---|
| el dispositivo cerrado deja de andar | hasta 10 min | hasta 60 s por instancia; en la instancia que revocó, ya | ya, en todas |
| costo por request | 0 | 0 en cache hit; un `SELECT` por PK por sesión por minuto | un `GET` a Redis por request |
| infra | ninguna | ninguna | Redis |
| cuándo | sin pantalla de dispositivos | este plan | si 60 s no alcanza y hay varias instancias |

## Capturar el dispositivo

```ts
// apps/api/src/auth/device.ts
import { UAParser } from 'ua-parser-js';

export function captureDevice(req: Request) {
  const ua = req.headers['user-agent'] ?? '';
  const p = new UAParser(ua).getResult();
  return {
    ua,
    device: {
      browser: [p.browser.name, p.browser.major].filter(Boolean).join(' ') || 'unknown',
      os: [p.os.name, p.os.version].filter(Boolean).join(' ') || 'unknown',
      type: p.device.type ?? (p.browser.name ? 'desktop' : 'unknown'),   // ua-parser deja type vacío en desktop
    },
    ip: req.ip,                                                          // real solo con trust proxy bien puesto
  };
}
```

`req.ip` es la IP del cliente solo si Express sabe qué proxy tiene adelante: `app.set('trust proxy', config.TRUSTED_PROXY)` con la IP o el CIDR del Caddy, **no** `true`. Con `true`, cualquiera que llegue directo a la API manda `X-Forwarded-For: 1.2.3.4` y esa es la IP que se guarda. Fastify: `trustProxy` en las opciones, mismo criterio.

`ua-parser-js` a confirmar en el proyecto; la tabla "Con qué" de la skill `node-api` suma la fila. Alternativa sin dependencia: guardar solo el `ua` crudo y parsear en el front. Menos prolijo, cero deps.

## Lo que el usuario ve

`SessionDto` en `contracts`:

```ts
export const SessionDto = z.object({
  id: z.string().uuid(),
  device: z.object({ browser: z.string(), os: z.string(), type: z.string() }),
  ip: z.string(),
  createdAt: z.string().datetime(),
  lastSeenAt: z.string().datetime(),
  current: z.boolean(),            // id === sid del request
});
```

Ni `refreshHash`, ni `ua` crudo, ni `userId`: lo que la pantalla muestra y nada más.

## Por qué Postgres y no Redis

| | Redis, una clave por familia (`redis-rejected.md`) | Postgres, una fila por sesión (este plan) |
|---|---|---|
| la lista de dispositivos | posible: campos en el hash, `SMEMBERS` + N `HGETALL` | un `SELECT` con índice |
| durabilidad | reinicio sin AOF = todos al login y la lista desaparece | es la DB |
| historia ("inicios recientes", "esta sesión se cerró por reuso el martes") | no: el TTL borra todo | 90 días de filas revocadas |
| consultas ("sesiones desde esta IP", "cuántos dispositivos por usuario") | no sin `SCAN` | SQL |
| atomicidad de la rotación | script Lua | un `UPDATE` con `WHERE` |
| expiración | TTL nativo | `expires_at` + un `DELETE` diario |
| carga | sub-ms | un `UPDATE` por usuario activo cada 10 min. Con 10 000 usuarios activos, menos de 20 por segundo |
| infra | Redis, un datastore más con su política de evicción | nada nuevo |
| revocar el access rápido | deny list por request | cache de 60 s, una consulta por minuto |

Lo que decidió: la sesión pasó a ser algo que el usuario **ve**. Eso la hace entidad de dominio, y las entidades de dominio viven en la DB (skill `architecture` §3). Redis era buena idea mientras la sesión era un detalle del refresh.

## Lo que queda abierto

- **Tope absoluto de sesión** (90 días aunque se use): `AND created_at > now() - interval '90 days'` en el `WHERE` del `UPDATE`. Un `AND` más; fuera de alcance hasta que alguien lo pida.
- **Varias instancias y los 60 s**: cada instancia tiene su cache. La que recibió el `DELETE` hace `forget(sid)` y revoca ya; las otras tardan hasta 60 s. Si no alcanza, pub/sub entre instancias o Redis como deny list. No antes.
- **Forjar `sid.basura`**: quien sepa un `sid` provoca un `reuse` y cierra esa sesión. El `sid` solo existe en dos cookies `httpOnly`; quien lo lee ya tiene el refresh entero. Aceptado.
- **El tamaño de la gracia**: 10 s cubre una respuesta lenta; 30 s cubriría una red móvil mala a cambio de 20 s más de ventana para un token robado y usado justo después de la rotación. Ajustable; se mide con los `reuse` en logs que tienen un `OK` de la misma sesión segundos antes.

## Cómo se ve en `psql`

```
app=# SELECT id, device->>'browser' AS browser, device->>'os' AS os, ip, last_seen_at, revoked_by FROM sessions WHERE user_id = 'u_42' ORDER BY last_seen_at DESC;
                  id                  |  browser   |    os     |      ip       |     last_seen_at       | revoked_by
--------------------------------------+------------+-----------+---------------+------------------------+------------
 5c2a…                                | Chrome 130 | Linux     | 190.191.1.10  | 2026-10-22 15:40:02+00 |
 e71b…                                | Safari 18  | iOS 18.1  | 181.44.3.9    | 2026-10-22 09:12:55+00 | user
```

## Fuentes

- `../../web-security/references/jwt.md`, `cookies.md`, `origin.md`: el flujo, las cookies, los códigos de error, los tests.
- [PostgreSQL, `UPDATE ... RETURNING` y row-level locks](https://www.postgresql.org/docs/current/explicit-locking.html#LOCKING-ROWS): por qué el `UPDATE` condicional es atómico frente a concurrencia.
- [Express, `trust proxy`](https://expressjs.com/en/guide/behind-proxies.html): `req.ip` y `X-Forwarded-For`.
- [ua-parser-js](https://github.com/faisalman/ua-parser-js): parseo de `User-Agent`.
- [OWASP, Session Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html): listar y cerrar sesiones, binding a dispositivo, expiración.
