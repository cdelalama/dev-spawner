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
        +-- --with-ollama: OLLAMA_HOST env var
        +-- --with-sounds: Claude Code sound hooks
        +-- --copy-admin-credentials: shared API key
```

## Key Flows

### Flow 1: New user provisioning
1. Admin runs `sudo ./scripts/spawn-user.sh <username>`
2. Script creates Linux user, adds to docker group
3. Copies/generates dotfiles from templates/
4. Installs NVM + Node as the new user
5. Installs Claude Code as the new user
6. Creates directory structure
7. Generates SSH key
8. Reports summary

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
