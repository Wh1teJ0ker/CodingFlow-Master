# CodingFlow-Master

[中文](./README.md)

> ZCode orchestrator workflow plugin — Hooks + Commands + Skills three-layer architecture with machine-enforced gates.

<p align="center">
  <img src="https://img.shields.io/badge/ZCode-Plugin-blue?style=flat" alt="ZCode Plugin"> <img src="https://img.shields.io/badge/version-2.1.1-blue?style=flat" alt="v2.1.1"> <img src="https://img.shields.io/badge/License-MIT-green?style=flat" alt="MIT">
</p>

---

## Overview

- **Three-layer enforcement**: Hooks (machine interception) → Commands (user-triggered) → Skills (agent guidance). Critical gates cannot be bypassed.
- **Orchestration loop**: Decompose requirements into DAG → dispatch coder → dispatch reviewer → main session accepts → E2E → commit.
- **Version gate**: Tagging is only triggered by explicit user command, and must pass Release QA audit first.
- **Tech-stack-agnostic**: Code standards are universal, not tied to specific frameworks or languages.

## Architecture

| Layer | Mechanism | Enforcement |
|---|---|---|
| **Hooks** | 4 scripts: state injection / tag intent detection / commit+tag gate / continuation check | Machine-enforced |
| **Commands** | `/plan` `/audit` `/tag` | User-triggered |
| **Skills** | SKILL.md + phases / specs / sync / references | Passive guidance |

Core hook interceptions: `git tag` requires a `qa_passed` QA report; `git commit` must follow Conventional Commits; tag format is strictly `vX.Y.Z`.

## Installation

```bash
git clone https://github.com/Wh1teJ0ker/CodingFlow-Master.git ~/.zcode/cli/plugins/codingflow-master
```

In ZCode client Settings → Plugins, add the local directory. The plugin auto-loads all components (agents / commands / hooks / skills).

## Usage

| Command | Purpose |
|---|---|
| `/plan <goal>` | Start workflow: empty repo → plan docs/; non-empty → audit + normalize → decompose tasks → execute → E2E → commit |
| `/audit` | Project audit: audit structure → build or normalize `docs/`, no task decomposition |
| `/tag vX.Y.Z` | Explicit tag: triggers Release QA → pass then tag + release.md, fail then output defect list |

## Workflow

```
Phase 0  Repo state detection (empty → plan docs/; non-empty → audit + normalize)
Phase 1  Decompose task DAG → write TASK-BOARD + HANDOFF
Phase 2  Dispatch coder → in_progress
Phase 3  Coder reports → read REPORT
Phase 4  Dispatch reviewer → read REVIEW → pass / reject
Phase 5  Main session judges verified_complete → delete handoff trio
Phase 6  Repeat 2-5 until all tasks pass
Phase 7  E2E acceptance → auto commit (no tag) → stop
Phase 8  [Only on explicit /tag] Release QA → qa_passed → tag + release.md
```

## Directory Structure

```
CodingFlow-Master/
├── marketplace.json              # Plugin marketplace manifest
├── plugins/
│   └── codingflow-master/
│       ├── .zcode-plugin/
│       │   └── plugin.json       # Plugin manifest
│       ├── agents/               # Sub-agent definitions (coder.md / reviewer.md)
│       ├── hooks/                # hooks.json + scripts/ (4 hook scripts)
│       ├── skills/orchestrator-workflow/
│       │   ├── SKILL.md          # Skill entry point
│       │   ├── phases/           # Phase process files (00-03, 07)
│       │   ├── specs/            # Sub-agent specs (04-coder, 05-reviewer)
│       │   ├── sync/             # Progress sync (06)
│       │   └── references/       # Standards (CODE / RELEASE / CI / README)
│       ├── commands/             # plan.md / audit.md / tag.md
│       └── assets/templates/     # Target project doc templates (7 files)
└── README.md
```

## License

MIT
