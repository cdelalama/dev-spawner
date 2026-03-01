# Repository Structure Guide

## Top-Level Layout
```
dev-spawner/
+-- README.md                    (project introduction and quick start)
+-- LLM_START_HERE.md            (mandatory reading for LLM contributors)
+-- VERSION                      (project version, source of truth)
+-- CHANGELOG.md                 (user-visible change log)
+-- LICENSE
+-- docs/
|  +-- PROJECT_CONTEXT.md
|  +-- ARCHITECTURE.md
|  +-- STRUCTURE.md              (this file)
|  +-- llm/
|     +-- HANDOFF.md
|     +-- HISTORY.md
|     +-- DECISIONS.md
|     +-- README.md
|     +-- REVIEWS.md
+-- scripts/
|  +-- spawn-user.sh             (main provisioning script)
|  +-- despawn-user.sh           (user removal script)
+-- templates/
|  +-- bashrc.template           (user .bashrc)
|  +-- profile.template          (user .profile)
|  +-- tmux.conf.template        (user tmux config)
|  +-- gitconfig.template        (user git config, with placeholders)
|  +-- claude/
|     +-- CLAUDE.md.template     (Claude Code instructions, simplified)
|     +-- settings.json.template (Claude Code settings, base)
|     +-- settings.sounds.json.template (Claude Code settings with sound hooks)
|     +-- sounds/
|        +-- play-remote.sh      (sound notification script)
|        +-- play-error-remote.sh (error sound script with filtering)
+-- src/                         (reserved for future code)
+-- tests/                       (reserved for future tests)
```

## Directory Descriptions
| Path | Purpose | Notes |
|------|---------|-------|
| docs/ | Project documentation | Required |
| docs/llm/ | Handoff and history for LLM contributors | Required |
| scripts/ | Provisioning and teardown scripts | Core of the project |
| templates/ | Dotfile and config templates | Copied/rendered per user |
| templates/claude/ | Claude Code configuration templates | Includes base + sounds variants |
| src/ | Future application code | Currently empty |
| tests/ | Future automated tests | Currently empty |
