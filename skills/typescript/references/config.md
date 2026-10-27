# Config en TypeScript

Con qué se implementa `../../web-security/references/config.md` en este stack. Las decisiones (una lectura, validada, congelada, tipada; qué entra y qué no; nada por `NODE_ENV`) están ahí; acá solo las herramientas: Zod para el schema, `process.env` como fuente, `Object.freeze` para la inmutabilidad, y `eslint.config.js` para que `process.env` no aparezca en ningún otro archivo.

## El objeto

```ts
// apps/api/src/config.ts: el único archivo que toca process.env
import { z } from 'zod';

const origin = z.string().url().refine((v) => new URL(v).origin === v, 'un origen exacto, sin path ni barra final');

const EnvSchema = z.object({
  PORT: z.coerce.number().int().positive().default(3000),
  DATABASE_URL: z.string().url(),
  LOG_LEVEL: z.enum(['debug', 'info', 'warn', 'error']).default('info'),
  WEB_ORIGIN: origin,                                       // origin.md y cors.md: literal exacto
  TRUSTED_PROXY: z.string().ip().or(z.string().regex(/^[\d.]+\/\d+$/)),   // IP o CIDR del Caddy, nunca true
  JWT_SECRET: z.string().min(32),                           // jwt.md
  CSRF_SECRET: z.string().min(32),                          // content-type.md
  SENTRY_DSN: z.string().url().optional(),
});

const parsed = EnvSchema.safeParse(process.env);
if (!parsed.success) {
  // al arrancar, con el nombre de cada variable que falta o está mal. Nunca a las 3am en el primer request
  console.error('config inválida:', parsed.error.flatten().fieldErrors);   // eslint-disable-line no-console -- antes de que exista el logger
  process.exit(1);
}

export const config = Object.freeze(parsed.data);
export type Config = typeof config;
```

| Decisión del core | Acá |
|---|---|
| una lectura, al arrancar | `EnvSchema.safeParse(process.env)` en el top level del módulo: corre una vez, en el primer `import` |
| validada contra un schema | Zod: `coerce` para números, `enum`, `url`, `min` para secretos, `refine` para el origen exacto |
| objeto inmutable y tipado | `Object.freeze` y `typeof config`: `config.PORT` es `number`, `config.LOG_LEVEL` es la unión literal |
| ningún otro archivo lee el entorno | `no-restricted-syntax` sobre `process.env` en `eslint.config.js`, con override solo para `**/config.ts` |
| el frontend, mismo patrón | `import.meta.env` con un schema de solo `VITE_*`: `apps/web/src/config.ts` |
| tests | `vi.stubEnv` + `expect(() => import('@/config')).rejects`; un test que parsea `.env.example` y compara `Object.keys` contra `EnvSchema.shape` |

```ts
// apps/web/src/config.ts
const EnvSchema = z.object({ VITE_API_URL: origin });
export const config = Object.freeze(EnvSchema.parse(import.meta.env));
```

## Detalles de Node que importan

- `process.env` no lee el disco, pero **no es un objeto normal**: cada acceso es un getter nativo que recorre el bloque de entorno y convierte a string. Más lento que una propiedad; se nota en un middleware que lo lea por request. Un motivo más para que solo `config.ts` lo toque.
- `dotenv` o `node --env-file` cargan el `.env` una vez al arrancar. Nunca `dotenv.config()` dentro de un handler: eso sí es disco, por request, y pisa el entorno real del contenedor.
- `Number(process.env.PORT ?? 3000)` con `PORT=abc` da `NaN` y el servidor escucha en un puerto aleatorio. `z.coerce.number()` lo rechaza.
- En tests, otro valor de config es `vi.mock('@/config', () => ({ config: { ...real, WEB_ORIGIN: 'http://localhost:5173' } }))`, no una asignación: el objeto está congelado.
