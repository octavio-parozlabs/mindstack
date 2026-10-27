#!/usr/bin/env bash
# Hook WorktreeCreate. Reemplaza la creación por defecto: arma el worktree con lo que una sesión necesita
# e imprime el path como última línea de stdout. Exit != 0 cancela.
# Recibe por stdin: { "name": "<slug>", "cwd": "<checkout principal>", ... }
set -euo pipefail

input=$(cat)
if command -v jq >/dev/null 2>&1; then
  name=$(jq -r .name <<<"$input")
  root=$(jq -r .cwd <<<"$input")
else
  name=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' <<<"$input" | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//')
  root=$(grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' <<<"$input" | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//')
fi
dir="$root/.claude/worktrees/$name"

# Desde tu HEAD, no desde origin/main: incluye tus commits sin pushear.
if git -C "$root" show-ref --verify --quiet "refs/heads/worktree-$name"; then
  git -C "$root" worktree add "$dir" "worktree-$name" >&2
else
  git -C "$root" worktree add -b "worktree-$name" "$dir" HEAD >&2
fi

# .worktreeinclude no se procesa cuando el hook crea el worktree: se copia a mano.
for f in .env .env.local; do
  [ -f "$root/$f" ] && cp "$root/$f" "$dir/$f"
done

# Mismo lockfile, mismas dependencias. Si una rama las cambia, un install en el worktree rompe el enlace.
[ -d "$root/node_modules" ] && ln -s "$root/node_modules" "$dir/node_modules"

# El codemap viaja con la sesión. Copia, no enlace: dos sesiones con --update no se pisan.
[ -d "$root/graphify-out" ] && cp -r "$root/graphify-out" "$dir/graphify-out"

echo "$dir"
