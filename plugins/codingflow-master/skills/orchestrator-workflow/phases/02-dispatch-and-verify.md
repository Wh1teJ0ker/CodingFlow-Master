# 02 — Phase 2-6: 分派 / 验收 / 闭环

> 主会话在分派 coder、收取报告、派 reviewer、单任务判定时阅读本文件。

## 固定交接文件（唯一可信源，不依赖对话历史）

所有交接必须落盘到项目根目录下的 `handoff/` 目录。对话里的副本仅为提示，**以文件为唯一可信源**。

| 文件 | 路径 | 写 | 读 | 删除时机 |
|------|------|----|----|----------|
| 任务 HANDOFF | `handoff/TASK-<id>-HANDOFF.md` | 主会话 | coder | 任务 verified_complete 后 |
| Coder 实施报告 | `handoff/TASK-<id>-REPORT.md` | coder | 主会话、reviewer | 任务 verified_complete 后 |
| Reviewer 缺陷清单 | `handoff/TASK-<id>-REVIEW.md` | reviewer | 主会话、coder | 任务 verified_complete 后 |
| 任务状态总表 | `handoff/TASK-BOARD.md` | 主会话 | 所有人 | E2E `done_e2e` 且自动 commit 后 |

规则：
- `handoff/` 不存在就先建
- 每轮覆写同名文件；要留历史手动复制为 `TASK-<id>-HANDOFF-<date>.md`
- 子 Agent 只读 / 只写约定文件，不读对话历史
- **任务通过验收后，主会话删除该任务的三件套文件**（HANDOFF / REPORT / REVIEW），保持工作区干净

## Phase 2 — 派 coder 子 Agent

选 `ready`（`depends_on` 全部 `verified_complete`）的任务，派 coder 子 Agent，把对应任务文件作为唯一输入源。子 Agent 遵守 [`04-coder-spec.md`](../specs/04-coder-spec.md) 定义的 Coder 规范。

调用输入：
- `task_id`: `T<id>`          # 版本内从 T1 递增，不跨版本累加（详见 01-task-decomposition.md "任务编号规则"）
- `handoff`: `handoff/TASK-<id>-HANDOFF.md`
- `expected_output`: `handoff/TASK-<id>-REPORT.md`
- `mode`: `initial` 或 `rework`

调用规则：
- 主会话只负责确认 HANDOFF 已写入磁盘，不重复粘贴 coder 执行规则
- coder 的实施边界、验证要求和 REPORT 格式由 [`04-coder-spec.md`](../specs/04-coder-spec.md) 定义
- 若 `handoff/TASK-<id>-REPORT.md` 未生成，任务不能进入 review

派单后状态 → `in_progress`。

## Phase 3 — 收 coder 报告

读 `handoff/TASK-<id>-REPORT.md`。以文件为唯一可信源，不信任对话里的口头结论。

判定：
- `reported_status: blocked` → 读原因，主会话决策（补 HANDOFF / 拆新任务 / 调方案），状态 `blocked`
- `reported_status: implemented_not_verified` → 要求 coder 先自验，状态保持
- `reported_status: partially_complete` → 看 `verification_results` 失败项，决定退回 coder 修还是拆新任务
- `reported_status: verified_complete`（建议）→ 进 Phase 4，不直接采信

## Phase 4 — 派 reviewer 子 Agent

派 reviewer 子 Agent，把 HANDOFF 与 coder REPORT 作为唯一输入源。子 Agent 遵守 [`05-reviewer-spec.md`](../specs/05-reviewer-spec.md) 定义的 Reviewer 规范。

调用输入：
- `task_id`: `T<id>`          # 版本内从 T1 递增，不跨版本累加
- `handoff`: `handoff/TASK-<id>-HANDOFF.md`
- `coder_report`: `handoff/TASK-<id>-REPORT.md`
- `expected_output`: `handoff/TASK-<id>-REVIEW.md`

调用规则：
- 主会话不重复粘贴 reviewer 审查规则
- reviewer 的审查边界、缺陷格式和 verdict 取值由 [`05-reviewer-spec.md`](../specs/05-reviewer-spec.md) 定义
- reviewer 只审查并写 REVIEW，不重写代码
- 若 `handoff/TASK-<id>-REVIEW.md` 未生成，任务不能进入最终判定

派单后状态 → `in_review`。

## Phase 5 — 主会话判定单任务状态

读 `handoff/TASK-<id>-REVIEW.md`。

判定规则（全部满足才 `verified_complete`）：
1. `verdict: review_passed`
2. `defects` 为空
3. coder `verification_commands` 全绿（看输出，不看"说跑过"）
4. commit 粒度与 message 基本符合规范：单一逻辑目的，且 message 使用 Conventional Commits 或 reviewer 明确接受的等价清晰写法
5. **下游未被破坏**：若该任务的改动可能影响已 `verified_complete` 的下游任务，重跑下游的 `verification_commands`；有失败 → 下游回 `not_complete`，本任务也回 `not_complete`
6. 文档已同步（reviewer 核过）

否则 → `not_complete`：
- `review_rejected` → 把 `defects` 合并进 HANDOFF（追加到 `acceptance_criteria` 或 `risks`），重新派 coder（回 Phase 2，**不另起新任务 id**）
- 验证失败 → 退回 coder 修
- 文档没同步 → 退回 coder 补

退回时 HANDOFF 追加一段：

```yaml
rework:
  source: TASK-<id>-REVIEW.md
  defects:
    - ...
  must_fix_before: verified_complete
```

### verified_complete 后必须做两件事

1. **清理 handoff**：删除该任务的 `handoff/TASK-<id>-HANDOFF.md` / `REPORT.md` / `REVIEW.md` 三件套。如需留历史，删除前手动复制存档。
2. **同步进度**：按 [`06-progress-sync.md`](../sync/06-progress-sync.md) 更新 `docs/versions/<ver>/更新日志.md` 中对应任务的状态，确保文档反映真实进度。

> 这两步缺一不可。只清理 handoff 不同步 docs，会导致文档与实际脱节；只同步 docs 不清理 handoff，会导致工作区堆积过期交接文件。

## Phase 6 — 推进到所有任务 verified_complete

重复 Phase 2–5，直到 `TASK-BOARD.md` 里所有任务 `status: verified_complete`。随后进入 [`03-e2e-acceptance.md`](./03-e2e-acceptance.md) 执行端到端集成验收。

E2E 通过（`done_e2e`）后，主会话执行**自动 commit**（Conventional Commits 格式），然后**停下**。不自动 tag，不自动进入 Release QA。

> 自动 commit 只在所有任务 `verified_complete` 且 E2E `done_e2e` 后执行一次。commit 后工作流暂停，等待用户显式指令（`/tag vX.Y.Z` 或明确说"发布版本"）才进入 Phase 8 Release QA。

如果同一任务被退回 ≥ 3 次仍未通过，停下，向用户报告：HANDOFF 可能本身有问题（goal 不可执行 / scope 错 / 验收项自相矛盾），请用户决策。
