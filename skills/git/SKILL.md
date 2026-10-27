---
name: git
description: >-
  Prácticas generales de git, agnósticas al lenguaje: commits atómicos y
  frecuentes, mensajes con Conventional Commits que explican el porqué,
  ramas cortas, rebase antes que merge, higiene pre-commit (secretos, tests,
  diff revisado), git como herramienta de debugging (bisect, blame, log),
  versionado semántico, tags inmutables y changelog de release escrito para
  humanos. Usar cuando se commitea, se arma una rama, se resuelve un conflicto,
  se parte un working tree sucio en commits limpios, se decide si un cambio es
  major, minor o patch, se taguea un release o se escribe un changelog. Las
  reglas de ramas, prefijos de commit y .gitignore del flujo de tareas viven en
  la skill mindstack:workflow (skills/workflow/references/git.md); esta skill es lo general.
---

# Git

## Resumen

Git es la red de contención. Los commits son puntos de guardado, las ramas son
cajas de arena, el historial es documentación. Con agentes generando código a
velocidad, la disciplina de versionado es lo que mantiene los cambios
revisables y reversibles.

## Cuándo usar

Siempre. Todo cambio de código pasa por git.

## Principios

### 1. Commiteá temprano, commiteá seguido

Cada incremento que funciona se commitea. No acumules cambios sin commitear.

```
Así:   implementar una porción → testear → verificar → commit → siguiente
No:    implementar todo → esperar que ande → commit gigante
```

Si el próximo cambio rompe algo, `git reset --hard HEAD` te devuelve al
último estado sano. Nunca perdés más de un incremento.

### 2. Commits atómicos

Un commit hace una sola cosa lógica.

```
# Bien: cada commit se entiende solo
a1b2c3d feat: endpoint de creación de tareas con validación
d4e5f6g feat: formulario de creación de tareas
h7i8j9k feat: conectar formulario a la API con estado de carga
m1n2o3p test: creación de tareas (unitarios + integración)

# Mal: todo mezclado
x1y2z3a tareas, arreglo sidebar, deps, refactor de utils
```

### 3. Mensajes que explican el porqué

El diff ya dice *qué* cambió. El mensaje dice *por qué*.

```
# Bien
feat: validar formato de email en el registro

Evita que lleguen emails inválidos a la base. Valida en el handler
de la ruta, igual que el resto de la validación en auth.

# Mal
update auth
```

Formato (Conventional Commits):

```
<tipo>(<ámbito opcional>): <descripción corta, en imperativo>

<cuerpo opcional: el porqué, no el qué>
```

Tipos: `feat` (funcionalidad nueva) · `fix` (bug) · `refactor` (ni fix ni
feat) · `test` · `docs` · `chore` (tooling, deps, config) · `perf` · `ci`.

Un `!` después del tipo o un pie `BREAKING CHANGE:` marcan un cambio
incompatible; eso decide el bump de versión (ver más abajo).

### 4. Una preocupación por commit

No mezcles formato con comportamiento, ni refactor con feature. Cada tipo de
cambio es un commit aparte, idealmente un PR aparte.

```
# Bien
git commit -m "refactor: extraer validación a utilidad compartida"
git commit -m "feat: validar teléfono en el registro"

# Mal
git commit -m "refactor validación y agregar teléfono"
```

Un refactor y una feature son dos cambios distintos: se mandan por separado,
así cada uno se revisa, se revierte y se entiende solo. Una limpieza chica
(renombrar una variable) puede ir dentro del commit de la feature.

### 5. Tamaño

Apuntá a ~100 líneas por commit o PR. Más de ~1000 se parte.

```
~100 líneas   → fácil de revisar, fácil de revertir
~300 líneas   → aceptable para un cambio lógico
~1000 líneas  → partir
```

## Ramas

`main` siempre desplegable. Ramas cortas que vuelven en 1-3 días. Una rama
que vive semanas diverge, acumula conflictos y atrasa la integración.

```
main ──●──●──●──●──●──●──●──  (siempre desplegable)
        ╲      ╱  ╲    ╱
         ●──●─╱    ●──╱       ← ramas cortas
```

