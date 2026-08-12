---
name: orchestrator-workflow
description: 主会话用规划与调度规范。负责把用户需求拆成可独立验收的任务 DAG，按依赖流水线分派给子 Agent（coder / reviewer），用落盘交接文件协调，直到每个任务都通过验收、整体端到端验证通过。版本发布（tag）仅在用户显式指令时触发，并强制通过 Release QA 审计。本插件同时提供 Hook 强制门禁（tag 格式 / commit message / QA 报告存在性检查）和斜杠命令（/plan /audit /tag）。Use whenever the user wants the main session to plan a feature/requirement, break it into tasks, delegate implementation and review to sub-agents, drive the work to true completion, or perform a version release with QA audit. 触发示例："规划并完成这个需求"、"拆任务并推进到完成"、"把这个功能做掉，要彻底"、"plan and drive this to done"、"版本发布前做全局审计"、"生成 QA 报告"、"发布前检查"、"/plan"、"/tag v1.0.0"、"/audit"。
---

# Orchestrator Workflow（V2 插件架构）

主会话的固定规划与调度规范。本 skill 只负责「规划 + 分派 + 验收闭环」，不负责写业务实现，也不负责逐行 code review。

## 三层强制架构

本插件通过三层机制保障工作流：

| 层 | 机制 | 强制性 | 职责 |
|---|---|---|---|
| **Hooks** | `hooks/hooks.json` + 脚本 | 机器强制 | tag 格式校验、commit message 校验、QA 报告存在性检查、工作流状态注入 |
| **Commands** | `commands/*.md` 斜杠命令 | 用户主动触发 | `/plan` 启动工作流、`/audit` 项目审计、`/tag` 显式 tag |
| **Skills** | 本文件 + 过程文件 | 被动指导 | 指导 Agent 如何执行每个阶段 |

### Hook 强制门禁一览

| Hook | 事件 | 阻断性 | 检查内容 |
|---|---|---|---|
| `session-start.sh` | SessionStart | 非阻断 | 注入当前工作流状态（TASK-BOARD + 版本状态） |
| `prompt-submit.sh` | UserPromptSubmit | 非阻断 | 注入工作流提醒（tag/发布意图 → QA 门禁提示） |
| `pre-bash-gate.sh` | PreToolUse(Bash) | 强制阻断 | `git tag` → 版本格式 + QA 报告存在且 qa_passed；`git commit` → Conventional Commits 格式 |
| `stop-check.sh` | Stop | 可续行 | 未完成任务 → 请求续行（最多 3 次） |

> Hook 是安全网：即使 Agent 试图绕过 skill 指导直接 `git tag`，hook 也会拦截。但 Hook 只检查机器可验证的条件（文件存在性、格式正则），语义级验收仍由 skill + reviewer 负责。

## 子 Agent 角色

- **Coder**（子 Agent）：消费单个任务 HANDOFF → 按 scope 实施 → 跑自验 → 回报实施报告
- **Reviewer**（子 Agent）：消费 coder 的改动 → 静态审查 + 验收项核对 → 回报缺陷清单（pass / 退回）
- **Release QA Auditor**（主会话职责）：在版本 tag 前（仅显式触发）做全局审计 → 生成版本化 QA 报告 → 决定是否允许 tag

主会话是唯一可以判定「任务 verified_complete」、「版本 QA 通过」和「整体彻底完成」的角色。Coder 自验通过只算「建议」，Reviewer 给 pass 只算「单任务质量合格」，E2E 通过只算「集成验收通过」。

## 本 skill 的过程文件跳转表

| 过程文件 | 阶段 | 何时读 |
|----------|------|--------|
| [`phases/00-doc-planning.md`](./phases/00-doc-planning.md) | Phase 0 | 仓库状态判断 + 文档规划 |
| [`phases/01-task-decomposition.md`](./phases/01-task-decomposition.md) | Phase 1 | 拆任务 DAG，写 TASK-BOARD + HANDOFF |
| [`phases/02-dispatch-and-verify.md`](./phases/02-dispatch-and-verify.md) | Phase 2-6 | 分派 coder → 收报告 → 派 reviewer → 单任务判定 → 闭环 |
| [`phases/03-e2e-acceptance.md`](./phases/03-e2e-acceptance.md) | Phase 7 | 所有单任务通过后，端到端集成验收 |
| [`specs/04-coder-spec.md`](./specs/04-coder-spec.md) | 子 Agent 规范 | 派 coder 时（coder 也应自读） |
| [`specs/05-reviewer-spec.md`](./specs/05-reviewer-spec.md) | 子 Agent 规范 | 派 reviewer 时（reviewer 也应自读） |
| [`sync/06-progress-sync.md`](./sync/06-progress-sync.md) | 进度同步 | 每次单任务完成、版本 QA 通过后、或发现文档与实际脱节时 |
| [`phases/07-release-qa-audit.md`](./phases/07-release-qa-audit.md) | Phase 8 | **仅当用户显式指令 tag 时**执行版本级 Release QA 审计 |

