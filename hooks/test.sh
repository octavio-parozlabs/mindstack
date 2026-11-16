#!/usr/bin/env bash
# Casos de los hooks: JSON por stdin, exit esperado. Corre local y en CI: bash hooks/test.sh
set -u
cd "$(dirname "$0")"
fallos=0; n=0
caso() { # caso "<descripción>" <exit esperado> <script y args...> <<< json
  local desc="$1" esperado="$2"; shift 2
  local json; json=$(cat)
  local out; out=$("$@" <<<"$json" 2>&1); local real=$?
  n=$((n+1))
  if [ "$real" -eq "$esperado" ]; then echo "  ✓ $desc"; else echo "  ✗ $desc (esperado $esperado, real $real) $out"; fallos=$((fallos+1)); fi
}
E() { printf '{"tool_name":"%s","tool_input":{"file_path":"%s"}%s}' "$1" "$2" "${3:-}"; }
B() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1"; }

echo "plan-immutable.sh"
caso "Edit PLAN en 1-pending bloquea"          2 ./plan-immutable.sh <<<"$(E Edit todolist/1-pending/x/PLAN.md)"
caso "Write SPEC en 4-done bloquea"        2 ./plan-immutable.sh <<<"$(E Write todolist/4-done/x/SPEC.md)"
caso "Edit PLAN en 0-draft pasa"              0 ./plan-immutable.sh <<<"$(E Edit todolist/0-draft/x/PLAN.md)"
caso "Edit TODO en 2-in-progress pasa"     0 ./plan-immutable.sh <<<"$(E Edit todolist/2-in-progress/x/TODO.md)"
caso "Edit CHANGELOG en 3-in-review pasa"      0 ./plan-immutable.sh <<<"$(E Edit todolist/3-in-review/x/CHANGELOG.md)"
caso "Edit src pasa"                             0 ./plan-immutable.sh <<<"$(E Edit src/a.ts)"
caso "Bash git mv de la carpeta pasa"            0 ./plan-immutable.sh <<<"$(B 'git mv todolist/1-pending/x todolist/2-in-progress/x')"
caso "Bash cat PLAN congelado pasa"              0 ./plan-immutable.sh <<<"$(B 'cat todolist/2-in-progress/x/PLAN.md')"
caso "Bash echo > PLAN congelado bloquea"        2 ./plan-immutable.sh <<<"$(B 'echo hola > todolist/2-in-progress/x/PLAN.md')"
caso "Bash sed -i SPEC congelado bloquea"        2 ./plan-immutable.sh <<<"$(B 'sed -i s/a/b/ todolist/1-pending/x/SPEC.md')"
caso "Bash rm PLAN congelado bloquea"            2 ./plan-immutable.sh <<<"$(B 'rm todolist/3-in-review/x/PLAN.md')"
caso "Bash chmod +w PLAN congelado bloquea"      2 ./plan-immutable.sh <<<"$(B 'chmod u+w todolist/1-pending/x/PLAN.md')"
caso "Bash echo > PLAN en borrador pasa"         0 ./plan-immutable.sh <<<"$(B 'echo hola > todolist/0-draft/x/PLAN.md')"
caso "REVIEW-qa por agente qa pasa"              0 ./plan-immutable.sh <<<"$(E Write todolist/3-in-review/x/REVIEW-qa.md ',"agent_type":"qa"')"
caso "REVIEW-qa por code-reviewer bloquea"      2 ./plan-immutable.sh <<<"$(E Write todolist/3-in-review/x/REVIEW-qa.md ',"agent_type":"code-reviewer"')"
caso "REVIEW-security por auditor pasa"         0 ./plan-immutable.sh <<<"$(E Write todolist/3-in-review/x/REVIEW-security.md ',"agent_type":"security-auditor"')"
caso "REVIEW-code sin agent_type pasa"         0 ./plan-immutable.sh <<<"$(E Write todolist/3-in-review/x/REVIEW-code.md)"
caso "Edit SPEC en blocked bloquea"            2 ./plan-immutable.sh <<<"$(E Edit todolist/blocked/x/SPEC.md)"
caso "Bash echo > PLAN en blocked bloquea"       2 ./plan-immutable.sh <<<"$(B 'echo hola > todolist/blocked/x/PLAN.md')"
caso "CHECKLIST por verifier pasa"               0 ./plan-immutable.sh <<<"$(E Edit todolist/3-in-review/x/CHECKLIST.md ',"agent_type":"verifier"')"
caso "CHECKLIST por developer bloquea"           2 ./plan-immutable.sh <<<"$(E Edit todolist/2-in-progress/x/CHECKLIST.md ',"agent_type":"developer"')"
caso "CHECKLIST sin agent_type (/plan) pasa"     0 ./plan-immutable.sh <<<"$(E Write todolist/0-draft/x/CHECKLIST.md)"
caso "backlog por developer bloquea"            2 ./plan-immutable.sh <<<"$(E Edit todolist/backlog/PROPUESTAS.md ',"agent_type":"developer"')"
caso "backlog sin agent_type (orquestador) pasa" 0 ./plan-immutable.sh <<<"$(E Edit todolist/backlog/PROPUESTAS.md)"
caso "Edit wireframe en pending bloquea"         2 ./plan-immutable.sh <<<"$(E Edit todolist/1-pending/x/wireframes/pedido.wireloom)"
caso "Edit wireframe en draft pasa"              0 ./plan-immutable.sh <<<"$(E Edit todolist/0-draft/x/wireframes/pedido.wireloom)"
caso "designer escribe wireloom"                 0 ./write-scope.sh '(/notes/ux\.md|/wireframes/[^/]+\.wireloom)$' <<<"$(E Write todolist/0-draft/x/wireframes/a.wireloom)"
caso "designer no escribe SPEC"                  2 ./write-scope.sh '(/notes/ux\.md|/wireframes/[^/]+\.wireloom)$' <<<"$(E Write todolist/0-draft/x/SPEC.md)"
caso "Read no se evalúa"                         0 ./plan-immutable.sh <<<"$(E Read todolist/1-pending/x/PLAN.md)"

