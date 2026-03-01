<!-- doc-version: 0.1.0 -->
# LLM Work Handoff - dev-spawner

## Current Status
- Last Updated: 2026-03-01 - Claude Opus 4.6
- Session Focus: v0.1.0 implementation complete — scripts + templates + docs
- Status: v0.1.0 implemented. Ready for testing with a real user (testuser first).

## Project Summary

**dev-spawner** automates provisioning of development user environments on a shared Ubuntu VM (dev-vm, 10.0.0.110). Run one script, get a fully working dev environment.

**Repository:** https://github.com/cdelalama/dev-spawner
**Current version:** 0.1.0
**Tech stack:** Bash scripts, no external dependencies beyond what's already on dev-vm

## What's Implemented

### scripts/spawn-user.sh
Idempotent provisioning script. Creates user, installs tools, configures environment.
- Validates: root, prerequisites, network, username regex + reserved names
- Creates: Linux user, docker group, dotfiles (create-if-missing), NVM+Node, pnpm, Claude Code, SSH key, directories
- Optional flags: `--with-ollama`, `--with-sounds`, `--copy-admin-credentials`, `--ollama-host`
- Update mode: `--update-templates` with `.bak.<timestamp>` backups
- Summary with [CREATED]/[SKIPPED]/[UPDATED]/[WARNING] counts

### scripts/despawn-user.sh
Safe user removal with confirmation.
- Validates: root, username, reserved names
- Handles: process cleanup (pkill + pkill -9 fallback), docker group, userdel -r
- Flags: `--yes` for automation

### Templates
- `bashrc.template` — Ubuntu standard + NVM + Go + pnpm + Claude alias (keychain guarded)
- `profile.template` — Standard + NVM for login shells
- `tmux.conf.template` — Prefix C-a, mouse on, custom status bar
- `gitconfig.template` — `{{GIT_NAME}}`/`{{GIT_EMAIL}}` placeholders + gh credential helpers
- `claude/CLAUDE.md.template` — Simplified: language policy + basic workflow rules
- `claude/settings.json.template` — Base (no hooks)
- `claude/settings.sounds.json.template` — With sound hooks
- `claude/sounds/play-remote.sh`, `play-error-remote.sh` — Fire-and-forget sound notifications

## Closed Design Decisions

See `docs/llm/DECISIONS.md` for full rationale (D-001 through D-006).

Summary:
- D-001: Multi-user on same VM (not separate VMs)
- D-002: NVM per-user
- D-003: Tiered provisioning (base + optional modules)
- D-004: Shared Ollama service
- D-005: API key shared opt-in only (--copy-admin-credentials)
- D-006: Create-if-missing with --update-templates for updates

## Top Priorities
1. **NOW**: Test with testuser (no --copy-admin-credentials)
2. **NEXT**: Test --update-templates backup behavior
3. **THEN**: Provision Laura and/or Oscar
4. **LATER**: Additional modules, docs updates

## Do Not Touch
- Templates should not be modified without re-testing spawn-user.sh
