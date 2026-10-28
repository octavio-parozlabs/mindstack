# Tests

Vitest. El test vive al lado del archivo que prueba. Se mockea solo la frontera. Qué librería por capa y la config: `TESTING.md`.

## Reglas

| Regla | Por qué |
|---|---|
| `foo.unit.test.ts` o `foo.int.test.ts` al lado de `foo.ts`; el sufijo dice la capa (`mindstack:qa`, "Nombres") | abrir el archivo y su test es un `Ctrl+P`. Y al mover la feature, el test viaja |
| Un test prueba un comportamiento, y el nombre lo dice: `it('rejects orders with expired coupon')` | si falla, el nombre ya dice qué se rompió. `it('works')` no dice nada |
| Arrange, act, assert, separados por una línea en blanco | el que lee encuentra en 2 segundos qué se prepara, qué se ejecuta, qué se espera |
| Unitario: sin mocks de módulos propios ni de DB; reloj, random y filesystem entran por parámetro. Integración: DB real, mock solo de la red externa | si mockeás `order.service` para testear `order.handler`, el test pasa aunque el service esté roto |
| Sin lógica en el test: ni `if`, ni loops que generen casos. `it.each` para tablas | un test con lógica necesita su propio test |
| Un `expect` por comportamiento. Varios `expect` están bien si verifican el mismo resultado | un test con 10 asserts de 10 cosas distintas falla en la primera y esconde las otras 9 |
| Datos de prueba con builders: `buildOrder({ status: 'pending' })` | el test muestra solo lo que importa para ese caso; el resto son defaults |
| Bug arreglado = test que fallaba antes del fix y pasa después, en el mismo commit | es la única prueba de que el fix arregla eso y no otra cosa |
| Sin `test.skip` ni `test.only` commiteados. ESLint `vitest/no-focused-tests` | un `only` olvidado apaga la suite entera en CI |

## Ejemplo

```ts
import { describe, it, expect, vi } from 'vitest';
import { applyCoupon } from './order.service';
import { buildOrder, buildCoupon } from './order.test-helpers';
import { ValidationError } from '@/shared/errors';

describe('applyCoupon', () => {
  it('rejects an expired coupon', () => {
    const order = buildOrder({ total: 100 });
    const coupon = buildCoupon({ expiresAt: new Date('2020-01-01') });
    vi.setSystemTime(new Date('2026-01-01'));

    const result = () => applyCoupon(order, coupon);

    expect(result).toThrow(ValidationError);
  });

  it.each([
    [100, 10, 90],
    [100, 100, 0],
    [50, 60, 0],
  ])('total %i with discount %i gives %i', (total, discount, expected) => {
    const order = applyCoupon(buildOrder({ total }), buildCoupon({ discount }));

    expect(order.total).toBe(expected);
  });
});
```

## Qué no testear

- Tipos: eso lo hace `tsc`.
- Librerías de terceros: ya tienen sus tests.
- Getters y setters triviales.
- Implementación: si el test rompe cuando refactorizás sin cambiar comportamiento, el test estaba mirando lo que no debía.
