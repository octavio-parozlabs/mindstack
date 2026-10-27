# Errores

Un error es un valor con tipo, contexto y causa. Nunca un string, nunca silencio.

## Reglas

| Regla | Por qué |
|---|---|
| Lanzar solo instancias de `Error` o subclases. Nunca `throw 'mensaje'` ni `throw { code: 1 }` | sin stack trace, sin `instanceof`, sin `cause`. Es un error que no se puede investigar |
| Clases de error por dominio, con `cause` | `NotFoundError`, `ValidationError`, `ExternalServiceError`. El que atrapa decide por tipo, no parseando mensajes |
| Nunca `catch {}` vacío ni `catch (e) { console.log(e) }` y seguir | un error tragado es un bug que va a aparecer en otro lado, más lejos, sin contexto |
| Atrapar solo donde se puede hacer algo: reintentar, degradar, traducir a respuesta, loguear con contexto y relanzar | el `try/catch` en cada función es ruido. Dejar que suba hasta donde tiene sentido |
| Validar **todo** input externo en la frontera: HTTP, archivos, env, mensajes de cola, respuestas de otras APIs | adentro del sistema los tipos son verdad porque la frontera los garantizó. Sin eso, `strict` no sirve de nada |
| `process.env` se lee una vez, validado con schema, en `config.ts`, y queda en un objeto congelado y tipado (`config.md`) | `process.env.PORT` es `string \| undefined` en 40 lugares. En un lugar, tipado, con default o error al arrancar |
| El mensaje dice qué pasó y con qué: `Order 123 not found`, no `Not found` | el que lee el log a las 3am no tiene el contexto |

## Ejemplo

```ts
export class AppError extends Error {
  constructor(message: string, options?: { cause?: unknown }) {
    super(message, options);
    this.name = new.target.name;
  }
}
export class NotFoundError extends AppError {}
export class ExternalServiceError extends AppError {}

async function fetchRates(signal: AbortSignal): Promise<Rates> {
  let res: Response;
  try {
    res = await fetch(RATES_URL, { signal });
  } catch (cause) {
    throw new ExternalServiceError(`rates service unreachable at ${RATES_URL}`, { cause });
  }
  if (!res.ok) throw new ExternalServiceError(`rates service returned ${res.status}`);
  return RatesSchema.parse(await res.json());
}
```

Arriba, en la frontera HTTP (sea el framework que sea), un solo handler traduce `NotFoundError` a 404, `ValidationError` a 400 y el resto a 500 con log. Ningún otro lugar sabe de status codes.

## Config validada

La decisión (una lectura, validada, inmutable, nada por `NODE_ENV`): `../../web-security/references/config.md`. Con qué acá: `config.md`.
