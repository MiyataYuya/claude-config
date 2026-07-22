#!/usr/bin/env bash
# PostToolUse hook: main 側 mutation の連続回数を session 単位で数え、閾値超で
# sonnet subagent への委譲を促す nudge を注入する。
# 根拠: effort-calibration「main で機械作業3連続 = 委譲」/ memory: model-delegation-mandate。
# 既存 require-agent-model.sh は「spawn 時の model 未指定」しか捕捉できず、
# 「そもそも委譲しない omission」を捕まえられない — その穴を埋める。
#
# 設計:
#  - Edit/Write/NotebookEdit と git commit|push|merge|rebase|reset、drizzle-kit push|migrate、
#    Azure DevOps の write 系 MCP を mutation とみなし増分。
#  - investigation(read/grep/diff/status/switch/rev-parse/ls-remote 等) は数えない。
#  - Agent|Task spawn が観測されたら counter を 0 リセット（委譲が起きた）。
#  - nudge は block ではなく additionalContext/systemMessage の注入のみ（作業は止めない）。
#  - jq 失敗や書き込み不可は fail-open（exit 0）。フックの不具合で作業を止めない。

payload=$(cat)
sid=$(printf '%s' "$payload" | jq -r '.session_id // "nosid"' 2>/dev/null) || exit 0
tool=$(printf '%s' "$payload" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
state="${TMPDIR:-/tmp}/claude-mainmut-${sid}"

# 委譲観測 → リセット
case "$tool" in
  Agent|Task)
    printf '0' > "$state" 2>/dev/null
    exit 0
    ;;
esac

# mutation 判定
is_mut=0
case "$tool" in
  Edit|Write|NotebookEdit|MultiEdit)
    is_mut=1
    ;;
  Bash)
    cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null)
    if printf '%s' "$cmd" | grep -Eq '(^|[;&|] *|&& *)git +(commit|push|merge|rebase|reset)( |$)|drizzle-kit +(push|migrate)'; then
      is_mut=1
    fi
    ;;
  mcp__azure-devops__repo_create_*|mcp__azure-devops__repo_update_*|mcp__azure-devops__repo_reply_*|mcp__azure-devops__repo_vote_*|mcp__azure-devops__wit_create_*|mcp__azure-devops__wit_update_*|mcp__azure-devops__wit_add_*)
    is_mut=1
    ;;
esac

[ "$is_mut" -eq 0 ] && exit 0

# increment（非数値は 0 に矯正）
count=$(cat "$state" 2>/dev/null || echo 0)
case "$count" in ''|*[!0-9]*) count=0 ;; esac
count=$((count + 1))
printf '%s' "$count" > "$state" 2>/dev/null

if [ "$count" -ge 3 ]; then
  msg="⚠ main で mutation を ${count} 連続実行しています。以降の機械的実行（edit/test/commit/push/定型コメント投稿）は sonnet subagent へ委譲を検討してください。判断（auth/security の妥当性・どの指摘を修正/却下するか）は main に残す。基準: ~/.claude/docs/effort-calibration.md（実装オーケストレーション節）/ memory: model-delegation-mandate。subagent を spawn すれば counter はリセットされます。"
  jq -n --arg m "$msg" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $m}, systemMessage: $m}' 2>/dev/null
fi
exit 0
