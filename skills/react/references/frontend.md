# Frontend

React. Estilos con Tailwind; lo dinámico en runtime con UnoCSS. Componentes de shadcn/ui copiados en `packages/ui`. HTTP con una instancia de axios. Datos con TanStack Query, Table y Virtual. Forms y respuestas validadas con los schemas de `contracts`. HTML de datos sanitizado con DOMPurify.

## Estilos: Tailwind vs UnoCSS

Tailwind genera CSS **en build** escaneando el código fuente. Una clase construida en runtime (`bg-${color}-500`) no existe en el CSS final. Para eso está UnoCSS runtime, que genera la clase en el browser cuando aparece.

Ojo con la CSP: el runtime inyecta `<style>` en el browser, y la política del core no aplica estilos inline sin nonce (`../../web-security/references/csp.md`, "Librerías que inyectan `<style>`"). Antes de usarlo en un proyecto, verificar en Playwright con la política en enforce que tome el nonce. Si no lo toma, no entra: la clase dinámica va por `style={{}}`, que React setea por CSSOM y CSP no bloquea, y esa es la única excepción al "nunca `style={}`" de abajo.

| Caso | Usar | Ejemplo |
|---|---|---|
| clase fija o elegida entre un set conocido | Tailwind | `className="p-4 bg-slate-100"`, `isActive ? 'bg-blue-500' : 'bg-gray-200'` |
| clase que depende de datos en runtime: color que elige el usuario, tema de un tenant, valor de un CMS | UnoCSS runtime | `className={\`bg-[${tenant.brandColor}]\`}` con `@unocss/runtime` cargado |
| variantes de un componente | `cva` (class-variance-authority, viene con shadcn) + Tailwind | `button({ variant: 'destructive', size: 'sm' })` |
| merge de clases desde props | `cn()` de shadcn (clsx + tailwind-merge) | `cn('p-4', className)` |

Nunca:

- `style={{ color: x }}` cuando hay utilidad. Inline rompe el sistema de diseño y no se puede overridear.
- CSS modules, styled-components, Emotion. Un sistema de estilos, no tres.
- Concatenar strings para armar clases de Tailwind. No las genera y falla en silencio.

## Componentes: shadcn/ui

- Se instalan con `npx shadcn@latest add button` **en `packages/ui`**, no en la app. Quedan como código propio.
- Se modifican ahí. Un `Button` que necesita una variante nueva: se agrega al `cva` del `Button`, no se envuelve en otro componente.
- `packages/ui` no conoce el dominio: exporta `Button`, `Dialog`, `DataTable`. `OrderTable` vive en `apps/web/src/orders/`.
- No instalar otra librería de componentes "para una cosa". Si shadcn no lo tiene, se arma con Radix (que shadcn ya trae) y Tailwind.

## HTTP: axios, una instancia

`fetch` no se usa. Una instancia de axios creada una vez y exportada como constante; todo request pasa por ella.

```ts
// apps/web/src/api/http.ts
import axios from 'axios';
import { ErrorResponseSchema } from '@acme/contracts';
import { config } from '@/config';          // el único que lee import.meta.env (../../typescript/references/config.md)
import { ApiError } from './api-error';

export const http = axios.create({
  baseURL: config.VITE_API_URL,
  timeout: 10_000,
  withCredentials: true,
});

http.interceptors.request.use((req) => {
  req.headers['X-Request-Id'] = crypto.randomUUID();
  return req;
});

http.interceptors.response.use(
  (res) => res,
  (error) => {
    const parsed = ErrorResponseSchema.safeParse(error.response?.data);
    throw parsed.success
      ? new ApiError(parsed.data, error.response.status)
      : new ApiError({ code: 'INTERNAL', message: error.message }, error.response?.status ?? 0);
  },
);
```

| Regla | Por qué |
|---|---|
| Un solo `axios.create` en `api/http.ts`. Ningún componente ni hook importa `axios` directo | base URL, timeout, credenciales, headers y manejo de errores en un lugar. Cambiar la auth es tocar un archivo |
| Los interceptors traducen el error HTTP al `ErrorResponse` del contrato y lo lanzan como `ApiError` tipado | el que llama hace `catch (e) { if (e instanceof ApiError && e.code === 'NOT_FOUND') }`, nunca mira `e.response.data` |
| Un módulo por recurso en `api/`: `orders.ts` exporta `createOrder(input): Promise<Order>`, usa `http` y parsea la respuesta con el schema | los componentes llaman funciones con tipos, no URLs |
| `AbortSignal` de TanStack Query se pasa al request: `http.get(url, { signal })` | al desmontar o cambiar de página, el request se cancela |

