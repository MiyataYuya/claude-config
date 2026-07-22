#!/usr/bin/env bash
# PostToolUse hook (ExitPlanMode): 計画→実行の境界で執行者割当を先に決めさせる。
# 根拠: AGENTS.md「フェーズ境界ごとに執行者を選ぶ」/ effort-calibration 実装オーケストレーション節。
# 不可視な per-op カウンタと違い、計画承認は salient で数少ない境界なので発火が確実。
# nudge のみ（block しない）。jq 失敗は fail-open。

payload=$(cat)
tool=$(printf '%s' "$payload" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
[ "$tool" = "ExitPlanMode" ] || exit 0

msg="計画が承認されました。実行に入る前に、最初の TodoWrite 項目として『各フェーズの執行者割当』を明記すること: 機械的実行（edit/test/commit/push/転記/grep網羅）= sonnet subagent、判断・設計・auth/security・レビュー = main。基準: ~/.claude/docs/effort-calibration.md。"
jq -n --arg m "$msg" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $m}, systemMessage: $m}' 2>/dev/null
exit 0
