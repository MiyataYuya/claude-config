# Effort Calibration Playbook

タスクにかける effort の選択則: `/effort` レベル・オーケストレーション（solo / subagents / Workflow / ultracode）・モデル・レビュー深度・検証。`retrospect` スキルがタスク末に更新する。

**使い方**: 実質的なタスクの開始前にスキムし、task-type + risk でマッチさせる。証拠に基づくデフォルトであってルールではない — 理由があれば上書きしてよい。各ルール末尾の `(日付 事例ID)` が根拠。詳細な事例ナラティブは本ファイルの git 履歴（claude-config repo、2026-07-16 の統合以前）にある。

## レバー別デフォルト

「effort」は1つのダイヤルでなく独立したレバーで考える — 重いレビューと軽いスカウトが同居するタスクもある。

- **Scout/理解**: solo のターゲット検索がデフォルト。blast radius が本当に未知かつ広い時だけ並列 subagent へ。根本原因が既に文書化済みなら再発見しない。
- **実装**: 変更に right-size。ロジックがあれば TDD。gold-plating とスコープ膨張を避ける。
- **レビュー**: リスクに比例。孤立・低リスクはセルフレビュー、共有コード / auth・security・data / 不可逆な変更には adversarial パスを追加。
- **検証**: 主張に見合う証拠。ユニットテストは常に、挙動/UI 変更は実アプリ / Playwright 検証をしてから done を主張。

## スカウト / 着手前

