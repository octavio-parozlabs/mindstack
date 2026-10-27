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
caso "Edit PLAN en 1-pending bloquea"          2 ./plan-immutable.sh <<<"$(E Edit docs/plans/1-pending/x/PLAN.md)"
caso "Write SPEC en 4-done bloquea"        2 ./plan-immutable.sh <<<"$(E Write docs/plans/4-done/x/SPEC.md)"
caso "Edit PLAN en 0-draft pasa"              0 ./plan-immutable.sh <<<"$(E Edit docs/plans/0-draft/x/PLAN.md)"
caso "Edit TODO en 2-in-progress pasa"     0 ./plan-immutable.sh <<<"$(E Edit docs/plans/2-in-progress/x/TODO.md)"
caso "Edit CHANGELOG en 3-in-review pasa"      0 ./plan-immutable.sh <<<"$(E Edit docs/plans/3-in-review/x/CHANGELOG.md)"
caso "Edit src pasa"                             0 ./plan-immutable.sh <<<"$(E Edit src/a.ts)"
caso "Bash git mv de la carpeta pasa"            0 ./plan-immutable.sh <<<"$(B 'git mv docs/plans/1-pending/x docs/plans/2-in-progress/x')"
caso "Bash cat PLAN congelado pasa"              0 ./plan-immutable.sh <<<"$(B 'cat docs/plans/2-in-progress/x/PLAN.md')"
caso "Bash echo > PLAN congelado bloquea"        2 ./plan-immutable.sh <<<"$(B 'echo hola > docs/plans/2-in-progress/x/PLAN.md')"
caso "Bash sed -i SPEC congelado bloquea"        2 ./plan-immutable.sh <<<"$(B 'sed -i s/a/b/ docs/plans/1-pending/x/SPEC.md')"
caso "Bash rm PLAN congelado bloquea"            2 ./plan-immutable.sh <<<"$(B 'rm docs/plans/3-in-review/x/PLAN.md')"
caso "Bash chmod +w PLAN congelado bloquea"      2 ./plan-immutable.sh <<<"$(B 'chmod u+w docs/plans/1-pending/x/PLAN.md')"
caso "Bash echo > PLAN en borrador pasa"         0 ./plan-immutable.sh <<<"$(B 'echo hola > docs/plans/0-draft/x/PLAN.md')"
caso "REVIEW-qa por agente qa pasa"              0 ./plan-immutable.sh <<<"$(E Write docs/plans/3-in-review/x/REVIEW-qa.md ',"agent_type":"qa"')"
caso "REVIEW-qa por code-reviewer bloquea"      2 ./plan-immutable.sh <<<"$(E Write docs/plans/3-in-review/x/REVIEW-qa.md ',"agent_type":"code-reviewer"')"
caso "REVIEW-security por auditor pasa"         0 ./plan-immutable.sh <<<"$(E Write docs/plans/3-in-review/x/REVIEW-security.md ',"agent_type":"security-auditor"')"
caso "REVIEW-code sin agent_type pasa"         0 ./plan-immutable.sh <<<"$(E Write docs/plans/3-in-review/x/REVIEW-code.md)"
caso "Read no se evalúa"                         0 ./plan-immutable.sh <<<"$(E Read docs/plans/1-pending/x/PLAN.md)"

echo "write-scope.sh"
caso "qa escribe test"                           0 ./write-scope.sh '(\.test\.|\.spec\.|/test/|/tests/|test-helpers|REVIEW-qa\.md$|CHANGELOG\.md$|/notes/repro\.md$)' <<<"$(E Write src/a.test.ts)"
caso "qa escribe REVIEW-qa"                      0 ./write-scope.sh '(\.test\.|\.spec\.|/test/|/tests/|test-helpers|REVIEW-qa\.md$|CHANGELOG\.md$|/notes/repro\.md$)' <<<"$(E Write docs/plans/3-in-review/x/REVIEW-qa.md)"
caso "qa escribe notes/repro.md"                 0 ./write-scope.sh '(\.test\.|\.spec\.|/test/|/tests/|test-helpers|REVIEW-qa\.md$|CHANGELOG\.md$|/notes/repro\.md$)' <<<"$(E Write docs/plans/0-draft/x/notes/repro.md)"
caso "qa no escribe producción"                  2 ./write-scope.sh '(\.test\.|\.spec\.|/test/|/tests/|test-helpers|REVIEW-qa\.md$|CHANGELOG\.md$|/notes/repro\.md$)' <<<"$(E Edit src/a.ts)"
caso "revisor escribe REVIEW-code"             0 ./write-scope.sh 'REVIEW-code\.md$' <<<"$(E Write docs/plans/3-in-review/x/REVIEW-code.md)"
caso "revisor no escribe REVIEW-qa"              2 ./write-scope.sh 'REVIEW-code\.md$' <<<"$(E Write docs/plans/3-in-review/x/REVIEW-qa.md)"
caso "dev escribe src"                           0 ./write-scope.sh --no '(PLAN\.md$|SPEC\.md$|REVIEW-[a-z]+\.md$|\.test\.|\.spec\.|/test/|/tests/|test-helpers)' <<<"$(E Edit src/a.ts)"
caso "dev escribe TODO"                          0 ./write-scope.sh --no '(PLAN\.md$|SPEC\.md$|REVIEW-[a-z]+\.md$|\.test\.|\.spec\.|/test/|/tests/|test-helpers)' <<<"$(E Edit docs/plans/2-in-progress/x/TODO.md)"
caso "dev no escribe test"                       2 ./write-scope.sh --no '(PLAN\.md$|SPEC\.md$|REVIEW-[a-z]+\.md$|\.test\.|\.spec\.|/test/|/tests/|test-helpers)' <<<"$(E Write src/a.test.ts)"
caso "dev no escribe REVIEW"                     2 ./write-scope.sh --no '(PLAN\.md$|SPEC\.md$|REVIEW-[a-z]+\.md$|\.test\.|\.spec\.|/test/|/tests/|test-helpers)' <<<"$(E Write docs/plans/3-in-review/x/REVIEW-code.md)"
caso "sin file_path pasa"                        0 ./write-scope.sh 'REVIEW-code\.md$' <<<'{"tool_name":"Edit","tool_input":{}}'

echo "$n casos, $fallos fallos"
[ "$fallos" -eq 0 ]
