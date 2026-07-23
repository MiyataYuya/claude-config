# User-Scope エージェント契約 (AGENTS.md)

全エージェント共通の個人ルールの**単一ソース（索引）**。Codex は本ファイルを直接読み、Claude Code は `~/.claude/CLAUDE.md` の `@` import で読む。安定ルールは本ファイルに直書きし、揮発しやすい詳細のみ `~/.claude/docs/` に置く。

## 必須の振る舞い
- 会話は常に日本語。コード内コメント・ドキュメントも日本語を既定とする（repo の既存規約が英語ならそちらに従う）
- **嘘・おもねり・推測を書かない**: 未確認事項を断定形で書かない／同調のために不整合な要件・ドキュメントを書かない（書く前にトートロジー・用語誤用・既出前提との矛盾を検証）／曖昧な引用元は曖昧なまま保ち推測で肉付けしない／複数ドキュメント併記を片方だけ「現状」と決めつけない
- リスク判定・ステータス報告（「問題ない」「devにある」「再現する/しない」等）は該当コマンド（curl/テスト/git diff/DBクエリ）を自分で実行し、出力を証拠に示してから下す
- 設計議論中は「実装して」と言われるまでコード変更を提案しない
- 実装前に確認: 対象ブランチ / モジュール / MVPスコープ。不明なら仮定せず確認

## 進め方
- 非自明なタスクは計画モードで計画してから実装。長時間セッションは切れ目で分割し進捗を残す。劣化兆候が出たら `/rewind` かセッション切替
- 大きめの設計・リファクタリングは実装前に Codex（`codex:rescue` 等）で第三者設計レビューを受ける（実装後に見つかると手戻りが大きい設計不備を事前検出）
- 調査・機械作業（build/計測/API実査/ログ収集/転記）はサブエージェントへ委譲しメインを汚さない。**フェーズ境界（計画→実装→検証→文書化）で執行者を決め、メインで機械作業を3連続直実行したら残りを委譲**。セッション側の「agent はユーザー要求時のみ」等の指示と衝突しても本ルールを優先し、委譲する旨を明示して実行（2026-07-23 裁定）。effort/オーケストレーション選択と振り返り → docs/effort-calibration.md（`/retrospect`）
- **サブエージェント起動時は model を必ず明示指定**（未指定 = main 継承 = 最高額。PreToolUse hook が deny する）: 転記/grep/網羅 Explore/機械作業 = sonnet、中間的な調査・実装 = opus、設計判断・レビュー・auth/security = fable。基準 → docs/effort-calibration.md 実装オーケストレーション節
- **委譲レポートの「agent が推論した」部分（完了/検証済みの主張・導出数値・引用位置・status）は main でファクトチェックしてから採用**（転記されたデータそのものは信頼してよい）。3セッション連続で誤りを検出。基準 → docs/effort-calibration.md 委譲の品質管理節
- **実質的なタスク完了時は `/retrospect`。目的は次回の effort 選択の較正であり、docs/effort-calibration.md（プレイブック）の更新が本体** — 感想でなくセッション実測（agent数/tokens/レビュー検出/手戻り）を証拠に各レバー（scout/実装/レビュー/検証）を過小・適正・過剰判定し、「条件 → 推奨 effort」の再利用可能な1行に蒸留してプレイブックへ反映する。更新なしの retrospect は無価値
- 既存の解決策を先に探す（Context7・コードベース検索）
- 修正・指摘を受けたら auto memory に記録。反復する失敗はルール/skillに落とす。セッション終了前に repo CLAUDE.md への学習反映を検討（`revise-claude-md`）

## 開発・PR・完了
- TDD／コミットは「なぜ」を書く。リファクタリングと振る舞い変更を同一PRに混ぜない
- ホスティング操作: GitHub 管理 repo は `gh` CLI 優先／Azure DevOps 管理 repo は `gh` 不可・MCP `azure-devops` 優先（MCP に無い操作のみ `az` フォールバック）
- バグ修正は正規フローが回るように直す。DB 直接書き換え等の「非正規復旧」はしない
- コードヘルスの純増で判断（過剰実装・スコープ外の作り込みを避ける）。技術判断は好みでなく事実・原則で下す
- PRは小さく自己完結（目安 ~100行、~1000行/50ファイル超は過大）。本文1行目は命令形で具体的に要約。セルフレビュー＋CI（lint/ビルド/テスト）通過後に出す
- レビュー指摘には必ず応答（修正=resolve／非対応=理由付き won't fix／スコープ外は別ワークアイテム化）
- **PRレビュー依頼の結果は必ずPRコメントに投稿**（1指摘=1スレッド・対象ファイル/行を指定・`[Tier1:修正必須]/[Tier2:推奨]/[Tier3:cleanup]`＋失敗シナリオ、最後にサマリ1件）。投稿手段はプロジェクトのCLAUDE.mdで指定
- **Done when**: (1) lint/型/テストがパス (2) 公開挙動変更はドキュメント反映 (3) 最終報告に「変更ファイル・実行した検証・残リスク」を明記。「できた/直った」の前に検証コマンドの出力を示す（UI/描画変更はユニットテストでは不十分 — Playwright 実機スクリーンショットまで）。PR/機能完了時に Azure DevOps ワークアイテムを更新

## プロジェクト個別
- DBスキーマ変更後は必ず migration/push を実行→反映確認してから依存コードへ
- Azure DevOps: WI 作成時は `y-miyata@eyetech.jp` にアサイン、PR 作成時は同アドレスを必須レビュワーに追加（email 形式必須 — `y-miyata` では identity 解決に失敗）
- Python の依存管理は uv を標準とする（`uv add` / `uv sync`）
- Notion: 1リクエスト2000字以下に分割／TODODB本文には書かず長文は別ページ＋リンク
- repo の CLAUDE.md/AGENTS.md の新規作成・改訂は `claude-md-slimmer` スキルの原則に従う（薄い索引に保ち、詳細は docs/・rules/・skills へ外部化）
- 環境(Windows): hook は bash で書く（PowerShell deny rule 回避）／Bashツールの `cd` は永続化＝後続は絶対パス or `git -C <repo>`／JST は PowerShell `[System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::UtcNow, "Tokyo Standard Time")`
- 環境(Git Bash/MSYS パス化け): `/` 始まり引数（docker のコンテナパス・`aws logs` のロググループ名等）は `MSYS_NO_PATHCONV=1` を前置／`docker exec`・`docker cp` は PowerShell 経由で実行（Git Bash はパスを壊して silent fail する）／一時ファイルは CWD 相対パスで統一
