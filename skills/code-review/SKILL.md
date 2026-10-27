---
name: code-review
description: Revisa un cambio de código en cuatro dimensiones (lógica y corrección, legibilidad, arquitectura, rendimiento) y escribe REVIEW-code.md con solo hallazgos negativos, cada uno con severidad, archivo:línea, entrada que lo dispara y fix en una línea. Usar cuando hay que revisar un diff, un PR o un rango de commits antes de que entre a main, sea código propio, de otro agente o de una persona, incluso si el diff viene pegado inline. Usar desde /mindstack:orchestrate (fase review) como code-reviewer.
---

# Revisión de código

## Qué es

Una revisión que mira el cambio desde cuatro lados, en pasadas separadas, y deja por escrito solo lo que falla: dónde, con qué entrada, cuán grave y cómo se arregla. Todo cambio pasa por acá antes de entrar a main, sin excepción.

No es un veredicto ni una opinión sobre cómo lo habrías hecho vos. Es una lista de fallos verificables. Si no hay fallos, la lista va vacía y eso es el resultado.

Las dimensiones son cuatro: **lógica y corrección**, **legibilidad**, **arquitectura** y **rendimiento**. La quinta, seguridad, la cubre `mindstack:security` y la hace otro rol; acá no se desarrolla.

## Cuándo usarla

- Antes de mergear cualquier PR o cambio
- Al terminar de implementar una feature
- Cuando otro agente o modelo produjo código que tenés que evaluar
- Al refactorizar código existente
- Después de un bug fix (se revisa el fix y el test de regresión juntos)

## Las cuatro dimensiones

### 1. Lógica y corrección

¿El código hace lo que dice que hace?

- ¿Coincide con el `SPEC.md` o con la tarea pedida?
- ¿Maneja los bordes: null, vacío, valores límite, los `CB-n` del SPEC?
- ¿Maneja los caminos de error, no solo el feliz?
- ¿Pasan los tests? ¿Los tests prueban lo correcto o solo pasan?
- Off-by-one, condiciones invertidas, ramas inalcanzables, estado que cambia y nadie actualiza, errores tragados, carreras.

### 2. Legibilidad y simplicidad

¿Otro ingeniero (o agente) lo entiende sin que el autor se lo explique?

- Nombres que dicen qué es y siguen la convención del proyecto (no `temp`, `data`, `result` sin contexto). Un nombre que miente es un bug diferido.
- Flujo de control plano: early return antes que anidamiento, nada de ternarios anidados ni callbacks en cascada.
- Funciones que entran en pantalla; código relacionado junto; límites de módulo claros.
- **¿Se puede hacer en menos líneas?** Mil líneas donde alcanzan cien es un fallo.
- **¿Cada abstracción paga su complejidad?** No se generaliza hasta el tercer uso.
- Comentario que explica código confuso = arreglar el código, no el comentario.
- Código muerto: variables no-op, shims de compatibilidad, comentarios `// removido`.
- **¿Un condicional nuevo pegado a un flujo que no tiene nada que ver?** Es un problema de diseño, no un nit: la lógica va en su propio helper, estado o política.
- **¿Condicionales repetidos sobre la misma forma?** Falta un modelo o un dispatcher. Una rama "temporal" suele ser deuda permanente.

### 3. Arquitectura

¿El cambio encaja en el diseño del sistema?

- ¿Sigue los patrones existentes o mete uno nuevo? Si es nuevo, ¿está justificado?
- ¿Respeta los límites de módulo? Una feature no importa internals de otra.
- ¿Duplica algo que ya existe y debería compartirse?
- ¿Las dependencias fluyen en una dirección (sin ciclos)?
- ¿El nivel de abstracción es el justo: ni sobreingeniería ni acoplamiento?
- ¿Lógica de negocio en el handler, el controlador o la vista?
- **¿El refactor reduce complejidad o solo la muda de lugar?** Contá los conceptos que el lector tiene que sostener para seguir el cambio. Si la versión "más limpia" deja ese número igual, no es más limpia. Preferí la reestructuración que hace desaparecer ramas, modos o capas antes que la que re-centraliza la misma lógica. Preferí borrar una abstracción antes que pulirla.
- **¿Lógica de una feature filtrándose en un módulo compartido?** La lógica vive en la capa dueña; se reúsa el helper canónico en vez de un casi-duplicado; la deriva arquitectónica no se normaliza.
- **¿Los límites de tipo son explícitos?** Cuestioná `any`, casts, opcionales gratuitos y fallbacks silenciosos que tapan un invariante poco claro. Hacer explícito el límite suele simplificar el flujo alrededor.
- Dependencia nueva para algo que el stack ya resolvía.

### 4. Rendimiento

