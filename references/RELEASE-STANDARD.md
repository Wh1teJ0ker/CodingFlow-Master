# Release 通用规范

本规范定义版本发布流程必须满足的通用要求。GitHub Actions 层面的执行约束见 [`GITHUB-ACTIONS-STANDARD.md`](./GITHUB-ACTIONS-STANDARD.md)；Release QA 审计流程见编排过程的 [`../07-release-qa-audit.md`](../07-release-qa-audit.md)。版本文档模板与三类闭环实例位于 `../assets/project-templates/release-docs/` 与 `../examples/release/`。

## 1. 版本号

- 应用版本采用稳定版语义化版本 `MAJOR.MINOR.PATCH`，例如 `0.1.0`。
- Git tag 格式为 `vMAJOR.MINOR.PATCH`，例如 `v0.1.0`。
- 禁止 `-rc`、`-beta`、`-alpha` 等任何预发布后缀；本 skill 只接受数字三段式正式版本。
- tag 创建前应再次校验格式，GitHub glob 匹配能力有限。

## 2. 唯一版本源

每个版本必须有一个权威版本源，其余位置同步自它：

- Rust + Tauri：`tauri.conf.json` 的 `version` 字段（或 `package.json` / `Cargo.toml`，二选一并固定）。
- Go + Wails：`wails.json` 的 `info.productVersion`，或 linker 注入的 `buildinfo.Version`。

要求：

- 应用版本、Git tag（去掉 `v` 前缀）、发布产物命名、版本文档目录必须一致。
- CI/Release 流程必须包含版本一致性检查步骤，不一致时 fail。
- 不得存在多个手工维护、可能漂移的版本常量。

## 3. 发布前置门禁

发布前必须依次满足：

1. 所有任务 `verified_complete`；
2. 端到端集成验收通过，状态 `done_e2e`；
3. Release QA 审计通过，`docs/qa/versions/<ver>/QA-审计报告.md` 结论为 `qa_passed`；
4. 版本文档（`规划需求.md`、`更新日志.md`，可选 `技术方案.md`）已同步；
5. tag 已打在已验证的提交上；
6. 必要的签名/公证凭据与环境已就绪，否则状态为 `blocked`。

CI 全绿、构建成功、产物存在都不足以单独放行发布。

## 4. Draft 与 Finalize

- 先创建 draft Release，避免 `latest` 指针提前迁移。
- 全平台矩阵构建并上传产物后，生成 SHA-256 checksums。
- 仅在所有质量门禁与全平台构建成功后，由独立 finalize job 将 draft 改为正式发布。
- finalize 必须显式依赖全部上游 job 成功，失败任一即不执行。
- 正式发布只面向稳定版 `vMAJOR.MINOR.PATCH` tag；不得通过预发布 tag 绕过正式发布门禁。

## 5. 产物命名

统一格式：

```text
{{PROJECT_NAME}}_{{VERSION}}_{{PLATFORM}}_{{ARCH}}.{{EXT}}
```

示例（实例值，非模板）：

```text
myapp_0.1.0_linux_amd64.tar.gz
myapp_0.1.0_windows_amd64.zip
myapp_0.1.0_macos_universal.zip
checksums.txt
```

要求：

- 模板使用 `{{PROJECT_NAME}}`、`{{VERSION}}` 等占位符，不写死项目名。
- 平台与架构使用小写规范名：`linux`、`windows`、`macos`、`amd64`、`arm64`、`universal`。
- 产物扩展名与归档方式一致：Linux 用 `.tar.gz`，Windows 用 `.zip` 或安装包，macOS 用 `.zip` 或 `.dmg`。

## 6. 完整性校验

- 每个 Release 必须附 SHA-256 checksums 文件。
- checksums 文件列出每行 `<sha256>  <filename>`。
- 推荐同时提供签名（cosign、GPG 或平台签名），签名作为可选扩展。

## 7. 签名与公证

签名/公证是可选扩展能力，但若启用必须满足：

- 密钥通过命名 secret 引用，不硬编码。
- macOS 启用 hardened runtime、entitlements、notarization 与 stapling。
- Windows 使用代码签名证书；无证书时必须明确声明未签名及 SmartScreen 影响。
- Tauri updater 签名密钥单独管理，启用时必须同时配置 updater JSON 上传。
- 缺少必要凭据时，发布状态为 `blocked`，不得跳过签名直接发布。

## 8. 失败与重跑

- 单平台构建失败不阻塞其他平台（`fail-fast: false`）。
- finalize 不执行，Release 保持 draft。
- 修复后重跑对应平台 job，产物覆盖更新。
- 已 finalize 的正式发布如需撤回，应使用 GitHub Release 的 delete/convert-to-draft，不得静默删除 tag 造成历史不一致。
- 重跑必须保持产物命名与版本一致，避免产生重复或冲突资产。

## 9. 状态语义

| 状态 | 含义 | 是否可发布 |
|---|---|---|
| `done_e2e` | 端到端验收通过 | 否 |
| `qa_passed` | Release QA 审计通过，可进入发布同步 | 允许进入 finalize |
| `qa_failed` | 发现 major/critical 问题，需回流修复 | 否 |
| `blocked` | 缺少证据、凭据或环境能力 | 否 |
| `release_complete` | finalize 成功 + 版本文档同步完成 | 已发布 |

`qa_failed` 与 `blocked` 禁止任何形式的 finalize 或公开发布声明。

## 10. Release 文案与版本文档写法

对外发布文案应保持简洁，重点回答两件事：

1. 这个版本是什么；
2. 这个版本更新了什么。

默认推荐 `docs/versions/<ver>/更新日志.md` 至少包含：

- 版本号；
- 一段简短版本摘要；
- 更新内容（新增 / 修复 / 调整）；
- 当前状态；
- 公开 Release 链接（如已发布）。

只有真实发生且对用户有意义的内容才写入对外更新日志。不要把内部试验、未发布能力、计划中事项或纯内部过程噪音写成“已交付变更”。

发布完成后仍必须同步：

- `docs/04-版本标准.md`：里程碑索引与版本状态。
- `docs/versions/<ver>/更新日志.md`：版本摘要与最终状态。
- `docs/qa/versions/<ver>/QA-审计报告.md`：审计结论。
- 项目 README 的当前版本与发布产物信息。

文档不得先于实际发布声明“已发布”；冲突时以真实验证证据和 QA 报告为准。

## 11. 禁止项

- 跳过 Release QA 直接发布；
- 用 CI 成功或产物存在替代 QA 通过；
- 多个手工版本源互相漂移；
- 顶层 workflow `contents: write`；
- finalize 早于全部门禁；
- 在更新日志或 GitHub Release 中写入未验证、未发布或计划中的能力；
- 用空泛宣传语替代实际更新内容；
- 模板中写死项目身份、真实密钥、绝对路径或固定版本文档路径。
