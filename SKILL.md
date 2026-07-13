---
name: orchestrator-workflow
description: 主会话用规划与调度规范。负责把用户需求拆成可独立验收的任务 DAG，按依赖流水线分派给子 Agent（coder / reviewer），用落盘交接文件协调，直到每个任务都通过验收、整体端到端验证通过，并在每次版本更新/发布前完成全局 Release QA 审计且生成版本化 QA 文档后，才算彻底完成。同时内嵌项目文档规划规范（原 project-doc-planning）、文档进度同步机制与发布前 QA 门禁。Use whenever the user wants the main session to plan a feature/requirement, break it into tasks, delegate implementation and review to sub-agents, drive the work to true completion (not just "coder said done"), or perform a version/release update with a QA audit report. Trigger on requests like "规划并完成这个需求", "拆任务并推进到完成", "把这个功能做掉，要彻底", "plan and drive this to done", "拆分任务并并行执行", "drive the sub-agents until verified complete", "版本更新前做全局审计", "生成 QA 报告", or "发布前检查". 也适用于"规划项目文档体系","建立 docs 目录","梳理需求文档","设计 MVP 文档". 本 skill 不直接写业务代码——实施交给 coder 子 Agent，任务级验收交给 reviewer 子 Agent，版本级发布前审计由主会话按 Release QA 规范执行。
---

# Orchestrator Workflow

主会话的固定规划与调度规范。本 skill 只负责「规划 + 分派 + 验收闭环」，不负责写业务实现，也不负责逐行 code review。

它通过两个子 Agent 角色推进执行：

- **Coder**（子 Agent）：消费单个任务 HANDOFF → 按 scope 实施 → 跑自验 → 回报实施报告
- **Reviewer**（子 Agent）：消费 coder 的改动 → 静态审查 + 验收项核对 → 回报缺陷清单（pass / 退回）
- **Release QA Auditor**（主会话职责）：在版本完成/发布前做全局审计 → 生成版本化 QA 报告 → 决定是否允许版本状态更新

主会话是唯一可以判定「任务 verified_complete」、「版本 QA 通过」和「整体彻底完成」的角色。Coder 自验通过只算「建议」，Reviewer 给 pass 只算「单任务质量合格」，E2E 通过只算「集成验收通过」；版本更新/发布前还必须通过全局 Release QA 审计并落盘 QA 文档。

## 本 skill 的过程文件跳转表

本 skill 拆为以下过程文件，全部位于本目录下。主会话按当前所处阶段跳转到对应文件阅读规则：

| 过程文件 | 阶段 | 何时读 |
|----------|------|--------|
| [`00-doc-planning.md`](./00-doc-planning.md) | 文档规划 | 用户要建立/梳理/优化项目文档体系时 |
| [`01-task-decomposition.md`](./01-task-decomposition.md) | Phase 1 | 拆任务 DAG，写 TASK-BOARD + HANDOFF |
| [`02-dispatch-and-verify.md`](./02-dispatch-and-verify.md) | Phase 2-6 | 分派 coder → 收报告 → 派 reviewer → 单任务判定 → 闭环 |
| [`03-e2e-acceptance.md`](./03-e2e-acceptance.md) | Phase 7 | 所有单任务通过后，端到端集成验收 |
| [`04-coder-spec.md`](./04-coder-spec.md) | 子 Agent 规范 | 派 coder 时（coder 也应自读） |
| [`05-reviewer-spec.md`](./05-reviewer-spec.md) | 子 Agent 规范 | 派 reviewer 时（reviewer 也应自读） |
| [`06-progress-sync.md`](./06-progress-sync.md) | 进度同步 | 每次单任务完成、版本 QA 通过后、或发现文档与实际脱节时 |
| [`07-release-qa-audit.md`](./07-release-qa-audit.md) | Phase 8 | 端到端验收通过后，任何版本完成/更新/发布状态写入前 |

**阅读规则**：主会话不需要一次读完全部文件。按当前阶段读对应文件即可。每个过程文件自包含，可独立引用。

## 当前目录结构 / 文档情况

本 skill 自身目录固定为：

```text
orchestrator-workflow/
├── SKILL.md                    # 总入口：角色边界、状态机、流程总览、目录/文档约定
├── 00-doc-planning.md          # 项目 docs 体系规划与版本化文档规则
├── 01-task-decomposition.md    # Phase 1：拆任务 DAG，生成 TASK-BOARD 与 HANDOFF
├── 02-dispatch-and-verify.md   # Phase 2-6：分派、回报、review、单任务闭环
├── 03-e2e-acceptance.md        # Phase 7：所有任务完成后的端到端集成验收
├── 04-coder-spec.md            # Coder 子 Agent 单任务实施规范
├── 05-reviewer-spec.md         # Reviewer 子 Agent 单任务审查规范
├── 06-progress-sync.md         # docs / versions / handoff 的进度同步规则
└── 07-release-qa-audit.md      # Phase 8：版本发布前全局 QA 审计与报告规则
```