¿El cambio mete un problema de rendimiento? Pasada corta, por patrón, no por perfilado:

| Patrón | Qué buscar |
|---|---|
| N+1 | query o llamada remota adentro de un loop |
| Sin cota | loop o fetch sin límite; endpoint de listado sin paginación |
| Carga de más | traer una colección entera para usar un elemento |
| Trabajo repetido | recomputar o re-pedir lo que antes se cacheaba o se calculaba una vez |
| Bloqueo | operación sincrónica en un camino que debería ser asíncrono |
| Hot path pesado | objetos grandes creados en cada iteración o cada request |
| UI | re-renders innecesarios por dependencias mal declaradas |

Cuando lo encuentres, cuantificá: "este N+1 agrega ~50 ms por ítem de la lista" vale más que "puede ser lento".

### Seguridad

La hace `security-auditor` con `mindstack:security`, en paralelo. Si en tu pasada ves algo de seguridad (input sin validar, secreto en código, query concatenada), anotalo en "A verificar" para que el otro rol no lo pierda; no lo desarrolles ni le pongas `CODE-n`.

## Remedios estructurales

Cuando señalás un problema de estructura, proponé el movimiento, no solo el problema. "Esto es complejo" deja al autor adivinando. Nombrá la reestructuración:

- **Reemplazar una cadena de condicionales** por un modelo tipado o un dispatcher explícito.
- **Colapsar ramas duplicadas** en un solo flujo más claro.
- **Separar orquestación de lógica de negocio** para que cada una se lea sola.
- **Mover lógica de feature** fuera de un módulo compartido, al paquete dueño del concepto.
- **Reusar el helper canónico** en vez del casi-duplicado.
- **Hacer explícito un límite de tipo** para que el branching aguas abajo desaparezca.
- **Borrar un wrapper pasamanos** que agrega indirección sin aclarar la API.
- **Extraer un helper o partir un archivo grande** en módulos enfocados.

Preferí el remedio que saca piezas móviles al que reparte la misma complejidad. Un refactor grande no es un fix de una línea: si lo que ves pide uno, va a "A verificar" como observación para otra tarea.

## Tamaño del cambio

```
~100 líneas cambiadas   → bien, se revisa de una sentada
~300 líneas cambiadas   → aceptable si es un solo cambio lógico
~1000 líneas cambiadas  → demasiado, se parte
```

**Mirá el tamaño del archivo, no solo del diff.** Un diff chico puede empujar un archivo más allá de un tamaño sano (~1000 líneas totales es señal de inspección, no tope duro). Si el cambio engorda un archivo que ya era grande, primero extraer helpers o módulos, después agregar.

**Un cambio** es una modificación autocontenida que resuelve una cosa, incluye sus tests y deja el sistema funcionando. Una parte de la feature, no la feature entera. Refactor y feature nueva son dos cambios: van separados. Los cambios grandes se aceptan solo cuando son borrados completos o refactors automáticos donde se verifica la intención y no cada línea.

## Proceso

### Paso 1: entender el contexto

Antes de mirar código: qué intenta lograr el cambio, qué SPEC o tarea implementa, qué comportamiento se espera que cambie. Sin esto, revisás sintaxis.

### Paso 2: los tests primero

Los tests revelan intención y cobertura:

- ¿Existen tests para el cambio? ¿Prueban comportamiento, no detalles de implementación?
- ¿Cubren los bordes? ¿Tienen nombres descriptivos?
- ¿Atraparían una regresión si el código cambiara?

La última se responde con un experimento, no leyendo. Invertí una condición que el cambio agrega (sacá una negación, cambiá `&&` por `||`), corré la suite, restaurá el archivo. Una mutación que sigue verde es un hallazgo: nombrá el caso de test que falta. Cómo se escriben esos tests es `mindstack:tdd`.

### Paso 3: la implementación

Para cada archivo del diff, leé el archivo completo, no solo el hunk: necesitás los callers y los tipos. Cuatro pasadas separadas, en este orden: lógica, legibilidad, arquitectura, rendimiento. Una pasada que mira todo mira todo por encima.

### Paso 4: clasificar

Cada hallazgo lleva severidad **por consecuencia, no por tamaño del fix**:

| Severidad | Significa | Efecto |
|---|---|---|
| **crítica** | pérdida de datos, plata o acceso | bloquea el PR |
| **alta** | bug en el camino principal | bloquea el PR |
| **media** | bug en un camino secundario | puede quedar como deuda con vencimiento |
| **baja** | puede quedar como deuda | deuda |

Lo que en otros esquemas sería `Critical` es crítica o alta según la consecuencia; `Required` es alta o media según el camino; `Optional`/`Consider` y `Nit` **no se escriben**: si no es un fallo concreto con fix, no es hallazgo. `FYI` tampoco: el contexto va en "A verificar" si hace falta, o no va.

