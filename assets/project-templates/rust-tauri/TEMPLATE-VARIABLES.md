# Rust + Tauri 模板变量清单

本文件登记 `rust-tauri/` 模板中使用的全部占位符。CI 与 Release 模板共享同一变量含义。实例（`examples/rust-tauri/`）中占位符应替换为脱敏示例值，不得保留占位符残留，也不得泄漏参考项目身份。

## 占位符约定

模板中标量位置的占位符使用 `<REPLACE:NAME>` 形式并用引号包裹，保证 YAML 可解析。复制到目标项目后，将 `<REPLACE:NAME>` 替换为真实值，引号可保留或去掉。`run` 脚本内的占位同样使用引号包裹的 `<REPLACE:NAME>`。

> 不使用 `{{NAME}}` 形式作为 YAML 标量占位符，因为裸花括号会破坏 YAML 可解析性。可选能力的整行配置（如 updater 签名 secret）以注释形式提供，启用时取消注释，而非用占位符表示整行键值对。

## 通用变量

| 变量 | 含义 | 示例值（脱敏） |
|---|---|---|
| `<REPLACE:NODE_VERSION>` | Node 主版本 | `22` |
| `<REPLACE:PNPM_VERSION>` | pnpm 主版本 | `11` |
| `<REPLACE:RUST_VERSION>` | Rust 工具链具体版本，不得用 `stable` 浮动 channel | `1.81.0` |

> 更新日志路径不使用静态占位符，而是由 Release workflow 的 validate job 从 tag 提取版本号后注入：`docs/versions/${{ needs.validate.outputs.version }}/更新日志.md`。模板不写死具体版本。

## Linux 依赖变量

| 变量 | 含义 | 可选值 |
|---|---|---|
| `<REPLACE:LINUX_INDICATOR_PACKAGE>` | Linux appindicator 依赖包，二选一，禁止混装 | `libayatana-appindicator3-dev`（默认）或 `libappindicator3-dev` |

> 选择 `libappindicator3-dev` 时，必须移除 workflow 中的 `remove -y libappindicator3-dev` 步骤，否则会自相矛盾。

## 可选能力变量

| 变量 | 含义 | 示例值（脱敏） |
|---|---|---|
| `PROJECT_NAME` | 项目名称，用于产物命名（release-config 中使用） | `myapp` |
| `ENABLE_UPDATER` | 是否启用 Tauri updater（release-config 中使用，workflow 中以注释控制） | `true` / `false` |
| `ENABLE_PORTABLE` | 是否产出 Windows portable 二进制 | `true` / `false` |
| `ENABLE_SIGNING` | 是否启用代码签名/公证 | `true` / `false` |

> updater 签名 secret（`TAURI_SIGNING_PRIVATE_KEY`、`TAURI_SIGNING_PRIVATE_KEY_PASSWORD`）与 updater 选项（`uploadUpdaterJson: true`）在 workflow 模板中以注释形式提供，启用时取消注释并配置对应 secret 名；禁用时保持注释。不得用占位符表示整行 YAML 键值对，否则破坏可解析性。

## 使用规则

- 变量在 CI 与 Release 模板中含义一致。
- 禁止用变量表示真实 secret 值，只表示变量名或可替换结构。
- 实例中所有变量必须替换为脱敏示例值，不得保留占位符残留。
- 不得引入本清单未登记的变量。
