DiaryDB の日次記録を集約し、リポジトリ別の週報を週報DBに作成する。

## 引数
- 引数なし: 今週（Asia/Tokyo の月曜〜金曜）を対象にする。
- `$ARGUMENTS` に `YYYY-MM-DD YYYY-MM-DD`（開始 終了）が渡された場合はその期間を対象にする。

## 識別子
- DiaryDB data source: `collection://35c483a9-a896-80cf-b562-000b544310e9`
- 週報DB data source: `collection://380483a9-a896-8018-b770-000b52a91825`
  - スキーマ: `名前`(title) / `開始日`(date) / `終了日`(date)。本文は子ブロックで表現する。

## 手順

1. 対象期間を確定する。
   - 引数なしなら現在日(Asia/Tokyo)を含む週の月曜〜金曜を `開始日`/`終了日` とする。
   - JST取得は PowerShell の `[System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::UtcNow, "Tokyo Standard Time")`。

2. 期間内の日次エントリを DiaryDB から集める。
   - `mcp__claude_ai_Notion__notion-search` を `data_source_url: collection://35c483a9-a896-80cf-b562-000b544310e9`、query に期間内の各日付(YYYY-MM-DD)を指定して検索し、該当ページ(`Name` が期間内の YYYY-MM-DD)を特定する。
   - 各ページを `mcp__claude_ai_Notion__notion-fetch` で取得し、bulleted_list_item の本文（`HH:MM [#sid] [<repo>] <要約>` 形式）を収集する。

3. **リポジトリごとに集約する**。
   - 各エントリ冒頭の `[<repo>]` ラベルでグルーピングする（ラベルは `/diary` で必須化済み）。
   - `[<repo>]` が無い・`[repo不明]` のエントリは、PR番号/WI/ブランチ/変更ディレクトリから repo を補完する。確定できなければ末尾に「## 要確認（repo未特定）」セクションを設けてそのまま列挙し、勝手に断定しない。
   - 同一 repo 内で重複・継続作業（同じPR/WIの複数日エントリ）は1項目にまとめ、最終状態を反映する。

4. 週報本文を Notion Markdown で構成する。
   - repo を `## <repo名>` の見出しにする。
   - 各見出し直下に1行のサマリ、続けて要点を `- **テーマ(WI/PR)**: 内容` の箇条書きにする。
   - 技術的事実（PR番号・SHA・WI・計測値）は日記から転記し、推測で補わない（不明は「要確認」と明示）。

5. `mcp__claude_ai_Notion__notion-create-pages` で週報DBにページを作成する。
   - parent: `{ type: "data_source_id", data_source_id: "380483a9-a896-8018-b770-000b52a91825" }`
   - properties: `{ "名前": "YYYY-MM-DD〜MM-DD 週報", "date:開始日:start": "YYYY-MM-DD", "date:終了日:start": "YYYY-MM-DD" }`
   - content: 手順4で構成した本文。
   - 同一期間のページが既にあれば（手順2と同様に週報DBを検索）新規作成せず `mcp__claude_ai_Notion__notion-update-page` で更新する。

完了したら作成/更新したページURLと、リポジトリ別の要約を表示する。
