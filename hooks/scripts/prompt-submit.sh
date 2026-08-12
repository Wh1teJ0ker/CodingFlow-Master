#!/usr/bin/env bash
# prompt-submit.sh — UserPromptSubmit hook: inject workflow reminders
# Analyzes the user's prompt and injects relevant workflow reminders.
set -euo pipefail

input=$(cat)

# Extract the user's prompt text
prompt_text=$(printf '%s' "$input" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    p = data.get('prompt') or data.get('text') or data.get('message') or ''
    print(p)
except:
    print('')
" 2>/dev/null || echo "")

# Extract cwd
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

# 1. Tag / release intent detection
if printf '%s' "$prompt_text" | grep -qiE '(tag[[:space:]]+v[0-9]|发布|release|打tag|打标签)'; then
    context_parts+=("检测到 tag/发布意图。根据工作流规范，tag 前必须完成 Release QA 审计并生成 docs/qa/versions/<ver>/QA-审计报告.md，且结论为 qa_passed。请使用 /tag vX.Y.Z 命令触发完整流程。")
fi

# 2. Unfinished tasks reminder
task_board="$cwd/handoff/TASK-BOARD.md"
if [ -f "$task_board" ]; then
    unfinished=$(python3 -c "
import re
try:
    with open('$task_board', 'r') as f:
        content = f.read()
    # Count non-verified tasks
    planned = len(re.findall(r'status:\s*planned', content))
    in_progress = len(re.findall(r'status:\s*in_progress', content))
    in_review = len(re.findall(r'status:\s*in_review', content))
    blocked = len(re.findall(r'status:\s*blocked', content))
    active = planned + in_progress + in_review + blocked
    if active > 0:
        print(f'提醒：handoff/TASK-BOARD.md 中仍有 {active} 个未完成任务（planned:{planned} in_progress:{in_progress} in_review:{in_review} blocked:{blocked}）。请先推进当前工作流再开始新任务。')
except:
    pass
" 2>/dev/null || echo "")
    if [ -n "$unfinished" ]; then
        context_parts+=("$unfinished")
    fi
fi

# 3. Missing docs/ directory
docs_dir="$cwd/docs"
if [ ! -d "$docs_dir" ] && [ -n "$prompt_text" ]; then
    # Only suggest /plan if the user seems to want to start work, not for casual questions
    if printf '%s' "$prompt_text" | grep -qiE '(实现|开发|做|写|build|implement|开发|开始|start)'; then
        context_parts+=("当前项目尚未建立 docs/ 目录。建议先运行 /plan 进行文档规划（Phase 0），建立文档基线后再拆任务。")
    fi
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