**阅读规则**：主会话不需要一次读完全部文件。按当前阶段读对应文件即可。每个过程文件自包含，可独立引用。

## 当前目录结构 / 文档情况

### 插件自身结构

```text
CodingFlow-Master/                          # 插件根目录
├── .zcode-plugin/
│   └── plugin.json                         # 插件清单
├── agents/                                 # 子 Agent 定义（插件自动加载）
│   ├── coder.md                            # Coder 子 Agent
│   └── reviewer.md                         # Reviewer 子 Agent
├── hooks/
│   ├── hooks.json                          # Hook 定义
│   └── scripts/
│       ├── session-start.sh                # SessionStart: 工作流状态注入
│       ├── prompt-submit.sh                # UserPromptSubmit: 提醒注入
│       ├── pre-bash-gate.sh                # PreToolUse: tag/commit 门禁
│       └── stop-check.sh                   # Stop: 未完成任务续行
├── skills/
│   └── orchestrator-workflow/
│       ├── SKILL.md                        # 总入口（本文件）
│       ├── phases/                         # Phase 流程文件
│       │   ├── 00-doc-planning.md          # Phase 0: 仓库审计 + 文档规划
│       │   ├── 01-task-decomposition.md    # Phase 1: 任务 DAG
│       │   ├── 02-dispatch-and-verify.md   # Phase 2-6: 分派/验收/闭环
│       │   ├── 03-e2e-acceptance.md         # Phase 7: 端到端验收
│       │   └── 07-release-qa-audit.md      # Phase 8: Release QA（显式触发）
│       ├── specs/                          # 子 Agent 规范
│       │   ├── 04-coder-spec.md            # Coder 规范
│       │   └── 05-reviewer-spec.md         # Reviewer 规范
│       ├── sync/                           # 进度同步
│       │   └── 06-progress-sync.md
│       └── references/                     # 标准规范
│           ├── CODE-STANDARD.md            # 前后端通用代码规范
│           ├── RELEASE-STANDARD.md         # Release 规范
│           ├── GITHUB-ACTIONS-STANDARD.md  # CI 规范
│           └── README-STANDARD.md          # README 规范
├── commands/
│   ├── plan.md                             # /plan — 启动工作流
│   ├── audit.md                            # /audit — 项目审计
│   └── tag.md                              # /tag — 显式 tag
├── assets/templates/                       # 目标项目模板
│   ├── README.md.template
│   ├── README_EN.md.template
│   ├── 规划需求.md.template
│   ├── 更新日志.md.template
│   ├── release.md.template                 # Release 发布文档
│   ├── 04-版本标准.md.template
│   └── QA-审计报告.md.template
└── README.md                               # 插件说明
```

### 资源分层权威性

| 层 | 路径 | 性质 | 权威性 |
|---|---|---|---|
| 规范 | `references/` | 定义"必须满足什么" | 权威，评审依据 |
| 模板 | `assets/templates/` | 通用可复制结构 | 权威起点，复制后替换占位符 |

### 目标项目文档结构

目标项目中的文档与交接产物：

```text
docs/                                    # 保存性文档：长期保留，不因任务完成而删除
├── 00-需求文档.md                       # 全景需求、MVP 边界、验收标准
├── 01-页面与交互说明.md                  # 页面结构、状态流、交互规则
├── 02-技术设计文档.md                    # 架构分层、模块职责、关键数据流
├── 03-开发任务清单.md                    # 全局任务、阶段、依赖、验收方式
├── 04-版本标准.md                       # 版本号语义、里程碑索引、版本状态口径
├── versions/
│   └── <ver>/
│       ├── 规划需求.md                   # 当前版本范围、目标、任务清单
│       ├── 技术方案.md                   # 当前版本技术方案；简单版本可选
│       ├── 更新日志.md                   # 当前版本进度表；必须与 TASK-BOARD 对齐
│       └── release.md                   # 当前版本发布文档：What's New / Fixed / Downloads
└── qa/
    └── versions/
        └── <ver>/
            └── QA-审计报告.md            # 当前版本 Release QA 报告

handoff/                                 # 临时交接文件：只服务当前执行闭环
├── TASK-BOARD.md                        # 当前任务 DAG、状态总表
├── TASK-<id>-HANDOFF.md                 # 主会话给 coder 的单任务边界
├── TASK-<id>-REPORT.md                  # coder 的实施与自验报告
└── TASK-<id>-REVIEW.md                  # reviewer 的单任务审查报告
```