## Datos: TanStack

Tres librerías de TanStack, cada una para un problema. No se reemplazan por `useEffect` + `useState`.

| Problema | Librería | Nunca |
|---|---|---|
| traer, cachear y refrescar datos de la API | `@tanstack/react-query` | `useEffect(() => { fetch... })`, estado de servidor en un store global |
| tablas: sort, filtro, paginación, selección, columnas | `@tanstack/react-table` | implementar sort y paginación a mano, otra librería de tablas |
| listas largas (cientos o miles de filas) | `@tanstack/react-virtual` | renderizar 5000 filas y "después vemos" |

Reglas:

- Toda lectura de la API es un `useQuery` con `queryKey` por recurso e id: `['orders', orderId]`. Toda escritura es un `useMutation` que invalida las keys que afecta.
- Estado de servidor (viene de la API) con Query. Estado de UI (modal abierto, tab activa, fila seleccionada) con `useState` o un store chico. No mezclar.
- Una tabla que muestra datos de la API usa Table sobre los datos de Query; la paginación server-side pasa `page` y `sort` por la `queryKey`.
- Lista con más de ~100 ítems visibles a la vez: Virtual. Antes, no hace falta.

## Editores de código y texto rico

Un `<textarea>` alcanza para texto plano corto. Cuando se queda corto, hay una sola opción:

| Caso | Usar | Nunca |
|---|---|---|
| editar código, JSON, YAML, SQL, expresiones, templates: cualquier cosa con sintaxis | Monaco Editor (`@monaco-editor/react`) | `<textarea>` con `font-family: monospace`, CodeMirror, Ace |
| texto plano, una o pocas líneas | `<input>` / `<textarea>` de shadcn | Monaco para un campo de descripción |

Reglas:

- Monaco se carga **lazy**: `React.lazy` o `dynamic` con el componente que lo envuelve. Pesa varios MB y no va en el bundle inicial.
- Un solo wrapper en `packages/ui`: `CodeEditor` con `language`, `value`, `onChange`, `readOnly`. Las apps no importan `@monaco-editor/react` directo.
- Si el contenido tiene schema (un JSON de config), se valida con Zod al guardar, no se confía en que "Monaco lo marcó verde".
- Diff de dos versiones: `DiffEditor` del mismo paquete, no una librería aparte.

## Forms

| Regla | Por qué |
|---|---|
| `react-hook-form` + `zodResolver(CreateOrderRequest)`. El schema viene de `contracts`, no se escribe otro | el front valida lo mismo que el back, campo por campo, antes de mandar |
| El submit llama a la función de `api/`, dentro de un `useMutation` | loading, error y refetch resueltos; el componente solo muestra |
| Errores de la API se leen por `code` del `ApiError`, nunca por `message` | `message` cambia; `code` es contrato |

## Seguridad en el front

Lo mínimo, siempre. El resto en `../../typescript/references/security.md`.

- Todo HTML que venga de datos (un comentario, una descripción de producto, un CMS) pasa por `DOMPurify.sanitize()` antes de `dangerouslySetInnerHTML`. Sin excepción.
- Mejor todavía: no renderizar HTML de datos. Texto plano en JSX ya escapa solo.
- Tokens de sesión en cookies `httpOnly`, no en `localStorage`. `withCredentials: true` en axios.
- Sin secretos en el bundle. `VITE_*` es público: solo URLs y flags.

## Lógica

- Sin lógica de negocio. El total lo calcula la API o una función pura de `contracts`. Dos implementaciones divergen.
- `lodash-es` para datos: `groupBy`, `sortBy`, `debounce`. Import por función: `import { debounce } from 'lodash-es'`.

## Estructura

```
apps/web/src/
├── api/               http.ts (instancia axios) + cliente tipado por recurso: orders.ts, users.ts
├── orders/            feature: componentes, hooks, estado de esa pantalla
│   ├── OrderList.tsx
│   ├── OrderList.test.tsx
│   └── useOrders.ts
├── app/ o routes/     según el router
└── lib/               cn(), config del cliente, helpers sin dominio
```

## Tests

- Componentes: Testing Library, por comportamiento visible ("muestra el error del cupón"), no por implementación (`state.error === ...`).
- API mockeada en la frontera con MSW, usando los schemas de `contracts` para generar respuestas válidas. No mockear `http` ni los módulos de `api/`: MSW intercepta por debajo de axios.
- Sin snapshot tests de componentes enteros. Rompen con cualquier cambio y nadie los lee.