echo "write-scope.sh"
caso "qa escribe test"                           0 ./write-scope.sh '(\.test\.|\.spec\.|/test/|/tests/|test-helpers|REVIEW-qa\.md$|CHANGELOG\.md$|/notes/repro\.md$)' <<<"$(E Write src/a.test.ts)"
caso "qa escribe REVIEW-qa"                      0 ./write-scope.sh '(\.test\.|\.spec\.|/test/|/tests/|test-helpers|REVIEW-qa\.md$|CHANGELOG\.md$|/notes/repro\.md$)' <<<"$(E Write todolist/3-in-review/x/REVIEW-qa.md)"
caso "qa escribe notes/repro.md"                 0 ./write-scope.sh '(\.test\.|\.spec\.|/test/|/tests/|test-helpers|REVIEW-qa\.md$|CHANGELOG\.md$|/notes/repro\.md$)' <<<"$(E Write todolist/0-draft/x/notes/repro.md)"
caso "qa no escribe producción"                  2 ./write-scope.sh '(\.test\.|\.spec\.|/test/|/tests/|test-helpers|REVIEW-qa\.md$|CHANGELOG\.md$|/notes/repro\.md$)' <<<"$(E Edit src/a.ts)"
caso "revisor escribe REVIEW-code"             0 ./write-scope.sh 'REVIEW-code\.md$' <<<"$(E Write todolist/3-in-review/x/REVIEW-code.md)"
caso "revisor no escribe REVIEW-qa"              2 ./write-scope.sh 'REVIEW-code\.md$' <<<"$(E Write todolist/3-in-review/x/REVIEW-qa.md)"
caso "dev escribe src"                           0 ./write-scope.sh --no '(PLAN\.md$|SPEC\.md$|REVIEW-[a-z]+\.md$|\.test\.|\.spec\.|/test/|/tests/|test-helpers)' <<<"$(E Edit src/a.ts)"
caso "dev escribe TODO"                          0 ./write-scope.sh --no '(PLAN\.md$|SPEC\.md$|REVIEW-[a-z]+\.md$|\.test\.|\.spec\.|/test/|/tests/|test-helpers)' <<<"$(E Edit todolist/2-in-progress/x/TODO.md)"
caso "dev no escribe test"                       2 ./write-scope.sh --no '(PLAN\.md$|SPEC\.md$|REVIEW-[a-z]+\.md$|\.test\.|\.spec\.|/test/|/tests/|test-helpers)' <<<"$(E Write src/a.test.ts)"
caso "dev no escribe REVIEW"                     2 ./write-scope.sh --no '(PLAN\.md$|SPEC\.md$|REVIEW-[a-z]+\.md$|\.test\.|\.spec\.|/test/|/tests/|test-helpers)' <<<"$(E Write todolist/3-in-review/x/REVIEW-code.md)"
caso "designer escribe notes/ux.md"              0 ./write-scope.sh '/notes/ux\.md$' <<<"$(E Write todolist/0-draft/x/notes/ux.md)"
caso "designer no escribe SPEC"                  2 ./write-scope.sh '/notes/ux\.md$' <<<"$(E Write todolist/0-draft/x/SPEC.md)"
caso "designer no escribe código"                2 ./write-scope.sh '/notes/ux\.md$' <<<"$(E Edit src/a.tsx)"
caso "verifier escribe CHECKLIST"               0 ./write-scope.sh '/CHECKLIST\.md$' <<<"$(E Edit todolist/3-in-review/x/CHECKLIST.md)"
caso "verifier no escribe código"                2 ./write-scope.sh '/CHECKLIST\.md$' <<<"$(E Edit src/a.ts)"
caso "dev no escribe CHECKLIST"                  2 ./write-scope.sh --no '(PLAN\.md$|CHECKLIST\.md$|SPEC\.md$|REVIEW-[a-z]+\.md$|\.test\.|\.spec\.|/test/|/tests/|test-helpers)' <<<"$(E Edit todolist/2-in-progress/x/CHECKLIST.md)"
caso "sin file_path pasa"                        0 ./write-scope.sh 'REVIEW-code\.md$' <<<'{"tool_name":"Edit","tool_input":{}}'

