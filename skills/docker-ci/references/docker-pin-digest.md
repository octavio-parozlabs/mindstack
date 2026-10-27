# Docker: la imagen se pinea por tag exacto y digest

Decisión cerrada: **todo `FROM` lleva tag exacto y `@sha256:<digest>`.** El tag es para la persona que lee; el digest es lo que Docker pullea. Un pin sin bot que lo mueva no es un pin, es una versión congelada: va con `docker-updates-bot.md`, siempre.

## Regla

```dockerfile
# bien: tag exacto para leer, digest para pullear
FROM registry/imagen:1.2.3@sha256:0a1b2c...  AS base
```

```dockerfile
# mal 1: tag flotante. Resuelve a "lo último que haya" en el momento del pull
FROM registry/imagen:1 AS base

# mal 2: tag exacto sin digest. Parece fijo y no lo es
FROM registry/imagen:1.2.3 AS base
```

El digest se obtiene así, y es el del índice multi-arch (Docker elige la arquitectura solo):

```bash
docker buildx imagetools inspect registry/imagen:1.2.3 | head -3
```

## Por qué

- **Un tag es un puntero mutable.** Incluso uno exacto. Las imágenes oficiales lo mueven a propósito: cuando la base saca un parche, reconstruyen `imagen:1.2.3` y lo publican bajo el mismo tag con otro contenido. Dos builds en días distintos con la misma línea dan dos imágenes distintas. Y quien tenga acceso al repo de la imagen, legítimo o no, puede apuntar el tag a lo que quiera.
- **Un digest es el contenido.** SHA-256 del manifest. Docker pullea y compara; si no coincide, falla el build. Ni el registry, ni un mirror, ni un proxy, ni un cache de CI pueden devolver otra cosa bajo ese digest.
- **El tag flotante tiene una ventana vulnerable.** En un security release, la imagen parcheada llega al registry horas o un día después del advisory. Hasta entonces `imagen:1` apunta a la vulnerable. Con digest + bot, el PR llega cuando la imagen existe, y vos sabés qué corrés en cada momento.
- **Es el criterio de OpenSSF Scorecard.** El check `Pinned-Dependencies` define pin como "explicitly set to a specific hash instead of allowing a mutable version". Un tag exacto no cuenta. Remediación textual: "For Dockerfiles used in building and releasing your project, pin dependencies by hash".
- **El precedente es real.** Marzo 2025, `tj-actions/changed-files`: el atacante movió todos los tags de versión a un commit que volcaba secretos de CI. Quien referenciaba `@v45` o `@v45.0.7` lo corrió. Quien pineaba por SHA, no. Un tag de Docker es el mismo mecanismo.
- **El lockfile ya hace esto.** Cada paquete del lockfile tiene su `integrity` con hash. El digest es la misma idea para la imagen base.

## Qué cubre y qué no

| Amenaza | Tag exacto | Digest |
|---|---|---|
| tag flotante resuelve a una versión vieja | sí | sí |
| el dueño del repo re-publica el tag con otro contenido | no | sí |
| cuenta de maintainer comprometida, re-push del tag | no | sí |
| mirror, proxy o cache de registry devuelve otra imagen | no | sí |
| la imagen ya era maliciosa cuando se pineó | no | no: firmas y attestations (`cosign`), fuera de alcance acá |
| alguien con write en el repo cambia la línea | no | no: branch protection y revisión de PR |
| dependencias del lenguaje comprometidas | no | no: lockfile y su hash |

## Cuándo cambia

Nunca. Lo único que cambia es quién mueve el digest, y eso lo dice `docker-updates-bot.md`.

## Qué pasa si no

| Atajo | Lo que cuesta |
|---|---|
| `imagen:1` flotante, "así se actualiza solo" | se actualiza cuando el registry quiere, no cuando vos sabés. Un día antes del parche corrés la vulnerable sin forma de saberlo. Y el cache de Docker puede no volver a consultar el registry |
| tag exacto sin digest, "ya está fijo" | está fijo el nombre, no el contenido. Es la ilusión de reproducibilidad |
| digest sin bot | una versión congelada que se vuelve vulnerable en silencio. Es cómo un runtime termina seis meses después de su EOL en la plantilla de todos los proyectos |

## Cómo se verifica

```bash
grep -E '^FROM ' apps/api/Dockerfile | grep -vE '^FROM [a-z-]+ AS|@sha256:[0-9a-f]{64}'   # vacío: todo FROM externo tiene digest
docker buildx imagetools inspect "$(grep -oE 'registry/imagen:[^ ]+' apps/api/Dockerfile)" | head -3    # el digest existe y es el del índice
```

## Fuentes

- [OpenSSF Scorecard, check `Pinned-Dependencies`](https://github.com/ossf/scorecard/blob/main/docs/checks.md#pinned-dependencies): pin = hash; manifest list para multi-arch; riesgo Medium.
- [Docker, referencia de `FROM`](https://docs.docker.com/reference/dockerfile/#from): `FROM <image>[:<tag>][@<digest>]`.
- [Chainguard, How I learned to stop worrying and love the latest tag](https://www.chainguard.dev/unchained/how-i-learned-to-stop-worrying-and-love-the-latest-tag): prefiere digest sobre tag de versión porque el tag "implies a deliberate choice that may be stale".
- [OneUptime, pin by digest and keep it updated](https://oneuptime.com/blog/post/2026-07-29-pin-chainguard-digest-security-updates/view): el digest hace el build "reproducible and immutable"; el tag flotante "delegates the update moment to the next pull".
- [OX Security, lecciones de tj-actions/changed-files](https://www.ox.security/blog/15-hours-of-open-sourced-hell-lessons-learned-from-tj-actions-changed-files/) y [Lullabot, ADR: pin GitHub Actions to a commit hash](https://architecture.lullabot.com/adr/20260505-pin-github-actions-to-hash/): el incidente y la decisión que sacaron de él.
