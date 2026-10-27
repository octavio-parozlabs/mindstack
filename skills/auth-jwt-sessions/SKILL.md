---
name: auth-jwt-sessions
description: >-
  Diseño de referencia de autenticación para una SPA y una API en subdominios: login con email y password, access JWT de 10 minutos, refresh rotativo con detección de reuso, sesiones por dispositivo en Postgres que el usuario lista y cierra, cookies httpOnly host-only. Usar cuando la persona quiera implementar, revisar, auditar o refactorizar login, sesiones, tokens, refresh, logout o "cerrar sesión en otros dispositivos", o pregunte si su auth está bien hecha. No aplica a la emisión de tokens con un IAM externo (Auth0, Cognito, Keycloak); sí aplica lo de cookies, Origin, interceptor y pantalla de dispositivos.
---

Pre-plan: orientativo, no regla. Un pre-plan es un PLAN.md de referencia para un tema recurrente: `/mindstack:draft` parte de él cuando el tema coincide. Lo cerrado que asume y no rediscute: `../web-security/references/jwt.md`, `cookies.md`, `origin.md`.

Dos modos, según lo que pide la persona:

- **Auditar** ("¿está bien mi auth?", "revisá el login"): leé `${CLAUDE_SKILL_DIR}/PLAN.md`, sección "Estado final", y marcá cada línea como cumple / no cumple con evidencia del repo (`archivo:línea`, `grep`, `graphify query`). No cambies nada. Lo que no cumple y es del core (`jwt.md`, `cookies.md`, `origin.md`) es un hallazgo; lo que no cumple y es de este pre-plan es una diferencia, no un error: decilo así.
- **Planificar** ("implementemos login", "refactoricemos la auth"): no armes el plan acá. El plan del proyecto lo arma `/mindstack:draft <slug>`, que parte de esta carpeta, la cruza con el repo y completa los `TODO`. Decile que lo corra. Si ya estás dentro de `/mindstack:draft`, seguí sus pasos.

Archivos, cada uno se lee entero cuando hace falta, en este orden:

| Archivo | Qué tiene | Cuándo leerlo |
|---|---|---|
| `PLAN.md` | diagramas de refresh, de cerrar sesión desde otro dispositivo y de lock entre pestañas; tabla de duraciones; estado final verificable; 14 tareas; riesgos | siempre que la skill se dispare |
| `CHANGELOG.md` | las decisiones ya tomadas, cada una con la alternativa descartada y el principio; observaciones al core | antes de proponer algo distinto: capaz ya se descartó |
| `notes/sessions.md` | el diseño en Postgres: tabla `sessions`, el `UPDATE` de rotación, cache de revocación de 60 s, captura de dispositivo | al implementar o al auditar el back |
| `notes/redis-rejected.md` | el diseño con Redis, por qué se descartó y cuándo vuelve (deny list multi-instancia) | solo si el proyecto tiene varias instancias o ya usa Redis |

Si el proyecto tiene IAM externo: la emisión es de ellos. Lo que sigue valiendo de acá: cookies, `Origin`, interceptor del front y la pantalla de dispositivos.
