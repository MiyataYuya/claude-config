#!/usr/bin/env bash
# PreToolUse hook (Agent|Task): deny subagent spawns without an explicit model.
# 根拠: effort-calibration ルール「spawn 毎に model を明示的に選ぶ」— 未指定 =
# main 継承 = 最高額。2026-07-21/22 に 2 セッション連続で全 agent が Fable
# 継承になったため機械的に強制する。fork は model 指定不可のため対象外。
# jq 失敗時は fail-open（allow）— フックの不具合で作業を止めない。

payload=$(cat)
model=$(printf '%s' "$payload" | jq -r '.tool_input.model // empty' 2>/dev/null) || exit 0
subtype=$(printf '%s' "$payload" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null) || exit 0

if [ -z "$model" ] && [ "$subtype" != "fork" ]; then
  jq -n '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: "Agent spawn に model が未指定です（未指定 = main 継承 = 最高額）。用途に合わせて明示してください: 転記/grep/網羅 Explore/機械作業 = sonnet、中間的な調査・実装 = opus、設計判断・レビュー・auth/security = fable。基準: ~/.claude/docs/effort-calibration.md（実装オーケストレーション節）"}}'
fi
exit 0
