---
name: node-api
description: >-
  Experto en una API en Node con Express, Fastify o Hono. Qué librería para qué y cuáles nunca (Node 24 exacto en .nvmrc y en el FROM con digest, config.ts con Zod, pino con requestId, jose y node:crypto para la sesión, helmet para headers y CSP, supertest o app.inject para tests), la forma de todo endpoint: validar al entrar con el schema del contrato, un error handler, respuestas que cumplen el contrato; el Dockerfile de producción. Usar al escribir o revisar handlers, services, repositories, middlewares, config o tests en apps/api sin NestJS, y al escribir su Dockerfile.
paths:
  - "apps/api/**"
  - "**/Dockerfile*"
---

# API en Node

El back. Asume la skill `typescript`: lo que está ahí no se repite. Si el proyecto usa NestJS, además la skill `nestjs`, que va encima de esta. Las decisiones de seguridad (tokens, cookies, `Origin`, CORS, body, CSP, headers, config) son de la skill `web-security`; acá está con qué se cumplen.

## Con qué

| Para | Se usa | Nunca | Regla |
|---|---|---|---|
| runtime | Node 24, versión exacta en `.nvmrc`, la misma en el `FROM` del `Dockerfile` con digest | `FROM node:24` flotante, la imagen en un `ARG` | skill `docker-ci` |
| framework HTTP | el que tenga el repo (Express, Fastify, Hono); la forma del endpoint es la misma | cambiarlo | `references/backend.md` |
| config | `config.ts` con schema de Zod sobre `process.env`, congelado | `process.env` suelto | `../typescript/references/config.md` |
| logs | logger estructurado (pino por defecto) con `requestId`, JSON a stdout | `console.log`, logs a archivo | `references/backend.md`, `../docker-ci/references/docker.md` |
| auth | `jose` para JWT, `node:crypto` para el refresh, cookie del framework | tokens en `localStorage`, `Authorization: Bearer` desde el browser | `../web-security/references/jwt.md`, `cookies.md` |
| headers de seguridad | `helmet` / `@fastify/helmet`, CSP con nonce por request | CSP por `<meta>`, `'unsafe-inline'` en scripts | `../web-security/references/csp.md`, `headers.md` |
| tests de endpoints | supertest o `app.inject` sobre el app en memoria, DB de test | levantar el server real | `references/TESTING.md` |

Una librería entra en esta tabla cuando ya se decidió que es **la** opción para ese problema. Hasta entonces, sigue `../typescript/references/dependencies.md`: se justifica en el PR.

## Reglas

`references/backend.md`: toda entrada se valida con el schema del contrato al entrar; toda salida cumple el schema del contrato; adentro se confía en los tipos. Un solo error handler que mapea los errores de dominio al formato de `architecture` §5. El orden de los middlewares de seguridad está en `../web-security/SKILL.md`.

## Tests

Integración de un endpoint entero (request → handler → service → repository → response) y test de contrato (el response real cumple el schema): `references/TESTING.md`, con la config de Vitest para `apps/api` y un ejemplo.

## Dockerfile

`examples/Dockerfile`: multi-stage, la imagen base una sola vez en `FROM node:<exacta>-alpine@sha256:… AS base`, `build` y `runtime` heredan con `FROM base`, usuario sin privilegios, `CMD` en exec form. El proyecto escribe el suyo siguiéndolo; `scripts/check.sh` verifica digest, stage base y que `.nvmrc` coincida con el `FROM`.
