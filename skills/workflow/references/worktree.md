# Cada tarea en su worktree

Claude trabaja en el worktree, no en tu checkout. Dos tareas a la vez son dos worktrees, dos ramas, dos `git status` que no se pisan.

No hay setting que haga que toda sesión arranque en un worktree: se pasa `-w` cada vez (`alias cw='claude -w'`). Lo que sí hay es el hook `WorktreeCreate`, que decide **cómo** se arma:

```mermaid
sequenceDiagram
    participant U as persona
    participant CC as Claude Code
    participant H as worktree-create.sh
    participant W as .claude/worktrees/slug
    U->>CC: claude -w reintento-pagos
    CC->>H: WorktreeCreate {name, cwd}
    H->>W: git worktree add -b worktree-slug desde HEAD
    H->>W: copia .env, .env.local
    H->>W: symlink node_modules si existe
    H->>W: copia graphify-out/ si existe
    H-->>CC: stdout: path del worktree
    CC->>CC: SessionStart: principios + estado de todolist
    CC-->>U: sesión lista
```

| Qué | Cómo lo arma el hook | Por qué así |
|---|---|---|
| rama | `worktree-<slug>` desde tu `HEAD` | incluye tus commits sin pushear, que es lo que una tarea nueva suele necesitar |
| `.env` | copia | `.worktreeinclude` no se procesa cuando un hook crea el worktree |
| dependencias instaladas | symlink a las del principal, si hay | mismo lockfile. Si la rama cambia dependencias, un install en el worktree reemplaza el enlace |
| `graphify-out/` | copia, no symlink, si hay | dos sesiones con `--update` sobre un symlink se pisan |

Nada de esto es obligatorio: sin `node_modules` ni `graphify-out/` el hook sigue. El flujo es agnóstico al stack; lo que el stack necesita lo dice su skill.

El worktree es el PR: `/draft`, el plan, el orquestador y el PR pasan adentro, para una tarea o para una cola (`orchestrate.md › Cola`). En el checkout principal no se corre ningún comando del flujo; para todo, `claude -w <slug>`.