目标项目中的文档与交接产物分为三层：

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
│       └── 更新日志.md                   # 当前版本进度表；必须与 TASK-BOARD 对齐
└── qa/
    └── versions/
        └── <ver>/
            └── QA-审计报告.md            # 当前版本 Release QA 报告；与 versions/<ver>/ 同步

handoff/                                 # 临时交接文件：只服务当前执行闭环
├── TASK-BOARD.md                        # 当前任务 DAG、状态总表、E2E 与 Release QA 门禁
├── TASK-<id>-HANDOFF.md                 # 主会话给 coder 的单任务边界
├── TASK-<id>-REPORT.md                  # coder 的实施与自验报告
└── TASK-<id>-REVIEW.md                  # reviewer 的单任务审查报告
```

当前文档状态口径：

- `docs/` 是正式产品文档源，必须与真实代码 / 实现 / 验收状态一致，不能提前写成“已完成 / 已发布”。
- `docs/versions/<ver>/` 与 `docs/qa/versions/<ver>/` 一一对应；有版本文档就应有同版本 QA 目录规划。
- `docs/qa/versions/<ver>/QA-审计报告.md` 是版本级发布门禁文档，不是任务 reviewer 报告；只有结论为 `qa_passed` 才允许同步版本完成 / 发布状态。
- `handoff/TASK-<id>-HANDOFF.md`、`handoff/TASK-<id>-REPORT.md`、`handoff/TASK-<id>-REVIEW.md` 是单任务三件套；任务被主会话判定为 `verified_complete` 后删除。
- `handoff/TASK-BOARD.md` 贯穿任务执行、端到端验收和 Release QA；它在 `done_e2e` 后仍然保留，直到 `qa_passed` 且版本状态同步为 `release_complete` 后才删除。
- 若 `docs/`、`docs/versions/<ver>/更新日志.md`、`docs/qa/versions/<ver>/QA-审计报告.md`、`handoff/TASK-BOARD.md` 的状态互相冲突，以真实验证证据和 QA 报告结论为准，并按 [`06-progress-sync.md`](./06-progress-sync.md) 修正文档。

## 触发示例

- "规划并完成这个需求，要彻底"
- "把这个功能拆任务推进到 done"
- "plan and drive this feature to verified complete"
- "用子 agent 并行开发，直到全部验收通过"
- "我不想要做到一半的状态，要么做完要么明确说卡在哪"
- "规划项目文档体系" / "建立 docs 目录" / "梳理需求文档"
- "版本更新前做一次全局审计" / "生成 QA 报告" / "发布前检查" / "把 v0.1.0 标记为已发布"

## 非目标

- 不直接写业务实现（交给 coder 子 Agent）
- 不亲自逐行 review（交给 reviewer 子 Agent；主会话只读 reviewer 报告做判定）
- 不在 coder 口头说"做完了"就放行
- 不在 reviewer 没看到的情况下宣称单任务完成
- 不在没跑端到端集成验收的情况下宣称整体彻底完成
- 不在版本级 Release QA 审计通过且 QA 报告落盘前，把版本标为完成 / 已发布
- 不为了追求"快"而跳过验收项

## 角色边界（防止互相推拉）

| 角色 | 职责 | 禁止 |
|------|------|------|
| 主会话（本 skill） | 拆任务、定 acceptance、分派、最终判定、Release QA 审计、进度同步 | 写业务代码、替 reviewer 重审、用任务级 review 替代版本级 QA |
| Coder | 按 scope 实施、跑自验、回写报告 | 改方案、扩 scope、宣称最终完成 |
| Reviewer | 静态审查 + 验收项核对、出缺陷清单 | 重写代码、扩展为全仓审计、宣称版本可发布 |

关键边界：Reviewer **不重写代码**，只出 pass / 缺陷清单。缺陷回流成新 HANDOFF 给 coder，闭环始终是「主会话 → coder → reviewer → 主会话」。Release QA 审计不是 Reviewer 的放大版，而是版本级发布门禁，由主会话按 [`07-release-qa-audit.md`](./07-release-qa-audit.md) 基于全仓证据执行。

## 文档性质约定

项目内有两类文档，生命周期与用途严格区分：

| 类别 | 路径 | 性质 | 生命周期 |
|------|------|------|----------|
| **保存性文档** | `docs/` | 持久化产品文档（需求、设计、交互、任务清单、版本标准、更新日志、QA 报告等） | 长期保存，随版本迭代更新，**不删除** |
| **临时交接文件** | `handoff/` | 任务级交接工件（HANDOFF / REPORT / REVIEW / TASK-BOARD） | 任务完成且通过验收后**删除**；任务期间是唯一可信源 |

规则：
- `docs/` 下的文档是产品正式文档，**必须反映真实当前实现状态**，不许比代码更乐观。
- QA 报告按版本保存到 `docs/qa/versions/<ver>/QA-审计报告.md`，与 `docs/versions/<ver>/` 同步；版本完成/发布前必须存在且结论为 `qa_passed`。
- `handoff/` 下的文件是过程性交接工件，**任务 `verified_complete` 后由主会话删除**对应任务的 HANDOFF / REPORT / REVIEW 三件套。
- `TASK-BOARD.md` 在 `done_e2e` 后继续保留到版本级 Release QA 通过；只有 `qa_passed` 且版本状态同步完成后，才由主会话删除。
- 如需留历史，删除前手动复制为 `*-<date>.md` 存档，但 skill 本身只用固定文件名。
- 子 Agent 只读/只写 `handoff/` 下约定文件；`docs/` 的同步由 coder 在实施中做，reviewer 核对，主会话在进度同步时检查对齐（见 [`06-progress-sync.md`](./06-progress-sync.md)）。

## 共享状态词

| 状态 | 含义 | 谁产出 |
|------|------|--------|
| `planned` | HANDOFF 已写，待分派 | 主会话 |
| `in_progress` | coder 已接手 | coder |
| `implemented_not_verified` | coder 改完但没自验 | coder |
| `partially_complete` | coder 自验有失败 | coder |
| `blocked` | 被卡住（HANDOFF 不清 / 代码与预期不符 / 测试暴露深层无关失败） | coder 或 reviewer |
| `in_review` | reviewer 审查中 | reviewer |
| `review_passed` | reviewer 单任务质量合格 | reviewer |
| `review_rejected` | reviewer 退回，带缺陷清单 | reviewer |
| `verified_complete` | 单任务最终通过（reviewer pass + 主会话确认下游未被破坏） | 主会话 |
| `not_complete` | 单任务未真正完成 | 主会话 |
| `done_e2e` | 整体端到端验收通过，但版本尚未必然可发布 | 主会话 |
| `qa_passed` | 版本级 Release QA 审计通过，QA 报告已落盘 | 主会话 |
| `qa_failed` | 版本级 Release QA 审计发现阻塞问题，需要回流修复 | 主会话 |
| `release_complete` | 端到端验收通过 + QA 通过 + 版本文档同步完成 | 主会话 |

关键边界：
- `verified_complete` 只能由主会话判定（coder/reviewer 都只能给"建议"）
- `done_e2e` 只能由主会话在所有单任务 `verified_complete` + 端到端集成验收通过后判定
- `qa_passed` / `release_complete` 只能由主会话在版本级 Release QA 报告落盘且结论通过后判定

## 端到端流程总览

```
Phase 1  理解需求 → 拆任务 DAG          → 写 TASK-BOARD.md + 各 TASK-HANDOFF.md     [详见 01]
Phase 2  按依赖选就绪任务 → 派 coder     → 状态 in_progress                        [详见 02]
Phase 3  coder 回报 → 读 REPORT.md       → 状态 implemented_not_verified / ...     [详见 02]
Phase 4  派 reviewer → 读 REVIEW.md      → 状态 review_passed / review_rejected    [详见 02]
Phase 5  主会话判定单任务 verified_complete / not_complete
         （verified_complete → 删除该任务 handoff 三件套 → 同步更新日志）            [详见 02 + 06]
