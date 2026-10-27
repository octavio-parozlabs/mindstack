# Logger

Pino como logger de Nest: JSON a stdout, una línea por request con id, y el código de negocio sigue usando `Logger` de `@nestjs/common` sin enterarse.

## Reglas

| Regla | Por qué |
|---|---|
| `nestjs-pino` + `pino-http`. `NestFactory.create(AppModule, { bufferLogs: true })` y `app.useLogger(app.get(Logger))` | sin `bufferLogs`, lo que se loguea antes de que Pino esté listo sale por el logger default, en texto |
| Los servicios usan `new Logger(X.name)` de `@nestjs/common`. No importan Pino | `useLogger` redirige todo. Cambiar de logger es una línea en `main.ts`, no 40 imports |
| `autoLogging: true`: una línea por request con método, url, status, duración | es lo que Loki indexa (`../../docker-ci/references/docker.md`). Sin eso, cada request son 8 líneas sueltas sin correlación |
| `redact` de `req.headers.authorization`, `req.headers.cookie`, `req.headers["x-api-key"]` | sin esto, el token de sesión se loguea en cada request. Está en los logs de todos |
| `genReqId` lee `x-request-id` del proxy y si no hay, genera uno. El mismo id vuelve en el header de respuesta | correlacionar el front con el back, y las 8 líneas de una request entre sí |
| `pino-pretty` solo en `NODE_ENV=development`, por `transport` | en producción Pino escribe JSON; pretty es para leer en la consola, y cuesta CPU |
| Loguear objetos, no strings armados: `logger.error({ orderId, err }, 'payment failed')` | `JSON.stringify(record)` dentro de un string es texto para Loki. Un objeto son campos consultables |
| Payloads grandes pasan por un helper con `util.inspect({ depth: 4, maxStringLength: 2000, maxArrayLength: 50 })` | un body de 50 KB por línea tumba el índice y no se lee |

## Cómo

```ts
// apps/api/src/app.module.ts
LoggerModule.forRootAsync({
  inject: [ConfigService],
  useFactory: (config: ConfigService<Env, true>) => ({
    pinoHttp: {
      level: config.getOrThrow('LOG_LEVEL'),
      autoLogging: true,
      redact: ['req.headers.authorization', 'req.headers.cookie', 'req.headers["x-api-key"]'],
      genReqId: (req, res) => {
        const id = (req.headers['x-request-id'] as string | undefined) ?? randomUUID();
        res.setHeader('x-request-id', id);
        return id;
      },
      transport: config.getOrThrow('NODE_ENV') === 'development' ? { target: 'pino-pretty' } : undefined,
    },
  }),
}),
```

```ts
// apps/api/src/main.ts
const app = await NestFactory.create(AppModule, { bufferLogs: true });
app.useLogger(app.get(Logger));   // Logger de nestjs-pino
```

```ts
// en cualquier servicio: nada cambia
private readonly logger = new Logger(PaymentService.name);
this.logger.error({ orderId, err }, 'payment failed');
```

## Mal / Bien

```ts
// Mal
console.log(`[Payment] error for ${orderId}: ${JSON.stringify(err)}`);   // texto, sin requestId, con el stack adentro de un string
```

```ts
// Bien
this.logger.error({ orderId, err }, 'payment failed');   // JSON con context, req.id, level, time
```

## Para copiar

El bloque del `LoggerModule`, las dos líneas de `main.ts`, y `shared/logging/format.ts` con el helper de `inspect`. Promtail y Loki ya están en `../../docker-ci/references/docker.md`.
