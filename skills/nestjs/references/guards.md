# Guards

Autorización declarativa: tres decoradores sobre el handler dicen qué roles, de qué recurso sale el tenant y con qué modo. El cuerpo del handler no tiene un solo `if` de permisos.

## Reglas

| Regla | Por qué |
|---|---|
| Identidad y autorización separadas. Un middleware resuelve **quién** es (`request.client` por `x-api-key`, `request.user` por la cookie de sesión) y no decide nada | parsear el token en cada guard es repetir; y permite dos modos de auth sobre el mismo request sin que los guards lo sepan |
| El token de sesión viene en la cookie `httpOnly` y se verifica con `jose`. `Authorization: Bearer` solo para clientes que no son browser, los de `x-api-key` | `../../web-security/references/jwt.md` y `cookies.md`. Las notas originales de este patrón usaban `Bearer` + `jsonwebtoken`; se adapta al core |
| Decorador = metadata, sin lógica: `SetMetadata(ROLES_KEY, roles)` | lo que se puede leer con `Reflector` no necesita un `if`. El decorador no sabe qué es un rol |
| Guard = lee la metadata con `getAllAndOverride([handler, class])` y decide. Sin metadata, deja pasar | el método pisa a la clase. Un guard que falla sin metadata obliga a decorar todo, incluso lo público |
| Los guards tiran `AppError` (`UNAUTHORIZED`, `FORBIDDEN`), nunca `ForbiddenException` | pasan por el filtro de `exceptions.md` y salen con el formato del contrato |
| Autorización por recurso: otro decorador (`@ClientFrom('wizard')`), otro guard, y la regla de negocio en un **port** que implementa el módulo dueño del recurso | el guard es genérico: saca el id de `params` o `body` y pregunta. La regla "este usuario puede tocar este wizard" vive donde vive el wizard |
| Param decorators fail-closed: `@GetClient()` explota si `request.client.id` no es string. La variante que devuelve `null` se escribe aparte y se llama `GetClientOptional` | el default seguro es el que no hay que acordarse de poner |
| Orden en `@UseGuards(RolesGuard, ResourceClientGuard)`: roles primero | `RolesGuard` deja `request.user`; `ResourceClientGuard` lo necesita |

## Cómo

```ts
// apps/api/src/shared/decorators/roles.decorator.ts  (entero)
export const ROLES_KEY = 'ROLES_KEY';
export const AllowedRoles = (...roles: UserRole[]) => SetMetadata(ROLES_KEY, roles);
```

```ts
// apps/api/src/shared/guards/roles.guard.ts
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector, private readonly session: SessionService) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const required = this.reflector.getAllAndOverride<UserRole[] | undefined>(ROLES_KEY, [ctx.getHandler(), ctx.getClass()]);
    if (!required) return true;

    const req = ctx.switchToHttp().getRequest<Request>();
    const token = req.cookies[ACCESS_COOKIE] ?? bearerFromNonBrowser(req);   // web-security/references/jwt.md
    if (!token) throw new AppError({ type: 'UNAUTHORIZED', code: 'UNAUTHORIZED', message: 'No session' });

    const payload = await this.session.verify(token);   // jose.jwtVerify; tira AppError UNAUTHORIZED si falla
    req.user = payload;
    if (payload.isSuperAdmin) return true;

    const role = effectiveRole(payload);
    if (!role || !required.includes(role)) throw new AppError({ type: 'FORBIDDEN', code: 'FORBIDDEN', message: 'Forbidden' });
    return true;
  }
}
```

```ts
// apps/api/src/shared/decorators/client-from.decorator.ts
export const ClientFrom = (source: ResourceKind, o: { param?: string; from?: 'params' | 'body'; mode?: 'read' | 'write' } = {}) =>
  SetMetadata(CLIENT_FROM_KEY, { source, param: o.param ?? 'id', from: o.from ?? 'params', mode: o.mode ?? 'read' });

// apps/api/src/shared/guards/resource-client.guard.ts  (lo que importa)
const meta = this.reflector.getAllAndOverride<ClientFromMeta | undefined>(CLIENT_FROM_KEY, [ctx.getHandler(), ctx.getClass()]);
if (!meta) return true;
const id = req[meta.from][meta.param];
const { clientId } = await this.access.resolve({ [meta.source]: id }, req.user, meta.mode);   // port, lo implementa el módulo dueño
req.client = clientId ? { id: clientId } : null;
```

```ts
// apps/api/src/shared/decorators/get-client.decorator.ts
export const GetClient = createParamDecorator((_, ctx): ClientContext => {
  const req = ctx.switchToHttp().getRequest<Request>();
  if (typeof req.client?.id !== 'string') {
    throw new AppError({ type: 'UNAUTHORIZED', code: 'CLIENT_UNRESOLVED', message: 'Could not resolve client for this request' });
  }
  return req.client;
});
export const GetClientOptional = createParamDecorator((_, ctx): ClientContext | null => ctx.switchToHttp().getRequest<Request>().client ?? null);
```

```ts
// apps/api/src/wizards/wizard.controller.ts
@UseGuards(RolesGuard, ResourceClientGuard)
@Controller('wizards')
export class WizardController {
  @AllowedRoles('USER', 'ADMIN', 'OPERATOR')
  @ClientFrom('wizard')
  @Get(':id')
  findOne(@Param('id') id: string, @GetClient() client: ClientContext, @CurrentUser() user: SessionPayload) { ... }
}
```

## Mal / Bien

```ts
// Mal: la regla en el handler, el tenant puede llegar undefined
@Get(':id')
async findOne(@Param('id') id: string, @Req() req: Request) {
  if (req.user?.role !== 'ADMIN' && req.user?.role !== 'OPERATOR') throw new ForbiddenException();
  return this.service.findOne(id, req.client?.id);   // undefined → TypeORM devuelve TODO
}
```

El bloque "Bien" es el controller de arriba: tres decoradores, cero `if`.

## Trampas

1. **`undefined` que se vuelve "todo".** TypeORM descarta `where: { client: { id: undefined } }` y devuelve todas las filas de todos los clientes. Un decorator que devolvía `undefined` fue una fuga multi-tenant real. Por eso `GetClient` explota si falta.
2. **`req.client` siempre truthy.** En Node, `IncomingMessage.client` es un alias legacy de `req.socket`. Un `if (!req.client)` nunca corta. Validar la **forma** (`typeof client.id === 'string'`), no la verdad.
3. **Metadata en la clase y en el método.** `getAllAndOverride` toma el método si existe; `getAllAndMerge` los une. Para roles, override: un endpoint público dentro de un controller de admin tiene que poder decir "sin roles".

## Para copiar

`roles.decorator.ts`, `roles.guard.ts`, `current-user.decorator.ts`, un `GetX` fail-closed para el scope que tengas (tenant, org, workspace). Cuando aparezca autorización por recurso: `client-from.decorator.ts`, `resource-client.guard.ts` y un port. Specs al lado, casos en `TESTING.md`.
