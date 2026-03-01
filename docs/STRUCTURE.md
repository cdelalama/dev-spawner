# Repository Structure Guide

## Top-Level Layout
```
dev-spawner/
+-- README.md                    (project introduction and quick start)
+-- LLM_START_HERE.md            (mandatory reading for LLM contributors)
+-- VERSION                      (project version, source of truth)
+-- CHANGELOG.md                 (user-visible change log)
+-- docs/
|  +-- PROJECT_CONTEXT.md
|  +-- ARCHITECTURE.md
|  +-- STRUCTURE.md              (this file)
|  +-- llm/                      (LLM working memory)
|  |  +-- HANDOFF.md
|  |  +-- HISTORY.md
|  |  +-- DECISIONS.md
+-- scripts/
|  +-- spawn-user.sh             (main provisioning script)
+-- templates/
|  +-- bashrc.template           (user .bashrc)
|  +-- profile.template          (user .profile)
|  +-- tmux.conf.template        (user tmux config)
|  +-- gitconfig.template        (user git config)
|  +-- claude/
|     +-- CLAUDE.md.template     (Claude Code instructions)
|     +-- settings.json.template (Claude Code settings)
+-- tests/                       (optional)
```

## Directory Descriptions
| Path | Purpose | Notes |
|------|---------|-------|
| docs/ | Project documentation | Required |
| docs/llm/ | Handoff and history for LLM contributors | Required |
| scripts/ | Provisioning scripts | Core of the project |
| templates/ | Dotfile and config templates | Copied/rendered per user |
| tests/ | Automated tests | Optional |
