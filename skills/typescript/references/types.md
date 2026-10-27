# Tipos

`strict` completo y nada que lo esquive. El compilador es el primer test.

## tsconfig mínimo

```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "noFallthroughCasesInSwitch": true,
    "verbatimModuleSyntax": true
  }
}
```

`noUncheckedIndexedAccess` es el que más duele y el que más bugs saca: `arr[0]` es `T | undefined`, como en la realidad.

## Reglas

| Regla | Por qué |
|---|---|
| Sin `any`. Usar `unknown` y hacer narrowing | `any` apaga el compilador para todo lo que toca. `unknown` te obliga a chequear antes de usar |
| Sin `as`, salvo con un comentario de por qué en la misma línea | un cast es una promesa que el compilador no puede verificar. Si hace falta, que quede escrito por qué es seguro |
| Sin `!` (non-null assertion) | lo mismo: "confiá en mí". Si sabés que no es null, el código tiene que demostrarlo con un `if` |
| Sin `@ts-ignore` ni `@ts-expect-error` en código de producción | si el tipo no cierra, el diseño no cierra |
| Tipar lo que entra y lo que sale de cada función exportada | la inferencia sirve adentro; en la frontera el tipo es el contrato |
| Uniones discriminadas para estados, no booleanos sueltos | `{ status: 'loading' } \| { status: 'error', error: E } \| { status: 'ok', data: T }` hace imposible el estado `loading && error` |
| `readonly` por defecto en props de objetos y arrays que no se mutan | la mutación accidental es el bug más difícil de rastrear |

## Preferencias (ajustables)

- `type` por defecto; `interface` solo cuando se necesita declaration merging o una clase lo implementa.
- Enums no. Union de string literals: `type Role = 'admin' | 'user'`. Mismo poder, sin runtime raro.

## Ejemplo

Mal:

```ts
function parseUser(data: any) {
  return { id: data.id as string, role: data.role! };
}
```

Bien:

```ts
import { z } from 'zod';

const UserSchema = z.object({ id: z.string(), role: z.enum(['admin', 'user']) });
type User = z.infer<typeof UserSchema>;

function parseUser(data: unknown): User {
  return UserSchema.parse(data);
}
```

El input externo es `unknown`, el schema lo valida y el tipo sale del schema: una sola fuente de verdad.
