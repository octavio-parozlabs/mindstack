# Redis para el refresh token: alternativa descartada

**Descartada el 2026-10-22.** Fue la primera versión de este pre-plan: una clave por familia en Redis, con TTL nativo y un script Lua para rotar. Se descartó cuando entró el requisito de que el usuario **vea** sus sesiones (dispositivo, IP, desde cuándo) y las cierre: eso convierte la sesión en entidad de dominio, y una entidad de dominio quiere durabilidad, historia y consultas, que son las tres cosas que Redis no da. El diseño vigente está en `sessions.md`; la comparación punto por punto, en su sección "Por qué Postgres y no Redis".

Queda acá porque vuelve a ser la respuesta correcta en un caso: **varias instancias de la API y la exigencia de que una sesión cerrada muera en el acto en todas** (el cache de 60 s de `sessions.md` no alcanza). Ahí Redis entra como deny list de `sid` revocados con TTL igual a lo que le quede al access, no como store de sesiones. Lo de abajo es el diseño original, sin cambios, como referencia.

---

Qué guarda Redis, cómo se ve, y por qué así. Era el spike que respaldaba usar Redis en vez de la tabla `refresh_tokens` de `../../web-security/references/jwt.md`.

## La idea en una línea

**Una clave por sesión (familia), que guarda el hash del refresh vigente.** Rotar es reemplazar ese hash. Reuso es presentar cualquier otro. No se guardan los tokens usados.

## El token

```
__Secure-refresh = <famId>.<secret>
                    uuid v4   32 bytes aleatorios, base64url
```

El `famId` viaja en claro dentro del token para que la API sepa qué clave mirar sin un índice secundario. El `secret` es lo que se hashea y compara. Un token sin punto, o con un `famId` que no es uuid, se rechaza antes de tocar Redis.

En el access token, `sid` = `famId`, igual que en `jwt.md`.

## Las claves

```
auth:fam:{famId}        HASH   uid  <userId>
                               cur  <sha256(secret) del refresh vigente>
                               iat  <epoch del login>
                        TTL    30 días, se renueva en cada rotación (deslizante)

auth:uid:{userId}       SET    { famId, famId, ... }    una por login/dispositivo
                        TTL    ninguno. SREM al revocar; lo expirado se limpia al leer
```

Dos claves. La segunda existe solo para "cerrar sesión en todos lados" y cambio de password.

`{famId}` entre llaves es un hash tag: en Redis Cluster garantiza que la clave y el script Lua caen en el mismo slot. Sin Cluster no cambia nada.

## Las operaciones

| Operación | Comandos | Cuándo |
|---|---|---|
| login | `HSET auth:fam:{f} uid u cur h iat t` · `EXPIRE auth:fam:{f} 2592000` · `SADD auth:uid:{u} f` | `POST /auth/login` |
| rotate | script Lua de abajo, atómico | `POST /auth/refresh` |
| logout | `DEL auth:fam:{f}` · `SREM auth:uid:{u} f` | `POST /auth/logout` |
| logout-all | `SMEMBERS auth:uid:{u}` → `DEL` de cada una → `DEL auth:uid:{u}` | `POST /auth/logout-all`, cambio de password |
| ¿sesión viva? | no hace falta: el access es JWT stateless | ningún request común toca Redis |

## El script de rotación

Es la única parte con lógica, y tiene que ser atómica: dos refresh concurrentes con el mismo token no pueden ganar los dos. Un script Lua corre solo en el servidor; es la transacción de `jwt.md` (`markUsed` + `insert`) en una pieza.

```lua
-- rotate.lua
-- KEYS[1] = auth:fam:{famId}
-- ARGV[1] = sha256(secret presentado)
-- ARGV[2] = sha256(secret nuevo)
-- ARGV[3] = ttl en segundos
local cur = redis.call('HGET', KEYS[1], 'cur')
if not cur then
  return { 'MISSING' }                      -- logout, expiró, o ya revocada por reuso
end
if cur ~= ARGV[1] then
  redis.call('DEL', KEYS[1])                -- reuso: alguien ya rotó este token. Toda la familia afuera
  return { 'REUSED' }
end
redis.call('HSET', KEYS[1], 'cur', ARGV[2])
redis.call('EXPIRE', KEYS[1], ARGV[3])
return { 'OK', redis.call('HGET', KEYS[1], 'uid') }
```

