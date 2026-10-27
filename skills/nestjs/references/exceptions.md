# Excepciones

Un solo error de dominio, un solo filtro que atrapa todo, un solo formato de salida: el de `architecture` §5. El dominio nunca sabe de HTTP.

## Reglas

| Regla | Por qué |
|---|---|
| El dominio y los repositorios tiran `AppError`. Nunca `HttpException` ni sus hijas | `NotFoundException` en un use case acopla el dominio a HTTP. Mañana ese use case corre desde una cola y el 404 no significa nada |
| `AppError` lleva `code` obligatorio, el del contrato (`ORDER_NOT_FOUND`), y `type`, la familia HTTP | `code` es lo que el front switchea y no se renombra. `type` es lo que el mapper usa para el status. Son dos cosas |
| Un filtro global con `@Catch()` sin argumento, y una cadena de mappers: `AppError`, Zod, `HttpException`, Axios, errores de Node, Postgres, fallback 500 | `@Catch(HttpException)` deja pasar un `QueryFailedError` con SQL adentro como 500 crudo. Sin argumento atrapa todo, y cada familia tiene quien la traduzca |
| Solo las familias 4xx exponen `message`. `DATABASE` y `UNKNOWN` salen con mensaje genérico y `details` vacío | "no encontramos el pedido 123" es útil. "relation orders violates constraint fk_client" es una fuga de esquema |
| El filtro loguea stack y `cause` encadenado antes de responder | el cliente recibe el formato del contrato; el stack va al log, no al body |
| El status sale de una tabla `type → status` en un solo archivo | ningún handler escribe `res.status(409)`. Cambiar qué es un 422 es una línea |
| Las respuestas de éxito son el schema de response del endpoint, sin envoltura | las notas originales de este patrón usaban `{ message, data, errors }` para todo. `../../architecture/SKILL.md` §5 manda formato fijo solo para errores y responses planos tipados por contrato. Se sigue al core |

## Cómo

```ts
// apps/api/src/shared/errors/app-error.ts
export type AppErrorType = 'VALIDATION' | 'BAD_REQUEST' | 'CONFLICT' | 'NOT_FOUND' | 'UNAUTHORIZED' | 'FORBIDDEN' | 'DATABASE' | 'UNKNOWN';

export class AppError extends Error {
  readonly type: AppErrorType;
  readonly code: string;                        // del contrato: ORDER_NOT_FOUND, COUPON_EXPIRED
  readonly details: Record<string, unknown> | undefined;
  constructor(p: { type: AppErrorType; code: string; message: string; details?: Record<string, unknown>; cause?: unknown }) {
    super(p.message, { cause: p.cause });
    Object.setPrototypeOf(this, new.target.prototype);   // instanceof funciona tras transpilar
    this.type = p.type; this.code = p.code; this.details = p.details;
  }
}
```

```ts
// apps/api/src/shared/errors/app-error.mapper.ts
const STATUS: Record<AppErrorType, number> = {
  VALIDATION: 422, BAD_REQUEST: 400, CONFLICT: 409, NOT_FOUND: 404,
  UNAUTHORIZED: 401, FORBIDDEN: 403, DATABASE: 500, UNKNOWN: 500,
};
const EXPOSES_MESSAGE = new Set<AppErrorType>(['VALIDATION', 'BAD_REQUEST', 'CONFLICT', 'NOT_FOUND', 'UNAUTHORIZED', 'FORBIDDEN']);

export function mapAppError(e: AppError): ErrorResponse & { status: number } {
  const exposed = EXPOSES_MESSAGE.has(e.type);
  return {
    status: STATUS[e.type],
    code: exposed ? e.code : 'INTERNAL',
    message: exposed ? e.message : 'Internal server error',
    details: exposed ? e.details : undefined,
  };
}
```

Un mapper por familia, cada uno devuelve el mismo shape o `null` si no le corresponde:

| Archivo | Qué traduce |
|---|---|
| `app-error.mapper.ts` | `AppError.type` → status, tabla fija |
| `zod.mapper.ts` | `ZodValidationException` de `nestjs-zod` → 422 `VALIDATION_ERROR`, `details.issues` con `path: message` |
| `http-exception.mapper.ts` | `HttpException` de Nest: guards built-in, pipes, 404 de ruta |
| `axios-error.mapper.ts` | fallas de llamadas salientes → 502 `UPSTREAM_ERROR`, sin el body del tercero |
| `node-error.mapper.ts` | `ECONNREFUSED`, `ENOTFOUND`, `ETIMEDOUT` → 503 |
| `postgres-error.mapper.ts` | `23505` unique → 409, `23502` not null → 422, otros `23xxx` → 409, resto → 500 `DATABASE` **sin mensaje** |

```ts
// apps/api/src/shared/exception-filter/app-exception.filter.ts
@Catch()   // sin argumento: atrapa TODO
export class AppExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(AppExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const res = host.switchToHttp().getResponse<Response>();
    if (res.headersSent) return;
    this.logger.error({ err: exception, cause: (exception as { cause?: unknown })?.cause }, 'unhandled');

    const mapped =
      (exception instanceof AppError && mapAppError(exception)) ||
      (exception instanceof ZodValidationException && mapZod(exception)) ||
      (exception instanceof HttpException && mapHttpException(exception)) ||
      mapAxiosError(exception) || mapNodeError(exception) || mapPostgresError(exception) ||
      { status: 500, code: 'INTERNAL', message: 'Internal server error' };

    const { status, ...body } = mapped;
    res.status(status).json(ErrorResponseSchema.parse(body));   // el contrato también valida la salida
  }
}
```

`main.ts`: `app.useGlobalFilters(new AppExceptionFilter())`. Y en el test, lo mismo: `TESTING.md`.

## Mal / Bien

```ts
// Mal: el use case sabe de HTTP, y el repositorio deja escapar SQL
async findOne(id: string) {
  const order = await this.repo.findOneBy({ id });
  if (!order) throw new NotFoundException(`Order ${id}`);
  return order;
}
```

```ts
// Bien: el dominio tira AppError con el code del contrato; el filtro traduce
async findOne(id: string) {
  const order = await this.repo.findOneBy({ id });
  if (!order) throw new AppError({ type: 'NOT_FOUND', code: 'ORDER_NOT_FOUND', message: `Order ${id} not found`, details: { orderId: id } });
  return order;
}
```

## Trampas

- `@Catch(HttpException)` parece suficiente hasta el primer `QueryFailedError`: sale como 500 con el SQL y los nombres de columna en el body.
- `Object.setPrototypeOf` no es opcional con `target` bajo: sin eso, `instanceof AppError` da `false` después de transpilar y el filtro cae al fallback.
- `res.headersSent`: un error dentro de un stream ya iniciado no puede responder dos veces. Loguear y salir.

## Para copiar

`shared/errors/` (clase, tipo, seis mappers), `shared/exception-filter/app-exception.filter.ts`, el `ErrorResponseSchema` en `packages/contracts`. Unas 300 líneas, sin dependencias del dominio. Sin TypeORM, se borra el mapper de Postgres; sin llamadas salientes, el de Axios.
