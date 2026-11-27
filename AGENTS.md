# Project instructions

- Keep game and experiment source directly in `src/`. Give diagnostics their own `.csx` files.
- Use `New-Build.ps1` to read the installed vanilla `data.win` in place and generate one `build/data.win`. Reserve `build/` for generated output and temporary logs. Run cleanup separately with `Clear-Build.ps1`.
- Read [DEVELOPMENT.md](DEVELOPMENT.md) before resuming work. Preserve decisions, technical findings, test results, open issues, and the next checkpoint. Update the relevant docs after significant decisions, test results, milestone changes, and before handoff. Keep the [README](README.md) build and playtest steps current and remove superseded instructions.