echo "orchestrate-stop.sh"
hooks=$(pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/repo" "$tmp/gh" "$tmp/nogh"
git -C "$tmp/repo" init -q
# gh falso: 'pr view' sale con GH_VIEW, 'pr checks' con GH_RC (0 verde, 8 pendiente, 1 rojo)
printf '#!/usr/bin/env bash\n[ "$2" = view ] && exit "${GH_VIEW:-0}"\nexit "${GH_RC:-0}"\n' >"$tmp/gh/gh"
chmod +x "$tmp/gh/gh"
# PATH sin gh: solo lo que usa el hook
for t in bash cat git grep sed rm find xargs basename jq; do p=$(command -v "$t") && ln -sf "$p" "$tmp/nogh/$t"; done
stop() { (cd "$tmp/repo" && "$hooks/orchestrate-stop.sh"); }
M="$tmp/repo/.git/mindstack-orchestrating"
marca() { rm -rf "$M" "$tmp/repo/.git/mindstack-cola"; mkdir -p "$M"; echo "${2:-/mindstack:orchestrate}" >"$M/${1:-s1}"; }
mover() { rm -rf "$tmp/repo/todolist"; mkdir -p "$tmp/repo/todolist/$1/x" "$tmp/repo/todolist/4-done/vieja"; }
S='{"session_id":"s1"}'
export PATH="$tmp/gh:$PATH"
mover 3-in-review
caso "sin marcador deja parar"                   0 stop <<<"$S"
marca s2; caso "marcador de otra sesión deja parar" 0 stop <<<"$S"
marca; caso "3-in-review no deja parar"          2 stop <<<"$S"
marca; mover blocked; caso "blocked sin BLOCKED.md no deja parar" 2 env GH_RC=1 bash -c 'cd "$1/repo" && "$2/orchestrate-stop.sh"' _ "$tmp" "$hooks" <<<"$S"
marca; touch "$tmp/repo/todolist/blocked/x/BLOCKED.md"; caso "blocked con BLOCKED.md deja parar" 0 stop <<<"$S"
caso "blocked borra el marcador"                 1 test -f "$M/s1" <<<""
marca; mover 4-done; caso "4-done con CI verde deja parar" 0 stop <<<"$S"
marca; mkdir -p "$tmp/repo/todolist/2-in-progress/x-2"; caso "hija en curso con padre en 4-done no deja parar" 2 stop <<<"$S"
marca; mover 4-done; export GH_RC=8; caso "4-done con CI pendiente no deja parar" 2 stop <<<"$S"
marca; export GH_RC=1; caso "4-done con CI rojo no deja parar" 2 stop <<<"$S"
marca; export GH_RC=0 GH_VIEW=1; caso "4-done sin PR no deja parar" 2 stop <<<"$S"
marca; caso "4-done sin gh deja parar"           0 env PATH="$tmp/nogh" bash -c 'cd "$1/repo" && "$2/orchestrate-stop.sh"' _ "$tmp" "$hooks" <<<"$S"
export GH_VIEW=0 GH_RC=1
mover 2-in-progress; marca s1 "/mindstack:orchestrate hija x"; caso "hija en curso no deja parar" 2 stop <<<"$S"
mover 4-done; marca s1 "/mindstack:orchestrate hija x"; caso "hija en 4-done deja parar sin mirar CI" 0 stop <<<"$S"
mover 2-in-progress; marca; echo "/mindstack:orchestrate hija x" >"$M/s2"; caso "padre con hija viva deja parar" 0 stop <<<"$S"
export GH_RC=0
mover 4-done; mkdir -p "$tmp/repo/todolist/1-pending/otra"; marca; echo x >"$tmp/repo/.git/mindstack-cola"; caso "pendiente fuera de la cola deja parar" 0 stop <<<"$S"
mover 1-pending; marca; echo x >"$tmp/repo/.git/mindstack-cola"; caso "pendiente de la cola no deja parar" 2 stop <<<"$S"
mover 1-pending; marca; caso "pendiente sin cola no deja parar"   2 stop <<<"$S"

echo "orchestrate-start.sh"
start() { (cd "$tmp/repo" && "$hooks/orchestrate-start.sh"); }
rm -rf "$M"
git -C "$tmp/repo" checkout -q -b main 2>/dev/null || git -C "$tmp/repo" switch -q -c main
caso "en main no marca"                          1 bash -c 'cd "$1/repo" && "$2/orchestrate-start.sh" && test -f .git/mindstack-orchestrating/s1' _ "$tmp" "$hooks" <<<'{"session_id":"s1","prompt":"/mindstack:orchestrate"}'
git -C "$tmp/repo" switch -q -c worktree-x
caso "otro prompt no marca"                      1 bash -c 'cd "$1/repo" && "$2/orchestrate-start.sh" && test -f .git/mindstack-orchestrating/s1' _ "$tmp" "$hooks" <<<'{"session_id":"s1","prompt":"hola"}'
caso "/mindstack:orchestrate en worktree marca"  0 bash -c 'cd "$1/repo" && "$2/orchestrate-start.sh" && grep -qx /mindstack:orchestrate .git/mindstack-orchestrating/s1' _ "$tmp" "$hooks" <<<'{"session_id":"s1","prompt":"/mindstack:orchestrate"}'
caso "hija en worktree marca con su prompt"      0 bash -c 'cd "$1/repo" && "$2/orchestrate-start.sh" && grep -q "hija a" .git/mindstack-orchestrating/s2' _ "$tmp" "$hooks" <<<'{"session_id":"s2","prompt":"/mindstack:orchestrate hija a"}'

echo "$n casos, $fallos fallos"
[ "$fallos" -eq 0 ]
