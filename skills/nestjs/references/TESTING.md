# Tests en NestJS

Lo que se suma a `../../node-api/references/TESTING.md` por el contenedor de dependencias de Nest. El runner, la capa unitaria y la cobertura están en `../../typescript/references/TESTING.md`; cómo se escribe un test, en `../../typescript/references/tests.md`.

## Las librerías

| Librería | Qué hace |
|---|---|
| `@nestjs/testing` | `Test.createTestingModule({ imports: [AppModule] })`: arma el contenedor igual que en producción. `overrideProvider(X).useValue(fake)` reemplaza **solo** la frontera (repositorio, cliente HTTP, reloj) |
| `supertest` | requests al app en memoria después de `app.init()`, sin puerto |
| `unplugin-swc` + `@swc/core` | compilan los decoradores con `emitDecoratorMetadata`. esbuild, el compilador de Vitest, no lo soporta: sin esto el contenedor no puede inyectar nada y todo provider llega `undefined` |

## Configuración

Lo que cambia respecto de `../../node-api/references/TESTING.md`: el plugin de SWC.

```ts
// apps/api/vitest.config.ts
import { defineConfig } from 'vitest/config';
import swc from 'unplugin-swc';

export default defineConfig({
  plugins: [swc.vite({ module: { type: 'es6' } })],   // decoradores y metadata para el contenedor de Nest
  test: {
    environment: 'node',
    include: ['src/**/*.test.ts'],
    setupFiles: ['./src/test/setup.ts'],
  },
});
```

## Integración de un endpoint

```ts
// apps/api/src/orders/order.controller.test.ts
import { beforeAll, afterAll, it, expect } from 'vitest';
import { Test } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '@/app.module';
import { AppExceptionFilter } from '@/shared/exception-filter/app-exception.filter';
import { ErrorResponseSchema } from '@acme/contracts';

let app: INestApplication;

beforeAll(async () => {
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  app = moduleRef.createNestApplication();
  app.useGlobalFilters(new AppExceptionFilter());   // lo mismo que main.ts, o el test no prueba el formato de error
  await app.init();
});
afterAll(() => app.close());

it('returns ORDER_NOT_FOUND for an unknown id', async () => {
  const res = await request(app.getHttpServer()).get('/orders/nope').set('Cookie', await sessionCookie());

  expect(res.status).toBe(404);
  expect(ErrorResponseSchema.parse(res.body).code).toBe('ORDER_NOT_FOUND');
});
```

Lo que `main.ts` configura (filtro global, pipe de Zod, `useLogger`) hay que repetirlo en el test o sacarlo a una función `configureApp(app)` que usen los dos. Lo segundo: un solo lugar.

## Guards

Un guard se testea sin HTTP, armando el `ExecutionContext` a mano. Están al lado: `*.guard.test.ts`.

```ts
// apps/api/src/shared/guards/roles.guard.test.ts
const ctx = (handlerRoles: UserRole[] | undefined, cookie?: string) =>
  ({
    getHandler: () => handler,
    getClass: () => RolesGuardTestController,
    switchToHttp: () => ({ getRequest: () => ({ cookies: { access: cookie }, headers: {} }) }),
  }) as unknown as ExecutionContext;

it('rejects a request without session cookie when roles are required', async () => {
  reflector.getAllAndOverride.mockReturnValue(['ADMIN']);

  await expect(guard.canActivate(ctx(['ADMIN']))).rejects.toMatchObject({ code: 'UNAUTHORIZED' });
});

it('lets the request through when no roles are declared', async () => {
  reflector.getAllAndOverride.mockReturnValue(undefined);

  await expect(guard.canActivate(ctx(undefined))).resolves.toBe(true);
});
```

Casos que tienen que existir por guard: sin metadata pasa; sin token 401; token inválido 401; rol que no está 403; `isSuperAdmin` pasa; y para `ResourceClientGuard`, recurso de otro tenant 403.

## Árbol de filtros

`resolve-filter-tree.test.ts` sin DB: entra un árbol, sale un `where` de TypeORM; se compara el objeto. Un caso por operador, uno por negación, uno por `and` sobre `or` (el producto cruzado), uno por profundidad y cantidad máximas. Y **un** test de integración contra la DB de test por endpoint que lista, con un árbol de dos reglas: es el que atrapa el `::text` y el alias sin comillar.
