<!-- doc-version: 0.1.0 -->
# dev-spawner Architecture

> Version: 0.1.0
> Last Updated: 2026-03-01
> Status: Design
> Authors: Carlos de la Lama-Noriega

## Overview

dev-spawner is a bash-based provisioning tool that creates development user environments on a shared Ubuntu VM. It runs on dev-vm (10.0.0.110) and creates Linux users with a fully configured development setup.

- **What it is**: A provisioning script + dotfile templates
- **Who uses it**: System admin (Carlos) to create environments for family members
- **Where it runs**: dev-vm (Ubuntu 22.04, 16GB RAM, 2 vCPU)
- **Primary inputs**: Username, optional config flags
- **Primary outputs**: A fully configured Linux user with dev tools

## Non-negotiables

- Must run on Ubuntu 22.04 with bash
- Must not break existing users or services
- Must be idempotent (safe to re-run)
- Zero external dependencies beyond what's already on dev-vm

## High-Level Architecture

```
spawn-user.sh (main entry point)
  |
  +-- create Linux user + groups
  +-- install dotfiles from templates/
  |     +-- .bashrc
  |     +-- .profile
  |     +-- .tmux.conf
  |     +-- .gitconfig
  +-- install NVM + Node.js
  +-- install Claude Code
  +-- setup Claude Code config from templates/
  |     +-- .claude/CLAUDE.md
  |     +-- .claude/settings.json
  +-- create directory structure (~/src, ~/runtime)
  +-- generate SSH key
  +-- [optional modules via flags]
  |     +-- --with-ollama: OLLAMA_HOST env var
  |     +-- --with-sounds: Claude Code sound hooks
  |     +-- --copy-admin-credentials: shared API key
  +-- set permissions
  +-- automatic verify (12 bash checks)
  +-- automatic diagnose (Claude Code CLI, only on failure)
```

## Key Flows

### Flow 1: New user provisioning
1. Admin runs `sudo ./scripts/spawn-user.sh <username> --git-name "Name" --git-email "email"`
2. Script validates root, prerequisites, network, username
3. Creates Linux user, adds to docker group
4. Copies/generates dotfiles from templates/ (create-if-missing)
5. Installs NVM + Node LTS + pnpm as the new user
6. Installs Claude Code as the new user
7. Configures Claude Code (~/.claude/)
8. Creates directory structure (~/src, ~/runtime, ~/.local/bin)
9. Generates SSH ed25519 key
10. Applies optional modules (if flags present)
11. Sets permissions (home 750, .ssh 700, .claude 700)
12. Runs 12 verification checks (node, npm, pnpm, claude, git, tmux, docker, dirs, ssh, permissions)
13. If any check fails: launches Claude Code CLI to diagnose and suggest fixes
14. Prints summary with counts and verify status

### Flow 2: Update existing user (idempotent)
1. Admin re-runs `sudo ./scripts/spawn-user.sh <username> --update-templates`
2. Script detects user exists, skips creation
3. Dotfiles: without `--update-templates`, existing files are SKIPPED (preserving customizations). With the flag, existing files are backed up (`.bak.<timestamp>`) and overwritten
4. Tools (NVM, Node, Claude): always skipped if already installed (no auto-update)
5. Reports what was created, updated, or skipped

## Storage & Data Layout

```
/home/<username>/
  +-- .bashrc, .profile, .tmux.conf     (from templates)
  +-- .claude/                           (Claude Code config)
  +-- .nvm/                              (Node Version Manager)
  +-- .ssh/                              (SSH keys)
  +-- .gitconfig                         (git config)
  +-- src/                               (project repositories)
  +-- runtime/                           (docker compose configs)
  +-- .local/bin/                        (user scripts)
```

## Security & Privacy Notes

- Each user's home is 750 (no cross-user access)
- SSH keys are generated per user
- Claude Code API credentials are per user
- Docker group membership grants root-equivalent access (acceptable for home lab)
- No secrets are stored in the repo (API keys entered interactively or via env)
