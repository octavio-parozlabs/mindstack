# scripts

- Raíz: corre en el proyecto que usa el plugin. `check.sh` (checks mecánicos de las skills de stack; lo corre `code-reviewer` y el CI del proyecto), `env-up.sh` / `env-down.sh` (entorno por tarea), `ci-plans-immutable.sh` (step de CI: SPEC y PLAN no cambian fuera de `0-draft/`), `config.sh` (lee `config/defaults.conf` y el `.claude/mindstack.conf` del proyecto), `sync-agents.sh` (copia `turnos_*` al `maxTurns` de los agentes), `doctor.sh` (`/mindstack:doctor`: lo que el flujo da por hecho en la máquina y el repo).
- `validate/`: valida este repo. Lo corre `.github/workflows/validate.yml` y el bloque "Validar" de `CLAUDE.md`.
