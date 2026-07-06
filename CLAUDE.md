@~/.codex/AGENTS.md

<!-- 個人ルールの単一ソースは import 元 ~/.codex/AGENTS.md（AGENTS.md）。Claude/Codex で挙動を揃えるため、共通ルールはそちらに書く。本ファイルには Claude Code 固有事項だけを追記する。 -->

## Claude Code 固有
- 共有の個人ルールは上の import（`~/.codex/AGENTS.md`）に集約。重複させない
- パス固有ルールは `~/.claude/rules/`、反復ワークフローは skills を使い、常時ロードの本ファイル / AGENTS.md を膨らませない（長いと adherence が下がる）
