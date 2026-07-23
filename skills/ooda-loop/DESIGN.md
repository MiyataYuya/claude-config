# ooda-loop スキル設計 (2026-07-23)

## 背景

2026-07-23 の OralImageArranger WI#810 修復セッションで、成果（設定3ファイル約40行＋WI#812起票）に対し ~4h・subagent 5体・~410k tokens・テスト実行15回超を投下した。既存ガードレール（main-mutation-meter / phase-boundary-reminder / agent-delegation-reminder の3層）はいずれも「実行場所（main→agent）」を制御するだけで、「継続可否・累計投下量」を問う層がなく、この浪費を防げなかった。また、調査中に別クラスの故障が出現したにもかかわらず報告せず自律続行し、スコープ外に踏み込んだ。

なぜなぜ分析の結論: スコープ外突入は Observe の不在、続行/停止を判断する層の不在は Decide の不在。main が Act（実行）を握り続ける限り、観察者の位置に立てない。

## 目的

main は**意思決定者**であり、実作業（Act）を絶対に自分で行わない。雑談・単純な一発回答であっても、内容生成を伴うものは全て軽量agentに委譲する。main が直接持つのは次の3つのみ:

- ユーザーとの判断・確認の往復
- 台帳（ループ状態）の読み書き
- 複数agent報告の集約・矛盾チェック（Observe/Orient/Decide）

狙いは、main が実行権限を握り続けることで生じる指示からの逸脱と、main 自身の「考えすぎ」によるコスト浪費を構造的に防ぐこと。

## 適用範囲

課題不明の反復作業全般（バグ調査に限らない）。ただし一発で完結する作業（日付確認など）にまで台帳やループの機構を持ち込むのは過剰管理であり、それ自体がこの skill が防ごうとする失敗である。「一発Actか複数サイクルループか」の判定自体が、この skill が鍛える中核の判断力である。

## 構造

`~/.claude/skills/ooda-loop/` を skills-directory プラグイン化する（`.claude-plugin/plugin.json` を配置、marketplace 登録・install 不要）。

```
~/.claude/skills/ooda-loop/
  .claude-plugin/plugin.json
  DESIGN.md                    <- 本ファイル
  skills/
    operate/SKILL.md           -> ooda-loop:operate （main用）
    report/SKILL.md            -> ooda-loop:report  （Act用）
```

2skill構成にした理由: 呼ばれる主体・タイミングが本質的に別（main は毎ターン、Act は作業終了時）。「複数Act報告の集約」を担う専用の観察エージェントは置かない — 既存の `superpowers:dispatching-parallel-agents` の前例（"Review each summary / Check for conflicts / Spot check" は呼び出し元が直接行う）と、本設計で決めた「集約・矛盾チェックはmain」という境界の両方に合致するため。集約用agentを別途挟むと往復コストが増えるだけで根拠がない。

## 起動

`~/.claude/hooks/agent-delegation-reminder.sh`（UserPromptSubmit hook）を書き換え、現状の汎用リマインダー文言の代わりに `ooda-loop:operate` の呼び出しを促す注入文にする。これにより雑談・単純質問も含め毎ターン必ず発火する。具体的なスクリプト文言・実装は実装計画側で詰める。

## main の中核判断（`ooda-loop:operate`）

毎回のプロンプト/状況を次のいずれかに分類する。固定ルール化はしない（判断力そのものが価値）:

1. **一発Actで完結** — 台帳を作らず、軽量agentに即dispatchして回答、終了
2. **既存ループの継続** — Act の報告（`ooda-loop:report` 形式）を main が直接読み、矛盾チェック（Observe）→ 問題分類との整合性・別クラス故障の有無を判断（Orient）→ Decide
3. **新規ループの開始が妥当** — 台帳を起こし、問題の分類を定義し、最初の Act を dispatch

## Decide の分岐（時間を使わない、回数・シグナルベース）

タイムスタンプ計測は使わない（main にリアルタイム時計がなく、計測の実装コストに見合わない）。

- **続行**: 次の Act dispatch。期待情報量を1行で正当化
- **方法転換**: 同一仮説/アプローチが**3回反証**されたら強制。`systematic-debugging` Phase 4「3回失敗でアーキテクチャを疑え」の閾値に合わせた
- **ユーザーに報告**: 別クラス故障の兆候（`ooda-loop:report` 項目2）を検知したら回数を待たず即座に
- **打ち切り**: ユーザーとの対話で決定。トラッカー（GitHub/Azure DevOps等）を決め打ちしない — 台帳（問題分類・検証済み仮説・反証内容・残った手がかり）を要約提示し、どう記録するかをユーザーに確認する（skill は user-scope でリポジトリ非依存のため）

## Act と systematic-debugging の関係

**粒度: 1 Act dispatch = 1仮説検証**（細粒度）。台帳側で反証回数を Act dispatch 横断でカウントする。

Act エージェントは `Skill` ツールで `systematic-debugging` 等の既存 skill を自分で呼び出せる（feasibility 調査済み — デフォルトの tool 制限なしの subagent は plugin skill を含め `Skill` ツール経由で自由に呼び出せる。tool を絞ったカスタム subagent 種別を使う場合のみ `Skill` を明示的に含める必要がある）。

dispatch プロンプトには falsifiable な合否基準を明記する。独立した実験は worktree 分離で並列 dispatch 可能。

## Act の報告フォーマット（`ooda-loop:report`）

Act エージェントは作業終了時に必ずこの形式で main に報告する:

1. 与えられた falsifiable な合否基準に対する結果（合格/不合格/判定不能）と、その根拠
2. 依頼された仮説・作業範囲から外れた別クラスの兆候に気づいたか（気づいたなら具体的に何か）

コスト概算（時間・tokens等）は含めない — Decide の分岐が時間ベースを使わないため不要。

## 台帳

セッションのスクラッチパッドディレクトリに配置する（git リポジトリでない状況でも動作するよう、リポジトリ内固定パスにしない）。

- 新規ループ開始時に作成
- Decide サイクル毎に main が読み書きして更新
- ループ終結時（ユーザー報告で解決 or 打ち切り）に破棄/アーカイブ

内容:
- 問題の分類（何を調査しているか）
- 仮説履歴（検証済み/反証済み/残存の3行）
- 現在の反証カウント
- サイクル数（Act dispatch 回数）

## 未決定（実装計画で詰める）

- 台帳の具体的なファイル形式・パス命名
- `agent-delegation-reminder.sh` の具体的な注入文言
- `ooda-loop:operate` / `ooda-loop:report` 各 SKILL.md の詳細な文面
- `.claude-plugin/plugin.json` の具体的な内容（`claude plugin init ooda-loop` で雛形生成）
