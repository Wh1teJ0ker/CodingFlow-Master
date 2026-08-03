# 07 — Phase 8: 版本发布前全局 QA 审计

> 所有单任务 `verified_complete` 且端到端验收通过后，主会话在任何版本更新、版本完成标记或发布前阅读并执行本文件。

## 核心原则

开发期 Reviewer 只审单个任务；Release QA 审计审整个版本。二者不能互相替代。

版本发布前全局 QA 的目标是回答：**当前代码、配置、数据、文档与验收证据，是否足以支持把这个版本标记为完成 / 发布 / 可交付？**

只要本次工作涉及以下任一动作，就必须先完成本流程：
- 将 `docs/versions/<ver>/更新日志.md` 顶部状态改为 `已完成` / `已发布` / 等价完成态。
- 更新 `docs/04-版本标准.md` 中对应版本的完成日期、发布状态或里程碑状态。
- 生成简洁 release note、版本交付说明、版本总结，或向用户宣称该版本可交付。
- 用户要求“版本更新”“发布前检查”“全局审计”“QA 文档”“验收报告”。

## QA 文档路径规则（与版本目录同步）

QA 报告是 `docs/` 下的永久文档，必须按版本组织，和 `docs/versions/<ver>/` 一一对应：

```text
docs/
├── versions/
│   └── <ver>/
│       ├── 规划需求.md
│       ├── 技术方案.md
│       └── 更新日志.md
└── qa/
    └── versions/
        └── <ver>/
            └── QA-审计报告.md
```

规则：
- `docs/versions/<ver>/...` 存在时，对应的 QA 报告路径固定为 `docs/qa/versions/<ver>/QA-审计报告.md`。
- 同一版本多次审计时，默认更新同一个 `QA-审计报告.md`，保留最新结论和历史审计记录摘要。
- 如用户要求保留每次审计快照，可额外写 `QA-审计报告-YYYYMMDD-HHMM.md`，但固定文件仍必须同步到最新结论。
- QA 报告不能放在散乱目录，也不能只写到 `handoff/`；`handoff/` 是临时交接，不能作为版本 QA 交付物。

## 审计输入

主会话必须基于实际文件和命令输出，而不是基于对话记忆：

1. `docs/versions/<ver>/规划需求.md`、`技术方案.md`（如存在）、`更新日志.md`
2. `docs/04-版本标准.md`（如存在）
3. `handoff/TASK-BOARD.md`（如仍存在）及端到端验收证据
4. 当前源代码、配置、数据库迁移、脚本、测试、构建配置
5. 实际运行的验证命令输出
6. 既有 `docs/qa/versions/<ver>/QA-审计报告.md`（如存在）

若关键输入缺失且无法从实际项目推断，审计结论必须是 `blocked`，不得写 `qa_passed`。

## 审计范围

至少覆盖以下维度。项目不涉及的维度可以标 `N/A`，但必须说明原因。

| 维度 | 必查内容 |
|------|----------|
| 需求覆盖 | 版本规划需求中的功能、非目标、验收标准是否与实现一致 |
| 端到端流程 | 主要用户 happy path 是否串联通过，跨任务集成是否存在断点 |
| 构建与测试 | 类型检查、单元测试、构建、平台特定检查是否运行并有证据 |
| 代码质量 | 模块边界、重复逻辑、错误处理、状态一致性、可维护性风险 |
| 安全与隐私 | 密钥处理、输入校验、文件/网络/数据库访问、日志泄露、权限边界 |
| 数据与迁移 | schema / migration / 本地存储兼容性，升级后数据风险 |
| 依赖与配置 | package / lockfile / Cargo / Tauri / CI 或脚本配置一致性 |
| 文档一致性 | `docs/` 是否反映真实实现状态，是否存在比代码更乐观的描述 |
| 已知问题 | 未修复缺陷、限制、人工验证缺口是否被如实记录 |
| 发布门禁 | 是否存在阻止版本完成 / 发布的 critical 或 major 问题 |

## 验证命令原则

优先从项目文档、`package.json`、`Cargo.toml`、CI 配置和 `TASK-BOARD.md` 中推导验证命令。常见命令包括但不限于：

```text
pnpm typecheck / npm run typecheck / yarn typecheck
pnpm test / npm test / yarn test
pnpm build / npm run build / yarn build
cargo check / cargo test
pnpm tauri build / pnpm tauri dev
```

规则：
- 不能只写“应当运行”，必须写实际是否运行、命令、结果摘要和失败输出。
- 关键命令无法运行时，必须写明原因，并通常判定为 `qa_failed` 或 `blocked`。
- 如果用户明确接受某项命令暂不运行，QA 报告仍要记录该豁免；但不能把未覆盖风险写成“已验证”。

## QA 报告固定结构

`docs/qa/versions/<ver>/QA-审计报告.md` 至少包含：