- Partí de `main` (o de la rama por defecto del equipo).
- Borrá la rama después del merge.
- Trabajo incompleto detrás de un feature flag antes que una rama larga.
- Ramas de release son aceptables cuando hay que estabilizar mientras `main` avanza.

Nombres fuera del flujo de tareas: `feature/<qué>`, `fix/<qué>`,
`chore/<qué>`, `refactor/<qué>`.

### Rebase vs merge

Para ponerte al día con `main`: **rebase**. El historial queda lineal y cada
conflicto se resuelve commit por commit, con contexto. Un merge commit de
"sync" esconde cómo se resolvió cada conflicto.

```bash
git fetch origin
git rebase origin/main
# conflicto → resolver, git add, git rebase --continue
```

Merge se reserva para integrar la rama terminada en `main`, vía PR con `main`
protegida. Varias ramas a la vez, sin cambiar de rama en el mismo directorio:
`git worktree add ../proyecto-x feature/x` (en el flujo lo hace el hook; ver
`mindstack:workflow`, `skills/workflow/references/worktree.md`).

Rebasear reescribe los commits de tu rama. Después de un rebase el push
necesita `--force-with-lease`, nunca `--force`: `--force-with-lease` falla si
alguien pusheó en el medio; `--force` lo pisa.

## Higiene pre-commit

Antes de cada commit:

```bash
git diff --staged                                  # 1. leer lo que vas a commitear
git diff --staged | grep -iE "password|secret|api_key|token"   # 2. sin secretos
<tests>                                            # 3. tests en verde
<lint> && <typecheck>                              # 4. lint y tipos
```

Automatizalo con un hook de pre-commit del proyecto (el runner lo dice la
skill del stack). Un secreto commiteado no se arregla borrándolo: queda en el
historial. Se rota.

### Archivos generados

- Commitear generados solo si el proyecto los espera (lockfiles, migraciones).
- No commitear build (`dist/`, `build/`), entornos (`.env`), ni config
  personal del editor.
- Todo repo nace con `.gitignore` antes del primer commit.

## Partir un working tree sucio

Cuando hay cambios mezclados sin commitear, no hagas un commit "varios":

```bash
git add -p                 # stagear hunk por hunk, un tema por vez
git diff --staged          # confirmar que lo stageado es un solo tema
git commit
# repetir hasta que git status quede limpio
```

Si un archivo mezcla dos temas en el mismo hunk, `e` dentro de `add -p` edita
el hunk a mano.

## Git para debuggear

```bash
git bisect start && git bisect bad HEAD && git bisect good <commit-sano>
# git va checkouteando el medio; corrés el test en cada paso

git log --oneline -20
git diff HEAD~5..HEAD -- src/
git blame <archivo>
git log --grep="validación" --oneline
git log -S "nombreDeFuncion" --oneline   # cuándo apareció o desapareció un texto
```

## Release y versionado

Los commits son para vos; la **versión** es para quien consume tu código.
Cuando algo depende de vos (otro equipo, un paquete publicado, un cliente
desplegado), "lo último de main" deja de responder "qué estoy corriendo y es
seguro actualizar". Lo responden un número de versión y un changelog.

### Versionado semántico

`MAJOR.MINOR.PATCH`, y que el número cargue significado:

```
MAJOR  cambio incompatible: el consumidor tiene que tocar su código
MINOR  funcionalidad nueva, compatible: actualizar es seguro
PATCH  arreglo compatible: actualizar es seguro
```

El número es una promesa. Un "patch" que cambia un comportamiento del que
alguien dependía es un major disfrazado. Ante la duda, es breaking: un major
de sorpresa es más barato que un consumidor roto.

Con Conventional Commits el bump sale solo: `feat` → minor, `fix` → patch,
`!` o `BREAKING CHANGE:` → major.

### Tag inmutable como fuente de verdad

Un release es un punto fijo del historial, no una rama que se mueve.

```bash
git tag -a v1.4.0 -m "Release 1.4.0"
git push origin v1.4.0
```

La versión se deriva del tag; no se edita a mano en archivos sueltos, así el
artefacto, el tag y el changelog nunca se contradicen.

### Changelog de release, escrito para humanos

