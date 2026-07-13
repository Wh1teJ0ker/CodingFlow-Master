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
  - pnpm install --frozen-lockfile=false
  - pnpm tauri build --debug 2>&1 | tail -5  # 整体可构建
  - pnpm test  # 全量单元测试绿
  - pnpm tauri dev &  # 启动后人工走 happy path
```

看命令输出，失败就如实报。关键命令未跑不能宣称 `done_e2e`。

### Step 3 — 判定

- **全绿** → `done_e2e`
  1. 记录端到端验收证据
  2. 进入 [`07-release-qa-audit.md`](./07-release-qa-audit.md) 执行版本级 Release QA 审计
  3. 注意：`done_e2e` 只表示集成验收通过，**不允许直接删除 `TASK-BOARD.md` 或把版本标为已发布**

- **有失败** → 定位是哪个任务的集成缺陷，开新 HANDOFF（新任务 id，`depends_on` 涉及的任务）回 Phase 2
  - 集成缺陷不是单任务验收能发现的跨任务问题，必须开新任务修
  - 修复后重跑端到端验收

## e2e 验收检查清单

在宣称 `done_e2e` 前，逐项确认：

- [ ] `e2e_acceptance` 每一条都通过，有证据（命令输出 / 截图 / 测试结果）
- [ ] `e2e_verification` 命令全部运行且全绿
- [ ] 未跳过任何验收项
- [ ] 未在"基本能用"时放行
- [ ] `docs/` 下文档已反映最终实现状态
- [ ] 已进入或计划进入版本级 Release QA 审计；未生成 `docs/qa/versions/<ver>/QA-审计报告.md` 前不标记版本发布
- [ ] 单任务 handoff 三件套已清理；`TASK-BOARD.md` 可保留到 QA 通过后的版本同步阶段再删除

## 禁止行为

- ❌ 在没跑端到端验收的情况下宣称整体完成
- ❌ 在 e2e 验收失败时跳过失败项只报通过的
- ❌ 在 e2e 验收未通过时宣称 `done_e2e`
- ❌ 在 e2e 验收通过后跳过 Release QA，直接同步 docs 版本发布状态
