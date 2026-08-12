#!/usr/bin/env bash
# setup.sh — CodingFlow-Master 子 Agent 自动配置脚本
#
# 职责：
#   1. 同步 V2 skill 文件到 ~/.agents/skills/orchestrator-workflow/
#   2. 安装 coder/reviewer Agent 定义到 ~/.zcode/agents/
#
# 特性：幂等（安全重复运行）、纯 bash 无外部依赖、macOS/Linux 兼容
set -euo pipefail

# ── 路径确定 ──────────────────────────────────────────────
# 脚本位于 <plugin-root>/scripts/setup.sh，反推插件根目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

AGENTS_SRC="$PLUGIN_ROOT/agents"
SKILL_SRC="$PLUGIN_ROOT/skills/orchestrator-workflow"

AGENTS_DST="$HOME/.zcode/agents"
SKILL_DST="$HOME/.agents/skills/orchestrator-workflow"

# ── 颜色输出 ──────────────────────────────────────────────
info()  { printf '\033[36m[INFO]\033[0m  %s\n' "$1"; }
ok()    { printf '\033[32m[OK]\033[0m    %s\n' "$1"; }
warn()  { printf '\033[33m[WARN]\033[0m  %s\n' "$1"; }
fail()  { printf '\033[31m[FAIL]\033[0m  %s\n' "$1"; exit 1; }

# ── 前置检查 ──────────────────────────────────────────────
[ -d "$AGENTS_SRC" ] || fail "插件 agents/ 目录不存在: $AGENTS_SRC"
[ -d "$SKILL_SRC" ]  || fail "插件 skill 目录不存在: $SKILL_SRC"
[ -f "$AGENTS_SRC/coder.md" ]    || fail "缺少 agents/coder.md"
[ -f "$AGENTS_SRC/reviewer.md" ] || fail "缺少 agents/reviewer.md"

info "插件根目录: $PLUGIN_ROOT"

# ── Step 1: 同步 skill 文件到 ~/.agents/ ──────────────────
info "同步 skill 文件到 $SKILL_DST ..."

# 清理旧 V1 目录（含 rust-tauri/go-wails/examples 等残留）
if [ -d "$SKILL_DST" ]; then
    rm -rf "$SKILL_DST"
    warn "已清理旧目录: $SKILL_DST"
fi

mkdir -p "$SKILL_DST"
cp -R "$SKILL_SRC/"* "$SKILL_DST/"

ok "skill 文件已同步"
# 验证关键文件存在
for f in SKILL.md specs/04-coder-spec.md specs/05-reviewer-spec.md; do
    [ -f "$SKILL_DST/$f" ] || fail "同步后缺少: $SKILL_DST/$f"
done
ok "关键文件验证通过"

# ── Step 2: 安装 Agent 定义到 ~/.zcode/agents/ ────────────
info "安装 Agent 定义到 $AGENTS_DST ..."

mkdir -p "$AGENTS_DST"
cp "$AGENTS_SRC/coder.md"    "$AGENTS_DST/coder.md"
cp "$AGENTS_SRC/reviewer.md" "$AGENTS_DST/reviewer.md"

ok "coder.md  → $AGENTS_DST/coder.md"
ok "reviewer.md → $AGENTS_DST/reviewer.md"

# ── 完成 ──────────────────────────────────────────────────
echo ""
ok "配置完成！"
echo ""
echo "已安装的组件："
echo "  • Skill 文件 → $SKILL_DST"
echo "  • Coder Agent → $AGENTS_DST/coder.md"
echo "  • Reviewer Agent → $AGENTS_DST/reviewer.md"
echo ""
echo "子 Agent 读取的 spec 路径："
echo "  • $SKILL_DST/specs/04-coder-spec.md"
echo "  • $SKILL_DST/specs/05-reviewer-spec.md"
echo ""
echo "现在可以在 ZCode 中使用 /plan 启动工作流，主会话会自动分派 coder 和 reviewer 子 Agent。"
