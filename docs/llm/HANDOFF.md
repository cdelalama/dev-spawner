<!-- doc-version: 0.1.0 -->
# LLM Work Handoff - dev-spawner

## Current Status
- Last Updated: 2026-03-01 - Claude Opus 4.6
- Session Focus: Added automatic verify + diagnose, fixed ((COUNT++)) bug, testing
- Status: v0.1.0 implemented and tested with testuser. Verify + diagnose integrated.

## Project Summary

**dev-spawner** automates provisioning of development user environments on a shared Ubuntu VM (dev-vm, 10.0.0.110). Run one script, get a fully working dev environment.

**Repository:** https://github.com/cdelalama/dev-spawner
**Current version:** 0.1.0
**Tech stack:** Bash scripts + Claude Code CLI (for diagnosis), no other external dependencies

## What's Implemented

### scripts/spawn-user.sh
Idempotent provisioning script. Creates user, installs tools, configures environment, verifies, and diagnoses failures.

**Flags:**
- `--git-name "Name"` — Git user.name (required on first run)
- `--git-email "email"` — Git user.email (required on first run)
- `--with-ollama` — Add OLLAMA_HOST env var (default: 127.0.0.1:11434)
- `--ollama-host "host:port"` — Override OLLAMA_HOST (implies --with-ollama)
- `--with-sounds` — Install Claude Code sound hooks
- `--copy-admin-credentials` — Copy Claude API key from admin ($SUDO_USER)
- `--update-templates` — Overwrite existing dotfiles (creates .bak.<timestamp> backups)

**Flow:**
1. Validate (root, prerequisites, network, username)
2. Create user + docker group
3. Install dotfiles (create-if-missing or --update-templates with backup)
4. Install NVM + Node LTS + pnpm + Claude Code
5. Configure Claude Code (~/.claude/)
6. Create directories (~/src, ~/runtime, ~/.local/bin)
7. Generate SSH key
8. Apply optional modules (ollama, sounds, credentials)
9. Set permissions
10. **Automatic verify** — 12 bash checks (node, npm, pnpm, claude, git config, tmux, docker group, dirs x3, SSH key, claude config, permissions)
11. **Automatic diagnose** — if verify fails, launches Claude Code CLI (`claude -p`) as admin user to analyze failures and suggest fixes. Read-only (Bash, Read, Glob, Grep tools only)

**Output per step:** `[CREATED]`, `[SKIPPED]`, `[UPDATED]`, `[WARNING]`
**Verify output:** `[PASS]` or `[FAIL]` per check
**Summary:** counts + verify status (ALL PASSED or N FAILED)

### scripts/despawn-user.sh
Safe user removal with confirmation.
- Validates: root, username regex, reserved names (root, cdelalama, nobody, daemon, sys, bin)
- Handles: process cleanup (pkill + pkill -9 fallback + pgrep verify), docker group removal, userdel -r
- Flags: `--yes` for automation (skips confirmation prompt)
- Graceful: exits 0 if user doesn't exist (not an error)

### Templates
- `bashrc.template` — Ubuntu standard + keychain (guarded with `command -v`), NVM, Go, pnpm (using $HOME), ~/.local/bin, Claude alias
- `profile.template` — Standard + NVM for login shells
- `tmux.conf.template` — Prefix C-a, mouse on, custom status bar
- `gitconfig.template` — `{{GIT_NAME}}`/`{{GIT_EMAIL}}` placeholders + gh credential helpers
- `claude/CLAUDE.md.template` — Simplified: language policy + basic workflow rules
- `claude/settings.json.template` — Base (no hooks)
- `claude/settings.sounds.json.template` — With sound hooks (SessionStart, Stop, Notification, PostToolUseFailure)
- `claude/sounds/play-remote.sh` — Fire-and-forget sound notification (curl to Windows host)
- `claude/sounds/play-error-remote.sh` — Smart error sound with filtering + cooldown

## Closed Design Decisions

See `docs/llm/DECISIONS.md` for full rationale (D-001 through D-007).

Summary:
- D-001: Multi-user on same VM (not separate VMs)
- D-002: NVM per-user
- D-003: Tiered provisioning (base + optional modules)
- D-004: Shared Ollama service
- D-005: API key shared opt-in only (--copy-admin-credentials)
- D-006: Create-if-missing with --update-templates for updates
- D-007: Automatic verify (bash) + diagnose (Claude Code CLI) post-provisioning

## Known Bugs Fixed
- `((COUNT++))` with `set -e`: bash arithmetic returns exit 1 when result is 0 (post-increment from 0). Fixed by using `COUNT=$((COUNT + 1))` instead.

## Top Priorities
1. **NOW**: Test with testuser including verify output
2. **NEXT**: Test --update-templates backup behavior
3. **THEN**: Provision Laura and/or Oscar
4. **LATER**: Additional optional modules

## Do Not Touch
- Templates should not be modified without re-testing spawn-user.sh
