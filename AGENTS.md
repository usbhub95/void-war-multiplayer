# Project instructions

## Repository structure
- Keep game source in `src/`, experiments in `tests/`, tooling in `scripts/` and documentation in `docs/`. Keep `AGENTS.md`, `README.md` and any licence file at the root.
- Store local copies of original assets in the Git-ignored `assets/` directory.

## Build workflow
- Use `scripts/New-Build.ps1` to read the installed vanilla `data.win` in place and generate a single `build/data.win`.
- Reserve `build/` exclusively for the generated `data.win` and associated build logs. Do not use it for intermediate source, vanilla copies, experiments or temporary working files.
- Use Git-ignored `temp/` for disposable working files and `tests/` for reusable experiments.
- Run cleanup separately using `scripts/Clear-TemporaryFiles.ps1`.

## Project documentation
- Maintain [DEVELOPMENT.md](docs/DEVELOPMENT.md) as the durable development record, including testing results and the next checkpoint. Read it before resuming work.
- Keep the [README](README.md) build and playtest instructions current and remove superseded instructions.