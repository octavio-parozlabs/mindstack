# Filtros de listados

El cliente manda un árbol de filtros (`and`/`or` con reglas `path`, `operator`, `value`, `negated`). El backend lo valida en forma, lo resuelve contra una whitelist por endpoint y lo convierte en `where` de TypeORM. Un parser, un componente de UI, y cada tabla nueva son cinco líneas.

Cuándo: en la **segunda** tabla con filtros. Con una, un query param por columna alcanza y esto es prematuro.

## Reglas

| Regla | Por qué |
|---|---|
| El árbol viaja en el query string con bracket-notation, serializado con `qs` en el front y parseado con `qs` en el back | la misma librería a los dos lados garantiza simetría. Axios solo no serializa objetos anidados |
| Un param decorator re-parsea **solo** la porción `filter` del query string crudo. No se cambia el query parser global de Express | Express 5 usa el parser simple de Node y deja `filter[rules][0][path][0]` como clave plana. Cambiarlo a `extended` rompe los endpoints que dependen de "clave repetida → array" |
| El schema de Zod del árbol valida **forma**, no contenido: grupo con combinador y reglas; regla con `path`, `operator`, `value` | si el schema supiera qué columnas existen, agregar una columna sería tocar el schema y la whitelist. Dos lugares, drift seguro |
| La whitelist es la lista de ejes del endpoint: `simpleAxes` (columnas) y `axisResolvers` (ejes derivados). `path[0]` que no está → 400 `FILTER_UNSUPPORTED` | no hay una lista aparte que mantener. Lo que no se declaró no se puede filtrar |
| `textAxis<T>(column: keyof T & string)`: el tipo ata la whitelist a la entidad | una columna inexistente es error de compilación, no un 500 en producción |
| Límites: profundidad 5, 30 reglas por árbol | un árbol de 10.000 nodos no tumba la instancia |
| Los operadores negativos se normalizan a positivo + `negated` antes de resolver | ningún resolver conoce `not_contains`; conoce `contains` y un booleano |
| Toda negación es NULL-safe: `(col IS NULL OR col::text != :v)` | en SQL de tres valores, `col != 'x'` no devuelve las filas con NULL |
| Comparar siempre con `::text` | una columna `uuid` contra un string que no es UUID es error de sintaxis → 500. Con `::text`, no matchea y listo |
| Dos reglas sobre la misma columna se combinan con `And()` de TypeORM, nunca con spread | el spread pisa la primera. Fue un bug real |
| El `ctx` de un eje derivado (userId, isAdmin) lo pone el servidor. Nunca viene del árbol | lo que el cliente manda es filtro; lo que el servidor sabe es autorización |

## Cómo

Wire, front:

```ts
// apps/web/src/api/qs-params.ts
import qs from 'qs';
export const QS_PARAMS = { paramsSerializer: (p: unknown) => qs.stringify(p, { skipNulls: true }) };
// http.get('/wizards', { params: { page, limit, filter: tree }, ...QS_PARAMS })
```

```
GET /wizards?page=1&limit=20
  &filter[type]=group&filter[combinator]=and
  &filter[rules][0][type]=rule&filter[rules][0][path][0]=name&filter[rules][0][operator]=contains&filter[rules][0][value]=alta
  &filter[rules][1][type]=rule&filter[rules][1][path][0]=createdAt&filter[rules][1][operator]=between
  &filter[rules][1][value][0]=2026-01-01&filter[rules][1][value][1]=2026-03-31
```

Wire, back:

```ts
// apps/api/src/shared/filters/parsed-filter-tree.decorator.ts
export const ParsedFilterTree = createParamDecorator((_, ctx): FilterTreeNode | undefined => {
  const req = ctx.switchToHttp().getRequest<Request>();
  const raw = qs.parse(req.url.split('?')[1] ?? '').filter;
  const result = filterTreeSchema.optional().safeParse(raw);
  if (!result.success) {
    throw new AppError({ type: 'BAD_REQUEST', code: 'FILTER_INVALID', message: 'Invalid filter', details: { issues: result.error.issues } });
  }
  return result.data;
});
```

