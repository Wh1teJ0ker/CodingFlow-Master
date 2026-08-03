# Go + Wails 模板变量清单

本文件登记 `go-wails/` 模板中使用的全部占位符。CI 与 Release 模板共享同一变量含义。实例（`examples/go-wails/`）中占位符应替换为脱敏示例值，不得保留占位符残留，也不得泄漏参考项目身份。

## 占位符约定

模板中标量位置的占位符使用 `<REPLACE:NAME>` 形式并用引号包裹，保证 YAML 可解析。`run` 脚本内的占位同样使用引号包裹的 `<REPLACE:NAME>`。复制到目标项目后，将 `<REPLACE:NAME>` 替换为真实值。

> 不使用 `{{NAME}}` 形式作为 YAML 标量占位符，因为裸花括号会破坏 YAML 可解析性。可选能力（如签名）以 release-config 开关或 workflow 注释形式控制。

## 通用变量

| 变量 | 含义 | 示例值（脱敏） |
|---|---|---|
| `<REPLACE:PROJECT_NAME>` | 项目名称，用于产物命名 | `myapp` |
| `<REPLACE:GO_MODULE_PATH>` | Go 模块路径，用于 ldflags 注入 | `github.com/org/myapp` |
| `<REPLACE:NODE_VERSION>` | Node 主版本 | `20` |
| `<REPLACE:WAILS_VERSION>` | Wails CLI 版本，固定到与 go.mod 一致 | `v2.11.0` |
| `<REPLACE:WEBKIT_PACKAGE>` | Linux WebKit 开发包，Wails v2 用 4.0 | `libwebkit2gtk-4.0-dev` |

> 更新日志路径不使用静态占位符，而是由 Release workflow 的 validate job 从 tag 提取版本号后注入：`docs/versions/${{ needs.validate.outputs.version }}/更新日志.md`。模板不写死具体版本。

## ldflags 变量

ldflags 通过变量配置，不跨平台手工拼接不同字符串。注入的变量路径基于 `<REPLACE:GO_MODULE_PATH>`：

- Version：`<REPLACE:GO_MODULE_PATH>/internal/buildinfo.Version`
- Commit：`<REPLACE:GO_MODULE_PATH>/internal/buildinfo.Commit`
- BuildDate：`<REPLACE:GO_MODULE_PATH>/internal/buildinfo.BuildDate`

## 可选能力变量

| 变量 | 含义 | 示例值（脱敏） |
|---|---|---|
| `ENABLE_SIGNING` | 是否启用代码签名/公证（release-config 中使用） | `true` / `false` |

> Windows 代码签名与 macOS 签名/公证为可选扩展，启用时密钥只通过 secret 引用；缺少凭据时发布状态为 `blocked`，不得跳过签名直接发布。

## 使用规则

- 变量在 CI 与 Release 模板中含义一致。
- 禁止用变量表示真实 secret 值，只表示变量名或可替换结构。
- 实例中所有变量必须替换为脱敏示例值，不得保留占位符残留。
- 不得引入本清单未登记的变量。