**Primero lo que importa.** Ordená por palanca: corrección primero, después regresiones estructurales y simplificaciones perdidas, después el resto. Pocos hallazgos de alta convicción valen más que una lista larga. Si tenés un problema estructural y diez detalles, el problema estructural *es* la revisión.

### Paso 5: verificar la verificación

Qué tests se corrieron, si pasó el build, si se probó a mano, si hay capturas para cambios de UI, si hay antes/después. Un cambio sin historia de verificación es un hallazgo.

## Formato de salida: `REVIEW-code.md`

Un solo archivo, se reescribe entero en cada ronda (la anterior queda en git y en `CHANGELOG.md › Revisión`). Frontmatter con rol, ronda, fecha y commit revisado. Sin veredicto, sin sección de aciertos, sin elogios, sin nits de estilo, sin "considerá". Solo hallazgos.

```markdown
---
rol: code-reviewer
ronda: 1
fecha: AAAA-MM-DD
commit: <sha revisado>
---

# Revisión de código: <título>

| ID | Severidad | Archivo:línea | Qué falla, con qué entrada | CB | Fix en una línea |
|---|---|---|---|---|---|
| CODE-1 | alta | `pagos.service.ts:42` | timeout con cobro hecho reintenta y cobra dos veces | CB-1 | consultar estado antes de reintentar |
| CODE-2 | media | `informes.ts:118` | lista sin paginar; con >5000 filas el request supera los 30 s | — | paginar con cursor como `clientes.ts` |

## A verificar

- `cache.ts:30`: parece que la clave no incluye el tenant; no encontré una entrada que lo dispare.
```

Reglas de la tabla:

- IDs `CODE-n`, correlativos dentro de la ronda.
- Cada fila tiene un fallo concreto, una entrada que lo dispara y un fix de una línea. Si no podés nombrar la entrada, no va en la tabla.
- Columna **CB**: el `CB-n` del `SPEC.md` que cubre, o `—`.
- **Máximo 15 hallazgos.** Si hay más, los 15 más graves en la tabla y el resto en "A verificar".
- "A verificar": lo que parece fallo y no pudiste confirmar con una entrada concreta. Una línea cada uno. No cuenta como hallazgo ni bloquea.
- **Tabla vacía = nada que objetar.** No la rellenes para justificar la ronda.
- Terminá con el conteo por severidad.

## En el flujo mindstack

Lo usa el agente `code-reviewer` dentro de `/mindstack:orchestrate (fase review)`, en un solo turno y en paralelo con `qa` (CB-n contra tests) y `security-auditor` (zero trust). Cada uno escribe su archivo y no lee el de los otros.

- Lee `SPEC.md`: lo que el SPEC dice que no se hace, o queda fuera de alcance, no es hallazgo.
- Lee `CHANGELOG.md › Decisiones`: lo decidido con principio no se vuelve a discutir. Un principio **mal aplicado** sí es hallazgo, con la evidencia.
- "Yo lo haría distinto" no es hallazgo. "Rompe explícito antes que implícito: el handler lee `process.env`" sí.
- El revisor no edita código ni escribe en el CHANGELOG. El `fixer` cierra cada hallazgo con **fix**, **deuda** (con vencimiento) o **rechazo** (con justificación), y lo deja en `CHANGELOG.md › Revisión`.
- Crítica o alta abierta → `/mindstack:orchestrate (fase fix)`. Dos rondas que no cierran son un desacuerdo, no un bug: decide la persona.

## Código muerto

Después de un refactor o una implementación, buscá lo que quedó huérfano: funciones sin callers, componentes reemplazados, constantes sin referencias. Listalo explícitamente como hallazgo baja con el fix "borrar". No lo borres vos: no editás.

## Honestidad y desacuerdos

- **No firmes sin leer.** Una tabla vacía tiene que ser el resultado de las cuatro pasadas, no de la pereza.
- **No suavices.** "Tal vez sea un problema menor" para un bug que va a pegar en producción es deshonesto.
- **Cuantificá** cuando se pueda: ms, filas, bytes, requests.
- **Pushback directo.** La complacencia es un modo de fallo de la revisión. Si hay un problema, decilo y proponé la alternativa.
- **Comentá el código, no a la persona.**

Cuando hay desacuerdo, en este orden: hechos técnicos y datos > guía de estilo del proyecto > principios de diseño > consistencia con el código existente. "Lo limpio después" no se acepta: el después no llega. Si lo de alrededor no entra en este cambio, queda como deuda con vencimiento e issue, no como promesa.

## Dependencias

