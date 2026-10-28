# TESTING.md

Qué se testea en cada capa y con qué. Las reglas de cómo escribir un test están en `tests.md`; esto es la guía de herramientas y configuración.

## Una idea antes de las librerías

**Vitest corre todo.** Funciones, servicios, componentes, endpoints. No hay "Jest para componentes y Vitest para funciones": es un solo runner, y lo que cambia por capa es lo que se le suma.

| Capa | Qué prueba | Vitest + | Entorno |
|---|---|---|---|
| unitario | una función o un service, sin I/O | nada más | `node` |
| componente | un componente de React: qué muestra, qué pasa al clickear | Testing Library + jest-dom + user-event | `happy-dom` |
| integración de API | un endpoint entero: request → handler → service → repository → response | supertest o `app.inject`, DB de test | `node` |
| contrato | que un response real cumple el schema de `contracts` | Zod, dentro del test de integración | `node` |
| end-to-end | un flujo de usuario en el browser real contra la app levantada | Playwright | browser |

De arriba a abajo: más rápido y más cantidad arriba, más lento y menos cantidad abajo. La mayoría de los tests son unitarios y de componente.

Qué trae cada capa, con su config y ejemplo: unitario acá; componente y end-to-end en `../../react/references/TESTING.md`; integración de API y contrato en `../../node-api/references/TESTING.md`.

## Las librerías

| Librería | Qué hace |
|---|---|
| `vitest` | el runner: `describe`, `it`, `expect`, `vi.fn()`, `vi.mock()`, `vi.setSystemTime()` |

Qué **no**: Jest. Mismo rol que Vitest, más lento, config aparte para TypeScript y ESM.

## Configuración

Un `vitest.config.ts` por workspace, porque el entorno es distinto (el de cada app está en su stack). En la raíz, uno que los junta (`vitest.workspace.ts` ya no existe en Vitest 4):

```ts
// vitest.config.ts en la raíz: npm test corre todos
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: { projects: ['apps/*', 'packages/*'] },   // + coverage, abajo
});
```

## Unitario

```ts
// apps/api/src/orders/order.service.unit.test.ts
import { describe, it, expect } from 'vitest';
import { applyCoupon } from './order.service';
import { buildOrder, buildCoupon } from './order.test-helpers';
import { ValidationError } from '@/shared/errors';

describe('applyCoupon', () => {
  it('rejects an expired coupon', () => {
    const order = buildOrder({ total: 100 });
    const coupon = buildCoupon({ expiresAt: new Date('2020-01-01') });

    expect(() => applyCoupon(order, coupon, { now: new Date('2026-01-01') })).toThrow(ValidationError);
  });
});
```

Sin mocks. La fecha entra por parámetro; si no, `vi.setSystemTime()`.

## Cobertura

Dos números, dos roles. El global es un ratchet: umbral igual a la cobertura actual, Vitest lo sube solo (`autoUpdate`) y nunca baja. El del **diff** es la guardia: cada línea tocada en un PR tiene test o el PR no entra. El global solo no sirve: un PR sin tests baja el número un punto y nadie lo ve. Por qué: `../../docker-ci/references/ci.md`. Config y job de CI: `ci.md`.

```ts
// vitest.config.ts en la raíz: coverage es global al workspace
coverage: {
  provider: 'v8',                              // @vitest/coverage-v8
  reporter: ['text', 'cobertura'],             // cobertura.xml lo lee diff-cover en CI
  include: ['apps/*/src/**', 'packages/*/src/**'],
  exclude: ['**/*.test.{ts,tsx}', '**/test/**'],
  thresholds: { lines: 60, branches: 60, functions: 60, statements: 60, autoUpdate: true },
}
```

## Comandos

```bash
npm test                      # todo, una vez (vitest run, vía workspace)
npm test -- --watch           # en desarrollo
npm test -- orders            # solo archivos que matchean
npm test -- --coverage        # cobertura (v8); falla si baja del umbral
npm run test:e2e              # playwright test
```

## Qué pedirle a Claude

- "Escribí el test que falla antes del fix" al arreglar un bug.
- "Testealo por comportamiento, no por implementación" si ves `expect(component.state...)` o mocks de módulos propios.
- "¿Qué capa le falta test a este cambio?" antes de un PR que toque endpoint y pantalla.
