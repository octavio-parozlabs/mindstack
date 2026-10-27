# Checklist de seguridad

Referencia rápida por superficie. Se usa junto con la skill `seguridad`; los patrones concretos están en [patterns.md](patterns.md). Agnóstica al lenguaje: lo específico de web (headers, CSP, cookies, CORS, CSRF) está en `mindstack:web-security`.

## Índice

- [Modelo de amenazas (empezar acá)](#modelo-de-amenazas-empezar-acá)
- [Antes de commitear](#antes-de-commitear)
- [Entrada](#entrada)
- [Identidad y permisos](#identidad-y-permisos)
- [Secretos](#secretos)
- [Datos sensibles](#datos-sensibles)
- [Dependencias](#dependencias)
- [Concurrencia e idempotencia](#concurrencia-e-idempotencia)
- [IA / LLM](#ia--llm)
- [Errores](#errores)
- [Auditoría: REVIEW-security.md](#auditoría-review-seguridadmd)
- [OWASP Top 10, referencia rápida](#owasp-top-10-referencia-rápida)

## Modelo de amenazas (empezar acá)

- [ ] Fronteras de confianza mapeadas (requests, archivos, webhooks, APIs de terceros, colas, salida de LLM, valores locales escritos por procesos que no controlás)
- [ ] Activos nombrados (credenciales, datos personales, pagos, acciones de admin, movimiento de plata)
- [ ] STRIDE pasado por cada frontera (suplantación, manipulación, repudio, fuga, denegación, elevación)
- [ ] Casos de abuso escritos al lado de los casos de uso ("¿cómo lo rompería?")

## Antes de commitear

- [ ] Sin secretos en el diff (`git diff --cached | grep -iE "password|secret|api[_-]?key|token"`)
- [ ] `.gitignore` cubre `.env`, `.env.*.local`, `*.pem`, `*.key`
- [ ] `.env.example` con placeholders, no valores reales
- [ ] Sin credenciales en tests ni fixtures

## Entrada

- [ ] Toda entrada externa validada por esquema en la frontera; lo de adentro usa solo el valor tipado
- [ ] Allowlist, no denylist; campos no declarados se descartan
- [ ] Longitudes y rangos acotados; formatos (email, URL, fecha) con la librería del stack
- [ ] Queries parametrizadas; comandos por `argv` sin shell; sin concatenación de entrada en ningún intérprete
- [ ] Salida a HTML por el auto-escape del motor; HTML ajeno sanitizado con allowlist
- [ ] Archivos: tipo por allowlist, tamaño acotado, contenido verificado, nombre generado por el servidor
- [ ] URLs validadas antes de redirigir (open redirect)
- [ ] Fetch de URLs ajenas: allowlist de esquema y host, rangos privados y reservados bloqueados, sin redirecciones (SSRF)
- [ ] Operaciones destructivas sobre paths derivados: symlinks resueltos, raíz permitida, profundidad mínima, propiedad leída antes de operar, y al rechazar se para sin caer a un path más amplio

## Identidad y permisos

- [ ] Contraseñas con bcrypt (≥ 12 rondas), scrypt o argon2
- [ ] Tokens verificados en cada uso: firma, expiración, emisor, audiencia
- [ ] Sesiones con expiración acotada; el detalle de cookies en `mindstack:web-security`
- [ ] Tokens de reset: un solo uso, ≤ 1 hora, invalidados al cambiar la contraseña
- [ ] Rate limiting en login, reset y verificación (≤ 10 intentos / 15 min), con store compartido si hay más de una instancia
- [ ] Cada endpoint protegido verifica autenticación
- [ ] Cada acceso a un recurso verifica dueño o permiso sobre *ese* id (IDOR), probado con la sesión de otro usuario
- [ ] Endpoints de admin verifican el rol en el handler, no por la ruta
- [ ] Claves de API, roles y cuentas de servicio con mínimo privilegio
- [ ] Cambios en flujos de auth, roles nuevos o permisos elevados aprobados por la persona antes

## Secretos

- [ ] Vienen del entorno o de un gestor de secretos; la ausencia falla rápido
- [ ] Ninguno en código, tests, fixtures, logs ni historial
- [ ] Si alguno llegó a un remoto: rotado primero, historia purgada después

## Datos sensibles

- [ ] Cada campo personal clasificado (no personal, personal, sensible) al agregarlo
- [ ] Recolectado contra un propósito declarado; "capaz lo usamos" no es propósito
- [ ] Campos sensibles fuera de toda respuesta, por allowlist de campos
- [ ] Contraseñas, tokens, tarjetas completas y datos de salud fuera de los logs
- [ ] Cifrado en tránsito siempre; en reposo cuando la clase lo exige; backups cifrados
- [ ] Retención definida; borrado que funciona de punta a punta (backups, caches, índices, analytics)
- [ ] Exportar y borrar a pedido del titular, donde la jurisdicción lo exige
- [ ] Compartir con terceros (analytics, ads, LLM) con consentimiento y acuerdo de procesamiento
- [ ] Categoría nueva de dato sensible aprobada por la persona antes

## Dependencias

Primero ubicá la **raíz de instalación**: la que tiene el manifiesto y el lockfile (en un monorepo, la raíz del workspace). Ahí tienen que coincidir el gestor declarado, el lockfile y lo que corre CI. Si no coinciden o hay dos lockfiles, pará.

| Gestor | Instalación reproducible | Auditoría nativa |
|---|---|---|
| npm | `npm ci` | `npm audit` |
| pnpm | `pnpm install --frozen-lockfile` | `pnpm audit` |
| Yarn 2+ | `yarn install --immutable` | `yarn npm audit -A -R` |
| pip | `pip install -r requirements.txt` con hashes, o `pip-sync` | `pip-audit` |
| Cargo | `cargo build --locked` | `cargo audit` |
| Go | `go mod verify` | `govulncheck` |
| Bundler | `bundle install --frozen` | `bundle audit` |

Para otro gestor o versión, su documentación oficial; no se sustituyen comandos de otro.

- [ ] Un solo lockfile por raíz, commiteado; CI nunca lo reescribe
- [ ] Instalación reproducible desde el lockfile en CI
- [ ] Scripts de instalación de dependencias bloqueados por defecto; cada excepción revisada (fuente y versión) y registrada en la política nativa del gestor
- [ ] Auditoría nativa antes de cada release; críticas y altas triageadas por alcanzabilidad; diferimientos con motivo y fecha
- [ ] Nunca remediación forzada automática; cada upgrade previsualizado, con changelog leído y probado
- [ ] Firmas o procedencia del registro verificadas donde el gestor lo soporta
- [ ] Dependencia nueva: justificada, dueño y mantenimiento revisados, edad del release, grafo transitivo, nombre correcto (typosquatting)

## Concurrencia e idempotencia

- [ ] Toda operación con efecto que se puede reintentar lleva clave de idempotencia o consulta estado antes de repetir
- [ ] Leer-decidir-escribir en una transacción o con escritura condicional atómica
- [ ] "Verificar que no existe y crear" resuelto con constraint único, no con un `find` previo
- [ ] Verificaciones sobre paths o permisos seguidas de la operación sin ventana para que un proceso ajeno cambie el estado

## IA / LLM

Para cualquier feature que llame a un modelo (chat, resúmenes, agentes, RAG):

- [ ] Salida del modelo tratada como hostil: nunca a `eval`, SQL, shell, DOM ni paths; parseada y validada por esquema
- [ ] Inyección de prompt asumida; permisos aplicados en código, no en el system prompt
- [ ] Secretos, datos de otros tenants y el system prompt completo fuera del contexto
- [ ] Herramientas del agente con mínimo privilegio; acciones destructivas o irreversibles con confirmación
- [ ] Tope de tokens, tasa y profundidad de recursión
- [ ] Embeddings de RAG particionados por tenant; documentos validados antes de indexar

## Errores

```text
// Producción: genérico hacia afuera, detalle al log con id de correlación
responder 500 { code: INTERNAL_ERROR, message: "Algo falló", requestId }

// NUNCA en producción:
responder 500 { error: err.message, stack: err.stack, query: err.sql }
```

- [ ] Respuestas de error sin stack traces, queries, rutas ni versiones internas
- [ ] Errores de auth sin revelar si la cuenta existe
- [ ] Eventos de seguridad logueados (login fallido, cambio de permisos, acceso rechazado) sin datos sensibles

## Auditoría: REVIEW-security.md

Cuando la skill audita, el único resultado es este archivo, con solo hallazgos:

- [ ] Tabla `ID | Severidad | Archivo:línea | Qué falla, con qué entrada | CB | Fix en una línea`
- [ ] IDs `SEC-n` correlativos; severidad `crítica` / `alta` / `media` / `baja`
- [ ] Cada fila con la entrada hostil concreta (payload, id, header, nombre de archivo) y un fix
- [ ] Máximo 15; lo no confirmado bajo "A verificar", una línea cada uno
- [ ] Hallazgos preexistentes incluidos y marcados "preexistente"
- [ ] Sin elogios, sin "considerá", sin nits de estilo
- [ ] Conteo por severidad al final

## OWASP Top 10, referencia rápida

| # | Vulnerabilidad | Prevención |
|---|---|---|
| 1 | Control de acceso roto | autorización por recurso en cada handler |
| 2 | Fallos criptográficos | transporte cifrado, hash fuerte, sin secretos en código |
| 3 | Inyección | queries parametrizadas, validación por esquema |
| 4 | Diseño inseguro | modelo de amenazas antes de escribir |
| 5 | Configuración insegura | defaults seguros, mínimo privilegio, headers (web) |
| 6 | Componentes vulnerables | auditoría nativa, dependencias mínimas y pineadas |
| 7 | Fallos de autenticación | hash fuerte, rate limiting, sesiones acotadas |
| 8 | Fallos de integridad | lockfile único, firmas verificadas, scripts de instalación revisados |
| 9 | Fallos de logging | eventos de seguridad logueados, sin secretos en logs |
| 10 | SSRF | allowlist de URLs, rangos privados bloqueados |

Para features con LLM, el OWASP Top 10 para aplicaciones LLM cubre lo mismo desde el lado del modelo: inyección de prompt, fuga por el contexto, salida sin validar, agencia excesiva, consumo sin tope.
