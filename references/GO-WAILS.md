# Go + Wails 技术栈参考

本参考定义 Go + Wails 桌面应用在使用本 skill 模板时的技术栈约束。通用要求见 [`GITHUB-ACTIONS-STANDARD.md`](./GITHUB-ACTIONS-STANDARD.md) 与 [`RELEASE-STANDARD.md`](./RELEASE-STANDARD.md)。可复制模板位于 `../assets/project-templates/go-wails/`，非权威实例位于 `../examples/go-wails/`。

## 1. 适用范围

适用于 Wails v2.x 桌面应用：Go 后端 + 前端（npm）。本参考不绑定具体项目身份。

## 2. 工具链固定

- Go：通过 `actions/setup-go` 的 `go-version-file: go.mod` 读取，或固定具体版本。禁止 `stable` 浮动版本。
- Node：固定主版本（如 20），启用 `cache: npm` 并绑定 `frontend/package-lock.json`。
- Wails CLI：固定到与 `go.mod` 中 Wails 库一致的版本（如 `v2.11.0`），通过 `go install github.com/wailsapp/wails/v2/cmd/wails@<version>` 安装。禁止可变引用。
- 模块路径建议使用全局规范路径（如 `github.com/<org>/<project>`），但模板不写死具体值。

## 3. CI 质量门禁

CI 必须包含：

- 前端：`npm ci`（确定性安装，禁止 `npm install`）、`npm run build`；
- Go：`go test ./...`、`go vet ./...`；
- 可选 Linux 原生 Wails smoke build，验证可打包。
- Linux 依赖步骤限定 `if: runner.os == 'Linux'`。

`go-sqlite3` 等 CGO 依赖存在时，不得假设完全静态或任意交叉编译；测试与构建优先使用原生平台 runner。

## 4. 三平台原生矩阵

发布矩阵覆盖三个原生平台：

| 平台 | runner | 产物 |
|---|---|---|
| Linux amd64 | `ubuntu-latest` | `.tar.gz` |
| Windows amd64 | `windows-latest` | `.zip` 或 `.exe` |
| macOS universal | `macos-latest` | `.zip`（含 `.app`） |

- 矩阵 `fail-fast: false`。
- 不在 CI 中跨平台交叉编译 CGO 产物。
- macOS 使用 `ditto` 将 `.app` 归档为 zip，保留权限与目录结构。

## 5. Linux 系统依赖

```sh
sudo apt-get update
sudo apt-get install -y \
  build-essential \
  pkg-config \
  libgtk-3-dev \
  libwebkit2gtk-4.0-dev
```

- Wails v2 对应 `libwebkit2gtk-4.0-dev`；若未来升级到需要 4.1 的版本，必须在变量清单注明。
- Linux 产物是依赖 GTK/WebKit 共享库的可执行文件，不是静态单文件；模板与 README 必须如实说明运行时依赖。

## 6. 版本注入

- 版本源为 `wails.json` 的 `info.productVersion`，或 linker 注入的 `buildinfo.Version`，二选一作为唯一源。
- 通过 `ldflags` 注入构建信息：

  ```text
  -X <module>/internal/buildinfo.Version=<version>
  -X <module>/internal/buildinfo.Commit=<sha>
  -X <module>/internal/buildinfo.BuildDate=<rfc3339>
  ```

- `ldflags` 通过变量配置，不跨平台手工拼接不同字符串。
- Release 必须校验 Git tag（去 `v` 前缀）与版本源一致。
- 不得同时维护多个手工版本常量（如桌面一个、agent 一个）而互相漂移。

## 7. 产物与校验

- 产物命名遵循 [`RELEASE-STANDARD.md`](./RELEASE-STANDARD.md) 第 5 节。
- 每平台产物必须存在性验证后再上传。
- 生成 SHA-256 checksums 文件随 Release 上传。
- Linux 与 Windows 不直接上传裸可执行文件作为正式发布产物，应打包为归档或安装包。

## 8. 签名与公证（可选扩展）

- Windows 代码签名：使用证书 secret，无证书时声明未签名及 SmartScreen 影响。
- macOS 签名/公证：hardened runtime、entitlements、notarization、stapling，密钥通过 secret 引用。
- 缺少必要凭据时状态为 `blocked`，不得跳过签名直接发布。

## 9. Draft 与 Finalize

遵循 [`RELEASE-STANDARD.md`](./RELEASE-STANDARD.md) 第 4 节：

1. 校验 tag 与版本源一致；
2. 校验 Release QA 状态；
3. 创建 draft Release；
4. 三平台矩阵构建上传；
5. 生成 checksums；
6. 全部成功后 finalize job 改为正式发布。

`contents: write` 仅授予创建/更新 Release 与 finalize job。普通 push 到分支不创建 Release。

## 10. 模板变量

模板变量登记于 `../assets/project-templates/go-wails/TEMPLATE-VARIABLES.md`，至少包括：

- `{{PROJECT_NAME}}`、`{{GO_MODULE_PATH}}`、`{{NODE_VERSION}}`、`{{WAILS_VERSION}}`
- `{{WEBKIT_PACKAGE}}`（4.0 或 4.1）
- `{{LDFLAGS_VERSION_VAR}}`、`{{LDFLAGS_COMMIT_VAR}}`、`{{LDFLAGS_DATE_VAR}}`
- `{{CHANGELOG_PATH}}`、`{{ENABLE_SIGNING}}`

变量在 CI 与 Release 中含义一致，实例中替换为脱敏示例值。

## 11. 禁止项

- Go `stable` 浮动版本、Wails 可变引用；
- `npm install` 替代 `npm ci`；
- 顶层 `contents: write`；
- 跨平台交叉编译 CGO 产物而不验证；
- finalize 早于全平台与质量门禁完成；
- 模板写死项目身份、真实密钥、绝对路径或固定版本文档路径。
