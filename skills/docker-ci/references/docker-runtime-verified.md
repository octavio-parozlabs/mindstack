# Docker: la versión del runtime se verifica, no se asume

Decisión cerrada: **CI compara la versión que corre, en el runner y dentro de la imagen, contra el archivo de versión del lenguaje, y falla si no coinciden. Y escanea la imagen construida: un CVE alto o crítico con fix disponible rechaza el PR.** "Pasó CI" sin esto solo dice que corrió alguna versión.

## Regla

Tres steps en el job de CI, después de instalar el runtime y después de construir la imagen. El stack da los comandos exactos (`../../typescript/references/ci.md`); la forma es esta:

```yaml
# después de setup del runtime: el runner corre la versión del archivo, no una del cache
- run: test "$(<runtime> --version)" = "v$(cat <archivo-de-version>)"

# después de docker build: la imagen corre la misma
- run: test "$(docker run --rm api:ci <runtime> --version)" = "v$(cat <archivo-de-version>)"

# scanner sobre la imagen construida: alto o crítico con fix disponible, rojo
- uses: aquasecurity/trivy-action@<sha>   # vX.Y.Z
  with: { image-ref: "api:ci", severity: "HIGH,CRITICAL", exit-code: "1", ignore-unfixed: "true" }
```

El archivo de versión es uno solo, en la raíz, el que el lenguaje ya use (`.nvmrc`, `.python-version`, `.tool-versions`). El `Dockerfile` y el `setup` del CI lo leen o lo repiten; el check obliga a que coincidan.

## Por qué

- **El setup del runtime usa cache.** Las actions de setup buscan primero en el tool cache preinstalado del runner. Con una versión mayor o un rango, usan lo que haya en cache aunque exista una más nueva en el manifest. Semanas después de un security release, un runner puede seguir corriendo la versión anterior. La versión exacta más el check cierran eso.
- **El build de Docker usa cache.** Una capa ya pulleada no vuelve a consultar el registry. El digest lo resuelve en CI (`docker-pin-digest.md`); el check es la prueba de que la imagen que se construyó corre lo que el archivo dice, en cualquier máquina.
- **Un advisory puede pedir rebuild, no solo upgrade.** Hay vulnerabilidades que quedan horneadas en artefactos del build (snapshots de arranque, caches de entropía). Reconstruir la imagen desde cero en CI lo cumple; el check de versión confirma que se reconstruyó con la nueva.
- **Dependabot no sabe de CVEs de imágenes.** Abre el PR cuando hay tag nuevo, sin decir qué corrige. El scanner es el que lista cada CVE con severidad y link a la advisory. Sobre el PR del bot, da el diff: la imagen vieja fallaba por X, la nueva pasa.
- **Es lo que convierte la pregunta en verificable.** "¿Estamos seguros de que corremos una versión sin la vulnerabilidad?" tiene respuesta: el step de versión verde, el scanner verde, en este commit.

## Límites

- El scanner cubre los paquetes del sistema de la imagen y las dependencias del lenguaje. El binario del runtime en una imagen oficial no siempre entra por el gestor de paquetes del sistema, así que la cobertura de CVEs del runtime mismo es parcial. Para esos, la señal es el advisory del runtime (los proyectos serios tienen RSS) y el PR del bot que llega al día siguiente. El check de versión es el que prueba que se aplicó.
- `ignore-unfixed: true`: solo falla por CVEs que ya tienen fix. Sin eso, un CVE de la base sin parche disponible deja el PR rojo sin que nadie pueda hacer nada, y el equipo aprende a ignorar el rojo. Ajustable a `false` cuando se quiera ver todo.

## Cuándo cambia

- El scanner: Trivy por defecto porque es gratis, sin cuenta, y corre como action. Grype o Docker Scout hacen lo mismo; Scout además compara dos digests y muestra el diff de CVEs, con cuenta Docker. Ajustable.
- La severidad: `HIGH,CRITICAL`. Bajar a `MEDIUM` cuando el proyecto esté limpio y se quiera mantener así.

## Qué pasa si no

| Atajo | Lo que cuesta |
|---|---|
| `setup` con versión mayor y sin check | el runner usa la del tool cache. Se cree que corre la parcheada y corre la anterior durante semanas |
| sin check en la imagen | el Dockerfile dice una versión y la imagen que se deployó es otra, por cache o por un build en otra máquina. Se descubre en producción |
| scanner sin `exit-code: 1` | es un reporte que nadie lee. El PR entra igual |
| scanner solo en `main`, no en PRs | se entera después de mergear. El PR era el momento de frenar |

## Cómo se verifica

Un PR de prueba que cambie solo el archivo de versión a una que no coincide con el `Dockerfile` → el check de la imagen rojo. Si pasa, el check no compara lo que debe.

## Fuentes

- [actions/setup-node, `check-latest`](https://github.com/actions/setup-node#check-latest-version): por qué el tool cache puede devolver una versión vieja. Mismo comportamiento en las otras actions de setup.
- [Trivy, GitHub Action](https://github.com/aquasecurity/trivy-action): `image-ref`, `severity`, `exit-code`, `ignore-unfixed`.
- [Docker Scout, compare](https://docs.docker.com/scout/): la alternativa con diff entre digests.
- [Node.js, security releases de octubre 2026](https://nodejs.org/en/blog/vulnerability/october-2026-security-releases): el caso que motivó el criterio. El advisory pide rebuild de artefactos por una de las CVEs.
