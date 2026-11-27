# Project instructions

- Keep game source in `src/`, experiments in `tests/`, and tooling in `scripts/`. Put project docs in `docs/`, with `AGENTS.md`, `README.md`, and any licence file at the root.
- Use `scripts/New-Build.ps1` to read the installed vanilla `data.win` in place and generate one `build/data.win`. Store local copies of original assets in the Git-ignored `assets/` directory. Reserve `build/` for generated output and temporary logs. Run cleanup separately with `scripts/Clear-Build.ps1`.
- Read [DEVELOPMENT.md](docs/DEVELOPMENT.md) before resuming work. Preserve decisions, technical findings, test results, open issues, and the next checkpoint. Update the relevant docs after significant decisions, test results, milestone changes, and before handoff. Keep the [README](README.md) build and playtest steps current and remove superseded instructions.
