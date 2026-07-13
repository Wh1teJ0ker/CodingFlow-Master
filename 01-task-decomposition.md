# 01 — Phase 1: 拆任务 DAG

> 主会话在理解需求后、分派前阅读本文件。

## 拆分判断标准（每个任务必须同时满足）

1. **可独立验收**：不依赖其它未完成任务就能跑出"通过/未通过"。否则它不是独立任务，是子步骤。
2. **单一行为变更**：goal 一句话能说清，不出现"并且""同时"。出现就拆。
3. **一次 coder pass 可完成**：大致 < 300 行净增或 < 5 个文件。再大就拆成"骨架→填充"两段。
4. **有显式 out_of_scope**：能列出"不许碰什么"。列不出说明边界模糊，回去再拆。
5. **依赖明确**：标注 `depends_on: [T2, T3]`，没依赖的可并行候选。

## 反例（不要这么拆）

- ❌ "实现整个登录模块"（不可验收、太大）
- ❌ "改 utils.ts"（按文件拆，不是按行为）
- ❌ "写测试"单独成任务（测试应跟实现绑同一个任务，否则验收项割裂）
- ❌ "重构 + 加新功能"塞一起（两种行为变更，拆开）

## 拆分维度（按优先级用）

**维度 1：按端到端可验收的垂直切片**（首选）
按"用户能感知的一个行为"切。每个切片能独立 demo。即使其它切片没做，产品也有可用形态。

**维度 2：按依赖链排序**
画 DAG：哪些任务的前置是别的任务的产出。
- 无依赖 → 并行候选
- 有依赖 → 前一个 verified_complete 后才派下一个
- 长链路里，如果中间产出是稳定的接口（已定义的 schema / 协议），可让下游提前对着接口写，并行度 +1

**维度 3：按风险/不确定性二次切分**
高风险段（不确定能否实现、要试错）先拆一个 spike 任务：只验证可行性、产出结论，不进产品路径。结论出来再拆真正的实现任务。

## 任务 DAG 输出

写入 `handoff/TASK-BOARD.md`，固定结构：

```yaml
goal: |                  # 整体目标（用户视角的一句话）
  ...
tasks:
  - id: T1
    title: ...
    depends_on: []       # 任务 id 列表，空表示无依赖
    status: planned
    handoff: handoff/TASK-T1-HANDOFF.md
  - id: T2
    title: ...
    depends_on: [T1]
    status: planned
    handoff: handoff/TASK-T2-HANDOFF.md
e2e_acceptance:          # 整体端到端验收项（Phase 7 用）
  - ...
e2e_verification:        # 端到端要跑的命令
  - ...
release_qa:              # 版本发布前全局 QA 门禁
  required: true
  report: docs/qa/versions/<ver>/QA-审计报告.md
  audit_scope:
    - 需求覆盖
    - 端到端流程
    - 构建与测试
    - 代码质量
    - 安全与隐私
    - 数据与迁移
    - 依赖与配置
    - 文档一致性
```

每个任务同时写一份独立的 `handoff/TASK-<id>-HANDOFF.md`（字段表见下）。

## HANDOFF 字段表（coder 必须遵守，不可改字段名）

```yaml
task_id: T1
goal: |                # 本次要实现的具体行为变更（一句话可验收）
  ...
in_scope:              # 允许改的文件 / 流程
  - path/to/file
out_of_scope:          # 明确不许动的
  - ...
acceptance_criteria:   # 怎样算做完了（可执行断言）
  - ...
verification_commands: # 必须跑的验证命令
  - ...
files_likely_to_change:
  - ...
risks:                 # 已知风险 / 注意点
  - ...
depends_on: []         # 任务依赖
status: planned
```

规则：
- `goal` 必须是 coder 可直接执行、可验收的一句话
- `out_of_scope` 必须显式列出（防止扩 scope）
- `verification_commands` 必须可执行
- `acceptance_criteria` 必须是可判定 true/false 的断言，不是模糊描述

## 并行模式：单 coder + reviewer 流水线

默认串行分派，但 reviewer 与下一个任务的准备可重叠，仍能加速：

```
T1: [coder T1] ─→ [reviewer T1] ─┐ pass → 主会话判定 verified_complete(T1)
                                  │
T2:                    （T1 review 期间，主会话可准备 T2 的 HANDOFF）
        [coder T2] ─→ [reviewer T2] ─┐ pass → verified_complete(T2)
                                       │
        ...                            ▼
                          全部单任务通过 → 端到端集成验收 → Release QA 审计 → 整体彻底完成
```

规则：
- 一次只派一个 coder 任务（避免多 coder 改同一片代码冲突）
- coder 回报后立即派 reviewer
- reviewer 期间，主会话可并行准备下一个任务的 HANDOFF，但不派下一个 coder（除非下一个任务 `depends_on` 当前任务为 false 且无文件重叠）
- reviewer 退回 → 缺陷合并进 HANDOFF 重新派给 coder，不另起新任务
