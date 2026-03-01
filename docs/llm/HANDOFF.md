<!-- doc-version: 0.1.0 -->
# LLM Work Handoff - dev-spawner

## Current Status
- Last Updated: 2026-03-01 - Claude Opus 4.6
- Session Focus: Brainstorming - design decisions before coding
- Status: v0.1.0. Project just bootstrapped. Need to resolve open questions before implementation.

## Project Summary

**dev-spawner** automates provisioning of development user environments on a shared Ubuntu VM (dev-vm, 10.0.0.110). The goal: run one script, get a fully working dev environment for a new user (family member).

**Repository:** https://github.com/cdelalama/dev-spawner
**Current version:** 0.1.0
**Tech stack:** Bash scripts (provisioning), no external dependencies beyond what's already on dev-vm

## Reference Environment (cdelalama@dev-vm)

What the reference user has installed (this is what we're replicating):

### System-level (shared, already installed)
- Ubuntu 22.04, Docker 29.2.0, Go 1.25.4, Python 3.10
- System packages (git, curl, build-essential, etc.)

### Per-user (needs replication)
- **Shell**: bash with custom .bashrc (PATH extensions, aliases, functions)
- **NVM**: v24.12.0 Node.js, npm 11.6.2, pnpm 10.28.2
- **Global npm**: claude-code, codex, playwright, clawhub
- **Claude Code**: ~/.claude/ (CLAUDE.md, settings.json, sounds/, credentials)
- **tmux**: custom config (prefix C-a, mouse on, status bar)
- **Git**: user config + gh credentials helper
- **SSH**: ed25519 key + keychain integration
- **Directories**: ~/src/, ~/runtime/, ~/.local/bin/
- **Systemd user services**: ollama.service, tmux-workspace.service
- **Cron jobs**: ollama reboot, notion-sync
- **Custom scripts**: ~/bin/np, ~/bin/op, ~/.local/bin/* (74+ executables)
- **Doppler CLI**: secrets management (authenticated)

---

## BRAINSTORMING: Open Design Decisions

### B-001: NVM - shared vs per-user

**Options:**
1. **Per-user NVM** (each user gets their own ~/.nvm): Full isolation, each can use different Node versions. More disk (~200MB per user). Standard approach.
2. **System-wide Node** (install Node globally, skip NVM): Simpler, less disk. But all users share same version, harder to update.
3. **Shared NVM with symlinks**: One NVM install, symlinked per user. Saves disk but fragile.

**Leaning toward:** Per-user NVM. Disk is cheap, isolation is valuable.

**Status:** OPEN

---

### B-002: Claude Code API key

**Options:**
1. **One shared family API key**: Simplest. Single bill. But usage is mixed (can't tell who spent what).
2. **Per-user API key**: Each person creates their own Anthropic account. Clear usage tracking. More setup.
3. **Shared key but different Claude Code configs**: One API key, but each user has their own ~/.claude/ with different CLAUDE.md, history, etc.

**Considerations:** Claude Code stores the API key in ~/.claude/.credentials.json. The CLAUDE.md and settings are always per-user regardless.

**Status:** OPEN - needs Carlos's input

---

### B-003: Scope of environment replication

**Options:**
1. **Minimal**: Node, Docker, Claude Code, git, tmux. Just the basics to start coding.
2. **Mirror**: Replicate everything Carlos has (Ollama, Doppler, custom scripts, systemd services, cron jobs).
3. **Tiered**: Base install (minimal) + optional modules (ollama, doppler, etc.) that can be enabled per user.

**Leaning toward:** Tiered. The kids don't need Doppler or Ollama on day one. But the script should make it easy to add later.

**Status:** OPEN

---

### B-004: Ollama - shared service vs per-user

**Options:**
1. **Shared**: Carlos's Ollama service (127.0.0.1:11434) is already running. Other users just use it. Zero extra resources.
2. **Per-user**: Each user runs their own Ollama. Wasteful (each instance loads models into RAM).
3. **Shared with user alias**: Shared service, but each user gets an alias/env var pointing to it.

**Leaning toward:** Shared (option 1). Ollama is already running, models are heavy. Just set OLLAMA_HOST in each user's .bashrc.

**Status:** OPEN

---

### B-005: Docker naming / port conflicts

**Options:**
1. **Naming convention**: Each user prefixes containers with username (laura-postgres, oscar-webapp). Docker Compose already does this with project directory name.
2. **Port ranges**: Assign port ranges per user (Carlos: 3000-3999, Laura: 4000-4999, Oscar: 5000-5999).
3. **No policy**: Let it be. Conflicts are rare in a family setting, resolve ad-hoc.

**Leaning toward:** Naming convention + no strict port policy. In practice, not everyone is running services simultaneously.

**Status:** OPEN

---

### B-006: SSH keys and access

**Options:**
1. **Generate during provisioning**: Script generates ed25519 key for each user. User manually copies it where needed.
2. **No SSH setup**: Each user sets up their own SSH keys. Less magic, more control.
3. **Full setup**: Generate key + copy to NAS/RPis + configure keychain. Requires passwords during provisioning.

**Leaning toward:** Option 1. Generate the key, let the user distribute it.

**Status:** OPEN

---

### B-007: Docker group membership

**Options:**
1. **Add to docker group**: Full Docker access, no sudo needed. Same as Carlos.
2. **No docker group**: Require sudo for Docker. More secure but annoying.

**Leaning toward:** Docker group. This is a home lab, not a production server.

**Status:** OPEN

---

### B-008: Idempotency and updates

**Options:**
1. **Create-only**: Script creates a user. If you want to update, edit manually.
2. **Idempotent**: Script can be re-run safely. Checks what exists, only adds/updates what's missing.
3. **Create + separate update script**: One script for initial setup, another for applying updates.

**Leaning toward:** Idempotent single script. More work upfront, much more useful long-term.

**Status:** OPEN

---

### B-009: Claude Code CLAUDE.md for new users

**Options:**
1. **Copy Carlos's CLAUDE.md**: Same rules (infra docs, language policy, mandatory updates).
2. **Simplified version**: Strip down to basics (language policy, project conventions). No infra doc requirements.
3. **Template with user-specific placeholders**: Generate from a template, filling in username, preferred language, etc.

**Leaning toward:** Simplified template. The kids don't need to update home-infra docs.

**Status:** OPEN

---

### B-010: De-provisioning

**Options:**
1. **Not needed**: Just delete the user manually if needed (userdel -r).
2. **Teardown script**: Reverses everything the provisioning did. Clean removal.
3. **v0.2.0**: Defer to a later version.

**Leaning toward:** Defer. Focus on creation first.

**Status:** OPEN (deferred)

---

## Implementation Plan (pending brainstorming)

After resolving the above decisions, the implementation order would be:

1. Core provisioning script (spawn-user.sh)
2. Dotfile templates (.bashrc, .profile, tmux.conf)
3. Claude Code setup (CLAUDE.md template, basic settings)
4. NVM + Node installation per user
5. Directory structure creation
6. Git + SSH setup
7. Testing with a real user (Laura or Oscar)

## Top Priorities
1. **NOW**: Resolve brainstorming decisions (B-001 through B-010)
2. **NEXT**: Implement core provisioning script
3. **LATER**: Idempotent updates, de-provisioning, optional modules

## Do Not Touch
- Nothing yet (project just created)