- **根本原因が既に文書化済み（CLAUDE.md / memory / 直近コミット）→ scout は solo grep で足りる**。理解用 Workflow（6 agents / ~510k tokens）は過剰だった *(2026-07-01 Bug#695)*
- **「Xが壊れてる / できない」という依頼 → 実装前に真の目的をブレインストーミング**。文字通りに作ると誤ったものを作り、潜在バグも踏む。設計がサードパーティ仕様に依存するなら公式 doc / probe を1回引いてから *(2026-07-13 WI#754: 真の要件は Entra ログインで設計が全転換、Cognito alias 制約も doc で先取り)*
- **外部システムの数値・能力の上に設計/投資する前に、その前提を安いプローブで直接確認**。ベンチ数値は「ベンチが通った層 vs 本番経路」の差分を列挙し、未通過層があれば仮説扱いで本番経路 E2E を1回先行 *(2026-07-10 ADR-0003: bench 75s vs 実E2E 236s で同日再設計)*。新ランタイム移植はハード上限（メモリ / op coverage）を30分のダミープローブで先に *(2026-07-15 LiteRT: 2GB heap 上限を知らずに変換パイプへ ~1.5M tokens 投資)*
- **スプリントトリアージ → 各 WI を現行コード + live probe で検証してから着手判断。Description 以外の全フィールド（ReproSteps / notes）を読む** *(2026-07-14 Sprint6: 5/11 WI が既修正、probe が残存バグ #760 も発見。ReproSteps 未読で2回手戻り)*
- **探索を main が既に吸収済みなら計画も main で書く** — Plan agent は新規リサーチが要る時だけ *(2026-07-10)*

## 実装オーケストレーション

- **仕様済み・局所的なバグ修正バッチ → solo + TDD + 1修正1コミット、orchestration 不要**。agent は広く未知の blast radius に温存 *(2026-07-01 WI×6; 2026-07-14 Sprint6: 10 WI / 5 PR を solo + Explore 1体で出荷欠陥ゼロ)*
- **コード込み計画（SDD）からのフル機能 → haiku 転記 implementer + sonnet 統合、浮いた予算をトップモデル whole-branch review 1回 + live 検証に集中投下**。計画コードが新規執筆なら転記タスクのレビューは「計画コードの初レビュー」なので省略不可 *(2026-07-06 WI#727; 2026-07-09 perf-003; 2026-07-15 LiteRT)*
- **長時間 ops / 計測セッション → コンテキスト圧迫の前にオーケストレーターモードへ**。フェーズ境界ごとに執行者を選び、main で機械作業3連続 = 違反（AGENTS.md に常設ルール化済み — 一度の是正では定着しない）。計測 agent は SendMessage 再開が新規 spawn に勝つ。時間制約つき単発の証拠取得だけが main 例外 *(2026-07-09〜10 oral-v2; 2026-07-16 でも DB probe ループ 5× main の軽微違反)*
- **~10 entity 規模の live-API provisioning → main が契約を読み、全呼び出しを冪等スクリプト1本に**。スクリプト化そのものが3連続機械ルールへの準拠。契約が複数ファイルに散る / デバッグ2周超で sonnet へ委譲 *(2026-07-10)*
- **大規模削除 / revert の委譲 → main が先に WHEN/WHY（ADR / commit history）を確定してからプロンプトを書く**（誤前提は誤ドキュメントになる）。受領後は削除シンボルの残参照 grep + 引用ドキュメントの実在確認 — `node --check` に runtime ReferenceError は見えない *(2026-07-10 SQS除去)*

## レビュー

- **幅はリスクに比例させ、デフォルトで最大化しない。共有 / auth / security / data に触れる変更は adversarial review 層を必ず残す** — ultracode の限界価値はこのレビュー層そのもの（TDD と実アプリ検証は effort レベルに関係なく行われる） *(2026-07-01 Bug#695: review が出荷寸前のリグレッションを検出、understand 側は過剰)*
- **巨大 PR → production / security ファイル群に correctness+cleanup 二重パス、テスト専用ファイル群は軽量 cleanup 単パス** *(2026-07-01 PR785: 86 agents 中テスト群17 findings に Tier-1/2 ゼロ、production 群は migration 破壊と email_verified バイパスを検出)*
- **小〜中規模の well-scoped PR → 領域分割 plain-text finder 3体 + main で solo 検証。8-angle フル機構に展開しない** *(2026-07-02 PR789: ~170k tokens で実 Tier-2 2件検出)*
- **既存フローを雛形にした新機能 → 「sibling フロー規約との一致」レンズを明示追加**（txn 境界 / audit / validation の形を雛形と diff）。汎用 correctness / cleanup レンズでは一貫性欠陥は見えない。小規模転記機能ではタスク単位レビューを軽くし、whole-branch + 規約比較パスに再投資 *(2026-07-13 WI#754: 自前6+1レビュー全通過後、規約比較レンズだけが Tier-2 2件を検出)*
- **レビュー指摘への対応 → 各主張をコードに当てて検証（盲従も盲反発もしない）。指摘 ≤6-8 件は solo 検証、超えたら領域別 plain-text agent に委譲**。作者の「修正済み・X は deferred」返信は git show + 実スイート再実行 + tracker の WI 実在確認で裏取り *(2026-07-01/02 PR785 15件・PR789 6件: 検証が「修正済み」の穴を2件暴いた)*

## 検証

- **orchestration が薄い時ほど verify を厚く**。修正ごとの証拠ループ（curl matrix / network trace / 2幅スクリーンショット）が実問題（stale module、phantom lint）を捕まえた層 *(2026-07-14 Sprint6)*
- **auth / session の timing バグ（ユニットテスト再現不能）→ 修正前に runtime 証拠（network + storage 状態）を集める。自己検証できないログインは user live-test まで done を主張しない** *(2026-07-01 WI#701: もっともらしい forceRefresh 案は誤りだった)*
- **マージコンフリクト解消後 → 全スイート実行**。テキスト的マージ可能 ≠ 意味的正しさ *(2026-07-02 PR789)*
- **インフラ / DB 再構築後 → 全 endpoint スイープ + クライアント層（SPA / 静的アセット）の世代確認**。現行ソースに無い UI 文字列 = 古いバンドルの指紋。バックエンドの ground truth（job done → 結果行あり → API 200）を先に確定してから配信物を疑う *(2026-07-10: 29 endpoint スイープがプロセス即死バグ発見; 2026-07-16 oral-vpc-v2: 正常パイプライン + stale SPA で機能全損に見えた)*
- **tenant / 認可境界の不安 → コードリーディングで答えず live probe を多面で**（tenantId param / header / no-auth / バイナリ配信パス）。JSON API と別経路のファイル配信ルートが最有力の漏れ箇所 *(2026-07-10: authMiddleware 前に登録された /uploads が他院X線を無認証配信)*
- **もっともらしい出力 ≠ 動作。定数入力 + リファレンス値比較で判定** — alloc 失敗を握り潰してゴミを返すランタイムがある *(2026-07-15 LiteRT)*
- **見た目の好み系フィードバック（色 / サイズ / 視認性）→ 定数チューニングでなく user-setting 化（既存 settings-hook パターン）を第一手**。UI 反復はイテレーション毎スクリーンショット必須。subjective UI は仕様が動くので commit は小さく決定単位で *(2026-07-14 WI#750: vivid 定数案は却下、設定パネル化は即受理)*

## Ops / デプロイ

- **本番と同じ経路をウィンドウ前にローカルで1回リハーサル**: DB cutover は本番 dump restore に対する migration 実行、リリースは `docker build -f Dockerfile.prod`（host-tree のゲートはビルドコンテキスト欠陥を見ない）。ガイド付き ops セッション自体は solo / 0 agents が right-size（user が書き込み実行、agent は read-only 検証と証拠ベース診断） *(2026-07-06 WI#690: window 内サプライズ3件すべて手元の dump で発見可能だった; 2026-07-14 v1.5.0 欠番; 2026-07-16 snapshot restore ~4 apply 往復)*
- **live-service mutation（terraform apply / cognito・az ad 更新 / modify-db-instance / ECS run-task 等）は承認済みタスク中でも classifier にブロックされる → 最初から `!` ハンドオフとして計画**。2分を超えうるコマンドは background-wrap（`(cmd > log 2>&1 &)`）。**user 実行ステップは毎回 read-back 検証 — 「done」テキストを信じない** *(2026-07-13 #754 prod: 3ステップ中2つに初回不備、「OK」返答1件が未適用; 2026-07-09〜16 で block 再現多数)*
- **リモートビルドの exit code を pipe に食わせない**: `; echo EXIT=$?` か pipefail *(2026-07-14: 失敗ビルドが exit 0 で成功通知)*
- **ツールの認証が突然壊れたら、2回目の失敗で credential-source 設定（~/.aws/config 等）を読む**。壊れた認証経路の再試行を繰り返さない *(2026-07-16: 動く credential_process profile を横目に ~5回リトライ)*

## 委譲の品質管理

- **委譲レポートは「agent が推論した」セクション（status / ops-notes / 推奨 / 導出数値 / 引用位置）をセッションの ground truth へファクトチェック**。転記されたデータ表は間違わない。数値ドキュメント（solo 執筆含む）は計算スクリプト1本から全セル導出し、独立再計算 + 引用照合レビューを1回だけ買う *(2026-07-09 perf-002〜004: 3本中2本に事実ドリフト、二重丸め 24.85→24.9 が7箇所へ伝播)*
- **Explore fan-out に複雑な構造化出力スキーマを付けない** — 失敗率 ~50%。plain-text なら 3/3 成功。落とすのはスキーマであって fan-out ではない *(2026-07-01)*
- **memory にある既知の落とし穴（MSYS path 等）は ops subagent への dispatch 毎に転記** — 1件の省略が計測1ラウンドを無駄にした *(2026-07-09 perf-003)*
