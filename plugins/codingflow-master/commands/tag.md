---
description: "显式 tag 命令：触发 Phase 8 Release QA 审计 + git tag"
---

# /tag

用户执行 `/tag <version>` 显式触发版本发布流程。

## 前置条件

- 所有任务已 `verified_complete`
- E2E 验收已通过（`done_e2e`）
- 自动 commit 已执行
- 版本号符合 SemVer 格式 `vMAJOR.MINOR.PATCH`（无 rc/beta/alpha 后缀）

## 执行步骤

1. **校验版本号**：
   - 格式必须为 `^v[0-9]+\.[0-9]+\.[0-9]+$`
   - 不允许 rc/beta/alpha/pre/dev 后缀
   - 不符合 → 拒绝并提示正确格式

2. **前置条件检查**：
   - 确认 `handoff/TASK-BOARD.md` 中所有任务 `verified_complete`
   - 确认 E2E 已通过
   - 确认版本目录 `docs/versions/<version>/` 存在
   - 任一不满足 → 拒绝并报告缺失项

3. **Phase 8 — Release QA 审计**：阅读 `skills/orchestrator-workflow/07-release-qa-audit.md`
   - 审计范围：需求覆盖、端到端流程、构建与测试、代码质量、安全与隐私、数据与迁移、依赖与配置、文档一致性、已知问题、发布门禁
   - 基于实际文件和命令输出审计
   - 生成 `docs/qa/versions/<version>/QA-审计报告.md`

4. **判定**：
   - `qa_passed` → **先生成 `docs/versions/<version>/release.md`** → 再执行 `git tag <version>` → 同步版本状态
   - `qa_failed` → 不 tag，将问题拆成修复任务，回到开发闭环
   - `blocked` → 不 tag，向用户报告缺失输入

## Hook 安全网

即使主会话误试图直接执行 `git tag`，`pre-bash-gate.sh` 会检查：
1. 版本号格式
2. `docs/qa/versions/<version>/QA-审计报告.md` 是否存在
3. QA 报告结论是否为 `qa_passed`

任一不满足，tag 命令被拦截。

## 注意

- 只有用户显式指令才触发本流程
- 主会话不自动进入 Phase 8
- tag 后必须生成 `release.md`
