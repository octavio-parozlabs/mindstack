# Async

Toda promesa se espera, se devuelve o se maneja. Una promesa suelta es un error que va a pasar en silencio.

## Reglas

| Regla | Por qué |
|---|---|
| Sin promesas flotantes. ESLint `@typescript-eslint/no-floating-promises` en `error` | `saveOrder(order);` sin `await` ni `.catch` falla sin que nadie se entere |
| `async` solo si hay `await` adentro. `@typescript-eslint/require-await` | un `async` sin `await` envuelve en promesa algo síncrono y miente sobre lo que hace |
| Paralelo cuando es independiente: `Promise.all`. Secuencial cuando no | `await a(); await b();` con `a` y `b` independientes tarda el doble sin razón |
| `Promise.allSettled` cuando un fallo no debe cancelar al resto | con `Promise.all`, una que falla tira todo y las demás quedan corriendo sin que nadie mire el resultado |
| Todo lo que puede tardar acepta `AbortSignal` y lo pasa hacia abajo | sin cancelación, el timeout del cliente no frena el trabajo del servidor |
| Sin `new Promise` a mano salvo para envolver una API de callbacks | casi siempre hay una forma con `async/await`, y el constructor manual es donde se olvida el `reject` |
| No mezclar `.then()` con `await` en la misma función | dos estilos para una cosa. `await` es más fácil de leer y de debuggear |

## Ejemplo

Mal:

```ts
async function notifyAll(users: User[]) {
  for (const u of users) {
    sendEmail(u); // flotante: si falla, nadie se entera
  }
}
```

Bien:

```ts
async function notifyAll(users: readonly User[], signal: AbortSignal): Promise<NotifyResult> {
  const results = await Promise.allSettled(users.map((u) => sendEmail(u, { signal })));
  const failed = results.flatMap((r, i) => (r.status === 'rejected' ? [{ user: users[i], cause: r.reason }] : []));
  return { sent: results.length - failed.length, failed };
}
```

Paralelo, un fallo no frena al resto, cancelable, y el resultado dice qué pasó con cada uno.

## Timeouts

```ts
const signal = AbortSignal.timeout(5_000);
const res = await fetch(url, { signal });
```

Nativo desde Node 17. No hace falta librería.