```markdown
# <ver> QA 审计报告

## 1. 审计范围
- 版本：<ver>
- 审计时间：YYYY-MM-DD HH:mm
- 审计人：...
- 审计结论：qa_passed | qa_failed | blocked

## 2. 证据核对
| 检查项 | 期望 | 实际证据 | 结论 |
|------|------|----------|------|

## 3. 发现的问题
| 严重级别 | 问题 | 状态 |
|----------|------|------|

## 4. 审计结论
- 是否允许标记版本完成 / 发布：是 / 否
- 后续动作：...
```

> QA 报告与版本文档模板可从 [`assets/project-templates/release-docs/`](./assets/project-templates/release-docs/) 复制（`QA-审计报告.md.template`、`04-版本标准.md.template`、`规划需求.md.template`、`更新日志.md.template`）。三种闭环场景（`qa_passed` / `qa_failed` / `blocked`）的正确处理顺序与证据形态见 [`examples/release/`](./examples/release/) 非权威实例。Release 工程规范（SemVer、唯一版本源、draft/finalize、checksums、签名）见 [`references/RELEASE-STANDARD.md`](./references/RELEASE-STANDARD.md)；GitHub Actions 门禁与状态语义见 [`references/GITHUB-ACTIONS-STANDARD.md`](./references/GITHUB-ACTIONS-STANDARD.md)。
>
> 注意：Actions workflow 的 CI 通过或产物构建成功只是自动化证据，不能替代本审计报告。对外更新日志可以简洁，但本 QA 报告仍必须足够支持 `qa_passed` / `qa_failed` / `blocked` 的结论。

## 判定规则

`qa_passed` 仅在全部满足时使用：
1. 端到端验收已通过且有证据。
2. 关键验证命令已运行并通过，或存在明确、合理、已记录的非阻塞豁免。
3. 没有未解决的 `critical` 或 `major` 问题。
4. `docs/` 与实际实现一致，没有比代码更乐观的完成态描述。
5. QA 报告已写入 `docs/qa/versions/<ver>/QA-审计报告.md`。

`qa_failed` 用于：
- 存在 critical / major 问题。
- 关键验证命令失败。
- 文档与实现严重不一致。
- 端到端验收证据不足或发现跨任务集成缺陷。

`blocked` 用于：
- 缺少关键输入，无法建立审计依据。
- 项目无法启动关键验证，且原因不是版本本身可修复的问题。
- 用户需要先决策发布范围、验收口径或风险接受策略。

## 审计失败后的闭环

如果结论是 `qa_failed`：
1. 不允许更新版本为完成 / 已发布。
2. 将 critical / major 问题拆成新的修复任务 HANDOFF，回到 [`01-task-decomposition.md`](./01-task-decomposition.md) / [`02-dispatch-and-verify.md`](./02-dispatch-and-verify.md) 的开发闭环。
3. 修复任务通过后，重新运行 [`03-e2e-acceptance.md`](./03-e2e-acceptance.md)。
4. 重新执行本 Release QA 审计，并更新同一个 QA 报告。

如果结论是 `blocked`：
1. 不允许更新版本为完成 / 已发布。
2. 向用户报告缺失输入或需要决策的问题。
3. 补齐输入后从本文件重新开始。

如果结论是 `qa_passed`：
1. 允许按 [`06-progress-sync.md`](./06-progress-sync.md) 执行版本级完成 / 发布状态同步。
2. 将 `docs/versions/<ver>/更新日志.md` 的验收记录指向 QA 报告路径。
3. 更新 `docs/04-版本标准.md` 对应版本状态。
4. 删除 `handoff/TASK-BOARD.md`（如存在）。

## 场景自检（主会话执行时必须符合）

**场景 A：E2E 通过，但 QA 发现 major 问题**
- 结果必须是 `qa_failed`。
- `docs/qa/versions/<ver>/QA-审计报告.md` 必须记录 major 问题、证据、影响和修复建议。
- 不允许把 `docs/versions/<ver>/更新日志.md` 或 `docs/04-版本标准.md` 改成完成 / 已发布。
- 必须把阻塞问题拆成修复 HANDOFF，修复后重新跑 E2E，再重新执行 Release QA。

**场景 B：E2E 通过，QA 全部通过**
- 结果必须是 `qa_passed`。
- `docs/qa/versions/<ver>/QA-审计报告.md` 必须存在并记录验证命令、审计矩阵和发布门禁结论。
- 才允许按 [`06-progress-sync.md`](./06-progress-sync.md) 同步版本完成 / 发布状态，并在更新日志验收记录中引用 QA 报告。
- 版本状态同步完成后，才允许删除 `handoff/TASK-BOARD.md`。

## 禁止行为

- ❌ 用任务级 REVIEW 替代版本级 QA 报告。
- ❌ 在未生成 `docs/qa/versions/<ver>/QA-审计报告.md` 时标记版本完成 / 发布。
- ❌ QA 失败时只记录问题但继续把版本状态改为已发布。
- ❌ 把 QA 报告只写在对话里或 `handoff/` 下。
- ❌ 文档写“已完成 / 已发布”，但 QA 报告结论不是 `qa_passed`。