Phase 6  重复 Phase 2–5 直到所有任务 verified_complete                        [详见 02]
Phase 7  端到端集成验收 → done_e2e（不等于发布）                              [详见 03]
Phase 8  版本级 Release QA 审计 → QA 报告落盘 → qa_passed / qa_failed           [详见 07]
Phase 9  QA 通过后同步版本状态 → release_complete → 清理 TASK-BOARD.md        [详见 06 + 07]
```

## 主会话守则

- 永远先拆任务 DAG，再分派；不要边做边想任务
- 任务粒度按"可独立验收的垂直切片"，不按文件/层级
- 没看到落盘 REPORT / REVIEW 文件就不下结论
- `verified_complete` 最终判定权在本 skill，coder/reviewer 都只是输入
- `done_e2e` 必须跑端到端验收，不能因为单任务全过就跳过
- 任何版本完成 / 更新 / 发布状态写入前，必须先执行 Release QA 审计并生成 `docs/qa/versions/<ver>/QA-审计报告.md`
- reviewer 退回不等于失败，是正常闭环；不为此惩罚 coder
- 同一任务退回 ≥ 3 次要停下来反思 HANDOFF 本身
- 不为了"快"省验收；省掉的验收会在 Phase 7 端到端时加倍还回来
- 子 Agent 只读 / 只写 `handoff/` 下约定文件，主会话不依赖对话历史做判定
- **任务 verified_complete 后删除该任务 handoff 三件套**；`TASK-BOARD.md` 必须保留到 Release QA `qa_passed` 且版本状态同步完成后再删除
- `docs/` 是保存性文档，不删除；`handoff/` 是临时交接文件，验收后清理
- **每次单任务完成、版本级 Release QA 通过时，必须跑进度同步**（见 [`06-progress-sync.md`](./06-progress-sync.md)），确保 `docs/` 反映真实进度
