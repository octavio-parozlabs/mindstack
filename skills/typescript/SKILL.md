---
name: typescript
description: >-
  Experto en TypeScript para front y back. Qué librería para qué y cuáles nunca (lodash-es, Zod en un paquete de contratos, Vitest para todo, Biome para formato, ESLint con reglas de tipos, ESM); reglas de tipos strict sin any ni as, errores tipados con cause, promesas siempre manejadas, estructura por feature con named exports y 300 líneas, estilo, dependencias justificadas, contratos schema-first, config con Zod, tests colocados que mockean solo la frontera, seguridad del lenguaje; hooks PostToolUse y Stop; cómo se cumple el CI. Usar al escribir o revisar .ts o .tsx, elegir o agregar una librería, configurar tsconfig, lint, formato, tests o cobertura.
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.mts"
  - "tsconfig*.json"
  - "eslint.config.*"
  - "biome.json"
  - "vitest.config.*"
  - "package.json"
---

# TypeScript

El lenguaje: lo que vale para todo archivo `.ts`, sea front o back. Lo de React está en la skill `react`, lo de la API en `node-api` y `nestjs`; las tres asumen esto. La arquitectura es `architecture`; la forma de trabajar, `workflow`.

Es una guía de **con qué**. No se reemplaza ni se discute por tarea: si algo no sirve para un caso, se plantea en un PR aparte, con el por qué. Nunca se instala primero.

## Con qué

| Para | Se usa | Nunca | Regla |
|---|---|---|---|
| utilidades de datos | `lodash-es`, import por función | reimplementar `groupBy`, `debounce`, `uniqBy` | `references/dependencies.md` |
| validación y tipos del borde | Zod, schemas en `packages/contracts`, tipo con `z.infer` | interfaces a mano, `JSON.parse` sin parsear, validación duplicada | `references/contracts.md` |
| runner de tests | Vitest, para todo: funciones, componentes, endpoints | Jest | `references/TESTING.md` |
| cobertura | `@vitest/coverage-v8` con thresholds `autoUpdate`; `diff-cover` en CI sobre el diff del PR | umbral global como única guardia, bajar el umbral para que pase | `references/ci.md` |
| contenedores | `Dockerfile` multi-stage por app, `docker compose` con profile `observability` | README con pasos de instalación a mano | skill `docker-ci` |
| formato | Biome (`examples/biome.json`), solo el formateador | Prettier, dos formateadores, reglas de formato en ESLint | `references/style.md` |
| lint | ESLint (typescript-eslint), con reglas que usan tipos (`examples/eslint.config.js`) | el linter de Biome encima de ESLint, desactivar reglas para que pase. Cambia cuando Biome cubra `no-floating-promises` con tipos | `references/style.md` |
| módulos | ESM | CommonJS nuevo | `references/structure.md` |
| runtime | Node 24, versión exacta en `.nvmrc`, la misma en el `FROM` del `Dockerfile` con digest | `FROM node:24` flotante | skill `docker-ci` |

Una librería entra en esta tabla cuando ya se decidió que es **la** opción para ese problema. Hasta entonces, es una dependencia más y sigue `references/dependencies.md`: se justifica en el PR.

## Reglas

Una línea por regla. La referencia tiene el por qué y el ejemplo bueno y malo; leerla cuando la tarea toca ese tema.

| Regla | La decisión | Referencia |
|---|---|---|
| Tipos | `strict` completo. Sin `any`, sin `!`, sin `@ts-ignore`; `as` solo con el por qué en la misma línea. Tipar lo exportado. Uniones discriminadas para estados. El compilador es el primer test | `references/types.md` |
| Errores | solo instancias de `Error` o subclases, por dominio, con `cause`, mensaje con el qué y el cuál. Nunca `catch` vacío; atrapar solo donde se puede hacer algo. Validar en la frontera, confiar adentro | `references/errors.md` |
| Async | toda promesa se espera, se devuelve o se maneja. `async` solo si hay `await`. `Promise.all` si es independiente, `allSettled` si un fallo no frena al resto. Cancelación con `AbortSignal` | `references/async.md` |
| Estructura | carpetas por feature, no por tipo. Named exports, sin barrels, imports `@/`. 300 líneas por archivo. `shared/` solo para lo que usan dos o más y no importa de features | `references/structure.md` |
| Estilo | nombres: `camelCase` con verbo para funciones, `PascalCase` para tipos. Funciones que entran en pantalla, máximo 3 parámetros, sin booleanos sueltos. Comentarios para el porqué, no el qué | `references/style.md` |
| Dependencias | antes de agregar una: ¿lo hace Node? ¿ya está en el stack? ¿son 20 líneas? Cada una se justifica en el PR. Lockfile commiteado, `npm ci`, `npm audit` high/critical no se ignora | `references/dependencies.md` |
| Contratos | `packages/contracts` es la única fuente de lo que cruza entre `api` y `web`. Schema primero, tipo derivado, sin lógica, solo `zod`. Un cambio incompatible lleva front y back en el mismo PR | `references/contracts.md` |
| Config | `config.ts` es el único archivo que lee `process.env`: `EnvSchema.safeParse`, `process.exit(1)` si falta algo, `Object.freeze`. El lint lo fuerza | `references/config.md` |
| Tests | Vitest, colocados al lado del archivo. Por comportamiento, un `expect` por comportamiento, mockear solo la frontera, builders. Bug arreglado = test que fallaba antes. Sin `skip` ni `only` commiteados | `references/tests.md` |
| Seguridad | XSS: texto plano en JSX, `DOMPurify` si hay HTML de datos; inyección: queries parametrizadas, `path.join` chequeado; SSRF: hosts por allowlist; uploads: tipo por contenido, nombre propio, nunca servidos como script; tokens nunca en `localStorage`; secretos nunca en el bundle | `references/security.md` |

