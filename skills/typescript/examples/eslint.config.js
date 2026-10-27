// Cada regla dice qué archivo de skills/typescript/references/ la explica. Acá se fuerza; ahí está el por qué.
import eslint from '@eslint/js';
import tseslint from 'typescript-eslint';
import vitest from '@vitest/eslint-plugin';
import prettier from 'eslint-config-prettier'; // apaga las reglas de formato de ESLint; vale igual con Biome como formateador

export default tseslint.config(
  { ignores: ['**/dist/**', '**/coverage/**', '**/node_modules/**'] },

  eslint.configs.recommended,
  ...tseslint.configs.strictTypeChecked, // types.md: no-explicit-any, no-non-null-assertion, ban-ts-comment
  ...tseslint.configs.stylisticTypeChecked,
  {
    languageOptions: {
      parserOptions: { projectService: true, tsconfigRootDir: import.meta.dirname },
    },
    rules: {
      // types.md: sin `as`. La excepción lleva eslint-disable-next-line con el por qué después de `--`
      '@typescript-eslint/consistent-type-assertions': ['error', { assertionStyle: 'never' }],
      '@typescript-eslint/consistent-type-definitions': ['error', 'type'], // types.md, ajustable

      // async.md
      '@typescript-eslint/no-floating-promises': 'error',
      '@typescript-eslint/require-await': 'error',

      // structure.md
      'no-restricted-syntax': [
        'error',
        { selector: 'ExportDefaultDeclaration', message: 'Named exports (structure.md)' },
        {
          selector: "MemberExpression[object.name='process'][property.name='env']",
          message: 'process.env solo en config.ts: se lee una vez, validado y tipado (config.md)',
        },
      ],
      'max-lines': ['error', { max: 300, skipBlankLines: true, skipComments: true }], // número ajustable

      'no-empty': ['error', { allowEmptyCatch: false }], // errors.md
      'no-console': 'error', // logger estructurado en el back (../node-api/references/backend.md), nada en el front
    },
  },

  // tests.md
  {
    files: ['**/*.test.{ts,tsx}'],
    plugins: { vitest },
    rules: {
      ...vitest.configs.recommended.rules,
      'vitest/no-focused-tests': 'error',
      'vitest/no-disabled-tests': 'error',
      'max-lines': 'off',
    },
  },

  // Vite, Vitest y este mismo archivo exportan default por contrato de la herramienta
  { files: ['**/*.config.{js,ts}'], rules: { 'no-restricted-syntax': 'off' } },

  // config.md: el único archivo que puede leer process.env. Conserva la restricción de export default
  {
    files: ['**/config.ts'],
    rules: {
      'no-restricted-syntax': ['error', { selector: 'ExportDefaultDeclaration', message: 'Named exports (structure.md)' }],
    },
  },

  prettier, // último: ESLint no opina de formato; eso es de Biome
);