文档状态口径：
- `docs/` 是正式产品文档源，必须与真实代码/实现/验收状态一致，不能提前写成"已完成/已发布"。
- `docs/versions/<ver>/release.md` 在 tag 后生成，包含 What's New / Fixed / Downloads；tag 前不创建。
- `docs/qa/versions/<ver>/QA-审计报告.md` 是版本级发布门禁文档，只有结论为 `qa_passed` 才允许 tag。
- `handoff/` 三件套在任务 `verified_complete` 后删除；`TASK-BOARD.md` 在 `qa_passed` 且版本状态同步后删除。

## 端到端流程总览

```
Phase 0  仓库状态判断 【V2 新增】
         ├─ 空仓库 → 根据任务规划 docs/ 文档体系
         └─ 非空仓库 → 审计现有项目 → 构建规范化 docs/          [详见 00]
Phase 1  理解需求 → 拆任务 DAG          → 写 TASK-BOARD.md + 各 TASK-HANDOFF.md     [详见 01]
Phase 2  按依赖选就绪任务 → 派 coder     → 状态 in_progress                        [详见 02]
Phase 3  coder 回报 → 读 REPORT.md       → 状态 implemented_not_verified / ...     [详见 02]
Phase 4  派 reviewer → 读 REVIEW.md      → 状态 review_passed / review_rejected    [详见 02]
Phase 5  主会话判定单任务 verified_complete / not_complete
         （verified_complete → 删除该任务 handoff 三件套 → 同步更新日志）            [详见 02 + 06]
Phase 6  重复 Phase 2–5 直到所有任务 verified_complete                        [详见 02]
Phase 7  端到端集成验收 → done_e2e（不等于发布）                              [详见 03]
         ── 自动 commit（Conventional Commits）──
         ── 停。不自动 tag。──
Phase 8  【仅当用户显式指令 /tag vX.X.Z 或明确说"tag vX.X.Z"】
         → Release QA 审计 → 生成 QA 报告 → qa_passed / qa_failed              [详见 07]
         → qa_passed → git tag + 生成 release.md → release_complete
         → qa_failed → 回流修复，不 tag
```

### V2 与 V1 的关键差异

1. **新增 Phase 0**：仓库状态判断（空 → 规划文档；非空 → 审计+规范化）
2. **Phase 7 后自动 commit 但不 tag**
3. **Phase 8 改为显式指令触发**（`/tag` 命令或用户明确说 "tag vX.X.Z"）
4. **新增 release.md**：版本发布文档（What's New / Fixed / Downloads）
5. **Hook 强制门禁**：tag 格式 + QA 报告存在性 + commit message 格式由机器强制

## 触发示例

- "规划并完成这个需求，要彻底"
- "把这个功能拆任务推进到 done"
- "plan and drive this feature to verified complete"
- "用子 agent 并行开发，直到全部验收通过"
- "我不想要做到一半的状态，要么做完要么明确说卡在哪"
- "规划项目文档体系" / "建立 docs 目录" / "梳理需求文档"
- `/plan <goal>` — 启动工作流
- `/audit` — 项目审计
- `/tag v1.0.0` — 显式 tag（触发 Release QA）
- "版本发布前做一次全局审计" / "生成 QA 报告" / "发布前检查"

## 非目标

- 不直接写业务实现（交给 coder 子 Agent）
- 不亲自逐行 review（交给 reviewer 子 Agent）
- 不在 coder 口头说"做完了"就放行
- 不在 reviewer 没看到的情况下宣称单任务完成
- 不在没跑端到端集成验收的情况下宣称整体彻底完成
- **不在用户显式指令 tag 前自动执行 Release QA 或创建 tag**
- 不在版本级 Release QA 审计通过且 QA 报告落盘前，创建 tag
- 不为了追求"快"而跳过验收项

