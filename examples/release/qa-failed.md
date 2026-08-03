# v0.2.0 Release QA 审计报告（实例：qa_failed）

> 非权威实例，仅展示 `qa_failed` 时 major 问题回流 HANDOFF 且版本保持未发布的正确处理。项目名为脱敏占位 `myapp`，不代表任何真实项目。

## 审计范围

- 版本号：v0.2.0
- 审计日期：2026-07-14
- 审计人：主会话
- 审计基线提交：a1b2c3d4

## 触发场景

端到端验收通过（`done_e2e`）后执行 Release QA 审计，发现一个 major 问题：版本一致性检查显示 Git tag `v0.2.0` 与应用版本源 `0.1.0` 不一致，且 macOS arm64 产物在 Release workflow 中构建失败。

## 证据核对

| 检查项 | 期望 | 实际证据 | 结论 |
|---|---|---|---|
| 所有任务 verified_complete | 全部 verified_complete | TASK-BOARD 全部 verified_complete | PASS |
| 端到端集成验收 | done_e2e | E2E 命令退出码 0 | PASS |
| 版本文档同步 | 文档已更新 | 已更新 | PASS |
| 版本一致性 | v0.2.0 一致 | tag=v0.2.0，版本源=0.1.0，不一致 | FAIL |
| CI 通过 | 全绿 | macOS arm64 build job 失败 | FAIL |
| 构建产物 | 全平台产物存在 | macOS arm64 产物缺失 | FAIL |
| 完整性校验 | checksums 生成 | 因构建失败未生成 | FAIL |
| 签名/公证 | 已配置或声明 | 明确声明未签名 | PASS |

## 发现的问题

| 编号 | 严重度 | 描述 | 状态 |
|---|---|---|---|
| F1 | major | 版本源未从 0.1.0 更新到 0.2.0，与 tag 不一致 | open |
| F2 | major | macOS arm64 构建失败，产物缺失 | open |

## 处理动作

1. **审计结论 `qa_failed`**：存在 2 个 major 未解决问题，禁止 finalize，禁止公开发布。
2. **回流修复**：为 F1、F2 创建新 HANDOFF 任务（TASK-T7 修正版本源、TASK-T8 修复 macOS arm64 构建），分派 coder 修复。
3. **修复后重跑**：coder 修复并自验 -> reviewer 审查 -> 主会话判定 verified_complete -> 重新执行端到端验收（`done_e2e` 必须重跑）。
4. **重新审计**：修复闭环后，更新本报告为同一文件 `docs/qa/versions/v0.2.0/QA-审计报告.md`，重新核对证据。若全部通过，结论改为 `qa_passed`。
5. **版本状态保持**：`docs/04-版本标准.md` 与 `更新日志.md` 不得标记为已发布；保持 `qa_failed` 直到重新审计通过。

## 审计结论

| 项 | 值 |
|---|---|
| 结论 | qa_failed |
| 阻塞问题数 | 2 |
| 是否允许发布 | 否 |
| 公开 Release | 无（draft 未创建，或 draft 保持 draft 状态未 finalize） |
| 后续 | 回流 TASK-T7/T8，修复后重跑 E2E 并重新审计 |
