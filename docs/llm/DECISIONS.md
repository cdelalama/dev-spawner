# Decision Log (Stable Rationale)

This file captures durable "why" decisions. Keep it stable and link to it from `docs/llm/HANDOFF.md`.

Format:
- Use IDs: `D-001`, `D-002`, ...
- Keep each decision self-contained.
- Prefer facts and tradeoffs over narration.

---

## D-001 - Multi-user on same VM over separate VMs

**Status:** accepted (2026-03-01)

### Decision
Provision multiple development users on a single shared VM rather than creating separate VMs.

### Context
Need to provide development environments for family members (Laura, Oscar). Options: separate VMs vs shared VM with multiple users.

### Rationale
- Shared VM avoids 3x overhead of base OS + services (Docker daemon, Ollama, system packages)
- 16GB RAM / 2 vCPU is enough for non-simultaneous use
- Single point of maintenance (one OS to update)
- Easy to scale up (add RAM/CPU) if needed later
- Home lab context: full isolation not required

### Implications
- Docker daemon is shared (all users see containers, resolved by naming convention)
- Port conflicts possible (resolved ad-hoc)
- Heavy process from one user affects others

---

## D-002 - NVM per-user, not system-wide

**Status:** accepted (2026-03-01)

### Decision
Each user gets their own `~/.nvm/` installation rather than a system-wide Node.js.

### Rationale
- Full isolation: each user can use different Node versions
- Standard approach, well-documented
- ~200MB per user is acceptable
- No coordination needed for version changes

---

## D-003 - Tiered provisioning with optional modules

**Status:** accepted (2026-03-01)

### Decision
Base install (Node, Docker, Claude Code, git, tmux, SSH) plus optional modules via flags (--with-ollama, --with-sounds, --copy-admin-credentials).

### Rationale
- Kids don't need Doppler, Ollama, or sound hooks on day one
- Flags make it explicit what gets installed
- Easy to add more modules later without touching core logic

---

## D-004 - Shared Ollama service

**Status:** accepted (2026-03-01)

### Decision
All users share Carlos's Ollama instance at 127.0.0.1:11434 via OLLAMA_HOST env var.

### Rationale
- Ollama is already running as a systemd service
- Each instance would load models into RAM separately (wasteful)
- Single env var addition per user

---

## D-005 - Claude API key shared by default, opt-in copy

**Status:** accepted (2026-03-01)

### Decision
Admin credentials are only copied with explicit `--copy-admin-credentials` flag. Not copied by default.

### Rationale
- Security: sharing API keys should be a conscious decision
- Each user can set up their own Anthropic account later
- Flag validates $SUDO_USER and source file existence before copying
- Never overwrites existing credentials (user may have set their own)

---

## D-006 - Create-if-missing with --update-templates for updates

**Status:** accepted (2026-03-01)

### Decision
Dotfiles are only created if they don't exist (idempotent). The `--update-templates` flag forces overwrite with automatic `.bak.<timestamp>` backups.

### Rationale
- Protects user customizations by default
- Backup before overwrite enables easy rollback
- Single script handles both create and update flows
