# v0.2.0 Release QA 审计报告（实例：blocked）

> 非权威实例，仅展示缺少关键证据或凭据时禁止发布的 `blocked` 处理。项目名为脱敏占位 `myapp`，不代表任何真实项目。

## 审计范围

- 版本号：v0.2.0
- 审计日期：2026-07-14
- 审计人：主会话
- 审计基线提交：a1b2c3d4

## 触发场景

所有任务 `verified_complete`、端到端验收通过（`done_e2e`），但 Release QA 审计时发现：项目要求 macOS 代码签名与公证，而签名证书与公证凭据未配置到 CI secret；同时 Release workflow 无法访问受保护的 `release` environment。

## 证据核对

| 检查项 | 期望 | 实际证据 | 结论 |
|---|---|---|---|
| 所有任务 verified_complete | 全部 verified_complete | TASK-BOARD 全部 verified_complete | PASS |
| 端到端集成验收 | done_e2e | E2E 命令退出码 0 | PASS |
| 版本文档同步 | 文档已更新 | 已更新 | PASS |
| 版本一致性 | v0.2.0 一致 | tag / 版本源 / 文档目录一致 | PASS |
| CI 通过 | 全绿 | CI 通过 | PASS |
| 构建产物 | 全平台产物存在 | 产物存在 | PASS |
| 完整性校验 | checksums 生成 | checksums 已生成 | PASS |
| 签名/公证 | 已配置凭据 | 证书与公证 secret 缺失；release environment 未配置 | BLOCKED |

## 发现的问题

| 编号 | 严重度 | 描述 | 状态 |
|---|---|---|---|
| B1 | critical | macOS 签名证书 secret 未配置，无法完成签名 | open |
| B2 | critical | notarization 凭据未配置，无法公证与 stapling | open |
| B3 | major | `release` environment 未在 GitHub 配置，无法保护发布凭据 | open |

## 处理动作

1. **审计结论 `blocked`**：缺少关键凭据与环境保护，禁止 finalize，禁止公开发布。
2. **不回流代码修复**：这不是代码缺陷，而是环境与凭据缺失。问题不在 coder 范围，由维护者补齐凭据与 environment 配置。
3. **版本状态保持**：`docs/04-版本标准.md` 与 `更新日志.md` 不得标记为已发布；保持 `blocked`。
4. **补齐后重审**：维护者配置证书 secret、公证凭据、`release` environment 后，重新执行 Release QA 审计，更新本报告。若全部通过，结论改为 `qa_passed`，再进入发布同步。
5. **未签名不得作为临时方案**：项目已声明要求签名，不得在 `blocked` 期间跳过签名直接发布。如改变策略为“允许未签名”，必须先更新规范与 README，再重新审计。

## 审计结论

| 项 | 值 |
|---|---|
| 结论 | blocked |
| 阻塞问题数 | 3 |
| 是否允许发布 | 否 |
| 公开 Release | 无 |
| 后续 | 维护者补齐凭据与 environment，再重新审计 |