## Qué fuerza y qué solo pide

| Criterio | Cómo se fuerza |
|---|---|
| sin `any`, `!`, `as`; promesas manejadas; named exports; sin `console`; sin `test.only`; `process.env` solo en `config.ts`; 300 líneas | `tsconfig` strict + `examples/eslint.config.js`. Cada regla ahí tiene un comentario con el `.md` que la explica |
| formato | `examples/biome.json`, aplicado por el hook `PostToolUse` en cada edición |
| lint del archivo recién editado | hook `PostToolUse`: `examples/hooks/post-edit.sh` corre ESLint `--fix` y devuelve lo que no se arregla solo |
| tipos, lint, tests verdes antes de terminar | hook `Stop`: `examples/hooks/stop-check.sh` sobre todo el proyecto |
| código nuevo trae su test | cobertura del diff en CI, ratchet global en `vitest.config.ts`: `references/ci.md` |
| estructura, nombres, errores | solo esta skill: Claude lee y aplica con criterio |

Dónde va una verificación nueva: mira un solo archivo y tarda segundos → `PostToolUse`; necesita el proyecto entero → `Stop`; necesita la rama base, secretos o Docker → CI. Más temprano de lo que corresponde frena cada edición; más tarde, se entera después de que Claude cerró el turno. Si `post-edit.sh` tarda (ESLint con tipos carga el proyecto la primera vez; `--cache` lo amortiza), sacar la línea de ESLint y dejar Biome: el `Stop` lo atrapa igual.

## Tests por capa

Vitest corre todo; lo que cambia por capa es lo que se le suma. Config y ejemplo por capa: `references/TESTING.md` (unitario), skill `react` (componente, e2e), skill `node-api` (integración de API, contrato).

| Capa | Qué prueba | Vitest + | Entorno |
|---|---|---|---|
| unitario | una función o un service, sin I/O | nada más | `node` |
| componente | qué muestra un componente, qué pasa al clickear | Testing Library + jest-dom + user-event | `happy-dom` |
| integración de API | request → handler → service → repository → response | supertest o `app.inject`, DB de test | `node` |
| contrato | que un response real cumple el schema de `contracts` | Zod, dentro del de integración | `node` |
| end-to-end | un flujo de usuario en el browser real | Playwright | browser |

## Supuestos

| Decisión | Default | Ajustable |
|---|---|---|
| Layout | monorepo `apps/api` + `apps/web` + `packages/contracts` + `packages/ui` | sí; los `paths:` de las skills asumen estos nombres |
| Gestor de paquetes | el que tenga el repo; npm en los ejemplos | sí, en `settings.json` y `stop-check.sh` del proyecto |
| Tests | Vitest | sí; Jest funciona igual |
| Formato / lint | Biome / ESLint con typescript-eslint | lint ajustable a Biome cuando sus reglas con tipos cubran `no-floating-promises` |
| Validación en fronteras | Zod | sí; cualquier schema validator |
| Runtime, pin por digest, bot | Node 24 exacta en `.nvmrc` | la versión sí; el pin y el bot no (`docker-ci`) |

## Ejemplos

Archivos para que el proyecto escriba los suyos siguiéndolos; nunca se copian ni se enlazan.

- `examples/eslint.config.js`: las reglas que se fuerzan, cada una con el `.md` que la explica.
- `examples/biome.json`: formato.
- `examples/settings.json`: permisos (`allow` para tests, lint, typecheck; `deny` para `.env`, `rm -rf`, `push --force`) y los dos hooks.
- `examples/hooks/post-edit.sh`, `examples/hooks/stop-check.sh`.
- `references/ci.md`: el `ci.yml` completo.