Tres salidas, tres respuestas de la API:

| Script | API | Front |
|---|---|---|
| `OK, uid` | `204`, access nuevo, refresh nuevo `famId.secretNuevo` | reintenta el request original una vez |
| `REUSED` | `401 SESSION_REVOKED`, borra cookies | va a `/login` |
| `MISSING` | `401 SESSION_REVOKED`, borra cookies | va a `/login` |
| error de conexión | `503`, **no** toca cookies | muestra error, reintenta después. No desloguea |

## Con qué (Node)

`ioredis`, por `defineCommand`: registra el Lua una vez y lo expone como método tipado; usa `EVALSHA` y recarga solo si Redis perdió el script. `node-redis` (el oficial) hace lo mismo con `scriptLoad` + `evalSha` a mano. Decisión a confirmar en el proyecto; la que entre va a la tabla "Con qué" de la skill `node-api`.

```ts
// apps/api/src/auth/refresh-store.ts: el único módulo que habla con Redis
import Redis from 'ioredis';
import { readFileSync } from 'node:fs';
import { config } from '@/config';

const TTL = 30 * 24 * 60 * 60;
const redis = new Redis(config.REDIS_URL, { enableOfflineQueue: false }); // Redis caído = error ya, no cola infinita
redis.defineCommand('rotate', { numberOfKeys: 1, lua: readFileSync(new URL('./rotate.lua', import.meta.url), 'utf8') });

const famKey = (fam: string) => `auth:fam:{${fam}}`;
const uidKey = (uid: string) => `auth:uid:{${uid}}`;

export async function create(uid: string, fam: string, hash: string): Promise<void> {
  await redis.multi().hset(famKey(fam), { uid, cur: hash, iat: Date.now() }).expire(famKey(fam), TTL).sadd(uidKey(uid), fam).exec();
}

export type Rotation = { status: 'OK'; uid: string } | { status: 'REUSED' | 'MISSING' };

export async function rotate(fam: string, presentedHash: string, nextHash: string): Promise<Rotation> {
  const [status, uid] = (await redis.rotate(famKey(fam), presentedHash, nextHash, TTL)) as [string, string?];
  return status === 'OK' ? { status, uid: uid! } : { status: status as 'REUSED' | 'MISSING' };
}

export async function revoke(uid: string, fam: string): Promise<void> {
  await redis.multi().del(famKey(fam)).srem(uidKey(uid), fam).exec();
}

export async function revokeAll(uid: string): Promise<void> {
  const fams = await redis.smembers(uidKey(uid));
  if (fams.length) await redis.del(...fams.map(famKey), uidKey(uid));
  else await redis.del(uidKey(uid));
}
```

`enableOfflineQueue: false` es lo que convierte "Redis caído" en un error inmediato que el handler mapea a `503`. Con el default, ioredis encola el comando y el request se cuelga hasta el timeout.

El tipo de `redis.rotate` lo agrega ioredis por module augmentation; `types.md` del stack pide declararlo, no castear.

## Por qué así y no como `jwt.md`

| | Tabla `refresh_tokens` (core) | Redis, una clave por familia (este plan) |
|---|---|---|
| expiración | `expires_at` + un job que borre filas viejas. El core no lo menciona: la tabla crece una fila por refresh (un usuario activo, ~50 por día) | TTL nativo. Cero jobs, cero crecimiento: una clave por sesión, siempre |
| detección de reuso | fila con `used_at`: hay que conservar cada token usado | comparar con `cur`: si no es el vigente, es reuso. No se guarda nada más |
| atomicidad | transacción SQL | script Lua, un round-trip |
| carga en Postgres | un `SELECT` + `UPDATE` + `INSERT` por refresh, cada 10 min por usuario activo | ninguna |
| latencia del refresh | ms de Postgres | sub-ms |
| infra | ninguna extra | Redis, que `docker.md` ya trae como profile |
| pérdida de datos | no | reinicio sin AOF = todos al login. Con `--appendonly yes` se pierde como mucho 1 s de rotaciones |
| auditoría | la tabla es historial: cuándo se rotó, desde dónde | no hay historial. Si hace falta, se loguea en Pino al rotar y Loki lo guarda 15 días |

