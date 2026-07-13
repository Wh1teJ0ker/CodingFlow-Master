# 06 — 文档进度同步机制

> 本文件解决"文档状态与实际进度脱节"问题。主会话在每次单任务完成、版本级 Release QA 通过后、或发现文档与实际脱节时阅读并执行本文件。

## 问题背景

文档脱节的典型表现：
- `handoff/TASK-BOARD.md` 显示任务已 `verified_complete`
- 但 `docs/versions/<ver>/更新日志.md` 仍标 `🔲 待启动`
- 代码已大量存在，文档却停留在规划态
- `handoff/` 下堆积已通过验收的交接文件未清理

根因：skill 之前只规定了"任务完成后删 handoff"，但没有规定"任务完成后同步 docs 进度"，导致 docs 更新日志永远滞后。

## 同步时机（三个必须同步的节点）

### 节点 1：单任务 verified_complete 后

在 [`02-dispatch-and-verify.md`](./02-dispatch-and-verify.md) Phase 5 判定 `verified_complete` 后，除了删除 handoff 三件套，**必须**同步更新对应版本的更新日志。

具体操作：
1. 找到该任务所属版本的 `docs/versions/<ver>/更新日志.md`
2. 在进度表中把该任务的状态从 `🔲 待启动` 改为 `✅ 已完成`
3. 在备注栏填入完成日期或关键产出
4. 更新 `TASK-BOARD.md` 中该任务状态为 `verified_complete`

### 节点 2：版本 Release QA 通过后

在 [`03-e2e-acceptance.md`](./03-e2e-acceptance.md) Phase 7 判定 `done_e2e` 后，还必须先执行 [`07-release-qa-audit.md`](./07-release-qa-audit.md)。只有 `docs/qa/versions/<ver>/QA-审计报告.md` 已生成且结论为 `qa_passed` 后，才允许同步版本级完成 / 发布状态：

1. 更新 `docs/versions/<ver>/更新日志.md`：
   - 顶部状态从 `🔲 待发布` 改为 `✅ 已发布`（或 `已完成`）
   - 填写验收记录段，并引用 `docs/qa/versions/<ver>/QA-审计报告.md`
   - 补充已知问题（如有）
2. 更新 `docs/04-版本标准.md`：
   - 该版本里程碑标记完成日期
   - 记录 QA 报告路径或审计结论
3. 删除 `handoff/TASK-BOARD.md`

### 节点 3：发现脱节时（修复性同步）

当主会话在任何时候发现文档与实际状态不符（例如用户指出、reviewer 发现、或自检时发现），**必须立即执行修复性同步**：

1. 读取 `handoff/TASK-BOARD.md`（如存在）获取真实任务状态
2. 若 `handoff/TASK-BOARD.md` 不存在但 `handoff/` 下有交接文件，从各 `TASK-<id>-REPORT.md` 的 `reported_status` 推断真实状态
3. 若 `handoff/` 已全部清理，检查实际代码结构（`src/`、`src-tauri/`、测试文件）推断真实进度
4. 将推断结果与 `docs/versions/<ver>/更新日志.md` 对比
5. 修正所有不一致项
6. 清理应删未删的 handoff 文件

## 更新日志状态标记规范

进度表使用以下标记：

| 标记 | 含义 | 对应 TASK-BOARD 状态 |
|------|------|---------------------|
| `🔲 待启动` | 未开始 | `planned` |
| `🔄 进行中` | coder 或 reviewer 处理中 | `in_progress` / `in_review` |
| `⚠️ 受阻` | 被卡住 | `blocked` |
| `✅ 已完成` | 单任务通过验收 | `verified_complete` |
| `🔁 退回修复` | reviewer 退回 | `review_rejected` |

版本级状态：

| 标记 | 含义 |
|------|------|
| `🔲 待发布` | 版本未开始或进行中 |
| `✅ 已发布` | 版本 done_e2e 且 Release QA `qa_passed` |

## 同步检查清单

每次同步后，逐项确认：

- [ ] `docs/versions/<ver>/更新日志.md` 进度表与 `handoff/TASK-BOARD.md`（或实际代码）状态一致
- [ ] 已 `verified_complete` 的任务在更新日志中标 `✅ 已完成`
- [ ] 已 `done_e2e` 且 QA `qa_passed` 的版本在更新日志顶部标 `✅ 已发布`
- [ ] 对应 QA 报告存在于 `docs/qa/versions/<ver>/QA-审计报告.md` 且结论为 `qa_passed`
- [ ] 已通过验收的任务 handoff 三件套已删除
- [ ] 已 QA 通过并同步版本状态的 `handoff/TASK-BOARD.md` 已删除
- [ ] `docs/` 下没有"比代码更乐观"的描述（即文档不能声称未实现的功能已完成）

## 自检命令

主会话可随时运行以下检查，判断是否需要执行修复性同步：

```
1. 对比 handoff/TASK-BOARD.md 中各任务 status 与 docs/versions/*/更新日志.md 进度表
2. 若 TASK-BOARD 显示 verified_complete 但更新日志显示待启动 → 需同步
3. 若 handoff/ 下存在任务三件套但 TASK-BOARD 显示该任务 verified_complete → 需清理
4. 若 handoff/ 下存在 TASK-BOARD.md 但所有任务已 verified_complete → 需继续做 e2e；若已 done_e2e 则继续做 Release QA；只有 QA 通过并同步版本状态后才清理
```

## 禁止行为

- ❌ 任务 verified_complete 后只删 handoff 不同步更新日志
- ❌ 端到端验收通过但 Release QA 未通过时，把版本状态写成已完成 / 已发布
- ❌ 版本 QA 通过后不同步版本状态
- ❌ 发现文档与实际脱节时继续推进新任务而不先修复
- ❌ 在文档中写"已完成"但实际代码不存在对应实现
- ❌ 在文档中写"待启动"但实际代码已大量存在
