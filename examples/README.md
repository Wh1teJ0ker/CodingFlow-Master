# 实例说明

本目录下的所有内容均为**非权威实例**，仅用于说明如何把 `assets/project-templates/` 模板填充为具体配置。实例不替代规范，规范以 `references/` 与根目录编号过程文件为准。

## 目录

- `rust-tauri/`：Rust + Tauri 工作流填充实例（CI 与 Release）。
- `go-wails/`：Go + Wails 工作流填充实例（CI 与 Release）。
- `release/`：Release QA 三种闭环实例，展示 `qa_passed`、`qa_failed`、`blocked` 三种状态下的正确处理顺序。

## 重要约束

- 实例中的项目名、模块路径、版本号均为脱敏占位值，不代表任何真实项目。
- `qa_failed` 与 `blocked` 实例必须清楚展示“不可发布”，不得出现 finalize 或公开发布声明。
- `qa_passed` 实例必须展示完整闭环：任务完成 -> E2E -> QA 报告 -> 版本同步 -> `release_complete`。
- 实例不得保留 `{{...}}` 或 `<REPLACE:...>` 占位符残留。
