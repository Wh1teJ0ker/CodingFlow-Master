#!/usr/bin/env bash
# session-start.sh — SessionStart hook: inject workflow state into conversation
# Reads handoff/TASK-BOARD.md and docs/04-版本标准.md (if they exist) and
# injects current workflow state as additionalContext.
set -euo pipefail

# Read stdin JSON (hook payload from ZCode)
input=$(cat)

# Find the project root: try reading cwd from the hook payload, fallback to $PWD
cwd=$(printf '%s' "$input" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    cwd = data.get('cwd') or data.get('workspace') or data.get('projectRoot') or ''
    print(cwd)
except:
    print('')
" 2>/dev/null || echo "")

if [ -z "$cwd" ]; then
    cwd="$PWD"
fi

context_parts=()

# 1. Check for active TASK-BOARD
task_board="$cwd/handoff/TASK-BOARD.md"
if [ -f "$task_board" ]; then
    # Extract task statuses
    statuses=$(python3 -c "
import re, sys
try:
    with open('$task_board', 'r') as f:
        content = f.read()
    # Count task statuses
    planned = len(re.findall(r'status:\s*planned', content))
    in_progress = len(re.findall(r'status:\s*in_progress', content))
    in_review = len(re.findall(r'status:\s*in_review', content))
    verified = len(re.findall(r'status:\s*verified_complete', content))
    blocked = len(re.findall(r'status:\s*blocked', content))
    total = planned + in_progress + in_review + verified + blocked
    if total > 0:
        print(f'工作流状态：{total} 个任务 — planned:{planned} in_progress:{in_progress} in_review:{in_review} verified_complete:{verified} blocked:{blocked}')
        if verified == total and total > 0:
            print('所有任务已 verified_complete。如 E2E 已通过，可自动 commit。如需发布版本，请显式指令 /tag vX.Y.Z')
        elif in_progress > 0 or in_review > 0:
            print('有任务正在进行中，继续推进工作流。')
    else:
        print('handoff/TASK-BOARD.md 存在但无任务记录。')
except Exception as e:
    print(f'读取 TASK-BOARD 失败: {e}')
" 2>/dev/null || echo "")
    if [ -n "$statuses" ]; then
        context_parts+=("$statuses")
    fi
fi

# 2. Check for docs/ directory
docs_dir="$cwd/docs"
if [ ! -d "$docs_dir" ]; then
    context_parts+=("当前项目尚未建立 docs/ 目录。建议先运行 /plan 进行文档规划（Phase 0）。")
fi

# 3. Check for existing version tags
tags=$(cd "$cwd" 2>/dev/null && git tag --list 'v*' 2>/dev/null | tail -3 || echo "")
if [ -n "$tags" ]; then
    latest_tag=$(echo "$tags" | tail -1)
    context_parts+=("最近版本 tag: $latest_tag")
fi

# Output additionalContext if we have anything to say
if [ "${#context_parts[@]}" -gt 0 ]; then
    context=$(printf '%s\n' "${context_parts[@]}")
    python3 -c "
import json, sys
ctx = sys.argv[1]
print(json.dumps({'additionalContext': ctx}))
" "$context" 2>/dev/null || true
fi

exit 0
