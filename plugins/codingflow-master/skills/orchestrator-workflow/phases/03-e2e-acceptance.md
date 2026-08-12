# 03 — Phase 7: 端到端集成验收

> 所有单任务 verified_complete 后，主会话阅读本文件执行最终验收。

## 核心原则

单任务全过 ≠ 整体完成。最后必须跑一次端到端验收（`TASK-BOARD.md` 里的 `e2e_acceptance` + `e2e_verification`）。

端到端验收关注的是**跨任务集成问题**——单个任务验收时无法发现的缺陷：
- 任务 A 的输出格式与任务 B 的输入期望不匹配
- 多个任务的副作用叠加产生意外行为
- 完整用户流程（happy path）走通时暴露的衔接缺口

## 验收步骤

### Step 1 — 串联 happy path

把所有切片串起来跑一遍完整用户流程。对照 `TASK-BOARD.md` 的 `e2e_acceptance` 逐条验证。

### Step 2 — 跑 e2e_verification 命令

```yaml
e2e_verification:
  - <安装依赖命令>    # 按项目实际包管理器执行
  - <构建命令>        # 整体可构建，保留完整输出或可审计日志
  - <全量测试命令>    # 全量单元测试绿
  - <启动命令>        # 前台启动后人工走 happy path，记录停止方式与关键观察
```

看命令输出，失败就如实报。关键命令未跑不能宣称 `done_e2e`。不要为"看起来简洁"而截断关键输出，也不要把需要人工终止的验证命令静默放到后台执行。

### Step 3 — 判定

- **全绿** → `done_e2e`
  1. 记录端到端验收证据
  2. **自动 commit**（Conventional Commits 格式，如 `feat: complete <version> milestone tasks` 或更具体的 scope 描述）
  3. commit 后**停下**。不自动 tag，不自动进入 Release QA。
  4. 向用户报告：所有任务已完成，E2E 验收通过，已自动 commit。如需发布版本，请显式指令 `/tag vX.Y.Z`。
  5. 注意：`done_e2e` 只表示集成验收通过。**不允许直接删除 `TASK-BOARD.md` 或把版本标为已发布**。`TASK-BOARD.md` 保留到 Phase 8 Release QA 通过且版本状态同步后再删除。

- **有失败** → 定位是哪个任务的集成缺陷，开新 HANDOFF（新任务 id，`depends_on` 涉及的任务）回 Phase 2
  - 集成缺陷不是单任务验收能发现的跨任务问题，必须开新任务修
  - 修复后重跑端到端验收

## 自动 commit 规则

`done_e2e` 后的自动 commit 遵循以下规则：

1. **commit message 格式**：Conventional Commits（`type(scope): subject`），由 PreToolUse hook 强制校验
2. **commit 粒度**：一次 commit 包含本轮所有任务的全部改动（而非每个任务单独 commit —— 单任务 commit 在 Phase 2-5 由 coder/reviewer 流程中已处理）
3. **不 tag**：commit 后不执行 `git tag`。tag 是 Phase 8 的显式触发动作
4. **不清理 TASK-BOARD**：`handoff/TASK-BOARD.md` 保留，供 Phase 8 Release QA 审计参考

> Hook 层安全网：即使主会话误试图在此时 `git tag`，`pre-bash-gate.sh` 会因缺少 `qa_passed` 的 QA 报告而拦截。

## e2e 验收检查清单

在宣称 `done_e2e` 前，逐项确认：

- [ ] `e2e_acceptance` 每一条都通过，有证据（命令输出 / 截图 / 测试结果）
- [ ] `e2e_verification` 命令全部运行且全绿
- [ ] 未跳过任何验收项
- [ ] 未在"基本能用"时放行
- [ ] `docs/` 下文档已反映最终实现状态
- [ ] 自动 commit 已执行（Conventional Commits 格式）
- [ ] 未执行 `git tag`（tag 留给 Phase 8 显式触发）
- [ ] 单任务 handoff 三件套已清理；`TASK-BOARD.md` 保留到 Phase 8 QA 通过后

## 禁止行为

- 在没跑端到端验收的情况下宣称整体完成
- 在 e2e 验收失败时跳过失败项只报通过的
- 在 e2e 验收未通过时宣称 `done_e2e`
- 在 e2e 验收通过后自动 tag 或自动进入 Release QA
- 在 e2e 验收通过后直接同步 docs 版本发布状态
- 在用户显式指令 tag 前执行 `git tag`
