---
name: nestjs
description: >-
  Experto en NestJS sobre una API en Node. Qué librería para qué y cuáles nunca (nestjs-zod con los schemas del contrato, AppError más un AppExceptionFilter global con cadena de mappers, @nestjs/config con validate de Zod y getOrThrow, nestjs-pino, TypeORM con entidades por módulo, guards que leen la cookie o x-api-key y roles por metadata, qs y un árbol de filtros validado para listados, @nestjs/testing con supertest) y el orden para adoptar cada pieza. Usar cuando el proyecto tiene @nestjs/core y se escriben o revisan módulos, controllers, providers, guards, filters, pipes, entidades, config o tests.
paths:
  - "apps/api/**"
---

# NestJS

Va encima de la skill `node-api` y asume `typescript`: lo que está ahí no se repite. El dominio nunca sabe de HTTP; Nest es el adapter.

## Con qué

| Para | Se usa | Nunca | Regla |
|---|---|---|---|
| framework | NestJS sobre el adapter de Express | cambiar el adapter sin PR | |
| validación de entrada | `nestjs-zod` (`ZodValidationPipe` global) con los schemas de `packages/contracts` | `class-validator`, DTOs con decoradores, un schema para el pipe y otro para el front | `../typescript/references/contracts.md` |
| errores | `AppError` del dominio + `AppExceptionFilter` global con una cadena de mappers | `HttpException` desde dominio o repositorio, `try/catch` que pone status en el handler | `references/exceptions.md` |
| config | `@nestjs/config` con `validate` de Zod, `ConfigService<Env, true>`, `getOrThrow` | Joi, `.get()` sin tipo, `process.env` fuera de `config/` | `references/config.md` |
| logger | `nestjs-pino` + `pino-http`, `bufferLogs: true`, `app.useLogger` | `Logger` default a texto, `console.log`, loguear headers de auth | `references/logger.md` |
| ORM | TypeORM, entidades por módulo, `createQueryBuilder` para listados | SQL concatenado, `find()` con un `where` que puede traer `undefined` | `references/filters.md`, `references/guards.md` |
| auth | guard que lee la cookie de acceso o `x-api-key`, verifica con `jose`, deja `request.user`; roles por metadata; recurso por port | `jsonwebtoken`, `Bearer` desde el browser, `if (user.role)` en handlers | `references/guards.md`, `../web-security/references/jwt.md` |
| query strings anidados | `qs` en los dos lados; un param decorator re-parsea solo `filter` | cambiar el query parser global de Express | `references/filters.md` |
| filtros de listados | árbol `and`/`or` validado en forma, whitelist por endpoint, `where` de TypeORM | un query param por columna y un `if` por parámetro | `references/filters.md` |
| tests | `@nestjs/testing` + supertest sobre `app.init()` | levantar el server real, mockear módulos propios | `references/TESTING.md` |

## Reglas

| Regla | La decisión | Referencia |
|---|---|---|
| Excepciones | un solo error de dominio (`AppError`), un solo filtro que atrapa todo, un solo formato de salida: el de `architecture` §5 | `references/exceptions.md` |
| Guards | auth en un guard, no en handlers; roles por metadata (`@AllowedRoles`); el acceso a un recurso lo decide un port del dominio, no el guard | `references/guards.md` |
| Config | el módulo `config/` es el único que lee el entorno; `validate` con el schema de Zod; `getOrThrow` tipado | `references/config.md` |
| Logger | Pino desde el primer log (`bufferLogs: true`), `requestId` en cada línea, nunca headers de auth | `references/logger.md` |
| Filtros de listados | un árbol `and`/`or` que llega por `filter`, se valida en forma y contra una whitelist por endpoint, y se traduce a `where` de TypeORM | `references/filters.md` |

## Orden para adoptar

En un proyecto nuevo, en este orden; cada uno antes del momento en que su ausencia empieza a costar.

1. `references/config.md`. Diez minutos; ahorra la primera hora de debugging.
2. `references/exceptions.md`. Antes de escribir el primer use case.
3. `references/logger.md`. Antes del primer deploy.
4. `references/guards.md`. Cuando aparece el primer rol.
5. `references/filters.md`. Cuando aparece la segunda tabla con filtros. Antes es prematuro.

## Tests

Lo que suma el contenedor de Nest: `Test.createTestingModule` arma el contenedor igual que en producción y `overrideProvider(X).useValue(fake)` reemplaza **solo** la frontera; `supertest` sobre `app.init()` sin puerto. Vitest necesita SWC para los decoradores. Config y ejemplo: `references/TESTING.md`.
