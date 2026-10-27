# CI

Decisión cerrada: **el CI es la guardia que el humano ya no puede ser.** Con un LLM escribiendo la mayoría del código, el volumen de cambios supera lo que una revisión manual atrapa. Lo que se quiere garantizar se escribe como check que rechaza el PR; lo que no se puede escribir como check, se asume que no está garantizado.

Tres checks que no son los habituales (typecheck, lint, tests) y por qué cada uno existe:

| Decisión | Valor | Por qué | Cuándo cambia |
|---|---|---|---|
| Cobertura **del diff** | 100% de las líneas tocadas en el PR, o no se mergea | el número global miente: con 87% total, un PR puede meter 200 líneas sin test y bajar a 86%. Nadie lo ve. Sobre el diff, una línea nueva sin test es rojo y se sabe en qué PR entró | nunca. Es la única métrica que atribuye |
| Cobertura **total** | umbral = cobertura actual, solo sube | ratchet. No bloquea por deuda vieja, impide que crezca. Cuando llega a 100, el reporte pasa a ser detector de deltas: cualquier línea sin test es visible | cuando llega a 100 se iguala al check del diff y uno de los dos sobra |
| Tamaño de archivo | 300 líneas por archivo, forzado por el linter (número ajustable) | un archivo de 1500 líneas degrada a quien lo lee, humano o modelo: más tokens por lectura, ediciones que pisan otras, más contexto para un cambio chico. Con un LLM generando, el archivo crece sin que nadie lo decida | el número, por proyecto. El mecanismo no |
| Secretos | scanner sobre el diff de cada PR, en un job aparte | está en `../../workflow/references/git.md` | |
| Patrones prohibidos | `scripts/check.sh`, en CI y en la revisión (`scripts/check.sh` del plugin), falla si aparecen: `origin: true`, `origin: '*'`, `origin: /`, `type: '*/*'`, `express.urlencoded()` global, `secure: process.env.NODE_ENV`; y `process.env` fuera de `config` | son las seis líneas que apagan `../../web-security/references/cors.md`, `content-type.md` y `cookies.md`, y las seis se escriben "para que ande en dev". `process.env` suelto apaga `config.md`. Un lint de una línea las frena en el PR | la lista crece cuando una regla nueva tenga su atajo de una línea |
| Imagen Docker | se buildea en cada PR, no se publica | un `Dockerfile` roto se entera en el PR, no en el deploy. Está en `docker.md` | |
| Actions por SHA | `uses: owner/action@<sha40>  # vX.Y.Z`. Nunca `@v4` | un tag de action se mueve igual que uno de Docker. En marzo 2025 movieron todos los tags de `tj-actions/changed-files` a código que volcaba los secretos del CI; quien pineaba por SHA no corrió nada. Dependabot `github-actions` mantiene el SHA y el comentario: `docker-updates-bot.md` | nunca |
| Runtime verificado | la versión del runner y la de la imagen se comparan con el archivo de versión; la imagen se escanea | el setup usa tool cache y Docker usa capas: "pasó CI" sin el check no dice qué versión corrió. Está en `docker-runtime-verified.md` | |

## Por qué 100 sobre el diff y no "un porcentaje razonable"

Un umbral con holgura no atribuye. Umbral 85, proyecto en 87: el primer PR sin tests pasa, el segundo falla y el culpable es el equivocado. Umbral 100 sobre el diff: falla el PR que metió la línea, y la línea aparece en el reporte con nombre y número.

No es "testear todo": es que **todo lo que se escribe nuevo** trae su test, que ya era regla de `../../workflow/SKILL.md`. El check solo la hace mecánica.

## Con qué

Lo dice el stack, no este archivo: `../../typescript/references/ci.md`. Lo que todo stack tiene que proveer para que el core funcione:

| El core pide | El stack provee |
|---|---|
| un reporte de cobertura en formato Cobertura XML | el runner de tests del lenguaje con su reporter |
| un comando `coverage:diff` que falla bajo el umbral | `diff-cover` sobre ese reporte contra la base del PR, o el equivalente del lenguaje |
| un umbral global que solo sube | el runner, si lo soporta; si no, un script que compara con el último valor commiteado |
| límite de líneas por archivo en el linter | la regla del linter del lenguaje |
| un job de CI con: setup del runtime y check de su versión, install, typecheck, lint, `scripts/check.sh`, tests con cobertura, `coverage:diff`, build de imagen, check de versión en la imagen, scan de la imagen. El scanner de secretos va en su propio job (`../../workflow/references/git.md`) | el `ci.yml` del stack, con esos pasos en ese orden, y las actions por SHA |

Alternativa sin herramienta propia: Codecov con `patch` status al 100. Mismo resultado, una cuenta y un token más.

## Dónde lo ve Claude

- Límite de líneas y umbral global corren en el `Stop hook` del stack (lint y tests). Claude no termina el turno con un archivo de 400 líneas ni con la cobertura global bajando.
- La cobertura del diff corre en CI y en `coverage:diff` local: el loop de `../../workflow/SKILL.md` lo tiene en su Done.

## Qué pasa si no

| Atajo | Lo que cuesta |
|---|---|
| Umbral global y nada más | el 20% sin cubrir se llena de código nuevo. El número no se mueve, la deuda sí |
| Umbral del diff en 80 "para no trabar" | 20% de cada PR entra sin test. Después de 50 PRs, es el mismo problema con otro nombre |
| Sin límite de archivo | el LLM agrega al archivo que ya tiene abierto. A los tres meses hay un `service.ts` de 2000 líneas que nadie, ni el modelo, puede leer entero |
| Bajar el umbral para que pase | la regla deja de existir. Si una línea no se puede testear, se discute esa línea, no el número |
| `uses: actions/x@v4` "porque es lo que muestra la doc" | el día que muevan el tag, el workflow corre lo que haya ahí, con los secretos del repo en el entorno |

## Cómo se verifica que frena

Un PR de prueba, antes de confiar en el pipeline:

1. Una función nueva sin test → `coverage:diff` rojo, con el archivo y la línea.
2. Un archivo de 310 líneas → lint rojo.
3. Borrar un test existente → thresholds rojos.

Si alguno pasa, el check no está activo.

## Fuentes

- [diff-cover](https://github.com/Bachmann1234/diff_cover): cobertura sobre el diff contra una rama base, `--fail-under`.
- [OpenSSF Scorecard, check `Pinned-Dependencies`](https://github.com/ossf/scorecard/blob/main/docs/checks.md#pinned-dependencies): actions por SHA, no por tag.
- [GitHub Docs, Security hardening for GitHub Actions](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions#using-third-party-actions): "pin actions to a full length commit SHA".
- [OX Security, lecciones de tj-actions/changed-files](https://www.ox.security/blog/15-hours-of-open-sourced-hell-lessons-learned-from-tj-actions-changed-files/): el incidente de marzo 2025.
- [ESLint, `max-lines`](https://eslint.org/docs/latest/rules/max-lines): el límite de líneas por archivo como regla de lint (ilustración del stack de referencia).
