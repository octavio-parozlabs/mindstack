# CI en TypeScript

Con qué se implementa `../../docker-ci/references/ci.md` en este stack. Las decisiones están ahí; acá solo las herramientas.

| Decisión del core | Acá |
|---|---|
| cobertura del diff | `@vitest/coverage-v8` genera el reporte Cobertura; `diff-cover` lo cruza con el `git diff` contra la base del PR. Es Python, `ubuntu-latest` ya lo trae; no entra al `package.json` |
| cobertura total, solo sube | `thresholds.autoUpdate` de Vitest reescribe los umbrales en `vitest.config.ts` cuando suben. Ese cambio se commitea con el PR que lo produjo |
| tamaño de archivo | ESLint `max-lines`, ya en `eslint.config.js` |
| secretos | `gitleaks`, en `../../workflow/references/git.md` |
| imagen | `docker build -f apps/api/Dockerfile -t api:ci .` (`../../node-api/examples/Dockerfile`: base en un stage, tag exacto + digest) |
| actions por SHA | `uses: owner/action@<sha>  # vX.Y.Z`. Dependabot `github-actions` lo mueve (`../../workflow/examples/github/dependabot.yml`) |
| runtime verificado | `.nvmrc` con la versión exacta, la misma del `FROM`. `setup-node` con `node-version-file`. `node --version` comparado con `.nvmrc` en el runner y dentro de la imagen. Trivy sobre `api:ci`, `HIGH,CRITICAL` con fix disponible falla |

```ts
// vitest.config.ts en la raíz (coverage es global al workspace, no por app)
export default defineConfig({
  test: {
    projects: ['apps/*', 'packages/*'],         // cada uno con su vitest.config.ts; reemplaza a vitest.workspace.ts (Vitest 4)
    coverage: {
      provider: 'v8',
      reporter: ['text', 'cobertura'],          // cobertura.xml es lo que lee diff-cover
      include: ['apps/*/src/**', 'packages/*/src/**'],
      exclude: ['**/*.test.{ts,tsx}', '**/test/**'],
      thresholds: {
        lines: 60, branches: 60, functions: 60, statements: 60,   // poner la cobertura actual
        autoUpdate: true,                                           // vitest sube los números solo; nunca bajan
      },
    },
  },
});
```

```json
{
  "scripts": {
    "typecheck": "tsc --noEmit",
    "lint": "eslint . && biome format .",
    "format": "biome format --write .",
    "test": "vitest run",
    "coverage:diff": "vitest run --coverage && diff-cover coverage/cobertura-coverage.xml --compare-branch=origin/main --fail-under=100"
  }
}
```

```bash
npm i -D typescript eslint @eslint/js typescript-eslint @vitest/eslint-plugin eslint-config-prettier @biomejs/biome vitest @vitest/coverage-v8
```

`lint` incluye `biome format .` sin `--write`: falla si algo no está formateado. `eslint-config-prettier` se queda aunque no haya Prettier: su único trabajo es apagar las reglas de formato de ESLint, que es lo que hace falta con cualquier formateador.

`coverage:diff` es el comando que el core pide: lo corre el Done del plan (`../../workflow/SKILL.md`) y el job de CI. El `--fail-under` es el umbral del proyecto; el core argumenta 100.

```yaml
# .github/workflows/ci.yml
# Actions por SHA con el tag en comentario: Dependabot github-actions mantiene los dos (skill docker-ci, references/ci.md).
name: ci
on: [pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1   # v7.0.1
        with: { fetch-depth: 0 }                  # diff-cover necesita la rama base
      - uses: actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1 # v7.1.0
        with: { node-version-file: .nvmrc, cache: npm }
      - run: test "$(node --version)" = "v$(cat .nvmrc)"     # el runner corre la del archivo, no una del tool cache
      - run: npm ci
      - run: npm run typecheck
      - run: npm run lint                         # max-lines falla acá
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1   # v7.0.1: el plugin, para tener check.sh en el runner
        with: { repository: octavio-parozlabs/agent-skills, path: mindstack }
      - run: bash mindstack/scripts/check.sh   # lo mismo que corre el revisor de código: patrones prohibidos, process.env, digest, .nvmrc, SHA
      - run: npx vitest run --coverage            # thresholds globales fallan acá
      - run: pip install diff-cover
      - run: diff-cover coverage/cobertura-coverage.xml
             --compare-branch=origin/${{ github.base_ref }} --fail-under=100
      - run: docker build -f apps/api/Dockerfile -t api:ci .
      - run: test "$(docker run --rm api:ci node --version)" = "v$(cat .nvmrc)"   # la imagen corre la misma
      - uses: aquasecurity/trivy-action@ed142fd0673e97e23eac54620cfb913e5ce36c25   # v0.36.0
        with: { image-ref: "api:ci", severity: "HIGH,CRITICAL", exit-code: "1", ignore-unfixed: "true" }
```

Los tres steps nuevos son `../../docker-ci/references/docker-runtime-verified.md`: sin el primero, `setup-node` puede usar una versión vieja del tool cache del runner; sin el segundo, la imagen puede no ser la del `Dockerfile`; sin Trivy, Dependabot abre el PR de la imagen nueva pero nadie dice qué CVE corrige.

```js
// eslint.config.js
rules: {
  'max-lines': ['error', { max: 300, skipBlankLines: true, skipComments: true }],
}
```

## Dónde lo ve Claude

- `max-lines` y los thresholds corren en el `Stop hook` (`npm run lint` y `vitest run`). Claude no termina el turno con un archivo de 400 líneas ni con la cobertura global bajando. Para que vea los thresholds hace falta `--coverage` en `../examples/hooks/stop-check.sh`, que suma unos segundos; si no, los ve en CI.
- La cobertura del diff corre en CI y en `npm run coverage:diff`. El reporte `text` de Vitest lista archivo por archivo qué líneas faltan.
