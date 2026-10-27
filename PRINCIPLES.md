# Principios

Lo que desempata cuando dos reglas chocan o ninguna aplica. No se verifican con lint: se invocan. Si ningún principio decide, se pregunta; no se adivina.

Fuente: el Zen de Python (https://peps.python.org/pep-0020/), que no es de Python. Quedan los que cambian una decisión en este flujo; los demás son decorativos o repiten a estos.

| Principio | Acá significa | Quién lo aplica |
|---|---|---|
| Explícito antes que implícito | validar en la frontera, named exports, tipar lo exportado, config leída una vez y validada. Una tarea dice su alcance en `SPEC.md`; lo que no está escrito no se hace | analista, dev, revisor de código |
| Los errores nunca pasan en silencio | sin `catch` vacío, promesas manejadas, cobertura roja bloquea el PR. Un hallazgo de revisión se corrige o queda como deuda con vencimiento; nunca se ignora | dev, qa, corrector |
| Plano antes que anidado | early return, funciones que entran en pantalla, carpetas por feature y no por tipo | dev, revisor de código |
| Una sola forma obvia de hacerlo | columna "Nunca" de la tabla "Con qué" de cada skill de stack. Dos librerías para lo mismo es una decisión que nadie tomó | planificador, dev |
| Práctico antes que puro, pero los casos especiales no rompen las reglas | la perfección no es el objetivo de una tarea; un refactor grande es otra tarea. Un caso especial cambia una regla por PR al plugin, no se la saltea | dev, corrector |
| Si es difícil de explicar, es mala idea | comentario que explica código confuso = arreglar el código. SPEC que no entra en un párrafo = dos tareas. Diagrama que no se entiende solo = rehacerlo | analista, planificador, dev |
| Ahora es mejor que nunca; nunca suele ser mejor que ya mismo | lo especulativo no entra (YAGNI). Lo que entra, entra completo, con test y en esta tarea | planificador, dev |
| Ante la ambigüedad, no adivinar | el analista pregunta hasta que no queda ambigüedad. El dev que encuentra una devuelve `DECISION:` y se busca consenso; si no hay, decide la persona | analista, dev, orquestador |
| Los namespaces son buena idea | una feature no importa internals de otra; `shared/` solo para lo que usan dos o más. Cada rol escribe sus archivos y no los de otro | dev, todos los roles |

## Cómo se usa

- En un plan: cuando dos opciones empatan, el principio decide y queda en Decisiones del `CHANGELOG.md`, columna Principio. Una decisión sin principio es gusto, y el gusto se discute en el PR.
- En una revisión: un comentario que dice "yo lo haría distinto" no es hallazgo. "Rompe explícito antes que implícito: el handler lee `process.env`" sí.
- En un consenso: cada analista cita el principio que respalda su opción. Dos opciones con principio distinto es un empate real y lo decide la persona.
- En el plugin: una regla nueva tiene que responder a uno de estos. Si no responde a ninguno, es preferencia y va marcada ajustable.
