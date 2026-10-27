# Docker: un bot mueve los pins

Decisión cerrada: **todo pin tiene un bot que abre un PR cuando hay versión nueva.** Dependabot por defecto, con `docker`, `github-actions` y el ecosistema del lenguaje. Un pin sin bot no existe en esta forma de trabajo: o están los dos, o no está ninguno.

## Regla

El archivo listo está en `../examples/dependabot.yml`; `/mindstack:install` escribe el del proyecto siguiéndolo y completa el ecosistema del lenguaje. Lo esencial:

```yaml
version: 2
updates:
  - package-ecosystem: docker           # cada FROM con digest: tag y digest nuevos en un PR
    directory: /apps/api                # donde está el Dockerfile
    schedule: { interval: daily }
  - package-ecosystem: github-actions   # cada uses: @<sha>: SHA nuevo, comentario de versión al día
    directory: /
    schedule: { interval: daily }
```

Lo que llega es un PR con un diff de una línea por imagen:

```diff
- FROM registry/imagen:1.2.3@sha256:0a1b2c... AS base
+ FROM registry/imagen:1.2.4@sha256:9f8e7d... AS base
```

CI corre sobre ese PR como sobre cualquier otro. Verde, una persona lo mergea. Rojo, se mira antes de que llegue a producción.

## Qué hace y qué no

| Hace | No hace |
|---|---|
| mira los `FROM` literales con imagen y digest, y los `uses:` con SHA | expandir `ARG` en `FROM` (por eso `docker-base-stage.md`) |
| abre un PR cuando el registry tiene un tag o digest más nuevo | decir qué vulnerabilidad corrige esa versión: para imágenes no tiene base de CVEs. Eso lo da el scanner (`docker-runtime-verified.md`) |
| para el ecosistema del lenguaje, además abre PR por CVE publicado contra un paquete que se usa | mergear. Siempre es un PR que alguien aprueba; es el control |
| mantiene el comentario `# vX.Y.Z` al lado del SHA de una action | mover el archivo de versión del runtime (`.nvmrc` o el equivalente del lenguaje). Eso se sube en el mismo PR, y el check de versión del CI obliga a que coincidan |

## Por qué

- **Pinear congela.** Un digest es una foto. Sin alguien que la mueva, la imagen deja de recibir los rebuilds de seguridad de su base y se vuelve vulnerable en silencio. Chainguard lo pone así: la violación de seguridad no es `latest`, son "slow-moving processes that leave users on out-of-date software". OneUptime: un digest quieto "turns reproducibility into staleness".
- **"Alguien se acuerda" no es un mecanismo.** Es el que dejó un runtime EOL seis meses en una plantilla. Los proyectos open source que pinean con `ARG` y sin bot (n8n) lo mueven a mano porque tienen un equipo pagado mirando advisories. Un proyecto chico no.
- **Dependabot ya está en GitHub.** Sin instalar nada, sin cuenta externa. Es el piso. Renovate es más capaz, pero es una app más que autorizar.

## Cuándo cambia

| Situación | Alternativa |
|---|---|
| el Dockerfile necesita `ARG` para la imagen, o agrupar varios PRs en uno, o pinear digests automáticamente en archivos que no lo tienen | Renovate, con `config:recommended` y `docker:pinDigests`. Expande `ARG` de un nivel. Mismo criterio, otra herramienta |
| GitHub Enterprise sin Dependabot | Renovate self-hosted |
| el intervalo | `daily` para `docker` y `github-actions` porque un security release no espera; `weekly` para el lenguaje porque el volumen es mayor. Ajustable |

## Qué pasa si no

| Atajo | Lo que cuesta |
|---|---|
| pin a mano, "lo subimos cuando sale algo" | nadie lee el advisory el día que sale. Se descubre en el próximo incidente, o cuando un scanner externo lo marca |
| bot configurado pero el Dockerfile no está en `directory` | silencio total. Parece cubierto y no lo está. Se verifica en Insights, no se asume |
| auto-merge de los PRs del bot | el PR del bot es el único camino por el que entra una imagen nueva. Con auto-merge, ese camino no tiene a nadie mirando. Un digest comprometido entra solo |
| ignorar los PRs del bot "porque son muchos" | se acumulan y el pin vuelve a estar congelado. Si son muchos, Renovate agrupa; no se apagan |

## Cómo se verifica

1. Insights → Dependency graph → Dependabot, en GitHub: lista cada archivo que mira y cuándo lo revisó por última vez. El Dockerfile y los workflows tienen que estar.
2. El primer PR llega dentro de las 24 horas del próximo tag nuevo en el registry. Si pasa una semana desde un security release y no hay PR, el bot no está mirando ese archivo.

## Fuentes

- [GitHub Docs, Dependabot `package-ecosystem: docker`](https://docs.github.com/en/code-security/dependabot/working-with-dependabot/dependabot-options-reference#package-ecosystem-): qué mira y cómo actualiza tag y digest.
- [Renovate, Docker](https://docs.renovatebot.com/docker/): digest pinning y `pinDigests`.
- [Chainguard, How I learned to stop worrying and love the latest tag](https://www.chainguard.dev/unchained/how-i-learned-to-stop-worrying-and-love-the-latest-tag): el pin es un mecanismo, no una foto.
- [OneUptime, pin by digest and keep it updated](https://oneuptime.com/blog/post/2026-07-29-pin-chainguard-digest-security-updates/view): staleness, PR con diff, rollback al digest anterior.
- [dependabot-core #2057](https://github.com/dependabot/dependabot-core/issues/2057): por qué no `ARG`.
