# Qué se abre cuándo

El componente sale de lo que la persona está haciendo. La tabla coincide con la guía de shadcn y le agrega el criterio de uso. Cómo se compone cada uno en código lo dice la skill `shadcn` o su documentación.

## Superposiciones

| Situación | Componente | Criterio |
|---|---|---|
| Tarea corta que pide datos (editar, crear, configurar) | Dialog | tamaño fijo, chico, mediano o grande, elegido por el estado más grande; título siempre visible; botones abajo y quietos |
| Confirmar algo destructivo o irreversible | AlertDialog | dice qué se pierde; el botón de la acción nombra la acción ("Borrar pedido"); el foco arranca en cancelar |
| Ver el detalle de un ítem de una lista, o filtros | Sheet | la lista sigue a la vista; cerrar vuelve al mismo lugar de la lista |
| Lo mismo que Dialog o Sheet en celular | Drawer | desde abajo; mismo contenido que su versión de escritorio |
| Elegir una acción entre varias sobre un elemento | DropdownMenu | acciones agrupadas; la destructiva al final y separada |
| Contenido interactivo chico anclado a un elemento | Popover | no lleva formularios largos; si crece, es un Dialog |
| Explicar qué hace un control | Tooltip | solo texto corto; nada que haga falta para completar la tarea, porque en celular no se ve |
| Vista previa al pasar el mouse | HoverCard | lo mismo tiene que estar disponible con un clic |
| Buscar y ejecutar comandos | Command dentro de Dialog | se abre con atajo de teclado visible |

## Avisos y estados

| Situación | Componente | Criterio |
|---|---|---|
| Resultado de una acción (guardado, enviado, falló al fondo) | toast | no corre el contenido; si tiene acción ("Deshacer"), dura lo suficiente para usarla; no es el único lugar donde se informa un error que bloquea |
| Aviso que la persona tiene que leer en la pantalla | Alert | dentro del contenido, con su lugar reservado o arriba de todo desde la carga, nunca insertado arriba de lo que se está leyendo |
| Cargando contenido | Skeleton | la forma y el tamaño del contenido que viene |
| Cargando una acción | Spinner dentro del botón | el botón queda deshabilitado y mide lo mismo |
| Progreso medible (subida, importación) | Progress | con porcentaje o pasos en texto |
| Lista o pantalla sin datos | Empty | por qué está vacío y la acción para salir de ahí |
| Estado de un ítem (activo, pendiente, vencido) | Badge | texto además del color |

## Navegación y elección

| Situación | Componente | Criterio |
|---|---|---|
| Vistas hermanas de lo mismo | Tabs | cambiar de Tab no cambia el tamaño del contenedor; la Tab elegida sobrevive a recargar |
| Elegir entre 2 y 7 opciones visibles | ToggleGroup | todas las opciones a la vista, la elegida se distingue por algo más que el color |
| Elegir entre muchas opciones | Select, o Combobox si hay que buscar | la opción elegida se ve completa sin abrir |
| Muchos registros | Table o Data Table | columnas con ancho estable; paginar o filtrar no las corre |
| Secciones de la app | Sidebar, Breadcrumb | la ubicación actual siempre se ve |
| Mostrar u ocultar contenido secundario | Collapsible, Accordion | lo de abajo se corre porque la persona lo pidió; es la única excepción a "nada se mueve" |

## Formularios

| Situación | Componente | Criterio |
|---|---|---|
| Cualquier campo | Field con su título, descripción y error | título visible siempre; el error va en el lugar del Field y no corre los campos de abajo |
| Campos relacionados (checkboxes, radios) | FieldSet con su leyenda | la leyenda dice qué se elige |
| Código de un solo uso | InputOTP | se puede pegar el código completo |

Si un caso no está acá, se elige el componente de shadcn más cercano y el SPEC dice por qué. Un componente hecho a mano donde existe uno de shadcn no entra.
