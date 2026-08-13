#!/usr/bin/env bash
# pre-bash-gate.sh — PreToolUse hook on Bash: enforce tag and commit gates
#
# Gate 1 (git tag): Block if ANY of:
#   a) Version format doesn't match ^v[0-9]+\.[0-9]+\.[0-9]+$ (no rc/beta/alpha suffix)
#   b) docs/qa/versions/<ver>/QA-审计报告.md doesn't exist
#   c) QA report conclusion is not qa_passed
#   d) docs/versions/<ver>/release.md doesn't exist (release doc must be generated before tag)
#   e) handoff/ still contains task files (TASK-BOARD.md / TASK-*.md) — must clean before tag
#
# Gate 2 (git commit): Block if commit message doesn't follow Conventional Commits
#   format: type(scope): subject  (type must be one of the standard types)
#
# All other commands: pass through (exit 0).
set -euo pipefail

input=$(cat)

# Extract the Bash command string from hook payload
cmd=$(printf '%s' "$input" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    # ZCode hook payload for PreToolUse:Bash
    tool_input = data.get('toolInput') or data.get('tool_input') or {}
    command = tool_input.get('command') or ''
    if not command:
        # Try alternate structures
        command = data.get('command') or ''
    print(command)
except:
    print('')
" 2>/dev/null || echo "")

if [ -z "$cmd" ]; then
    exit 0
fi

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

deny_reason=""

# ── Gate 1: git tag ──────────────────────────────────────────────
# Detect 'git tag' as an actual command, not inside quoted strings (e.g. commit -m "...git tag...")
is_git_tag=$(printf '%s' "$cmd" | python3 -c "
import sys, re
cmd = sys.stdin.read()
# Strip quoted strings so 'git tag' inside a commit message won't match
cleaned = re.sub(r'\"[^\"]*\"', '\"\"', cmd)
cleaned = re.sub(r\"'[^']*'\", \"''\", cleaned)
# Match 'git tag' at start or after a shell connector
if re.search(r'(^|[;&|]\s*|&&\s*|||\s*)git\s+tag(\s|$)', cleaned):
    print('yes')
else:
    print('no')
" 2>/dev/null || echo "no")

if [ "$is_git_tag" = "yes" ]; then
    # Extract version number from git tag command
    # Matches: git tag v1.0.0, git tag -a v1.0.0 -m "...", git tag v1.0.0 -m "..."
    version=$(printf '%s' "$cmd" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+[a-zA-Z0-9.-]*' | head -1 || echo "")

    if [ -z "$version" ]; then
        deny_reason="git tag 命令未包含有效的版本号。格式必须为 vX.Y.Z（如 v1.0.0）。"
    elif printf '%s' "$version" | grep -qiE '(rc|beta|alpha|pre|dev)'; then
        deny_reason="版本号 ${version} 包含不允许的后缀（rc/beta/alpha/pre/dev）。只允许纯 SemVer 格式 vX.Y.Z。"
    else
        # Check version format strictly: ^v[0-9]+\.[0-9]+\.[0-9]+$
        if ! printf '%s' "$version" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$'; then
            deny_reason="版本号 ${version} 不符合 SemVer 格式。必须为 vX.Y.Z（如 v1.0.0）。"
        else
            # Check QA report exists
            # Try both with and without 'v' prefix (e.g. v1.1.5 and 1.1.5)
            ver_num="${version#v}"
            qa_report_v="$cwd/docs/qa/versions/$version/QA-审计报告.md"
            qa_report_num="$cwd/docs/qa/versions/$ver_num/QA-审计报告.md"
            qa_report=""

            if [ -f "$qa_report_v" ]; then
                qa_report="$qa_report_v"
            elif [ -f "$qa_report_num" ]; then
                qa_report="$qa_report_num"
            else
                deny_reason="版本 ${version} 的 QA 审计报告不存在（尝试路径: docs/qa/versions/${version}/ 和 docs/qa/versions/${ver_num}/）。必须先通过 Release QA 审计并生成 QA 报告且结论为 qa_passed 后才能 tag。请使用 /tag ${version} 命令触发完整流程。"
            fi

            # Only check conclusion and release.md if QA report was found
            if [ -f "$qa_report" ]; then
                # Check QA report conclusion is qa_passed
                conclusion=$(python3 -c "
try:
    with open('$qa_report', 'r') as f:
        content = f.read()
    import re
    m = re.search(r'审计结论\s*[:：]\s*(\S+)', content)
    if m:
        print(m.group(1).strip())
    else:
        m = re.search(r'qa_passed|qa_failed|blocked', content)
        if m:
            print(m.group(0))
        else:
            print('unknown')
except:
    print('error')
" 2>/dev/null || echo "error")

                if [ "$conclusion" != "qa_passed" ]; then
                    deny_reason="版本 ${version} 的 QA 审计报告结论为 '${conclusion}'，不是 qa_passed。不允许 tag。请先修复 QA 审计发现的问题并重新审计。"
                else
                    # Check release.md exists
                    release_md_v="$cwd/docs/versions/$version/release.md"
                    release_md_num="$cwd/docs/versions/$ver_num/release.md"
                    if [ ! -f "$release_md_v" ] && [ ! -f "$release_md_num" ]; then
                        deny_reason="版本 ${version} 的发布文档 release.md 不存在（尝试路径: docs/versions/${version}/release.md 和 docs/versions/${ver_num}/release.md）。Release QA 通过后必须先执行生成 release.md 的步骤，才能 tag。"
                    else
                        # Check handoff/ is clean (no task files)
                        handoff_dir="$cwd/handoff"
                        if [ -d "$handoff_dir" ]; then
                            task_files=$(find "$handoff_dir" -maxdepth 1 -type f \( -name 'TASK-BOARD.md' -o -name 'TASK-*.md' \) 2>/dev/null || true)
                            if [ -n "$task_files" ]; then
                                deny_reason="handoff/ 目录仍包含临时任务文件，必须在 tag 前清理。残留文件：
$task_files
请先删除 handoff/ 下的 TASK-BOARD.md / TASK-*.md，再执行 git tag。"
                            fi
                        fi
                    fi
                fi
            fi
        fi
    fi
fi

# ── Gate 2: git commit message format ────────────────────────────
if [ -z "$deny_reason" ] && printf '%s' "$cmd" | grep -qE 'git[[:space:]]+commit[[:space:]]+'; then
    # Only check if there's a -m flag with a message
    # Skip if it's just git commit (no -m, will open editor)
    if printf '%s' "$cmd" | grep -qE '\-m\b'; then
        # Extract commit message(s) from -m "..." or -m '...'
        messages=$(printf '%s' "$cmd" | python3 -c "
import sys, re
cmd = sys.stdin.read()
# Find all -m '...' or -m \"...\" patterns
msgs = re.findall(r'-m\s+[\"' + \"'\" + r'](.*?)[\"' + \"'\" + r']', cmd)
if msgs:
    # Use the first message as the subject line
    print(msgs[0].strip())
" 2>/dev/null || echo "")

        if [ -n "$messages" ]; then
            # Check Conventional Commits format: type(scope): subject or type: subject
            # Standard types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
            if ! printf '%s' "$messages" | grep -qE '^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?:[[:space:]]+.+'; then
                deny_reason="git commit message 不符合 Conventional Commits 格式。必须为 'type(scope): subject' 或 'type: subject'。\n标准 type: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert\n当前 message: $messages"
            fi
        fi
    fi
fi

# ── Output result ────────────────────────────────────────────────
if [ -n "$deny_reason" ]; then
    python3 -c "
import json, sys
reason = sys.argv[1]
print(json.dumps({'decision': 'deny', 'reason': reason}))
" "$deny_reason" 2>/dev/null
    exit 2
fi

exit 0
