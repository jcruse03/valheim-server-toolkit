# Project instructions

This repository manages independent Valheim dedicated-server instances on Linux.

- Runtime scripts must remain Bash-compatible and pass `mise run check`.
- Never commit a real `valheim.env`, server password, save, backup, or downloaded mod binary.
- Package versions and SHA-256 values are pinned in `templates/valheim-mods.lock`.
- Maintenance operations must refuse to mutate a running systemd service.
- Restore behavior must retain checksum validation, path validation, a pre-restore safety backup, and rollback on failure.
- Keep client setup at the top of README.md; it is the player-facing entry point.
