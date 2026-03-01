<!-- doc-version: 0.1.0 -->
# LLM Start Guide - dev-spawner

## Read This First (Mandatory)

Welcome to dev-spawner. Before you contribute, review the sections below.

Recommended reading order:
1. This file (rules, workflows, and current expectations)
2. docs/PROJECT_CONTEXT.md (vision, architecture, current state)
3. docs/llm/HANDOFF.md (current work state and priorities)

## Critical Rules (Non-Negotiable)

### Language Policy
- All code and documentation: English
- Conversation with the user: Spanish
- Comments in code: English
- File names: English

### Documentation Update Rules
- Update docs/llm/HANDOFF.md every time you make a change.
- Append an entry to docs/llm/HISTORY.md in every session.
- HISTORY format: YYYY-MM-DD - <LLM_NAME> - <Brief summary> - Files: [list] - Version impact: [yes/no + details]

### Commit Message Policy
- **Title:** under 72 characters
- **Description:** under 200 characters, focused on user impact and why the change matters

### Infrastructure Context
- Reference environment: cdelalama@dev-vm (10.0.0.110)
- Infrastructure docs: ~/src/home-infra/docs/ (INVENTORY.md, SERVICES.md, CONVENTIONS.md, ONBOARDING.md)
- These docs are the source of truth for network and infrastructure context

## Current Focus (Snapshot)

Source of truth: docs/llm/HANDOFF.md.
- Last Updated: 2026-03-01 - Claude Opus 4.6
- Working on: Testing v0.1.0 with verify + diagnose
- Status: v0.1.0 implemented. Auto-verify (bash) + auto-diagnose (Claude CLI) integrated. Testing with testuser.

## Quick Navigation
- Project Overview: docs/PROJECT_CONTEXT.md
- Current Work State: docs/llm/HANDOFF.md
- Change History: docs/llm/HISTORY.md

---

Every change must be documented. If you are unsure about a rule, ask the user before proceeding.
