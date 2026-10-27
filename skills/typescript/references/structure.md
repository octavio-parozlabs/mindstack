# Estructura

Carpetas por **feature**, no por tipo de archivo. Lo que cambia junto, vive junto.

## Forma

```
src/
├── config.ts                 env validado, único lugar que lee process.env
├── orders/
│   ├── order.ts              tipos y schema del dominio
│   ├── order.service.ts      lógica
│   ├── order.service.test.ts
│   ├── order.repository.ts   acceso a datos
│   └── order.repository.test.ts
├── users/
│   └── ...
└── shared/                   solo lo que usan 2+ features. Si lo usa una, va en la feature
    ├── errors.ts
    └── logger.ts
```

No: `src/services/`, `src/repositories/`, `src/types/` con todo mezclado. Para tocar "orders" hay que abrir cuatro carpetas.

## Reglas

| Regla | Por qué |
|---|---|
| Named exports. Sin `export default` | refactor con rename funciona, el import dice qué trae, y no hay dos nombres para la misma cosa |
| Sin `index.ts` barrel que re-exporte | rompe tree-shaking, crea ciclos de import, y `import { x } from '../orders'` oculta de qué archivo viene |
| Imports absolutos con alias `@/`: `@/orders/order.service` | `../../../shared/errors` se rompe al mover archivos |
| Un archivo, un concepto. Si el nombre necesita "y" (`userAndOrderUtils`), son dos | lo que se puede nombrar se puede encontrar |
| Dependencias en una dirección: `shared` no importa de features; una feature no importa internals de otra, solo su API pública | los ciclos son la causa número uno de "undefined is not a function" en el arranque |
| Lo que no se exporta es privado. No exportar "por las dudas" | cada export es superficie que alguien va a usar y después no se puede cambiar |
| Un archivo no pasa de 300 líneas. ESLint `max-lines` lo corta; el número es ajustable, el límite no | un archivo largo degrada a quien lo lee: más tokens por lectura, ediciones que pisan otras, y la tentación de agregar "acá mismo". Si no entra, son dos conceptos. Por qué y cómo se fuerza en CI: `../../docker-ci/references/ci.md` |

```js
// eslint.config.js
rules: {
  'max-lines': ['error', { max: 300, skipBlankLines: true, skipComments: true }],
}
```

## Preferencias (ajustables)

- Sufijos `.service`, `.repository`, `.schema` en el nombre. Dicen el rol sin abrir el archivo.
- Clases solo cuando hay estado y ciclo de vida (una conexión, un cliente). Lo demás, funciones.
