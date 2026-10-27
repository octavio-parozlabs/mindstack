# Config: el entorno se lee una vez, se valida, y queda en un objeto

Decisión cerrada: **una app lee su entorno en un solo módulo, `config`, al arrancar. Lo valida contra un schema, lo congela, y lo exporta como un objeto plano y tipado. Ningún otro archivo toca el entorno: todos importan `config`.** Es `../../architecture/SKILL.md` §6 con los detalles que no se negocian. Con qué se implementa en cada lenguaje lo dice el stack (`../../typescript/references/config.md`).

## Las decisiones

| Decisión | Valor | Por qué | Cuándo cambia |
|---|---|---|---|
| Dónde se lee el entorno | en `config`, y en ningún otro archivo. Lo fuerza el lint del lenguaje | afuera de `config`, una variable de entorno es un string que puede no existir, y el error aparece en el código que la usó, en producción. Adentro, aparece al arrancar con el nombre de la variable | nunca |
| Cuándo | una vez, al arrancar, antes de aceptar tráfico | si falta algo, el proceso sale con código distinto de 0 y el orquestador lo ve. Un servicio "arriba pero roto" es peor que uno caído | nunca |
| Cómo | contra un schema: tipo, formato, rango, defaults | `PORT=abc` no es un puerto; un origen con barra final no es un origen; un secreto de 8 bytes no es un secreto. El schema es el contrato del entorno, como `contracts` es el del HTTP | nunca |
| Qué sale | un objeto plano, inmutable, con tipos derivados del schema | leerlo es leer una propiedad: barato, tipado, sin `?? default` repartidos. Inmutable para que ningún test ni hot fix lo mute y el orden de ejecución decida quién ve qué | nunca |
| Qué entra | lo que cambia entre entornos: URLs, puertos, secretos, flags, nivel de log, orígenes, IPs de proxy | es la definición de config: lo que es distinto en dev, staging y prod | |
| Qué no entra | constantes del código (duraciones de tokens, límites de body, nombres de cookies) y el "modo" del entorno (`NODE_ENV` y equivalentes) | una constante en config es una decisión que alguien va a cambiar por `.env` sin PR. Y el "modo" es una convención de herramientas, no una descripción: un staging en "development" es común y no debería apagar nada | |
| Decisiones de seguridad | por el valor concreto, nunca por el modo. "¿`WEB_ORIGIN` es `http://localhost…`?", no "¿es development?" | `cookies.md`, `origin.md`: un staging con el modo equivocado mandaría cookies sin `Secure` y CORS abierto | nunca |
| Secretos | nunca en el repo. `.env` ignorado desde el primer commit (`../../workflow/references/git.md`); `.env.example` con los nombres y sin valores, con exactamente las claves del schema | un secreto commiteado se rota, no se borra. El example al día es lo que hace que la persona nueva arranque en cinco minutos | nunca |
| El frontend | mismo patrón sobre las variables que el bundler hornea en build; solo URLs y flags públicos | lo que entra al bundle lo ve cualquiera. Un secreto ahí no es un secreto (`../../typescript/references/security.md`) | nunca |
| Leer el entorno en runtime | no. Ni releer el archivo, ni consultar el entorno por request | ahí sí es disco, y por request. Y pisa valores que el entorno real del contenedor había puesto | nunca |

## Por qué una sola lectura, y por qué no es por el disco

Leer una variable de entorno no toca el disco: el sistema operativo le pasa el bloque de entorno al proceso al arrancar y queda en memoria. Un archivo `.env` lo lee una sola vez la herramienta que lo carga, al arrancar. El costo de leer el entorno en cada uso es menor y es real en un hot path, pero no es el motivo. El motivo es que **afuera de `config` el entorno es un string sin validar que puede no existir**, y que un proceso que arrancó con el entorno incompleto es un incidente diferido. Una lectura, un lugar, un schema, un objeto: el entorno se valida como se valida cualquier otra frontera (`../../architecture/SKILL.md` §4).

## Qué pasa si no

| Atajo | Lo que cuesta |
|---|---|
| leer el entorno donde se usa | la misma variable con tres defaults distintos en tres archivos; el error aparece en producción en el request que la tocó |
| convertir sin validar (`Number(PORT)`) | `PORT=abc` da un número inválido y el servidor escucha en cualquier lado. Arranca "bien" |
| config mutable | un test la cambia "para probar algo" y el orden de los tests decide el resultado |
| decidir seguridad por el modo | staging con el modo equivocado: sesión por HTTP, CORS abierto. Y nadie lo ve porque "funciona" |
| releer el entorno por request | disco en el hot path, y valores del contenedor pisados por un archivo viejo |
| `.env.example` desactualizado | la persona nueva pierde una hora con stack traces de variables que no sabía que existían |
| una constante en config "por flexibilidad" | alguien pone `ACCESS_TTL=86400` en el `.env` de prod y el access token dura un día. Sin PR, sin revisión |

## Tests que tienen que existir

- Arrancar sin una variable obligatoria: el proceso sale con código distinto de 0 y el mensaje nombra la variable.
- Un valor con formato inválido (puerto no numérico, origen con path, secreto corto): no arranca.
- `.env.example` tiene exactamente las claves del schema, ni una más ni una menos. Es el test que lo mantiene al día.
- Ningún archivo fuera de `config` lee el entorno: lo frena el lint en cada edición y un `grep` en CI (`../../docker-ci/references/ci.md`, patrones prohibidos).
- `config` es inmutable: asignar una propiedad falla o no tiene efecto, y hay un test que lo prueba.

## Qué pedirle a Claude

> "Antes de usar una variable de entorno nueva, agregala al schema de `config` con su tipo y su default o su obligatoriedad, y a `.env.example`. Después importá `config`."

## Fuentes

- [The Twelve-Factor App, III. Config](https://12factor.net/config): la config en el entorno; lo que cambia entre deploys y nada más.
- [OWASP, Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html): secretos fuera del repo, rotación cuando se filtran.
- [Node.js, `process.env`](https://nodejs.org/api/process.html#processenv): el entorno es un objeto de strings cargado al arrancar.
