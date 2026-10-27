# Changelog: Autenticación con JWT: access + refresh rotativo, sesiones por dispositivo en Postgres, SPA y API en subdominios

Memoria del plan mientras se ejecuta. Lo escriben los agentes al terminar cada paso; nadie reescribe, solo se agrega abajo. Quién: `developer` · `tester` · `reviewer` · `fixer` · `resolver` · `person`.

## Cambios

| Fecha | Quién | Qué | Evidencia |
|---|---|---|---|
| | | | |

## Observaciones

| Fecha | Quién | Qué vio | Dónde |
|---|---|---|---|
| 2026-10-22 | persona | la tabla `refresh_tokens` del core guarda una fila por rotación y no dice quién borra las vencidas. Un usuario activo deja ~50 filas por día. La tabla `sessions` de este pre-plan (una fila por sesión, hash vigente adentro, purga a 90 días) la reemplaza; PR al core cuando esté probada | `../web-security/references/jwt.md` § Tabla |
| 2026-10-22 | persona | `jwt.md` acepta que el access siga valiendo hasta 10 min después de revocar. Con pantalla de dispositivos eso es un bug visible. El check de sesión con cache de 60 s es una fila "cuándo cambia" para la decisión "Logout" del core | `../web-security/references/jwt.md` § Las decisiones |

## Decisiones

| Fecha | Quién | Decisión | Alternativa descartada | Principio |
|---|---|---|---|---|
| 2026-10-22 | persona | la sesión es una entidad que el usuario ve: tabla `sessions` en Postgres con dispositivo, IP, fechas | Redis, una clave por familia (`notes/redis-rejected.md`): sin durabilidad, sin historia, sin consultas, un datastore más. Era buena idea mientras la sesión era un detalle del refresh | explícito antes que implícito; las entidades de dominio viven en la DB (skill `architecture` §3) |
| 2026-10-22 | persona | una fila por sesión con el hash del refresh vigente; reuso = presentar otro hash | una fila por rotación con `used_at` (la tabla de `jwt.md`): crece sin tope, necesita purga agresiva | lo simple antes que lo complejo |
| 2026-10-22 | persona | rotación con un `UPDATE ... WHERE refresh_hash = $presented ... RETURNING` | transacción `SELECT FOR UPDATE` + `UPDATE` + `INSERT` | una sola forma obvia: el row lock ya es la transacción |
| 2026-10-22 | persona | el middleware de auth consulta si la sesión está revocada, con cache en memoria de 60 s por `sid` | aceptar 10 min (core): invisible sin pantalla, inaceptable con ella. Deny list en Redis: instantáneo, pero un datastore y un round-trip por request | práctico antes que puro: 60 s cubre la feature sin infra; el caso especial (varias instancias, instantáneo) cambia el nivel por PR |
| 2026-10-22 | persona | `sid` en claro dentro del refresh (`sid.secret`) | índice por `sha256(token)` | una sola forma obvia: la fila se deriva del token |
| 2026-10-22 | persona | `DELETE /auth/sessions/:id` de otro usuario → `404` | `403` | no revelar existencia: `WHERE user_id = $uid` da 0 filas y listo |
| 2026-10-22 | persona | cerrar la sesión actual desde la pantalla = logout (revoca, borra cookies, el front va a `/login`) | `400 usá /auth/logout`: una regla más para el front sin ganar nada | una sola forma obvia |
| 2026-10-22 | persona | el front no sabe cuándo vence el access y no lo necesita: asume acceso, `401 TOKEN_EXPIRED` → refresh → reintento | `accessExpiresAt` en el body + refresh anticipado: ahorra un round-trip cada 10 min por pestaña a cambio de estado duplicado en el front. Decodificar el JWT: imposible, es `httpOnly` | lo simple antes que lo complejo: un mecanismo, un lado |
| 2026-10-22 | persona | refresh opaco (32 bytes aleatorios, hasheado), no JWT | refresh como JWT firmado con `exp` y `sub` adentro: duplica lo que ya está en la fila, y su único uso sería validarlo sin DB, que es justo lo que un token revocable no puede hacer | una sola forma obvia: la fila es la fuente de verdad del refresh |
| 2026-10-22 | persona | `navigator.locks` entre pestañas + probe antes de refrescar; en el servidor, gracia de 10 s para el refresh anterior | solo dedupe por pestaña (dos pestañas se revocan entre sí); solo gracia sin lock (cada pestaña rota igual, N rotaciones por vencimiento); `BroadcastChannel` a mano (es lo que Web Locks ya resuelve) | los errores nunca pasan en silencio: "me desloguea solo" era un bug de diseño, no de usuario |
| 2026-10-22 | persona | UTC en todas las fechas que cruzan el borde (`Z`), epoch en las comparaciones, hora local solo al mostrar; tests con dos `TZ` | `TZ=UTC` en el servidor y confiar: un `new Date('2026-10-22 15:40')` sin zona en cualquier lado lo rompe | los errores nunca pasan en silencio: un test con otra `TZ` los hace ruido |
| 2026-10-22 | persona | DB caída → `503`, nunca `SESSION_REVOKED` | tratar todo error como sesión inválida | los errores nunca pasan en silencio, y un incidente de infra no es un logout |
| `TODO` | | `ua-parser-js` vs guardar solo el `ua` crudo y parsear en el front | | a decidir en el proyecto; lo que entre va a la tabla "Con qué" de la skill `node-api` |

## Deuda técnica

| Fecha | Quién | Qué falta | Por qué no ahora | Issue |
|---|---|---|---|---|
| 2026-10-22 | persona | geolocalización de IP y mail de "nuevo inicio de sesión" | cada uno es un plan chico aparte; la tabla ya guarda lo que necesitan | |
| 2026-10-22 | persona | tope absoluto de sesión (90 días) | nadie lo pidió; es un `AND created_at >` en el `UPDATE` | |
| 2026-10-22 | persona | invalidación instantánea entre instancias (pub/sub) | 60 s alcanza para la pantalla; si no, es el momento de Redis | |

## Revisión

| Ronda | Hallazgos | Resueltos | Pendientes y por qué |
|---|---|---|---|
| | | | |

## Conflictos

| Fecha | Archivo | Decisión |
|---|---|---|
| | | |

## Cierre

