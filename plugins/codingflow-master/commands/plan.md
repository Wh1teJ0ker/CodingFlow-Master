---
description: "启动工作流：Phase 0 仓库审计/文档规划 + Phase 1 任务拆分"
---

# /plan

用户执行 `/plan <goal>` 启动编排工作流。

## 执行步骤

1. **Phase 0 — 仓库状态判断**：阅读 `skills/orchestrator-workflow/00-doc-planning.md`
   - 检测仓库是否为空（`git ls-files` 是否为空）
   - **空仓库** → 基于 `<goal>` 规划 `docs/` 文档体系（需求文档、技术设计、开发任务清单等）
   - **非空仓库** → 审计现有项目结构 → 构建或规范化 `docs/`
   - 创建 `versions/<ver>/` 版本目录（如用户指定了版本号）或使用默认 `v0.1.0`

2. **Phase 1 — 任务拆分**：阅读 `skills/orchestrator-workflow/01-task-decomposition.md`
   - 基于 `docs/03-开发任务清单.md` 或 `<goal>` 拆分任务 DAG
   - 写入 `handoff/TASK-BOARD.md`
   - 为每个就绪任务写 `handoff/TASK-<id>-HANDOFF.md`

3. **进入 Phase 2-6 循环**：阅读 `skills/orchestrator-workflow/02-dispatch-and-verify.md`
   - 按依赖顺序派 coder → 收报告 → 派 reviewer → 判定
   - 直到所有任务 `verified_complete`

4. **Phase 7 — E2E 验收**：阅读 `skills/orchestrator-workflow/03-e2e-acceptance.md`
   - 端到端集成验收
   - 通过后自动 commit（Conventional Commits）
   - **停下，不 tag**

5. 向用户报告完成状态，提示如需发布版本请执行 `/tag vX.Y.Z`

## 注意

- 不自动 tag，tag 需要用户显式指令
- 代码规范遵循 `skills/orchestrator-workflow/references/CODE-STANDARD.md`
