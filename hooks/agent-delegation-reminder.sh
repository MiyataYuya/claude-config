#!/usr/bin/env bash
# UserPromptSubmit hook: 毎回のユーザープロンプトで ooda-loop:operate の運転規律を強制する。
# リマインダーを additionalContext として注入する（プロンプト本文の書き換えではない）。
# jq失敗はfail-open。

msg="ooda-loop:operate skill を呼び出し、その手順に従ってください。雑談・単純な質問であっても省略しないでください。"
jq -n --arg m "$msg" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $m}}' 2>/dev/null
exit 0
