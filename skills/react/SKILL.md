---
name: react
description: >-
  Experto en el frontend con React. Qué librería para qué y cuáles nunca (Tailwind para estilos estáticos y UnoCSS runtime para dinámicos, shadcn/ui copiado en packages/ui, cva y cn, una instancia de axios, TanStack Query, Table y Virtual, react-hook-form con los schemas del contrato, DOMPurify, Monaco), CSP con nonce frente a librerías que inyectan estilos, y tests de componente con Testing Library, happy-dom, MSW y Playwright. Usar al escribir o revisar componentes, hooks, estilos, forms, llamadas a la API o tests en apps/web o packages/ui.
paths:
  - "apps/web/**"
  - "packages/ui/**"
---

# React

El front. Asume la skill `typescript` (tipos, errores, estructura, tests, lint): lo que está ahí no se repite. La seguridad del lado del cliente (XSS, tokens, CSP) está en `../typescript/references/security.md` y en la skill `web-security`.

## Con qué

| Para | Se usa | Nunca | Regla |
|---|---|---|---|
| UI | React | | `references/frontend.md` |
| estilos estáticos | Tailwind CSS | CSS modules, styled-components, Emotion, `style={}` | `references/frontend.md` |
| estilos calculados en runtime | UnoCSS runtime (`@unocss/runtime`), solo si toma el nonce de la CSP; si no, no entra | concatenar clases de Tailwind con strings dinámicos | `references/frontend.md`, `../web-security/references/csp.md` |
| componentes | shadcn/ui, copiados en `packages/ui` y modificados ahí | instalarlos de npm, otra librería de componentes | `references/frontend.md` |
| variantes y merge de clases | `cva` y `cn()` (vienen con shadcn) | ternarios encadenados de clases | `references/frontend.md` |
| HTTP | axios, **una** instancia en `api/http.ts`, `withCredentials: true`, interceptor `401 TOKEN_EXPIRED` → refresh → reintento | `fetch`, `axios.get` directo en componentes | `references/frontend.md`, `../web-security/references/jwt.md` |
| datos de servidor | `@tanstack/react-query` | `useEffect` + `useState` para traer datos, estado de servidor en un store | `references/frontend.md` |
| tablas | `@tanstack/react-table` | sort y paginación a mano, otra librería de tablas | `references/frontend.md` |
| listas largas | `@tanstack/react-virtual` | renderizar miles de filas | `references/frontend.md` |
| forms | `react-hook-form` + `@hookform/resolvers` (zod) con el schema del contrato | validación a mano, otro schema para el form | `references/frontend.md` |
| HTML de datos | `dompurify` antes de `dangerouslySetInnerHTML` | HTML sin sanitizar | `../typescript/references/security.md` |
| editar código, JSON, SQL en la UI | Monaco Editor (`@monaco-editor/react`), lazy, wrapper en `packages/ui` | `<textarea>` monospace, CodeMirror, Ace | `references/frontend.md` |
| DOM para tests de componentes | `happy-dom` | `jsdom` por defecto | `references/TESTING.md` |
| render y queries en tests | `@testing-library/react` + `@testing-library/user-event`; rol o label primero, `data-testid` donde no hay semántica | Enzyme; `container.querySelector`, clases, `closest`: navegar la estructura | `references/TESTING.md` |
| matchers del DOM | `@testing-library/jest-dom` (vía `/vitest`) | | `references/TESTING.md` |
| mock de API en tests | MSW | mockear `http` o los módulos de `api/` | `references/TESTING.md` |
| end-to-end | Playwright | Cypress | `references/TESTING.md` |

Una librería entra en esta tabla cuando ya se decidió que es **la** opción para ese problema. Hasta entonces, sigue `../typescript/references/dependencies.md`: se justifica en el PR.

## Reglas

`references/frontend.md` tiene el por qué de cada fila y los ejemplos: cómo se arma la instancia de axios y el interceptor, cómo se usan Query, Table y Virtual, cómo un form toma el schema del contrato, qué se sanitiza y cuándo, y por qué una librería que mete `<style>` sin nonce rompe la CSP.

## Tests

Qué se suma a Vitest para componentes y end-to-end, con config y un ejemplo por capa: `references/TESTING.md`. En una línea: `happy-dom` como entorno, Testing Library para ver lo que ve el usuario, MSW para la API falsa en un solo lugar con los schemas de `contracts`, Playwright para pocos flujos críticos.
