# Docker: la imagen base va una vez, en un stage `base`

Decisión cerrada: **cada imagen externa aparece en un solo `FROM` literal, con alias `AS base`. Los demás stages heredan con `FROM base`.** Nunca la imagen en un `ARG`, nunca la misma imagen repetida en dos `FROM`.

## Regla

```dockerfile
# bien: un FROM literal, los stages heredan del alias
FROM registry/imagen:1.2.3@sha256:<digest> AS base
WORKDIR /app

FROM base AS build
# ...

FROM base AS runtime
# ...
```

```dockerfile
# mal 1: la misma imagen dos veces. Dos lugares que mover; un día uno queda atrás
FROM registry/imagen:1.2.3 AS build
FROM registry/imagen:1.2.3 AS runtime

# mal 2: la imagen en un ARG. Queda prolijo y el bot de updates no la ve
ARG IMAGE=registry/imagen:1.2.3@sha256:<digest>
FROM ${IMAGE} AS build
```

## Por qué

- **Un solo lugar para el pin.** La versión y el digest (`docker-pin-digest.md`) viven en una línea. Build y runtime no pueden divergir: lo que se testeó es lo que corre.
- **Los bots solo leen `FROM` literal.** Dependabot no expande `ARG`: el pedido está abierto desde 2019 (dependabot-core #2057), un intento se revirtió, y los duplicados se cerraron "not planned" (#4597, #10190). Peor: con la imagen en un `ARG`, Dependabot reporta la dependencia como "ya no se usa" y deja de mirarla. Renovate expande un `ARG` de un nivel, pero no documenta anidados ni digest dentro del `ARG`.
- **`FROM base` no es una imagen.** Es una referencia a un stage del mismo archivo. Ningún bot lo toca, ningún registry lo resuelve, no hay nada que pinear. Docker lo soporta desde que existe multi-stage.
- **Es lo que hace el open source que tiene bot.** immich: un `FROM ...@sha256 AS builder`, y después `FROM builder AS sdk`, `FROM sdk AS web`, `FROM sdk AS cli`. Un pin, siete stages. Los que usan `ARG` con digest (n8n) no tienen bot y lo mueven a mano.

## Cuándo cambia

- Dos imágenes externas distintas (toolchain para compilar, distroless para correr): dos stages base, `AS build-base` y `AS runtime-base`. Sigue siendo un `FROM` literal por imagen.
- Nunca por "el `ARG` queda más prolijo". Prolijo y sin bot es una versión congelada.

## Qué pasa si no

| Atajo | Lo que cuesta |
|---|---|
| `ARG IMAGE=...` + `FROM ${IMAGE}` | Dependabot calla. El pin se congela sin que nadie lo sepa. Es el peor escenario: peor que no pinear, porque parece cubierto |
| La misma imagen en dos `FROM` | el bot mueve las dos; a mano se mueve una. Build con una versión, runtime con otra |
| `FROM base` pero `base` sin digest | el stage resuelve el problema de la repetición y nada más. Sin digest, `docker-pin-digest.md` |

## Cómo se verifica

```bash
grep -c '^FROM .*@sha256:' apps/api/Dockerfile    # 1 por imagen externa
grep -E '^FROM \$\{|^ARG .*(IMAGE|VERSION)=' apps/api/Dockerfile   # vacío
```

Y en GitHub, Insights → Dependency graph → Dependabot: el Dockerfile tiene que estar listado con su imagen. Si no está, el bot no lo mira.

## Fuentes

- [dependabot-core #2057, Add global ARG support for Dockerfiles](https://github.com/dependabot/dependabot-core/issues/2057): abierto desde 2019, sin maintainer asignado.
- [dependabot-core #4597](https://github.com/dependabot/dependabot-core/issues/4597) y [#10190](https://github.com/dependabot/dependabot-core/issues/10190): cerrados "not planned". El segundo documenta el "dependencia ya no se usa".
- [Renovate, manager `dockerfile`](https://docs.renovatebot.com/modules/manager/dockerfile/): "Renovate will automatically expand variables and ARG directives", un nivel.
- [immich, `server/Dockerfile`](https://github.com/immich-app/immich/blob/main/server/Dockerfile): el patrón en producción.
- [Docker, multi-stage builds](https://docs.docker.com/build/building/multi-stage/): `FROM <stage>` para reusar un stage.
