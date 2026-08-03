# Rust + Tauri 工作流实例

本目录是非权威实例，仅展示如何把 `assets/project-templates/rust-tauri/` 模板填充为脱敏示例配置。实例不替代规范，规范以 `references/RUST-TAURI.md`、`references/GITHUB-ACTIONS-STANDARD.md`、`references/RELEASE-STANDARD.md` 为准。

## 实例假设

- 项目名：`myapp`（脱敏占位）
- Node 22、pnpm 11
- Linux 默认采用 `libayatana-appindicator3-dev`
- updater 与 signing 未启用（最小可用实例）

## 文件说明

- `ci.yml`：填充后的 CI 工作流实例
- `release.yml`：填充后的 Release 工作流实例

实例中的版本号通过 Release 的 validate job 从 tag 注入，不写死具体版本。更新日志路径使用 `docs/versions/${{ needs.validate.outputs.version }}/更新日志.md` 形式。
