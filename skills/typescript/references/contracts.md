# Contratos compartidos

`packages/contracts` es la única fuente de verdad de lo que cruza entre `api` y `web`. Schema primero, tipo derivado, sin lógica.

## Reglas

| Regla | Por qué |
|---|---|
| Todo se declara como schema de Zod; el tipo sale con `z.infer`. Nunca una `interface` suelta para algo que cruza el borde | una interfaz no valida en runtime. El schema valida en las dos puntas y el tipo no puede divergir |
| Un archivo por recurso: `order.ts`, `user.ts`, `error.ts`. Cada uno exporta schemas de entidad, de request y de response | encontrar "qué recibe `POST /orders`" es abrir `order.ts` |
| Sin lógica. Sin `if`, sin fetch, sin funciones salvo refinements del schema (`.refine`) y helpers puros de derivación | si tiene lógica, `api` y `web` la ejecutan por separado y la testean por separado. Lo puro y compartido sí: un `calculateTotal(items)` que los dos necesitan va acá como función pura con su test |
| Sin dependencias de runtime salvo `zod`. Sin imports de `apps/*` | el paquete tiene que poder importarse desde el browser y desde Node sin arrastrar nada |
| Cambios compatibles: agregar campos opcionales, agregar valores a un enum. Un cambio incompatible (renombrar, quitar, cambiar tipo) va con su migración de front y back en el mismo PR | el front deployado ayer sigue pegándole a la API de hoy |
| El formato de error vive acá: `ErrorResponseSchema` con `code` como enum | el front switchea por `code`; si cada endpoint inventa el suyo, el front tiene un `if` por endpoint |

## Forma

```ts
// packages/contracts/src/order.ts
import { z } from 'zod';

export const OrderStatus = z.enum(['pending', 'paid', 'shipped', 'cancelled']);
export type OrderStatus = z.infer<typeof OrderStatus>;

export const OrderItemSchema = z.object({
  productId: z.string().uuid(),
  quantity: z.number().int().positive(),
  unitPrice: z.number().nonnegative(),
});

export const OrderSchema = z.object({
  id: z.string().uuid(),
  status: OrderStatus,
  items: z.array(OrderItemSchema).min(1),
  total: z.number().nonnegative(),
  createdAt: z.string().datetime(),
});
export type Order = z.infer<typeof OrderSchema>;

// request / response por endpoint
export const CreateOrderRequest = OrderSchema.pick({ items: true }).extend({
  couponCode: z.string().optional(),
});
export type CreateOrderRequest = z.infer<typeof CreateOrderRequest>;

export const CreateOrderResponse = OrderSchema;
export type CreateOrderResponse = z.infer<typeof CreateOrderResponse>;
```

```ts
// packages/contracts/src/error.ts
export const ErrorCode = z.enum([
  'VALIDATION_ERROR', 'NOT_FOUND', 'CONFLICT', 'INTERNAL',
  'UNAUTHORIZED', 'TOKEN_EXPIRED', 'SESSION_REVOKED', 'FORBIDDEN', // auth: qué hace el front con cada uno en web-security/references/jwt.md
]);
export const ErrorResponseSchema = z.object({
  code: ErrorCode,
  message: z.string(),
  details: z.record(z.unknown()).optional(),
});
export type ErrorResponse = z.infer<typeof ErrorResponseSchema>;
```

Lo mismo con el mismo nombre para schema y tipo (`Order` el tipo, `OrderSchema` el schema; `OrderStatus` para los dos cuando es enum) es a propósito: se importa uno y se usa como tipo o como validador según el contexto.

## Qué no va acá

- Modelos de Prisma, entidades de ORM, DTOs internos del backend.
- Props de componentes, estado de UI, tipos de formularios que no se mandan.
- Clientes HTTP. El `fetchOrder()` tipado vive en `apps/web`, usa el schema de acá.
