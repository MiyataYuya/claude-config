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
- **スプリントトリアージ → 各 WI を現行コード + live probe で検証してから着手判断。Description 以外の全フィールド（ReproSteps / notes）を読む** *(2026-07-14 Sprint6: 5/11 WI が既修正、probe が残存バグ #760 も発見。ReproSteps 未読で2回手戻り; 2026-07-21 WI793)*
- **ハーネス自身の能力/可否（「Claude Code に機能 X はあるか」「X をスケジュール/無人実行できるか」）が推奨をゲートする時 → 一般 Sonnet にローカルファイル推論させず、claude-code-guide（Opus・公式doc引用）へ最初から委譲**。回答は authoritative-doc 依存で、部分的なローカル証拠からの推論は機能クラスを丸ごと見落とす *(2026-07-24 auto-review-task: Sonnet が登録可否調査で Desktop Local scheduled task の実在を見落とし「cloud不可=Task Scheduler唯一」と誤結論→user が指摘→claude-code-guide/Opus が実在を doc で確認して訂正。前セッション計画が実は正しかった)*
- **探索を main が既に吸収済みなら計画も main で書く** — Plan agent は新規リサーチが要る時だけ *(2026-07-10)*
- **フォーマット/URL/共有シグネチャの変更を user に「今 PR でやる」と諮る前に全 consumer を grep で trace**（server 生成箇所だけでなく client 側で自前組み立てするコンポーネント・親ページも）。過小見積もりは着手後の revert 手戻りになる *(2026-07-17 PR826-review: media URL 変更を「3-4箇所」と見積もり user 承認→実際 8+ファイル+Web UI コンポーネント2+親ページ2、部分実装後に全 revert して別 WI 化; 2026-07-21 WI802)*
- **「動作を見たい/検証して」系が本番 footprint（設定変更・テストデータ・コスト・EC2起床）を伴う時 → 先に env 現況を probe してから footprint を列挙し fork ごと sign-off**。recalled memory の creds/データはリビルドで陳腐化する（着手前に実在確認）。実データ隣接なら特に *(2026-07-22 WI803/804: 「デプロイして動作を見たい」が perf-005 相当のフル計測に発展。11日前 memory のデモ資格は v1スナップショット再構築で消滅、env は v1実データ54クリニックのコピーと判明。footprint(設定/テストデータ/再デプロイ)を4回の fork で都度 sign-off し過剰回避)*

## 実装オーケストレーション

- **仕様済み・局所的なバグ修正バッチ → solo + TDD + 1修正1コミット、orchestration 不要**。agent は広く未知の blast radius に温存。owner 決定済みの feature ペアも実装自体は solo TDD で足りる（計画フェーズの Explore/Plan agent と PR 前 cleanup パスに投資を寄せる） *(2026-07-01 WI×6; 2026-07-14 Sprint6: 10 WI / 5 PR を solo + Explore 1体で出荷欠陥ゼロ; 2026-07-21 WI803/804: 全 Edit 一発適用・初回テスト green・手戻りゼロ)*
- **コード込み計画（SDD）からのフル機能 → haiku 転記 implementer + sonnet 統合、浮いた予算をトップモデル whole-branch review 1回 + live 検証に集中投下**。計画コードが新規執筆なら転記タスクのレビューは「計画コードの初レビュー」なので省略不可 *(2026-07-06 WI#727; 2026-07-09 perf-003; 2026-07-15 LiteRT)*
- **トップモデル main は agent spawn 毎に model を明示的に選ぶ（未指定 = main 継承 = 最高額）**。grep+read の網羅転記 Explore・仕様確定後のテスト改修・N ファイル同型編集・ログ整形ループは sonnet へ。設計判断（Plan）・認可/セキュリティロジック・レビューだけ top model に残し、浮いた分を adversarial review 層に再投資 *(2026-07-21 WI802; 2026-07-24 WI810/811-cleanup: 14 spawn 全て model 明示・継承ゼロで良好、mechanical→sonnet/judgment→opus の切り分けも適正; 2026-07-24 lint削減63→15: 8 spawn 全 model 明示、triage/verify=Sonnet・fix/risky-fix=Opus・review=Fable の三層切り分け適正; 2026-07-24 auto-review-task: 8 spawn 全 model 明示・継承ゼロ、改稿=Fable/合成調査=Opus/機械編集=Sonnet は適正だが MCP-fetch+逐語転記の #1 を Opus にしたのは too-high〈Sonnet で足りた〉)*
- **独立した read-only 調査/計測 agent が2件以上（トラッカー照会・lint 計測・重い vitest 実行等）→ 1レスポンスで並列 dispatch**。重い1本（vitest ~17min）が軽い方のタダの傘になる。逐次は wall-clock を浪費するだけ *(2026-07-24 WI810/811 状態調査: ADO照会/git+lint/vitest を逐次実行、vitest 17min の裏で他2件を回せた — tier でなく並列化の見落とし)*
- **挙動中立の大規模機械変換（className scrub・dead-code 削除・AST/ホワイトリスト変換）→ Opus 実装**（Sonnet は誤爆リスクで too-low、Fable は過剰）。検証は build + Playwright 実機比較で足り、Fable adversarial review は不要（auth/security/design 非該当） *(2026-07-24: opus が print-hook `[class*="bg-white"]` 保持と `viewType==="thumbnails"` 誤爆を dry-run で捕捉、login 前後一致で挙動中立を実証)*
  - **対照: lint 修正が制御フローを変える（effect 削除 / ロジックの onChange 移設 / 時刻値スナップショット化）なら挙動中立でない → Opus 実装 + Fable adversarial review を1回買う**（review には per-line disable の理由照合と shadow 検査〈`set-state-in-effect` は 1 effect につき先頭1件しか診断しない〉を含める）。Opus fix の自己検証（eslint 0 + tsc 0）は振る舞いドリフトにも lint 自身の死角（モジュールレベル関数内の `Date.now`）にも盲目 *(2026-07-24 lint削減63→15: Fable が TemplateSettings の Select deselect→scope 空文字化経路と ApiToken の style/label 時刻不整合〈expiryTextStyle がモジュール関数で lint 非検出のまま live Date.now〉を検出、Opus fix 4体の eslint-0/tsc-0 自己検証は素通り; 2026-07-24 lint残15→0: Fable が AuthProvider の token 二重読取レースと実装報告の disable 数え誤りを検出、Opus の等価論証15件は全件支持で手戻りゼロ)*
- **長時間 ops / 計測セッション → コンテキスト圧迫の前にオーケストレーターモードへ**。フェーズ境界ごとに執行者を選び、main で機械作業3連続 = 違反（AGENTS.md に常設ルール化済み — 一度の是正では定着しない）。計測 agent は SendMessage 再開が新規 spawn に勝つ。時間制約つき単発の証拠取得だけが main 例外。**バースト実行+ポーリング/ログ収集+集計 one-off が委譲単位** *(2026-07-09〜10 oral-v2; 2026-07-16 DB probe ループ 5× main の軽微違反; 2026-07-22 WI803/804: 実機バースト計測を main で機械作業10+連続〈docker×2/ecr×2/tf plan×2/one-off×5/ログ収集/S3〉、委譲は Explore1体のみ — 再違反; 2026-07-22 PR832: コメント投稿6連続だがセッション指示が agent 禁止で委譲せず — この判断は 2026-07-23 裁定により撤回; 2026-07-23 npm-audit: 同じ衝突で委譲を選択し良好 — **user 裁定で「常設ルール優先・衝突しても委譲」に確定、AGENTS.md に明記済み**)*
- **~10 entity 規模の live-API provisioning → main が契約を読み、全呼び出しを冪等スクリプト1本に**。スクリプト化そのものが3連続機械ルールへの準拠。契約が複数ファイルに散る / デバッグ2周超で sonnet へ委譲 *(2026-07-10)*
- **大規模削除 / revert の委譲 → main が先に WHEN/WHY（ADR / commit history）を確定してからプロンプトを書く**（誤前提は誤ドキュメントになる）。受領後は削除シンボルの残参照 grep + 引用ドキュメントの実在確認 — `node --check` に runtime ReferenceError は見えない *(2026-07-10 SQS除去)*

## レビュー

- **幅はリスクに比例させ、デフォルトで最大化しない。共有 / auth / security / data に触れる変更は adversarial review 層を必ず残す** — ultracode の限界価値はこのレビュー層そのもの（TDD と実アプリ検証は effort レベルに関係なく行われる） *(2026-07-01 Bug#695: review が出荷寸前のリグレッションを検出、understand 側は過剰)*
- **認可漏れ / 脆弱性クラスタの修正 → 修正と同時に grep ベースの同型欠陥スイープ（or `/security-review` 軽量パス）を1回買い「未列挙の穴」を網羅する**。実機 curl matrix は列挙済みルートの挙動（404/401/403/200）は捕まえるがレビュー対象外ルートは見えない。スイープは死コード(削除カラム参照で 500)や別軸スコープの IDOR も surface する *(2026-07-17 WI#795: 6ルート修正時に adversarial 層をスキップ→網羅が grep 頼みに; 2026-07-17 PR826-review: レビューが突いた迂回2ルートは grep スイープで事前検出可能、同スイープで job-images 死コード500 と image-groups 別軸IDOR も発見)*
- **巨大 PR → production / security ファイル群に correctness+cleanup 二重パス、テスト専用ファイル群は軽量 cleanup 単パス** *(2026-07-01 PR785: 86 agents 中テスト群17 findings に Tier-1/2 ゼロ、production 群は migration 破壊と email_verified バイパスを検出)*
- **小〜中規模の well-scoped PR → 領域分割 plain-text finder 3体 + main で solo 検証。8-angle フル機構に展開しない** *(2026-07-02 PR789: ~170k tokens で実 Tier-2 2件検出)*
- **既存フローを雛形にした新機能 → 「sibling フロー規約との一致」レンズを明示追加**（txn 境界 / audit / validation の形を雛形と diff）。汎用 correctness / cleanup レンズでは一貫性欠陥は見えない。小規模転記機能ではタスク単位レビューを軽くし、whole-branch + 規約比較パスに再投資 *(2026-07-13 WI#754: 自前6+1レビュー全通過後、規約比較レンズだけが Tier-2 2件を検出)*
- **レビュー指摘への対応 → 各主張をコードに当てて検証（盲従も盲反発もしない）。指摘 ≤6-8 件は solo 検証、超えたら領域別 plain-text agent に委譲**。作者の「修正済み・X は deferred」返信は git show + 実スイート再実行 + tracker の WI 実在確認で裏取り *(2026-07-01/02 PR785 15件・PR789 6件: 検証が「修正済み」の穴を2件暴いた; 2026-07-17 PR824対応: 2件 solo 検証で「本番設定は変更済みで前提半減」まで発見; 2026-07-22 PR830: 「Fixed」thread の根拠 commit が実在せず、tracker WI#807 のみ実在)*
- **耐障害性パラメータ（リトライ上限 / タイムアウト / defer 窓）を触る修正 → 「全損時にユーザーが決着を知る最悪時間」を計算して SLA と突き合わせるレンズを1回通す。既存定数の流用は元の目的（インフラ保護 vs ユーザー体験）が転用先と一致するか確認** — 目的違いの流用は根拠を説明できない *(2026-07-17 PR824対応: インフラ用15分を defer 窓に流用、user 指摘で最悪決着 ~20分と判明し SLA 同値 120s へ是正; 2026-07-21 WI804: ECONNRESET を defer 対象に含めるかを OOM 全損シナリオで判定し owner 確認)*
- **ホットパス/配送系インフラ（ジョブディスパッチ・probe・リトライ配管）の solo 実装 → PR 前に multi-angle cleanup パス（/simplify 4体規模）を1回買う**。nits でなく設計級の無駄が出る層 — 二重 probe・無制限再 probe を efficiency 角が検出、プロトコル重複には 3/4 体が収束（~350k tokens で全採用級）。correctness review の代替ではない。**ただし抽出/移設が主の diff への再 /simplify は軽量で足りる**（moved code は既レビュー済 → efficiency/altitude 角は指摘ゼロになりがち、opus 4体は過剰） *(2026-07-21 WI803/804; 2026-07-22 ファクトリ抽出後の2回目 /simplify: efficiency/altitude ゼロ・簡素化2件のみ)*
- **識別子ベースの URL / パラメータ形式変更のレビュー → バリデーション正規表現を「DB カラム型の範囲」と「正準形の一意性」の2軸で live probe**（int4 上限超え・先頭ゼロ・空・異形式）。regex が通す値と列型が受ける値のギャップは未捕捉 DB 例外 = 500 になり、dev ビルドでは SQL 全文が露出する。コード読解では仮説までしか出ず、証拠は実機の 1 コマンドで取れる *(2026-07-22 PR832: `/^\d+$/` が int4 範囲未検査、実機 curl で 500 + クエリ露出を確認 — 本 PR 唯一の Tier1)*
- **PR 本文が検証内容（テスト数 / 実機 curl / E2E 差分）を詳細に主張している自 PR → 読解 agent を増やすより、その主張の再実行 + 境界入力 probe に予算を寄せる**。主張が正確な PR ほど finder の限界価値は下がり、未検証の入力空間だけが残る *(2026-07-22 PR832: solo 0 agents で Tier1×1 / Tier2×1 / Tier3×3、手戻りゼロ)*
- **固定N観点のレビューテンプレ → spawn 前に各観点の前提を main の1コールで棄却確認**（過去PRコメント観点なら PR 一覧1コール）。自リポジトリの PR は「PR head vs 作業ツリー+memory の既知修正」diff を最初の安いパスに — Tier1 級のドキュメントドリフトはこれだけで出る *(2026-07-17 PR824: 62k tokens が「初PRなので対象なし」の確認に消え、Tier1 は未コミット修正との diff で発見可能だった)*

## 検証

- **orchestration が薄い時ほど verify を厚く**。修正ごとの証拠ループ（curl matrix / network trace / 2幅スクリーンショット）が実問題（stale module、phantom lint）を捕まえた層 *(2026-07-14 Sprint6)*
- **auth / session の timing バグ（ユニットテスト再現不能）→ 修正前に runtime 証拠（network + storage 状態）を集める。自己検証できないログインは user live-test まで done を主張しない** *(2026-07-01 WI#701: もっともらしい forceRefresh 案は誤りだった)*
- **マージコンフリクト解消後 → 全スイート実行**。テキスト的マージ可能 ≠ 意味的正しさ *(2026-07-02 PR789)*
- **インフラ / DB 再構築後 → 全 endpoint スイープ + クライアント層（SPA / 静的アセット）の世代確認**。現行ソースに無い UI 文字列 = 古いバンドルの指紋。バックエンドの ground truth（job done → 結果行あり → API 200）を先に確定してから配信物を疑う *(2026-07-10: 29 endpoint スイープがプロセス即死バグ発見; 2026-07-16 oral-vpc-v2: 正常パイプライン + stale SPA で機能全損に見えた)*
- **tenant / 認可境界の不安 → コードリーディングで答えず live probe を多面で**（tenantId param / header / no-auth / バイナリ配信パス）。JSON API と別経路のファイル配信ルートが最有力の漏れ箇所 *(2026-07-10: authMiddleware 前に登録された /uploads が他院X線を無認証配信)*
- **もっともらしい出力 ≠ 動作。定数入力 + リファレンス値比較で判定** — alloc 失敗を握り潰してゴミを返すランタイムがある *(2026-07-15 LiteRT)*
- **ツール出力が不安定なセッション、または前セッション / compaction summary が「commit 済み・検証済み」と主張する作業 → done 報告・積み増しの前に git ls-remote/rev-parse/reflog + サーバ状態で実在を裏取り**。summary は捏造された「検証済み」結果（ハッシュ付き「push 成功」等）をそのまま事実として引き継ぐ。Edit 成功メッセージや要約の主張だけを信じない *(2026-07-17 PR826-review: FOR UPDATE 実装が破損時間帯にサイレント未適用、commit 前の git status で検出; 2026-07-22 PR830: 前セッションが捏造した commit 76c9c603 と「Fixed」thread を、git branch --contains の malformed object name / reflog 不在で露見)*
- **変更を書き換える live テスト（DB mutation / コンテナ再起動）を全 E2E・スイート実行と並行させない → phantom 失敗を自作し切り分けに浪費**。直列化するか E2E は最後にクリーン実行。スイートが広く落ちたらまず自領域の decisive spec を1本確認して in-scope か切り分ける *(2026-07-17 PR826-review: background Playwright 中に curl live テストでコンテナ再起動+DB変更、36 失敗の大半が干渉。決定信号=自領域スペック pass は早期に出ていた)*
- **常時赤の検証ゲート（共有 E2E / lint / テスト）での回帰判定 → 変更前ベースラインを先に1回実測し、diff + 差分のみ再実行で判定。総数では判定しない**。ローカル repo は `git archive HEAD:<subdir> | tar -x -C <tmp> && npm ci` が worktree 不要・作業ツリー無汚染で最速 *(2026-07-21 WI802; 2026-07-23 npm-audit: HEAD 実測で lint 47件 / test 7件が既存と判明、「更新が壊した」誤断を回避)*
- **実データ隣接環境の破壊的クリーンアップ（S3 rm / DB delete）→ 削除前に「自分のテストデータだけにマッチするか」を case-sensitive/完全一致で実査**。ツール既定の case-insensitive マッチが実データを巻き込む。テストデータは大文字小文字・命名を実データと衝突しない形にしておく *(2026-07-22 WI803/804: `Select-String` の既定 case-insensitive が実患者 P0001 を誤ヒット〈テストは小文字 p0001〉、case-sensitive 化で自分の31件だけに限定して回避)*
- **依存解決 / ビルド環境の破壊的操作（lockfile・node_modules・キャッシュ削除）→ scratchpad の clean-room で先に再現し、成功した clean-room の前提条件を漏れなく本体へ転写する**。probe が成功した理由そのもの（空の node_modules 等）が手順の一部 *(2026-07-23 npm-audit: clean-room で 0 vulns 確認済みなのに本体は lockfile だけ削除して失敗 — npm は既存ツリーから再解決するため1往復手戻り)*
- **依存巻き戻し2仮説が反証された描画ループ/ハング → 依存二分を打ち切り、当該ライブラリ site を直接計測**（node_modules パッチ + バンドルキャッシュ削除 + ブラウザコンソール読取）。二分は「どの依存でも再現」を積むだけで発生源を示さない *(2026-07-23 WI810/812: react/floating-ui/compiler 4+ 反証 ~1.5h の後、mergeRefs 計測1回で Mantine ScrollArea と犯人 ref を即特定)*
- **flaky なブラウザモードテスト（vitest browser 等）の結果を判断根拠にする時 → 合否はテスト名の出力行で判定、サマリ数値では判定しない**。ブラウザ死亡時は `1 passed (3)` が「残り未実行」を意味し、`tests 0ms` で内訳が消える *(2026-07-23 WI810/812: サマリ誤読で誤修正1件 revert、委譲 agent も stderr grep 判定で誤結論; 2026-07-24: `1 skipped(2)`/`tests 0ms` を verbose の per-test 行で判定し「収集は復元 ✓／Dental Editor が無限ループでハング」を切り分け)*
- **見た目の好み系フィードバック（色 / サイズ / 視認性）→ 定数チューニングでなく user-setting 化（既存 settings-hook パターン）を第一手**。UI 反復はイテレーション毎スクリーンショット必須。subjective UI は仕様が動くので commit は小さく決定単位で *(2026-07-14 WI#750: vivid 定数案は却下、設定パネル化は即受理)*

## Ops / デプロイ

- **本番と同じ経路をウィンドウ前にローカルで1回リハーサル**: DB cutover は本番 dump restore に対する migration 実行、リリースは `docker build -f Dockerfile.prod`（host-tree のゲートはビルドコンテキスト欠陥を見ない）。ガイド付き ops セッション自体は solo / 0 agents が right-size（user が書き込み実行、agent は read-only 検証と証拠ベース診断） *(2026-07-06 WI#690: window 内サプライズ3件すべて手元の dump で発見可能だった; 2026-07-14 v1.5.0 欠番; 2026-07-16 snapshot restore ~4 apply 往復)*
- **live-service mutation（terraform apply / cognito・az ad 更新 / modify-db-instance / ECS run-task 等）は承認済みタスク中でも classifier にブロックされる → 最初から `!` ハンドオフとして計画**。2分を超えうるコマンドは background-wrap（`(cmd > log 2>&1 &)`）。**user 実行ステップは毎回 read-back 検証 — 「done」テキストを信じない** *(2026-07-13 #754 prod: 3ステップ中2つに初回不備、「OK」返答1件が未適用; 2026-07-09〜16 で block 再現多数)*
- **長時間ランナー（リモートビルド / Playwright / テストスイート）の exit code を pipe に食わせない**: `; echo EXIT=$?` か pipefail、Playwright は `test-results/.last-run.json` の status が真実 *(2026-07-14; 2026-07-21 WI802)*
- **ツールの認証が突然壊れたら、2回目の失敗で credential-source 設定（~/.aws/config 等）を読む**。壊れた認証経路の再試行を繰り返さない *(2026-07-16: 動く credential_process profile を横目に ~5回リトライ)*

## 委譲の品質管理

- **委譲レポートは「agent が推論した」セクション（status / ops-notes / 推奨 / 導出数値 / 引用位置）をセッションの ground truth へファクトチェック**。転記されたデータ表は間違わない。数値ドキュメント（solo 執筆含む）は計算スクリプト1本から全セル導出し、独立再計算 + 引用照合レビューを1回だけ買う *(2026-07-09 perf-002〜004: 3本中2本に事実ドリフト、二重丸め 24.85→24.9 が7箇所へ伝播; 2026-07-17 PR824: agent の「改訂履歴が存在しない」主張が虚偽 — 外部投稿前の main 検証で捕捉; 2026-07-23 npm-audit: 転記は正確だが「両ファイル完全一致」の推論主張が行数比較のみで誤り、main の diff で捕捉; 2026-07-23 WI810/812: 二分探索 agent の「空 section でも FAIL」推論を main の計測で反証 — 反復判定タスクの委譲は falsifiable な合否基準〈テスト名〉をプロンプトに明記; 2026-07-24 cleanup: 委譲コミットの staging を git show で、scrub の 218 除去トークンを目視、source diff を main で検証 — 全て正確で手戻りゼロ; 2026-07-24 lint残15→0: sonnet 仕上げが仕様外の新規 warning に独自判断→自己申告+main 現物確認で受理 — 仕上げ委譲プロンプトには「仕様外の新規 lint 発生時の扱い」を明記して往復を消す)*
- **Explore fan-out に複雑な構造化出力スキーマを付けない** — 失敗率 ~50%。plain-text なら 3/3 成功。落とすのはスキーマであって fan-out ではない *(2026-07-01)*
- **権限/allowlist の拡大（特に write・外向き MCP ツールの自動承認）は、main が「スコープ（グローバル vs タスク限定）・どのツールを含めるか」を先に判断してから機械編集を委譲する**。スコープ未確定のまま write ツール込みで委譲すると harness の security 警告 → revert 往復になる。auth/security の是非は main に残す原則（実装オーケストレーション節）の委譲版 *(2026-07-24 auto-review-task: settings.json allow に repo_create_pull_request_thread〈PRコメント投稿=外向き〉をグローバル追加で委譲→harness security-flag→user が「タスク限定」を選択→1行削除の追加 Sonnet サイクル。先にスコープ判断していれば1編集で済んだ)*
- **memory にある既知の落とし穴（MSYS path 等）は ops subagent への dispatch 毎に転記** — 1件の省略が計測1ラウンドを無駄にした *(2026-07-09 perf-003)*
