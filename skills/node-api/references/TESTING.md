# Tests en una API Node

Lo que se suma a Vitest para endpoints. El runner, la capa unitaria y la cobertura están en `../../typescript/references/TESTING.md`; cómo se escribe un test, en `../../typescript/references/tests.md`.

## Las librerías

| Librería | Qué hace |
|---|---|
| `supertest` / `app.inject` | mandar requests al app en memoria sin abrir un puerto. `inject` es de Fastify; `supertest` sirve para cualquiera |

## Configuración

```ts
// apps/api/vitest.config.ts
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    include: ['src/**/*.test.ts'],
    setupFiles: ['./src/test/setup.ts'],   // DB de test, env
  },
});
```

## Integración de API

```ts
// apps/api/src/orders/order.handler.int.test.ts
import { describe, it, expect } from 'vitest';
import request from 'supertest';
import { CreateOrderResponse, ErrorResponseSchema } from '@acme/contracts';
import { app } from '@/app';
import { seedProduct } from '@/test/seed';

describe('POST /orders', () => {
  it('creates an order and the response matches the contract', async () => {
    const product = await seedProduct({ price: 50 });

    const res = await request(app).post('/orders').send({ items: [{ productId: product.id, quantity: 2, unitPrice: 50 }] });

    expect(res.status).toBe(201);
    expect(() => CreateOrderResponse.parse(res.body)).not.toThrow();
    expect(res.body.total).toBe(100);
  });

  it('returns NOT_FOUND for an unknown product', async () => {
    const res = await request(app).post('/orders').send({ items: [{ productId: crypto.randomUUID(), quantity: 1, unitPrice: 1 }] });

    expect(res.status).toBe(404);
    expect(ErrorResponseSchema.parse(res.body).code).toBe('NOT_FOUND');
  });
});
```

DB de test real (Docker local, `DATABASE_URL` en `env` del `settings.json`), limpiada entre tests. El `parse` con el schema de response es el test de contrato: si el handler filtra un campo de más o cambia un tipo, falla acá.
