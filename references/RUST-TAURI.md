# Rust + Tauri 技术栈参考

本参考定义 Rust + Tauri 桌面应用在使用本 skill 模板时的技术栈约束。通用 Actions 与 Release 要求见 [`GITHUB-ACTIONS-STANDARD.md`](./GITHUB-ACTIONS-STANDARD.md) 与 [`RELEASE-STANDARD.md`](./RELEASE-STANDARD.md)。可复制模板位于 `../assets/project-templates/rust-tauri/`，非权威实例位于 `../examples/rust-tauri/`。

## 1. 适用范围

适用于 Tauri 2.x 桌面应用：前端（pnpm/npm/yarn）+ Rust 后端（`src-tauri/`）。本参考不绑定具体项目身份。

## 2. 工具链固定

- Node：通过变量指定固定主版本（如 22），启用 pnpm/npm 缓存并绑定 lockfile。
- pnpm：固定主版本（如 11），通过 `pnpm/action-setup` 安装。
- Rust：通过 `dtolnay/rust-toolchain` 指定具体版本（如 `1.81.0`）或固定到项目 `rust-toolchain.toml`；不得使用 `stable` 浮动 channel，因为它是随时间漂移的移动目标，并非真正固定。
- Rust 缓存：`Swatinem/rust-cache@v2`，`workspaces: src-tauri`，缓存键绑定目标三元组。
- 前端安装必须使用 `pnpm install --frozen-lockfile`，禁止修改 lockfile。

## 3. CI 质量门禁

CI 必须包含分层检查，发布构建依赖全部通过：

- frontend：lint、typecheck、test、build；
- rust：`cargo fmt --check`、`cargo clippy -D warnings`、`cargo check`、`cargo test`；
- 构建任务 `needs: [frontend, rust]`，不得与质量门禁并行后绕过。

Rust 命令统一使用 `--manifest-path src-tauri/Cargo.toml`，避免工作目录歧义。

## 4. 四目标构建矩阵

发布矩阵覆盖四个目标：

| 平台 | runner | target |
|---|---|---|
| Linux x64 | `ubuntu-latest` | `x86_64-unknown-linux-gnu` |
| macOS arm64 | `macos-latest` | `aarch64-apple-darwin` |
| macOS x64 | `macos-latest` | `x86_64-apple-darwin` |
| Windows x64 | `windows-latest` | `x86_64-pc-windows-msvc` |

- 矩阵使用 `fail-fast: false`。
- Rust toolchain 按 `matrix.target` 添加目标。
- 构建使用 `tauri-apps/tauri-action`，`args: --target ${{ matrix.target }}`。

## 5. Linux 系统依赖

Ubuntu runner 预装 `libappindicator3-dev` 与 Tauri 2 偏好的 `libayatana-appindicator3-dev` 冲突。二者必须二选一，禁止混装。模板默认采用 ayatana 方案：

```sh
sudo apt-get remove -y libappindicator3-dev libappindicator3-1 || true
sudo apt-get install -y \
  libwebkit2gtk-4.1-dev \
  librsvg2-dev \
  patchelf \
  libssl-dev \
  libgtk-3-dev \
  libayatana-appindicator3-dev
```

- 若项目改用 `libappindicator3-dev`，必须移除 ayatana 并在变量清单中注明选择。
- `libwebkit2gtk-4.1-dev` 对应 Tauri 2；Tauri 1 使用 `4.0`，二者不可混用。
- Linux 依赖步骤通过 `if: matrix.os == 'ubuntu-latest'` 或 `runner.os == 'Linux'` 限定。

## 6. 版本源与一致性

- 版本源为 `src-tauri/tauri.conf.json` 的 `version` 字段。
- Release 流程必须校验 Git tag（去 `v` 前缀）与 `tauri.conf.json` version 一致。
- 不得在 `package.json`、`Cargo.toml`、`tauri.conf.json` 各自手工维护可能漂移的版本。
- `更新日志.md` 路径通过版本号动态注入，模板不得写死具体版本文档路径。

## 7. Updater 与签名（可选）

- Tauri updater 为可选能力，启用时必须：
  - 配置 `TAURI_SIGNING_PRIVATE_KEY` 与 `TAURI_SIGNING_PRIVATE_KEY_PASSWORD` 命名 secret；
  - `tauri-action` 启用 `uploadUpdaterJson: true`；
  - updater JSON 仅在 finalize 后生效，draft 期间不迁移 `latest` 指针。
- macOS 签名/公证、Windows 代码签名为可选扩展，启用时密钥只通过 secret 引用。
- 未启用签名时，模板与实例必须明确声明未签名及平台警告影响。

## 8. Windows portable（可选）

- 可选产出 portable 二进制，使用 `tauri-action` 的 `uploadPlainBinary: true` 与 `args: --no-bundle`。
- portable 命名使用 `_portable` 后缀，与正式安装包区分。
- portable 不替代签名安装包作为推荐产物。

## 9. Draft 与 Finalize

遵循 [`RELEASE-STANDARD.md`](./RELEASE-STANDARD.md) 第 4 节：

1. 校验 tag 与 `tauri.conf.json` 版本一致；
2. 校验 Release QA 状态；
3. 创建 draft Release；
4. 四目标矩阵构建上传；
5. 生成 checksums；
6. 全部成功后 finalize job 改为正式发布，只允许稳定版 `vMAJOR.MINOR.PATCH` tag。

`contents: write` 仅授予创建/更新 Release 与 finalize job。

## 10. 模板变量

模板变量登记于 `../assets/project-templates/rust-tauri/TEMPLATE-VARIABLES.md`，至少包括：

- `{{PROJECT_NAME}}`、`{{NODE_VERSION}}`、`{{PNPM_VERSION}}`、`{{RUST_TARGETS}}`
- `{{LINUX_DEPENDENCY_VARIANT}}`（ayatana 或 appindicator3）
- `{{CHANGELOG_PATH}}`、`{{TAURI_ACTION_VERSION}}`
- `{{ENABLE_UPDATER}}`、`{{ENABLE_PORTABLE}}`、`{{ENABLE_SIGNING}}`

变量在 CI 与 Release 中含义一致，实例中替换为脱敏示例值。

## 11. 禁止项

- 可变引用（`latest`、`stable`、`master`、`main`）作为工具或 action 版本；
- Linux indicator 依赖混装；
- 顶层 `contents: write`；
- finalize 早于四目标与质量门禁完成；
- 模板写死项目身份、真实密钥、绝对路径或固定版本文档路径。
