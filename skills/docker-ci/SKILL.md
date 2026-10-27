---
name: docker-ci
description: >-
  Entrega y verificación mecánica, como decisiones cerradas: docker compose con profiles y un entorno aislado por plan, observabilidad opcional, imagen base una sola vez en "FROM … AS base" con tag exacto y digest, Dependabot que mueve los pins, versión del runtime verificada contra el archivo de versión y escaneo de la imagen, CI que mide cobertura del diff al 100, ratchet global, 300 líneas por archivo, secretos, actions por SHA y patrones prohibidos. Usar al escribir o revisar Dockerfile, docker-compose, .dockerignore, .github/workflows, dependabot, .nvmrc, observability/ o la config de cobertura.
paths:
  - "**/Dockerfile*"
  - ".dockerignore"
  - "docker-compose*.y*ml"
  - "compose*.y*ml"
  - "observability/**"
  - ".seed/**"
  - ".github/**"
  - "renovate.json*"
  - ".nvmrc"
  - ".python-version"
  - ".tool-versions"
  - "**/coverage*"
  - "**/*.config.*"
---

# Docker y CI: lo que la máquina garantiza

Con un modelo escribiendo la mayoría del código, la revisión humana no alcanza. Lo que se quiere garantizar se escribe como check que rechaza el PR; lo que no se puede escribir como check, se asume que no está garantizado. Y la imagen que corre en producción tiene que ser exactamente la que se pensó: pineada, verificada, con alguien que la mueva.

## Decisiones cerradas

| Tema | Decisión | Referencia |
|---|---|---|
| Entornos | `docker-compose.yml` con profiles; Postgres como DB; cada plan corre su stack aislado (`-p <slug>`, puertos por env, DB copiada de la de dev); observabilidad (logs JSON a stdout, métricas de host, sin métricas de app ni tracing por defecto) en un profile aparte, en su propia red, que no se levanta por plan; infra publicada solo en loopback; logs de Docker con tope; migraciones en un servicio que corre una vez | `references/docker.md` |
| Imagen base | cada imagen externa aparece **una vez**, en `FROM <imagen> AS base`; los demás stages `FROM base`. Nunca en un `ARG`: Dependabot no lo expande | `references/docker-base-stage.md` |
| Pin | todo `FROM` con tag exacto y `@sha256:<digest>`. El tag para la persona, el digest para Docker | `references/docker-pin-digest.md` |
| Quién mueve el pin | Dependabot con `docker`, `github-actions` y el ecosistema del lenguaje. Un pin sin bot no existe: o están los dos, o ninguno | `references/docker-updates-bot.md` |
| Runtime verificado | la imagen se buildea en cada PR, no se publica. CI compara `<runtime> --version` del runner y de la imagen construida contra el archivo de versión del lenguaje (`.nvmrc` o equivalente), y falla si no coinciden. La imagen se escanea: CVE alto o crítico con fix disponible rechaza el PR | `references/docker-runtime-verified.md` |
| Cobertura | 100 sobre el diff del PR: es el único número que atribuye cada línea sin test al PR que la metió. Umbral global que solo sube (ratchet) | `references/ci.md` |
| Tamaño de archivo | 300 líneas, forzado por el linter. El número es ajustable; el mecanismo no | `references/ci.md` |
| Secretos | scanner de secretos sobre el diff de cada PR, en su propio job; `.env` ignorado desde el primer commit | `references/ci.md`, `../workflow/references/git.md` |
| Actions | `uses: owner/action@<sha40>  # vX.Y.Z`, nunca `@v4`. Dependabot mantiene el SHA y el comentario | `references/ci.md` |
| Patrones prohibidos | un script en CI que falla si aparecen las líneas que apagan la seguridad: `origin: true`, `origin: '*'`, `type: '*/*'`, `express.urlencoded()` global, `secure: process.env.NODE_ENV`, `process.env` fuera de `config` | `references/ci.md`, `../../scripts/check.sh` |

## El mismo script, local y en CI

`${CLAUDE_PLUGIN_ROOT}/scripts/check.sh` corre los checks mecánicos (patrones prohibidos, `process.env`, digest y stage base, `.nvmrc` = `FROM`, actions por SHA) y sale 1 con `archivo:línea` si algo falla. La skill `verify` lo ejecuta antes de decir "listo"; el `ci.yml` del proyecto lo corre después del lint. Lo que falla local va a fallar en el PR.

## Qué pasa si no

| Atajo | Lo que cuesta |
|---|---|
| `FROM node:24-alpine` sin digest | la imagen cambia por debajo sin PR; "en mi máquina andaba" con la misma línea |
| la imagen en un `ARG` | Dependabot no la ve: el pin queda congelado para siempre |
| umbral de cobertura "razonable" (85) | el PR sin tests pasa; el siguiente falla y el culpable es el equivocado |
| `@v4` en una action | marzo 2025: todos los tags de `tj-actions/changed-files` movidos a código que volcaba los secretos del CI |
| "pasó CI" sin comparar versiones | el runner usó una del tool cache y la imagen otra: nadie sabe qué versión corrió |
| observabilidad levantada por plan | diez planes no caben en una máquina de desarrollo |

## Con qué, en cada stack

Esta skill no nombra runners ni gestores de paquetes. Con qué se cumple en TypeScript (reporter de cobertura, umbral que sube solo, límite de líneas en el linter, setup del runtime por archivo de versión, scanner de imagen): `../typescript/references/ci.md`, con un `ci.yml` completo para seguir. El `Dockerfile` de una API en Node: `../node-api/examples/Dockerfile`. Los workflows de los agentes (`pr.yml`, `implement.yml`) y `dependabot.yml`: `../workflow/examples/github/`.

## Qué pedirle a Claude

> "Mostrame los `FROM` del Dockerfile y los `uses:` de los workflows. Una imagen externa, con digest, en `AS base`; todas las actions por SHA. Después corré `check.sh`."
