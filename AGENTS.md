# Project instructions

## Repository structure
- Keep game source in `src/`, experiments in `tests/`, tooling in `scripts/` and documentation in `docs/`. Keep `AGENTS.md`, `README.md` and any licence file at the root.
- Store local copies of original assets in the Git-ignored `assets/` directory.

## Build workflow
- Use `scripts/Setup-Assets.ps1` to prepare the local vanilla `assets/data.win` and pinned CLI cache under `assets/`, `scripts/New-Build.ps1` to generate `build/data.win`, and `scripts/Start-VoidWar.ps1` to launch it.
- Reserve `build/` for build outputs and launcher logs. Use the Git-ignored `temp/` directory for disposable working files. Run build cleanup separately using `scripts/Clear-Build.ps1`.

## Project documentation
- Maintain [DEVELOPMENT.md](docs/DEVELOPMENT.md) as the durable development record, including testing results and the next checkpoint. Read it before resuming work.
- Keep the [README](README.md) build and playtest instructions current and remove superseded instructions.