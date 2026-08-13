# CodingFlow-Master

[English](./README_EN.md)

> ZCode 编排工作流插件 — Hooks + Commands + Skills 三层架构，机器强制关键门禁不可绕过。

<p align="center">
  <img src="https://img.shields.io/badge/ZCode-Plugin-blue?style=flat" alt="ZCode Plugin"> <img src="https://img.shields.io/badge/version-2.1.0-blue?style=flat" alt="v2.1.0"> <img src="https://img.shields.io/badge/License-MIT-green?style=flat" alt="MIT">
</p>

---

## 简介

- 三层强制：Hooks（机器拦截）→ Commands（用户触发）→ Skills（Agent 指导），关键门禁不可绕过。
- 编排闭环：需求拆 DAG → 派 coder 执行 → 派 reviewer 审查 → 主会话验收 → E2E → commit。
- 版本门禁：tag 仅在用户显式指令时触发，强制通过 Release QA 审计后才能创建。
- 技术栈无关：代码规范通用，不绑定特定框架或语言。

## 架构

| 层 | 机制 | 强制性 |
|---|---|---|
| **Hooks** | 4 个脚本：状态注入 / tag 意图检测 / commit+tag 门禁 / 续行检查 | 机器强制 |
| **Commands** | `/plan` `/audit` `/tag` | 用户主动触发 |
| **Skills** | SKILL.md + phases / specs / sync / references | 被动指导 |

Hook 核心拦截：`git tag` 必须有 `qa_passed` 的 QA 报告；`git commit` 必须符合 Conventional Commits；tag 格式严格 `vX.Y.Z`。

## 安装

```bash
git clone https://github.com/Wh1teJ0ker/CodingFlow-Master.git ~/.zcode/cli/plugins/codingflow-master
```

在 ZCode 客户端 Settings → Plugins 中添加本地目录，插件自动加载（含 agents / commands / hooks / skills 全部组件）。

## 使用

| 命令 | 作用 |
|---|---|
| `/plan <goal>` | 启动工作流：空仓库→规划 docs/；非空→审计+规范化→拆任务→执行→E2E→commit |
| `/audit` | 项目审计：审计结构 → 构建或规范化 `docs/`，不启动任务拆分 |
| `/tag vX.Y.Z` | 显式 tag：触发 Release QA → 通过则 tag + release.md，失败则输出缺陷清单 |

## 工作流

```
Phase 0  仓库状态判断（空→规划 docs/；非空→审计+规范化）
Phase 1  拆任务 DAG → 写 TASK-BOARD + HANDOFF
Phase 2  派 coder → in_progress
Phase 3  coder 回报 → 读 REPORT
Phase 4  派 reviewer → 读 REVIEW → pass / 退回
Phase 5  主会话判定 verified_complete → 删除三件套
Phase 6  重复 2-5 直到全部通过
Phase 7  E2E 验收 → 自动 commit（不 tag）→ 停
Phase 8  【仅当 /tag 显式触发】Release QA → qa_passed → tag + release.md
```

## 目录结构

```
CodingFlow-Master/
├── marketplace.json              # 插件市场清单
├── plugins/
│   └── codingflow-master/
│       ├── .zcode-plugin/
│       │   └── plugin.json       # 插件清单
│       ├── agents/               # 子 Agent 定义（coder.md / reviewer.md）
│       ├── hooks/                # hooks.json + scripts/（4 个 hook 脚本）
│       ├── skills/orchestrator-workflow/
│       │   ├── SKILL.md          # Skill 总入口
│       │   ├── phases/           # Phase 流程文件（00-03, 07）
│       │   ├── specs/            # 子 Agent 规范（04-coder, 05-reviewer）
│       │   ├── sync/             # 进度同步（06）
│       │   └── references/       # 标准规范（CODE / RELEASE / CI / README）
│       ├── commands/             # plan.md / audit.md / tag.md
│       └── assets/templates/     # 目标项目文档模板（7 个）
└── README.md
```

## License

MIT
