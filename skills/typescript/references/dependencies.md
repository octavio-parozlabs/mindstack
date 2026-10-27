# Dependencias

Cada `npm install` es código de otro que ahora es tuyo: lo mantenés, lo auditás, lo actualizás.

## Reglas

| Regla | Por qué |
|---|---|
| Antes de agregar una: ¿lo hace Node? ¿lo hace una que ya está en el stack fijo? ¿son 20 líneas? | `fetch`, `AbortSignal`, `structuredClone`, `util.parseArgs`: Node ya trae mucho. Y `lodash-es`, Zod, Tailwind ya están: no agregar `ramda`, `yup` o `date-fns-tz` para algo que el stack ya cubre |
| Una dependencia nueva se justifica en el PR: qué hace, por qué esa, cuántos downloads y último release | el que revisa decide con datos. "La vi en un tutorial" no es justificación |
| Lockfile commiteado siempre. `npm ci` en CI, nunca `npm install` | sin lockfile, el build de hoy y el de mañana instalan cosas distintas |
| No cambiar el gestor de paquetes del repo | si hay `pnpm-lock.yaml`, es pnpm. Mezclar lockfiles rompe el install de todos |
| `dependencies` vs `devDependencies` bien puestas | lo que no se necesita en runtime no va a producción. Afecta tamaño de imagen y superficie de ataque |
| Versiones con `^` para libs, exactas (`save-exact`) para herramientas de build | un patch de ESLint que cambia reglas rompe CI sin que nadie haya tocado nada |
| `npm audit` con `high` o `critical` no se ignora. Se actualiza o se documenta por qué no se puede | esperar al incidente es más caro |

## Lo que ya está y no se discute

La lista completa es la tabla "Con qué" de `../SKILL.md` (y la de `react` o `node-api` según el lado). Si una tarea "necesita" una alternativa a algo de ahí, se plantea en el PR con el por qué. No se instala primero.

## Qué pedirle a Claude

> "¿Se puede hacer sin agregar dependencia? Si no, proponé una y justificala."

Claude tiende a agregar la librería que conoce. Con esto, primero mira lo que hay.