Dos trampas de `qs` que el schema absorbe: no convierte tipos (`negated=true` llega como `"true"`: `z.union([z.boolean(), z.enum(['true','false'])]).transform(...)`), y omite arrays vacíos (un grupo raíz sin reglas llega sin `rules`: `rules: z.array(filterTreeSchema).default([])`).

Whitelist, una línea por columna:

```ts
// apps/api/src/clients/infrastructure/filter-axes.ts  (entero)
export const FILTER_DEPS: FilterTreeDeps<Client> = {
  axisResolvers: {},            // ejes derivados, acá ninguno
  simpleAxes: [
    textAxis('name'),           // contains / starts_with / ends_with / is
    boolAxis('isActive'),       // is / is_any_of
    dateAxis('createdAt'),      // is / between / is_before / is_after
    dateAxis('updatedAt'),
  ],
};
```

Repositorio y controller:

```ts
// client.repository.ts
const qb = this.repo.createQueryBuilder('c').setFindOptions({ where: toArray(resolveFilterTree(tree, ctx, FILTER_DEPS)) });
return paginateQuery(qb, options, ORDER, 'createdAt', 'c.createdAt');

// client.controller.ts
@Get() list(@ParsedFilterTree() tree: FilterTreeNode | undefined, @Query() q: ListQuery) { return this.useCase.list(tree, q); }
```

Cómo resuelve `shared/filters/resolve-filter-tree.ts`:

1. Límites anti-DoS: `MAX_TREE_DEPTH = 5`, `MAX_RULES = 30`.
2. Normalización: `is_not` → `is` + `negated`, `not_contains` → `contains` + `negated`; XOR con el `negated` explícito.
3. Dispatch por `path[0]`: primero `axisResolvers`, después `simpleAxes`. Desconocido → 400. Esa es la whitelist.
4. Grupo `or` → array de `where` (TypeORM lo lee como OR). Grupo `and` → producto cruzado (`crossAnd` en `where-algebra.ts`): `(A or B) and C` → `[A∧C, B∧C]`.
5. Misma columna dos veces → `And()` (`mergeAnd`).

Detalles SQL en `simple-axes.ts`: negación NULL-safe, `::text` siempre, `quoteAlias` (TypeORM entrega el alias sin comillar dentro de `Raw()` y Postgres lo pliega a minúsculas: "missing FROM-clause entry"), y jsonb por path con `#>>` parametrizado (`"user.dni"` e `"items.0.sku"` con el mismo mecanismo, sin interpolar).

Ejes derivados, `shared/filters/status-axis.ts`: un estado calculado de varias columnas (draft "pendiente" = `completedAt IS NULL AND awaitingActor IS NOT NULL`) se declara como mapa `{ opcion: where }` y el helper genera `is`, `is_any_of` y la negación (las opciones restantes). Un `axisResolver` custom es `(operator, value, negated, ctx) => where | where[] | null`.

## Mal / Bien

```ts
// Mal: un endpoint por tabla, un if por parámetro, AND fijo, sin negación
@Get() list(@Query('name') name?: string, @Query('status') status?: string, @Query('from') from?: string) {
  const where: FindOptionsWhere<Client> = {};
  if (name) where.name = ILike(`%${name}%`);
  if (status) where.status = status;          // "status" no está validado contra nada
  if (from) where.createdAt = MoreThan(from);
  return this.repo.find({ where });
}
```

El bloque "Bien" son las cinco líneas de `FILTER_DEPS` más el decorator. La lógica vive una vez en `shared/filters/`.

## Para copiar

`shared/filters/` entera (unas 700 líneas con specs: schema, resolver, `where-algebra`, `simple-axes`, `status-axis`, `sql-helpers`, decorator), `qs` en los dos lados, `paginateQuery` de `shared/helpers/pagination.ts`. El componente de UI que arma el árbol es la otra mitad y se reutiliza igual. Tests: `TESTING.md`, sección "Árbol de filtros".
