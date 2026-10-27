# Backend

Toda entrada se valida con el schema del contrato al entrar. Toda salida cumple el schema del contrato. Adentro, se confía en los tipos.

## Reglas

| Regla | Por qué |
|---|---|
| Cada endpoint parsea `body`, `params` y `query` con el schema de `contracts` antes de tocar lógica. Un `ValidationError` sale como 400 con `code: VALIDATION_ERROR` y `details` con los issues de Zod | la lógica recibe tipos verdaderos; el cliente recibe un error que puede mostrar campo por campo |
| El response se construye con el tipo de `contracts` y, en tests, se parsea con el schema de response | un campo de más (un `passwordHash` que se coló) lo atrapa el test, no un incidente |
| Un solo error handler traduce clases de error a `{ code, message, details }` y status HTTP. Ningún handler escribe status codes a mano | si cada endpoint decide el status, hay 40 opiniones de qué es un 404 |
| Capas: `handler` (HTTP ↔ tipos) → `service` (reglas) → `repository` (DB). El handler no sabe de DB; el service no sabe de HTTP; el repository no sabe de reglas | para testear la regla "cupón vencido" no hace falta levantar HTTP ni DB |
| El modelo de DB no es el DTO. Hay una función `toOrderDto(row): Order` por entidad | la DB cambia (una columna más) sin que el contrato cambie, y nunca se filtra un campo interno |
| `config.ts` con schema de env, leído una vez. `process.env` no aparece en ningún otro archivo | `../../typescript/references/config.md` tiene el ejemplo |
| Logs estructurados (objeto, no string) con `requestId`. Sin `console.log` fuera de scripts | a las 3am se busca por `requestId`, no por "Error procesando" |
| `lodash-es` para transformar datos: `groupBy`, `keyBy`, `uniqBy`, `chunk`. No reimplementar | la versión a mano tiene el bug del caso vacío que lodash ya arregló |
| Operaciones que pueden tardar reciben `AbortSignal` del request. Si el cliente se va, el trabajo para | `../../typescript/references/async.md` |
| Los middlewares de seguridad van antes de cualquier ruta y en el orden de `../../web-security/SKILL.md`: `requireOrigin` → CORS → headers y CSP → `requireJson` → auth → rutas. Exentos solo `/health`, webhooks firmados y clientes no-browser en su router | cada capa responde una pregunta distinta (quién llama, quién lee, qué entra) y filtra lo que la siguiente asume. El por qué de cada una está en las references de `web-security` |

## Forma de un endpoint

```ts
// apps/api/src/orders/order.handler.ts
import { CreateOrderRequest, CreateOrderResponse } from '@acme/contracts';

export async function createOrderHandler(req: Request, res: Response) {
  const input = CreateOrderRequest.parse(req.body);          // 400 si falla, vía error handler
  const order = await orderService.create(input, req.user);  // reglas; lanza NotFoundError, ConflictError...
  res.status(201).json(CreateOrderResponse.parse(toOrderDto(order))); // parse: el response cumple el contrato
}
```

Sea Express, Fastify o Hono, la forma es la misma: parse al entrar, service en el medio, DTO al salir.

## Tests

- Service: unitario, sin HTTP ni DB. Repository mockeado en la frontera.
- Handler: integración liviana con el app en memoria (supertest o `app.inject`), DB de test real o en memoria. Verifica status, `code` de error y que el body parsea con el schema de response.
- Un test por regla de negocio, con el nombre de la regla.
