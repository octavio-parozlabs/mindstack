# Config

El env se valida al arrancar con el schema de Zod, y `ConfigService` queda tipado. Falta una variable: la app no levanta y dice cuál.

## Reglas

| Regla | Por qué |
|---|---|
| `ConfigModule.forRoot({ isGlobal: true, validate })` con una función que corre el schema de Zod | `process.env.BUCKET_HOST` es `undefined` y te enterás en el primer upload, en producción. Con `validate`, te enterás en el arranque, con el nombre |
| Zod, no Joi | el stack ya tiene Zod; Joi es una dependencia más y no tipa. `../../architecture/SKILL.md` §6 pide schema; el stack dice cuál |
| `z.coerce.number()` para todo lo numérico | todo env llega como string. Sin coerce, `PORT: z.number()` falla siempre |
| Validar la forma, no solo la presencia: `MASTER_KEY: z.string().base64().length(44)` | una key de 31 bytes pasa `min(1)` y rompe al primer cifrado |
| `ConfigService<Env, true>` y `getOrThrow`. Nunca `.get()` | `get('PORT')` devuelve `any` y puede ser `undefined`. Con el tipo y `true`, `getOrThrow('PORT')` es `number` |
| Las claves como constantes o como literales tipados, nunca strings sueltos en servicios | `config.get('JWT_SECRTE')` compila y devuelve `undefined`. Con `Env` tipado, no compila |

## Cómo

```ts
// apps/api/src/config/env.schema.ts
import { z } from 'zod';

export const envSchema = z.object({
  PORT: z.coerce.number().int().positive().default(3000),
  NODE_ENV: z.enum(['development', 'test', 'production']),
  LOG_LEVEL: z.enum(['trace', 'debug', 'info', 'warn', 'error', 'fatal']).default('info'),
  DATABASE_URL: z.string().url(),
  SESSION_SECRET: z.string().base64().length(44),      // 32 bytes
  PUBLIC_URL: z.string().url(),
  REDIS_URL: z.string().url().optional(),
});

export type Env = z.infer<typeof envSchema>;

export function validateEnv(raw: Record<string, unknown>): Env {
  const result = envSchema.safeParse(raw);
  if (!result.success) {
    const lines = result.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`);
    throw new Error(`Invalid environment:\n${lines.join('\n')}`);
  }
  return result.data;
}
```

```ts
// apps/api/src/app.module.ts
ConfigModule.forRoot({ isGlobal: true, validate: validateEnv }),

// en un servicio
constructor(private readonly config: ConfigService<Env, true>) {}
const port = this.config.getOrThrow('PORT');   // number
```

## Mal / Bien

```ts
// Mal
const secret = process.env.JWT_SECRET;              // string | undefined, en 14 archivos
const port = Number(process.env.PORT ?? 3000);      // "abc" → NaN, arranca igual
```

El bloque "Bien" es el de arriba: un archivo, un schema, un tipo.

## Para copiar

`config/env.schema.ts` y la línea del `ConfigModule`. `.env.example` con los nombres del schema y sin valores (`../../workflow/references/git.md`).
