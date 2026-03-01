# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - 2026-03-01

### Added
- Project bootstrap from LLM-DocKit template
- `scripts/spawn-user.sh` — idempotent user provisioning with optional modules
  - Base: Linux user, docker group, dotfiles, NVM+Node, pnpm, Claude Code, SSH key
  - Optional: `--with-ollama`, `--with-sounds`, `--copy-admin-credentials`
  - Update mode: `--update-templates` with automatic `.bak` backups
- `scripts/despawn-user.sh` — safe user removal with confirmation and `--yes` flag
- Templates: bashrc, profile, tmux.conf, gitconfig, Claude Code config (base + sounds)
- 6 design decisions documented in DECISIONS.md (D-001 through D-006)
- Initial documentation (README, PROJECT_CONTEXT, ARCHITECTURE, STRUCTURE)
