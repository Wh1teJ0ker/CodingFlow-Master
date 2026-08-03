# GitHub Actions 通用规范

本规范定义本 skill 提供的所有 CI / Release workflow 模板必须满足的通用要求。技术栈相关要求见 [`RUST-TAURI.md`](./RUST-TAURI.md) 与 [`GO-WAILS.md`](./GO-WAILS.md)；发布流程要求见 [`RELEASE-STANDARD.md`](./RELEASE-STANDARD.md)。可复制模板位于 `../assets/project-templates/`，非权威实例位于 `../examples/`。

## 1. 通用原则

- 模板使用通用占位符，不嵌入项目身份、真实密钥、绝对路径或固定版本文档路径。
- 禁止使用 `latest`、`master`、`main`、`stable` 等可变引用；Action 使用固定主版本或受审计 commit SHA，工具版本通过变量或受控文件指定。
- workflow YAML 必须能被标准 YAML 解析器加载；GitHub 表达式与占位符不得破坏可解析性。
- 实例是说明性产物，不替代规范；实例必须显式声明非权威。
- CI 成功不等于 `verified_complete`，不等于 `done_e2e`，更不等于 `qa_passed`。Actions 门禁只提供自动化证据，不能替代 Release QA 审计报告。

## 2. 触发分层

区分三类工作流，职责不可混用：

| 工作流 | 触发 | 目的 | 默认权限 |
|---|---|---|---|
| CI | `pull_request`、`push` 到默认分支、可选 `workflow_dispatch` | 验证质量，不发布 | `contents: read` |
| Release | 仅 `push` 到 `v*` 语义化 tag | 构建产物并发布 | 顶层 `contents: read`，仅发布 job 提升 `contents: write` |
| 可选快照 | `workflow_dispatch` 手动 | 产出临时产物供测试，不发布 | `contents: read` |

要求：

- CI 必须覆盖 PR 触发，避免未检查变更合入。
- Release 不得由普通 `push` 到分支触发。
- fork PR 不得访问仓库 secret；如需在 fork PR 中运行需要依赖的步骤，应使用 `pull_request_target` 并严格限定 checkout 的 ref，默认不使用。
- tag 触发模式应在 shell 步骤中再次校验语义化版本格式，GitHub glob 匹配能力有限。

## 3. 最小权限

- workflow 顶层默认 `permissions: contents: read`，或显式声明所需只读权限。
- `contents: write` 只授予实际创建或更新 GitHub Release 的 job，不授予构建 job。
- 不使用 `permissions: write-all`。
- `GITHUB_TOKEN` 通过 `secrets.GITHUB_TOKEN` 引用，不硬编码。
- 发布签名、公证等密钥通过命名 secret 引用，模板中只出现 secret 名占位符，不得出现真实值。

## 4. 并发与超时

- CI 使用 `concurrency` 取消同一分支的旧运行：

  ```yaml
  concurrency:
    group: ci-${{ github.ref }}
    cancel-in-progress: true
  ```

- Release 使用分组但不取消，避免半成品发布：

  ```yaml
  concurrency:
    group: release-${{ github.ref }}
    cancel-in-progress: false
  ```

- 每个 job 设置合理 `timeout-minutes`，避免卡死占用 runner。

## 5. 缓存与锁文件

- 包管理器安装必须使用锁文件确定性命令：
  - npm：`npm ci`
  - pnpm：`pnpm install --frozen-lockfile`
  - yarn：`yarn install --immutable`
- Go 使用 `go-version-file: go.mod` 或固定版本，并启用模块缓存。
- Rust 启用 `Swatinem/rust-cache` 等缓存，缓存键绑定 lockfile 与目标三元组。
- 前端缓存键绑定对应 lockfile，避免跨包管理器误命中。
- 不得使用会修改锁文件的安装命令作为 CI 步骤。

## 6. Action 与工具版本策略

- 第三方 Action 使用固定主版本（如 `@v4`），高安全项目可改为受审计 commit SHA。
- 禁止 `latest`、`master`、`main` 等可变引用作为 action 版本。
- 工具版本通过 workflow 变量或受控文件注入，不在多个 job 间重复硬编码不同值。
- Wails CLI 必须固定到与 `go.mod` 中 Wails 库一致的版本，不得使用可变引用。
- Go 不得使用 `stable` 浮动版本，应来自 `go.mod` 或固定版本。

## 7. 构建矩阵

- 矩阵显式列出每个目标三元组与 runner，不依赖隐式默认。
- `fail-fast: false` 用于发布矩阵，确保单平台失败不掩盖其他平台问题。
- CI 质量门禁 job 必须是发布 job 的依赖，发布不得与质量门禁并行后绕过。
- 平台系统依赖在对应 `if: runner.os == 'Linux'` 等条件下安装，命令可复制。

## 8. 产物与校验

- 产物上传使用 `actions/upload-artifact@v4`，名称包含平台与架构，便于跨 job 聚合。
- 发布前生成 SHA-256 校验文件，随 Release 一并上传。
- macOS `.app` 使用 `ditto` 归档为 zip，保留权限与目录结构。
- Linux 与 Windows 产物按规范命名打包，不直接上传裸可执行文件作为正式发布产物。
- 产物存在性必须在 finalize 前验证。

## 9. Draft 与 Finalize 顺序

发布必须遵循：

1. 校验 tag 与应用版本一致；
2. 校验 Release QA 状态证据；
3. 创建 draft Release；
4. 全平台矩阵构建并上传产物；
5. 生成并上传 checksums；
6. 所有质量门禁与全平台构建成功后，单独 job 执行 finalize，将 draft 改为正式发布。

finalize job 不得在任一上游 job 失败时执行，应使用 `if: ${{ needs.<job>.result == 'success' && ... }}` 显式约束。draft 状态保证 `latest` 指针在发布完成前不迁移。

## 10. 状态语义对照

| Actions 信号 | skill 状态 | 含义 |
|---|---|---|
| CI 全绿 | 无直接映射 | 仅表示自动化检查通过 |
| 所有任务 verified_complete + E2E 通过 | `done_e2e` | 集成验收通过，仍不可发布 |
| Release QA 报告 `qa_passed` | `qa_passed` | 版本可进入发布同步 |
| 公开 Release finalize 成功 + 版本文档同步 | `release_complete` | 真正完成 |

`qa_failed` 与 `blocked` 禁止 finalize，禁止将 draft 改为正式发布。

## 11. 模板变量约定

- workflow 模板使用 `{{UPPER_SNAKE_CASE}}` 占位符，并在同目录 `TEMPLATE-VARIABLES.md` 中逐一登记。
- 占位符不得表示真实 secret 值，只表示变量名或可替换结构。
- 同一变量在 CI 与 Release 模板中含义一致。
- 实例中占位符应被替换为脱敏示例值，不得保留 `{{...}}` 残留，也不得泄漏参考项目身份。

## 12. 禁止项

- 可变引用（`latest`、`stable`、`master`、`main`）作为工具或 action 版本；
- 顶层 `contents: write`；
- `permissions: write-all`；
- 在普通 push 到分支时创建或更新 Release；
- 在 fork PR 中暴露 secret；
- 跳过 finalize 门禁直接发布；
- 用 CI 成功替代 Release QA；
- 模板中出现参考项目身份、绝对本机路径、真实密钥或固定版本文档路径（如写死某个 `docs/versions/vX.Y.Z` 路径）。