Agregar una dependencia es parte del cambio y se revisa. Antes de aceptarla: ¿el stack ya lo resuelve? ¿cuánto pesa? ¿está mantenida? ¿tiene vulnerabilidades conocidas? ¿la licencia es compatible? Preferí stdlib y utilidades existentes: cada dependencia es un pasivo.

Subir una versión también es un cambio de comportamiento que nadie escribió:

1. **Leé el changelog, no el número.** Semver es una promesa que el mantenedor pudo no cumplir. En un major, leé las notas de migración.
2. **Una dependencia por cambio.** Un bump masivo que rompe el build esconde cuál fue.
3. **Que decidan los tests.** Suite verde antes y después; si la cobertura alrededor de la dependencia es fina, ese hueco es el hallazgo.
4. **Mirá el lockfile.** Un bump directo arrastra decenas de indirectos. El lockfile se commitea, se revisa su diff y nunca se edita a mano.

## Racionalizaciones comunes

| Racionalización | Realidad |
|---|---|
| "Funciona, con eso alcanza" | Código que funciona pero es ilegible o está mal ubicado es deuda que se acumula con interés. |
| "Lo escribí yo, sé que está bien" | El autor es ciego a sus propios supuestos. Todo cambio gana con otros ojos. |
| "Lo limpiamos después" | Después no llega. La revisión es la compuerta: la limpieza va antes del merge o queda como deuda con vencimiento. |
| "Lo generó un modelo, seguro está bien" | El código generado necesita más escrutinio, no menos. Es seguro de sí mismo y plausible incluso cuando está mal. |
| "Los tests pasan, así que está bien" | Los tests son necesarios, no suficientes. No atrapan problemas de arquitectura ni de legibilidad. |
| "El refactor lo deja más limpio" | Mover complejidad no es reducirla. Si el lector sostiene la misma cantidad de conceptos, la estructura no mejoró. |
| "Es un agregado chico a este archivo" | Un diff chico igual empuja archivos pasado un tamaño sano y pega ramas a flujos ajenos. Juzgá la estructura resultante, no el tamaño del diff. |
| "Es solo un bump de versión" | Es un cambio de comportamiento que no escribiste. Leé el changelog. |
| "No encontré nada, pongo algo para que no quede vacía" | Tabla vacía es un resultado válido. Un hallazgo inventado le cuesta una ronda al corrector. |
| "Yo lo haría distinto" | No es hallazgo. Hallazgo es "rompe <principio>: <evidencia>" o "falla con <entrada>". |

## Señales de alarma

- Cambios mergeados sin revisión
- Revisión que solo mira si los tests pasan
- Tabla vacía sin evidencia de las cuatro pasadas
- Cambio sensible a seguridad sin pasada de `security-auditor`
- PRs "demasiado grandes para revisar bien" (se parten)
- Bug fix sin test de regresión
- Hallazgos sin severidad, sin archivo:línea o sin entrada que los dispare
- Hallazgos sobre algo que el SPEC declara fuera de alcance
- Rediscutir una decisión del CHANGELOG sin mostrar que el principio está mal aplicado
- Aceptar "lo arreglo después" sin deuda registrada
- Refactor que mueve código sin reducir los conceptos que el lector sostiene
- Cambio que engorda un archivo ya grande en vez de descomponerlo
- Condicionales nuevos esparcidos en caminos ajenos (falta una abstracción)
- Helper a medida que duplica uno canónico, o lógica de feature en un módulo compartido
- PR "bump de dependencias" masivo sin changelog revisado ni aislamiento por paquete
- Lockfile editado a mano, sin commitear o mergeado sin revisar su diff

## Verificación

Al terminar la revisión:

- [ ] Se hicieron las cuatro pasadas, en orden, sobre cada archivo completo del diff
- [ ] Cada `CODE-n` tiene severidad, archivo:línea, entrada que lo dispara y fix en una línea
- [ ] Nada en la tabla está fuera del alcance del SPEC ni rediscute una decisión con principio
- [ ] Lo no confirmado está en "A verificar", no en la tabla
- [ ] Hay como máximo 15 hallazgos
- [ ] Al menos una mutación sobre una condición nueva se probó contra la suite
- [ ] Se revisó la historia de verificación del autor (tests, build, manual)
- [ ] Los bumps de dependencias se revisaron contra su changelog, aislados por paquete, con suite verde y lockfile revisado
- [ ] El archivo termina con el conteo por severidad

**Bloqueantes presuntos** (van a la tabla como media salvo que empeoren activamente la estructura, en cuyo caso alta): refactor que reubica complejidad en vez de reducirla; cambio que pasa un archivo del límite de tamaño sin descomponer; lógica de feature en un módulo compartido; casi-duplicado de un helper canónico; fallback silencioso que esconde un invariante poco claro. Para cada uno, el fix nombra el remedio estructural.
