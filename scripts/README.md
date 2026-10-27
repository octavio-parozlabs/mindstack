# scripts

- Raíz: corre en el proyecto que usa el plugin. `check.sh` (checks mecánicos de las skills de stack; lo corre `code-reviewer` y el CI del proyecto), `env-up.sh` / `env-down.sh` (entorno por tarea), `ci-plans-immutable.sh` (step de CI: SPEC y PLAN no cambian fuera de `0-draft/`).
- `validate/`: valida este repo. Lo corre `.github/workflows/validate.yml` y el bloque "Validar" de `CLAUDE.md`.