## 角色边界（防止互相推拉）

| 角色 | 职责 | 禁止 |
|------|------|------|
| 主会话（本 skill） | 拆任务、定 acceptance、分派、最终判定、Release QA 审计、进度同步 | 写业务代码、替 reviewer 重审、用任务级 review 替代版本级 QA |
| Coder | 按 scope 实施、跑自验、回写报告 | 改方案、扩 scope、宣称最终完成、自动 tag |
| Reviewer | 静态审查 + 验收项核对、出缺陷清单 | 重写代码、扩展为全仓审计、宣称版本可发布 |

## 文档性质约定

| 类别 | 路径 | 性质 | 生命周期 |
|------|------|------|----------|
| **保存性文档** | `docs/` | 持久化产品文档 | 长期保存，随版本迭代更新，**不删除** |
| **临时交接文件** | `handoff/` | 任务级交接工件 | 任务完成且通过验收后**删除** |

规则：
- `docs/` 下的文档必须反映真实当前实现状态，不许比代码更乐观。
- QA 报告按版本保存到 `docs/qa/versions/<ver>/QA-审计报告.md`，与 `docs/versions/<ver>/` 同步；tag 前必须存在且结论为 `qa_passed`。
- `release.md` 在 tag 后生成到 `docs/versions/<ver>/release.md`，包含 What's New / Fixed / Downloads。
- `handoff/` 下的文件是过程性交接工件，任务 `verified_complete` 后由主会话删除三件套。
- `TASK-BOARD.md` 在 `done_e2e` 后保留到版本级 Release QA 通过；只有 `qa_passed` 且版本状态同步完成后才删除。

## 共享状态词

| 状态 | 含义 | 谁产出 |
|------|------|--------|
| `planned` | HANDOFF 已写，待分派 | 主会话 |
| `in_progress` | coder 已接手 | coder |
| `implemented_not_verified` | coder 改完但没自验 | coder |
| `partially_complete` | coder 自验有失败 | coder |
| `blocked` | 被卡住 | coder 或 reviewer |
| `in_review` | reviewer 审查中 | reviewer |
| `review_passed` | reviewer 单任务质量合格 | reviewer |
| `review_rejected` | reviewer 退回，带缺陷清单 | reviewer |
| `verified_complete` | 单任务最终通过 | 主会话 |
| `not_complete` | 单任务未真正完成 | 主会话 |
| `done_e2e` | 整体端到端验收通过，已自动 commit，但不 tag | 主会话 |
| `qa_passed` | 版本级 Release QA 审计通过，QA 报告已落盘 | 主会话 |
| `qa_failed` | 版本级 Release QA 审计发现阻塞问题 | 主会话 |
| `release_complete` | tag 已创建 + release.md 已生成 + 版本文档同步完成 | 主会话 |

关键边界：
- `verified_complete` 只能由主会话判定
- `done_e2e` 只能由主会话在所有单任务 `verified_complete` + 端到端集成验收通过后判定
- `qa_passed` / `release_complete` 只能由主会话在用户显式指令 tag 后、Release QA 报告落盘且结论通过后判定

## 主会话守则

- 永远先拆任务 DAG，再分派
- 任务粒度按"可独立验收的垂直切片"
- commit 粒度按"单一逻辑目的"，使用 Conventional Commits：`type(scope): subject`
- **不在用户显式指令 tag 前自动执行 Release QA 或创建 tag**
- 没看到落盘 REPORT / REVIEW 文件就不下结论
- `verified_complete` 最终判定权在本 skill
- `done_e2e` 必须跑端到端验收
- 任何 tag 创建前，必须先执行 Release QA 审计并生成 `docs/qa/versions/<ver>/QA-审计报告.md`
- reviewer 退回不等于失败，是正常闭环
- 同一任务退回 ≥ 3 次要停下来反思 HANDOFF 本身
- 子 Agent 只读/只写 `handoff/` 下约定文件，主会话不依赖对话历史做判定
- **任务 verified_complete 后删除该任务 handoff 三件套**；`TASK-BOARD.md` 必须保留到 Release QA `qa_passed` 且版本状态同步完成后再删除
- `docs/` 是保存性文档，不删除；`handoff/` 是临时交接文件，验收后清理
- **每次单任务完成、版本级 Release QA 通过时，必须跑进度同步**
