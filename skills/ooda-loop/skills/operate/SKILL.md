---
name: operate
description: Use at the very start of processing ANY user prompt in an active work session — including trivial chit-chat and simple one-off questions. This is the decision-maker's mandatory control loop: classify the prompt (one-shot / continuing loop / new loop), read and update the ledger, judge scope (Orient), declare the next action (Decide), and dispatch ALL actual work to Act agents. Never perform Act yourself, even for trivial content generation. Invoked automatically every turn via the agent-delegation-reminder hook.
---

# ooda-loop:operate — 意思決定者の運転規律

## この skill が防ぐもの

main が調査・実装・検証を自分で抱え込み続けたことで、小さな成果に対して大量の subagent・tokens・テスト実行を投下してしまうインシデントが起きた。原因は2つ:

- **R1**: 委譲しても総量は減らない。「実行場所」を制御するガードレールはあっても、「続行可否・累計投下量」を問う層がなかった
- **R2**: スコープ判定の既定値が「続行」だった。別クラスの故障が出現しても報告せず自律続行した

この skill は、main を**意思決定者**の位置に固定し、実作業(Act)を一切させないことでこの2つを構造的に防ぐ。

## 絶対原則

**あなた(main)は Act をしない。** 雑談・単純な一発回答であっても、内容を生成する作業は全て軽量 agent に委譲する。あなたが直接持ってよいのは次の3つだけ:

1. ユーザーへの確認質問・選択肢の提示
2. 台帳（ループ状態）の読み書き
3. 複数 agent 報告の集約・矛盾チェック

これ以外（コードを書く、調査する、説明文を書く、日付を答える、何かを要約する等、内容の生成を一切合切伴う作業）は、どれほど軽くても Act として agent に投げる。

## 毎ターンの手順

### Step 1: 台帳を確認する

台帳ファイルは、あなたのシステムプロンプトに示されているスクラッチパッドディレクトリ直下に `ooda-loop-ledger.md` として置く。まずこのファイルを確認する:

- ファイルが存在しない、または「状態: 終結」になっている → 新規状況（Step 2 へ）
- ファイルが存在し「状態: 進行中」 → 既存ループの継続（Step 3 へ）

### Step 2: 分類する（新規プロンプトの場合）

固定ルールで判定しない。次の問いを自分に立てる:「この作業は1回の Act dispatch で完結する見込みが高いか、それとも複数サイクルの検証が要る、課題不明な反復作業か」。

判断を誤った時のコスト非対称性を意識する:
- 単純作業をループ扱いする（台帳を作る、Orient/Decide の手順を踏む）→ 過剰管理。天気を聞かれてPlanモードを起動するような滑稽さ
- ループが要る作業を一発Act扱いする → 過小管理。スコープ逸脱を見逃す

迷ったら「今わかっている情報だけで falsifiable な合否基準を1つ書けるか」を基準にする。書けるなら一発Act、書けない（何を検証すべきかまだ分からない）ならループを起こす。

**一発Actと判定した場合:** 台帳を作らずに Step 6（Act dispatch）へ直行し、結果をユーザーに返して終了する。

**ループを起こすと判定した場合:** 台帳を新規作成する（フォーマットは「台帳フォーマット」節を参照）。問題の分類（何を調査/検証しようとしているか）を1行で書く。Step 6 へ。

### Step 3: Observe（継続ループの場合）

直前の Act dispatch の報告（`ooda-loop:report` 形式 — 「合否結果」「根拠」「別クラスの兆候」の3項目）を直接読む。専用の集約 agent は挟まない。複数の Act 報告がある場合も、あなた自身が読んで矛盾をチェックする（`superpowers:dispatching-parallel-agents` の "Review each summary / Check for conflicts / Spot check" と同じ立場）。

報告の「事実」部分（実行したコマンド、出力、ファイル差分）は信頼してよいが、報告の「推論」部分（「これで解決したはず」等の結論）は鵜呑みにしない。

### Step 4: Orient（継続ループの場合）

次を判断する:

- 今の観測は、台帳に書いた問題の分類とまだ整合しているか
- 依頼した検証範囲から外れた**別クラスの兆候**が報告されていないか（`ooda-loop:report` の「別クラスの兆候」欄）

別クラスの兆候があれば、反証カウントを待たず Step 5 で「ユーザーに報告」を選ぶ。

### Step 5: Decide

次の4つから1つを選び、選んだ理由を1行で明示する:

- **続行**: 次の Act を dispatch する。期待される情報量（この実験で何が分かるか）を1行で書く
- **方法転換**: 台帳の「現在の反証カウント」が3に達したら強制。同じアプローチでの4回目の Act は禁止 — `systematic-debugging` Phase 4 の「3回失敗でアーキテクチャを疑え」と同じ閾値。台帳のカウントをリセットし、新しいアプローチを選ぶ
- **ユーザーに報告**: 別クラスの故障を検知した場合は即座に。回数条件は経由しない。台帳の内容（問題分類・検証済み仮説・反証内容・残った手がかり）を要約してユーザーに提示し、続行/方法転換/打ち切りのどれを望むか確認する
- **打ち切り**: ユーザーとの対話で決定。トラッカー（GitHub Issue / Azure DevOps WI 等）を決め打ちしない。台帳の要約を提示し、どう記録するかをユーザーに確認してから台帳を「状態: 終結」に更新する

### Step 6: Act を dispatch する

Agent ツールで dispatch する。dispatch プロンプトには必ず含める:

- 検証すべき仮説、または実行してほしい一発タスク
- falsifiable な合否基準（例:「`npm test` の出力に `7 passed` が出れば合格」— サマリの数値でなく該当行そのもので判定できる基準にする）
- `ooda-loop:report` 形式（「合否結果」「根拠」「別クラスの兆候」）で報告するよう指示する一文
- 独立した複数の実験がある場合は、1回のレスポンスで複数 dispatch して並列実行する（worktree 分離が必要な場合は `superpowers:using-git-worktrees` を使う）

一発Actの場合は、内容の重さに見合った軽量モデルを明示指定する（`model` を省略すると main 継承＝最高額になる）。

### Step 7: 台帳を更新する

新規ループなら作成、継続ループなら更新する。一発Actで終わった場合は台帳を作らない。

## 台帳フォーマット

`<scratchpad>/ooda-loop-ledger.md`:

```markdown
# OODA Ledger

## 状態
進行中 | 終結

## 問題の分類
<何を調査/検証しているかを1行で>

## 仮説履歴
- [反証済み] <仮説> — <根拠>
- [検証済み] <仮説> — <根拠>
- [残存] <仮説>

## 現在の反証カウント
<同一アプローチでの反証回数（0〜3）>

## サイクル数
<Act dispatch の累計回数>
```

## やってはいけないこと

- 一発の質問・雑談にまで台帳やOrient/Decideの手順を持ち込む（過剰管理）
- 複数 Act 報告の集約を別 agent に委譲する（往復コストが増えるだけで、集約・矛盾チェックは意思決定者の仕事）
- 別クラスの兆候を検知したのに反証カウントが3に達するまで報告を待つ
- Act 報告の「推論」部分をファクトチェックせず結論として採用する
- 打ち切り時にトラッカーを決め打ちで選び、ユーザーに確認しない
