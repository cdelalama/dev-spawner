# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - 2026-03-01

### Added
- Project bootstrap from LLM-DocKit template
- `scripts/spawn-user.sh` — idempotent user provisioning with optional modules
  - Base: Linux user, docker group, dotfiles, NVM+Node, pnpm, Claude Code, SSH key
  - Optional: `--with-ollama`, `--with-sounds`, `--copy-admin-credentials`
  - Update mode: `--update-templates` with automatic `.bak` backups
  - Automatic post-provisioning verify (12 bash checks: node, npm, pnpm, claude, git, tmux, docker, dirs, ssh, permissions)
  - Automatic diagnose on failure via Claude Code CLI (read-only, uses admin's subscription)
- `scripts/despawn-user.sh` — safe user removal with confirmation and `--yes` flag
- Templates: bashrc, profile, tmux.conf, gitconfig, Claude Code config (base + sounds)
- 7 design decisions documented in DECISIONS.md (D-001 through D-007)
- Initial documentation (README, PROJECT_CONTEXT, ARCHITECTURE, STRUCTURE)

### Fixed
- `((COUNT++))` arithmetic with `set -e` causing premature exit (bash returns exit 1 when post-increment evaluates to 0)
