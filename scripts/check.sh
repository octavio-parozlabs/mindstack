#!/usr/bin/env bash
# Checks mecánicos de las skills de stack (web-security, docker-ci, typescript) sobre un repo. Lo corre el revisor de código y el CI.
# Una línea por check: OK, SKIP o FAIL con archivo:línea. Exit 1 si hay algún FAIL.
# Qué regla pide cada check: la reference de la skill que se nombra en cada uno
set -u
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" || exit 1
fails=0
# Lo trackeado, sin skills/ (sus reglas traen los ejemplos "mal"), sin docs ni markdown
code=(':!skills' ':!docs' ':!*.md' ':!*.lock' ':!package-lock.json')

report() { # report <OK|SKIP|FAIL> <check> [detalle]
  printf '%s %s%s\n' "$1" "$2" "${3:+: $3}"
  [ "$1" = FAIL ] && fails=$((fails + 1))
  return 0
}

# 1. patrones prohibidos: skills/docker-ci/references/ci.md. Cada uno apaga cors.md, content-type.md o cookies.md
pat='origin: *true|origin: *.\*.|origin: */|type: *.\*/\*.|app\.use\(express\.urlencoded|secure: *process\.env\.NODE_ENV'
out=$(git grep -n -E -e "$pat" -- "${code[@]}" 2>/dev/null)
[ -z "$out" ] && report OK "patrones prohibidos" || report FAIL "patrones prohibidos" "$out"

# 2. process.env fuera de config: skills/web-security/references/config.md. Solo Node
if git ls-files --error-unmatch package.json >/dev/null 2>&1; then
  out=$(git grep -n -F -e 'process.env' -- "${code[@]}" ':!*/config.ts' ':!config.ts' ':!*.config.*' ':!*.test.*' ':!*.spec.*' 2>/dev/null)
  [ -z "$out" ] && report OK "process.env solo en config" || report FAIL "process.env fuera de config" "$out"
else
  report SKIP "process.env solo en config" "no es Node"
fi

# 3. Dockerfile: la imagen externa una vez, con digest y alias; el resto hereda. docker-base-stage.md, docker-pin-digest.md
dockerfiles=$(git ls-files -- '*Dockerfile*' ':!skills')
if [ -z "$dockerfiles" ]; then
  report SKIP "docker base con digest" "sin Dockerfile"
else
  for f in $dockerfiles; do
    aliases=" $(grep -iE '^FROM .* AS ' "$f" | awk '{print $NF}' | tr '\n' ' ') "
    bad=$(grep -niE '^FROM ' "$f" | while IFS= read -r l; do
      img=$(awk '{print $2}' <<<"${l#*:}")
      case "$aliases" in *" $img "*) continue ;; esac
      grep -qE '@sha256:[0-9a-f]{64}' <<<"$l" && grep -qiE ' AS ' <<<"$l" || echo "$f:$l"
    done)
    [ -z "$bad" ] && report OK "docker base con digest ($f)" || report FAIL "docker FROM sin digest o sin AS ($f)" "$bad"
  done
fi

# 4. .nvmrc = versión del FROM: docker-runtime-verified.md
if [ -f .nvmrc ] && [ -n "$dockerfiles" ]; then
  want=$(tr -d '[:space:]' < .nvmrc)
  for f in $dockerfiles; do
    from=$(grep -E '^FROM node:' "$f" | head -1)
    [ -z "$from" ] && continue
    ver=$(sed -E 's/^FROM node:([0-9.]+).*/\1/' <<<"$from")
    [ "$ver" = "$want" ] && report OK ".nvmrc = FROM ($f)" || report FAIL ".nvmrc ($want) != FROM ($ver) en $f"
  done
else
  report SKIP ".nvmrc = FROM" "sin .nvmrc o sin Dockerfile"
fi

# 5. actions por SHA de 40: skills/docker-ci/references/ci.md
wf=$(git ls-files -- '.github/workflows/*.yml' '.github/workflows/*.yaml')
if [ -z "$wf" ]; then
  report SKIP "actions por SHA" "sin workflows"
else
  bad=$(grep -nE '^\s*-?\s*uses:' $wf | grep -vE '@[0-9a-f]{40}' | grep -vE 'uses:\s*(\./|docker://)')
  [ -z "$bad" ] && report OK "actions por SHA" || report FAIL "actions por tag" "$bad"
fi

[ "$fails" -eq 0 ] && exit 0
echo "$fails check(s) FAIL"
exit 1
