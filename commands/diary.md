このセッションで行った作業をNotionの日記DBに記録する。

## 手順

1. このセッションの会話内容から、実際に達成したことを1-2行の日本語で要約する。
   - **冒頭に必ずリポジトリ名とコンテキストラベルを付ける**: `[<repo>] <機能/Epic/モジュール>` の形式。どのリポジトリの作業かを必ず明記する（複数リポジトリにまたがる場合はエントリを分けるか各項目にrepo名を付ける）。
     - リポジトリ名は git remote / 作業ディレクトリ名 / ブランチ・PRのコンテキストから特定する。**推測で曖昧な場合は確定するまで `[repo不明]` と明示し、勝手に断定しない**（後で振り分け不能になるのを防ぐため）。
   - コンテキストラベルは機能/Epic/モジュールを示す（例: 'DIA画像取り込み', 'SSO', 'デプロイ'）。ブランチ名、PR名、変更対象ディレクトリ、ユーザーの発言から特定する。
   - 良い例: '**[TotalSCOPE-Viewer] 歯軸計測(WI612)**: bone-tangentのvertical fallback全廃、弧長リサンプリング+PCAへ置換'
   - 悪い例（repo名なし）: 'scanner の flattenAndResolveCollisions 適用'
   - 作業がなかった場合は '（作業なし）' とする。

2. `mcp__claude_ai_Notion__notion-search` で今日の日付 (YYYY-MM-DD) をDiaryDBから検索する。
   - query: 今日の日付 (YYYY-MM-DD)
   - data_source_url: `collection://35c483a9-a896-80cf-b562-000b544310e9`
   - page_size: 5
   - filters: {}

3. ページがなければ `mcp__claude_ai_Notion__notion-create-pages` で作成する。
   - parent: { data_source_id: "35c483a9-a896-80cf-b562-000b544310e9" }
   - pages: [{ properties: { Name: "YYYY-MM-DD" } }]

4. `mcp__claude_ai_Notion__notion-update-page` で今日のページに bulleted_list_item を追加する。
   - 形式: `HH:MM <要約>`
   - 時刻は現在時刻 (Asia/Tokyo)

完了したら追加した内容を表示する。
