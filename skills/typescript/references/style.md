# Estilo

Biome decide el formato (`biome.json`) y ESLint fuerza lo que se puede forzar (`eslint.config.js`, cada regla con el `.md` que la explica). Esto es lo que ninguno de los dos decide.

## Nombres

| Qué | Cómo | Ejemplo |
|---|---|---|
| variables, funciones | `camelCase`, verbo para funciones | `fetchOrder`, `isExpired`, `orderTotal` |
| tipos, clases | `PascalCase` | `Order`, `NotFoundError` |
| constantes de módulo | `UPPER_SNAKE` solo si son valores fijos de verdad | `MAX_RETRIES`, no `DEFAULT_USER` para un objeto |
| booleanos | `is`, `has`, `can`, `should` | `isActive`, `hasPermission` |
| archivos | `kebab-case.ts`, con sufijo de rol | `order-service.ts` o `order.service.ts`, uno de los dos en todo el repo |

Sin abreviaturas que no sean universales: `req`, `res`, `id`, `url` sí; `ord`, `usr`, `cfg` no.

## Funciones

- Caben en una pantalla. Si no, hacen dos cosas.
- Early return. El camino feliz al final, sin indentación.
- Máximo 3 parámetros. Más, un objeto con nombres: `createOrder({ userId, items, coupon })`.
- Sin parámetros booleanos: `render(true)` no dice nada. `render({ compact: true })` sí.
- Puras cuando se puede: mismo input, mismo output, sin tocar nada afuera. Son las fáciles de testear.

## Comentarios

- Dicen **por qué**, no qué. El qué lo dice el código.
- Un comentario que explica código confuso es una señal: arreglar el código.
- `// TODO` siempre con referencia: `// TODO(#123): quitar cuando migre la API v1`.
- Sin código comentado. Para eso está git.

## Ejemplo

Mal:

```ts
// check if user can edit
function chk(u: any, o: any, f: boolean) {
  if (u) {
    if (u.role === 'admin' || (u.id === o.ownerId && !f)) {
      return true;
    } else {
      return false;
    }
  }
  return false;
}
```

Bien:

```ts
function canEditOrder(user: User | null, order: Order, { frozen }: { frozen: boolean }): boolean {
  if (!user) return false;
  if (user.role === 'admin') return true;
  // Owners lose edit rights once the order is frozen for fulfillment.
  return user.id === order.ownerId && !frozen;
}
```
