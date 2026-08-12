#!/usr/bin/env bash
# stop-check.sh — Stop hook: check for unfinished tasks and request continuation
# If handoff/TASK-BOARD.md has unfinished tasks, request continuation (max 3 times).
set -euo pipefail

input=$(cat)

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

task_board="$cwd/handoff/TASK-BOARD.md"

if [ ! -f "$task_board" ]; then
    exit 0
fi

# Analyze task statuses
result=$(python3 -c "
import re
try:
    with open('$task_board', 'r') as f:
        content = f.read()

    planned = len(re.findall(r'status:\s*planned', content))
    in_progress = len(re.findall(r'status:\s*in_progress', content))
    in_review = len(re.findall(r'status:\s*in_review', content))
    verified = len(re.findall(r'status:\s*verified_complete', content))
    blocked = len(re.findall(r'status:\s*blocked', content))
    done_e2e = 'done_e2e' in content

    active = planned + in_progress + in_review + blocked
    total = active + verified

    if total == 0:
        exit(0)

    if active > 0:
        msg = f'工作流未完成：{active}/{total} 个任务仍活跃（planned:{planned} in_progress:{in_progress} in_review:{in_review} blocked:{blocked}）。'
        if blocked > 0:
            msg += ' 有任务被阻塞，需要主会话决策。'
        msg += ' 请继续推进工作流。'
        print(f'REQUEST_CONTINUE|{msg}')
    elif verified == total and total > 0 and not done_e2e:
        msg = f'所有 {total} 个任务已 verified_complete，但端到端验收尚未完成。请执行 Phase 7 E2E 验收。'
        print(f'REQUEST_CONTINUE|{msg}')
    elif verified == total and total > 0 and done_e2e:
        msg = f'所有任务已完成且 E2E 已通过。已自动 commit。如需发布版本，请显式指令 /tag vX.Y.Z。'
        print(f'INFO_ONLY|{msg}')
except:
    pass
" 2>/dev/null || echo "")

if [ -z "$result" ]; then
    exit 0
fi

action=$(printf '%s' "$result" | cut -d'|' -f1)
message=$(printf '%s' "$result" | cut -d'|' -f2-)

if [ "$action" = "REQUEST_CONTINUE" ]; then
    # Request continuation — ZCode will re-prompt the agent
    python3 -c "
import json, sys
msg = sys.argv[1]
print(json.dumps({'decision': 'request_continuation', 'reason': msg}))
" "$message" 2>/dev/null || true
fi

if [ "$action" = "INFO_ONLY" ]; then
    # Just inject info, don't block
    python3 -c "
import json, sys
msg = sys.argv[1]
print(json.dumps({'additionalContext': msg}))
" "$message" 2>/dev/null || true
fi

exit 0
