# BLOCKED: <slug>

<!-- Lo escribe el orquestador al mover la tarea a todolist/blocked/ (orchestrate.md › Bloquear). Es lo único que la persona lee: corto, cada motivo citando algo de la tarea (CA-n, CB-n, ID de hallazgo, tarea n del TODO), con opciones cerradas y una recomendada. Al retomar, las respuestas van a CHANGELOG › Decisiones y este archivo se borra. -->

desde: <2-in-progress | 3-in-review | 4-done> · ronda <n> · PR #<n> (en draft) | sin PR

## Motivos

1. **<qué no cerró, citando el id>.** <por qué, en una o dos líneas, con archivo:línea si ayuda>.
   - a) <opción y su consecuencia> ← recomendado
   - b) <opción y su consecuencia>
2. ...

## Para retomar

`/mindstack:orchestrate` en el worktree: te pregunta cada motivo y sigue desde `desde:`.
