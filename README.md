<!-- doc-version: 0.1.0 -->
# dev-spawner

Automated provisioning of development user environments on dev-vm.

**Version:** see [VERSION](VERSION) | [CHANGELOG](CHANGELOG.md)

## Overview

dev-spawner creates and manages development environments for multiple users on a shared Ubuntu VM. It replicates the core development tooling (Node.js, Docker, Claude Code, tmux, git) into isolated user home directories, so each person gets a fully functional dev setup without interfering with others.

Built for a family home lab where the main dev-vm (Ubuntu 22.04, 16GB RAM, 2 vCPU) serves as the shared development machine.

## Quick Start

### Prerequisites
- Ubuntu 22.04+ VM with sudo access
- Existing working dev environment (the "reference" user)

### Usage
```bash
# Create a new dev user
sudo ./scripts/spawn-user.sh <username> --git-name "Full Name" --git-email "email@example.com"

# With optional modules
sudo ./scripts/spawn-user.sh <username> --git-name "Name" --git-email "email" --with-ollama --copy-admin-credentials

# Update existing user's dotfiles (creates .bak backups)
sudo ./scripts/spawn-user.sh <username> --update-templates

# Remove a user
sudo ./scripts/despawn-user.sh <username>
```

## Documentation

| Document | Purpose |
|----------|---------|
| [LLM_START_HERE.md](LLM_START_HERE.md) | Entry point for LLM contributors |
| [docs/PROJECT_CONTEXT.md](docs/PROJECT_CONTEXT.md) | Vision, architecture, current state |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Technical architecture details |
| [docs/llm/HANDOFF.md](docs/llm/HANDOFF.md) | Current work state |

## License

Released under the MIT License. See [LICENSE](LICENSE) for details.

---

*Documentation scaffold powered by [LLM-DocKit](https://github.com/cdelalama/LLM-DocKit).*