El changelog de release no es `git log`. Es la respuesta curada a "qué cambió
y me importa", agrupada en `Added / Changed / Fixed / Deprecated / Removed /
Security`, lo más nuevo arriba, cada entrada por impacto en el usuario.

```markdown
## [1.4.0] - 2025-06-12
### Added
- Importación masiva de tareas por CSV
### Fixed
- Desfase de zona horaria en tareas recurrentes
### Deprecated
- `GET /v1/tasks/all`: usar `GET /v1/tasks` paginado (se saca en 2.0)
```

La entrada se escribe en el mismo cambio que la produce, mientras el impacto
está fresco; no se reconstruye de los commits al momento del release. Un
cambio incompatible lleva nota de migración y ventana de deprecación.

Este changelog de release es distinto del `CHANGELOG.md` por tarea del flujo:
aquel registra decisiones, deuda y revisión de una tarea y reemplaza a los
ADRs; este es el contrato con los consumidores.

## En el flujo mindstack

Las reglas de ramas, commits y `.gitignore` del flujo de tareas están en la
skill `mindstack:workflow`, `skills/workflow/references/git.md`: una rama `worktree-<slug>` por
tarea, commits de movimiento de estado `plan(<slug>): …`, prefijos
`feat|fix|test|chore(<slug>)`, `review(<slug>): round n`, nadie mergea,
`--force-with-lease` solo el resolutor, `.gitignore` desde la plantilla. Lo
usan `/mindstack:orchestrate (fase pr)`, el agente `conflict-resolver` y el `developer`.
Esta skill es lo general que aplica también fuera del flujo.

## Racionalizaciones comunes

| Racionalización | Realidad |
|---|---|
| "Commiteo cuando termine la feature" | Un commit gigante no se revisa, no se debuggea, no se revierte. Commit por porción. |
| "El mensaje da igual" | Los mensajes son documentación. Vos y el próximo agente van a necesitar saber qué cambió y por qué. |
| "Después squasheo todo" | El squash borra la narrativa. Commits limpios desde el principio. |
| "Las ramas agregan overhead" | Las ramas cortas son gratis. El problema son las largas: volvé en 1-3 días. |
| "Después parto el cambio" | Un cambio grande se revisa peor y se revierte peor. Se parte antes de mandarlo. |
| "No necesito `.gitignore`" | Hasta que se commitea `.env` con secretos de producción. Primero el `.gitignore`. |
| "Es un fix chico, bump de patch" | Mirá lo que el consumidor puede observar. Si cambió un comportamiento del que dependía, es major. |
| "El changelog es el commit log" | Los commits son para vos; el changelog para los consumidores, curado por impacto. |
| "El changelog lo escribimos al release" | Para entonces el impacto se reconstruye de memoria y falta la mitad. Se escribe con el cambio. |
| "Un `--force` rápido y listo" | Pisa lo que otro pusheó mientras tanto. `--force-with-lease`, y solo sobre tu rama. |

## Señales de alarma

- Cambios grandes acumulados sin commitear.
- Mensajes tipo "fix", "update", "varios".
- Formato mezclado con comportamiento en el mismo commit.
- Sin `.gitignore`, o `node_modules/`, `.env`, build commiteados.
- Ramas largas que divergen mucho de `main`.
- `git push --force` sobre una rama compartida.
- Merge commits de "sync con main" en una rama de feature.
- Un cambio incompatible publicado como minor o patch.
- Release sin tag, o versión editada a mano fuera de sincronía con el tag.
- Release visible para usuarios sin entrada de changelog, o con commits volcados como changelog.

## Verificación

Por cada commit:

- [ ] Hace una sola cosa lógica.
- [ ] El mensaje explica el porqué y sigue Conventional Commits.
- [ ] Tests en verde antes de commitear.
- [ ] Sin secretos en el diff.
- [ ] Sin cambios de formato mezclados con comportamiento.
- [ ] `.gitignore` cubre las exclusiones estándar.

Por cada release (cualquier cosa con consumidores):

- [ ] El bump coincide con el cambio: incompatible → major, aditivo → minor, fix → patch.
- [ ] Está tagueado y la versión se deriva del tag.
- [ ] El changelog tiene una entrada curada, agrupada por impacto, para esta versión.
