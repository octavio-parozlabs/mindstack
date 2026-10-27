# Tests en React

Lo que se suma a Vitest para componentes y para end-to-end. El runner, la capa unitaria y la cobertura están en `../../typescript/references/TESTING.md`; cómo se escribe un test, en `../../typescript/references/tests.md`.

## Las librerías

| Librería | Qué hace |
|---|---|
| `happy-dom` | implementa `document`, `window`, eventos: el DOM que necesita React para renderizar en Node. Más rápido que `jsdom` |
| `@testing-library/react` | `render()`, `screen`, queries por rol y texto. Hace que el test vea lo que ve el usuario, no el estado interno |
| `@testing-library/jest-dom` | matchers del DOM: `toBeInTheDocument()`, `toBeDisabled()`, `toHaveTextContent()`. El nombre es histórico; funciona con Vitest vía `@testing-library/jest-dom/vitest` |
| `@testing-library/user-event` | `userEvent.click()`, `type()`, `selectOptions()`: interacciones como las hace una persona, con todos los eventos intermedios |
| `msw` | intercepta HTTP por debajo de axios y responde con lo que el test diga. La API falsa vive en un lugar, usando los schemas de `contracts` |
| `@playwright/test` | browser real, flujo completo. Pocos, para lo crítico: login, checkout |

Qué **no**:

- `jsdom`. Funciona, pero `happy-dom` es más rápido y alcanza. Si un test necesita algo que happy-dom no implementa, se cambia **ese** archivo con `// @vitest-environment jsdom`.
- Enzyme. Testea implementación, no comportamiento.
- Cypress. Playwright hace lo mismo, con mejor soporte de TypeScript y paralelismo.

## Configuración

```ts
// apps/web/vitest.config.ts
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'happy-dom',
    globals: false,                      // import explícito de describe/it/expect
    setupFiles: ['./src/test/setup.ts'],
    include: ['src/**/*.test.{ts,tsx}'],
  },
});
```

```ts
// apps/web/src/test/setup.ts
import '@testing-library/jest-dom/vitest';   // registra los matchers en expect
import { afterAll, afterEach, beforeAll } from 'vitest';
import { cleanup } from '@testing-library/react';
import { server } from './msw-server';

beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));  // request sin handler = test falla
afterEach(() => { cleanup(); server.resetHandlers(); });
afterAll(() => server.close());
```

```ts
// apps/web/src/test/msw-server.ts: la API falsa, en un solo lugar
import { setupServer } from 'msw/node';
import { http, HttpResponse } from 'msw';
import { OrderSchema } from '@acme/contracts';
import { buildOrder } from './builders';

export const handlers = [
  http.get('*/orders/:id', ({ params }) => HttpResponse.json(OrderSchema.parse(buildOrder({ id: String(params.id) })))),
];
export const server = setupServer(...handlers);
```

Cada handler devuelve algo que pasa por el schema del contrato: si el contrato cambia, el mock rompe en el test y no en producción. Un test que necesita otra respuesta la agrega con `server.use(...)`, como abajo.

## Componente

```tsx
// apps/web/src/orders/OrderForm.test.tsx
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { server } from '@/test/msw-server';
import { renderWithProviders } from '@/test/render';   // QueryClientProvider, router
import { OrderForm } from './OrderForm';

describe('OrderForm', () => {
  it('shows the coupon error returned by the API', async () => {
    server.use(
      http.post('*/orders', () =>
        HttpResponse.json({ code: 'VALIDATION_ERROR', message: 'Coupon expired', details: { field: 'couponCode' } }, { status: 400 }),
      ),
    );
    renderWithProviders(<OrderForm />);

    await userEvent.type(screen.getByLabelText(/coupon/i), 'OLD2020');
    await userEvent.click(screen.getByRole('button', { name: /place order/i }));

    expect(await screen.findByText(/coupon expired/i)).toBeInTheDocument();
  });
});
```

Queries por rol y label, no por `data-testid` ni clase. MSW responde con la forma del contrato. `findBy*` espera a que aparezca.

## End-to-end

```ts
// apps/web/playwright.config.ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  use: { baseURL: 'http://localhost:5173', trace: 'retain-on-failure' },
  webServer: { command: 'npm run dev', url: 'http://localhost:5173', reuseExistingServer: !process.env.CI },
});
```

```ts
// apps/web/e2e/checkout.spec.ts
import { test, expect } from '@playwright/test';

test('user completes checkout', async ({ page }) => {
  await page.goto('/products/1');
  await page.getByRole('button', { name: 'Add to cart' }).click();
  await page.getByRole('link', { name: 'Checkout' }).click();
  await page.getByLabel('Card number').fill('4242424242424242');
  await page.getByRole('button', { name: 'Pay' }).click();

  await expect(page.getByText('Order confirmed')).toBeVisible();
});
```

Pocos. Contra la app levantada con datos de prueba. Corren en CI en un job aparte porque tardan.