Lo que **no** cambia: el refresh sigue hasheado (un dump de Redis no sirve para loguearse), sigue rotando, el reuso sigue revocando la familia, el access sigue siendo stateless de 10 minutos.

## Alternativa descartada: una clave por token

```
auth:rt:<sha256(token)>   HASH { fam, uid, used }   TTL 30d
auth:fam:<famId>          HASH { uid, revoked }      TTL 30d
```

Es la traducción literal de la tabla del core. Funciona, pero cada rotación deja una clave `used=1` viva hasta su TTL: un usuario activo acumula más de mil claves por mes, por sesión. Y el `rotate` tiene que tocar tres claves, que en Cluster exige que las tres compartan hash tag. La versión por familia hace lo mismo con una clave y sin basura. Se descartó por `PRINCIPLES.md`: lo simple antes que lo complejo.

## Lo que queda abierto

- **Tope absoluto de sesión.** Hoy es deslizante: mientras se use, dura. Si se quiere "máximo 90 días aunque se use", el script compara `iat` con `now` y devuelve `MISSING` si pasó. Un `if` más; fuera de alcance hasta que alguien lo pida.
- **Forjar `famId.basura`.** Quien sepa un `famId` puede provocar un `REUSED` y desloguear esa sesión. El `famId` solo existe en dos cookies `httpOnly`; quien lo lee ya tiene el refresh entero y puede hacer bastante peor. Si se quiere cerrar igual: que el script devuelva `MISSING` sin borrar cuando el hash presentado no coincide **y** la familia tiene menos de N segundos desde su última rotación. Complejidad que no se paga hoy.
- **Un Redis para esto y para cache.** Mismo Redis, prefijo `auth:`. El problema es la política de evicción: con `allkeys-lru` o `volatile-lru`, bajo presión de memoria Redis borra sesiones para hacer lugar al cache, y las claves de auth tienen TTL, así que ninguna política `volatile-*` las protege. Para auth la política tiene que ser `noeviction`. Si el cache necesita LRU, Redis aparte para el cache. Decisión del proyecto; queda en Deuda del `CHANGELOG.md`.

## Cómo se ve en `redis-cli`

```
> SCAN 0 MATCH auth:* COUNT 100
1) "0"
2) 1) "auth:fam:{5c2a...}"
   2) "auth:uid:{u_42}"
> HGETALL auth:fam:{5c2a...}
1) "uid"   2) "u_42"
3) "cur"   4) "9f86d0...b2b7"
5) "iat"   6) "1761100000000"
> TTL auth:fam:{5c2a...}
(integer) 2591880
> SMEMBERS auth:uid:{u_42}
1) "5c2a..."
2) "e71b..."       ← otro dispositivo
```

## Fuentes

- `../../web-security/references/jwt.md` y `cookies.md`: el flujo, las cookies, los códigos de error, los tests.
- [Redis, scripting con Lua](https://redis.io/docs/latest/develop/interact/programmability/eval-intro/): atomicidad de `EVAL`, hash tags.
- [Redis, key expiration](https://redis.io/docs/latest/develop/using-commands/keyspace/#key-expiration): `EXPIRE` deslizante.
- [ioredis, `defineCommand`](https://github.com/redis/ioredis#lua-scripting): scripts como métodos.
- [OWASP, refresh token rotation and reuse detection](https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_for_Java_Cheat_Sheet.html): la familia y el reuso, como lo describe `jwt.md`.
