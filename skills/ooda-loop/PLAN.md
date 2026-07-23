# ooda-loop skill family Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `ooda-loop` skills-directory plugin (`ooda-loop:operate` for the decision-maker / `ooda-loop:report` for Act agents) and wire it to fire on every UserPromptSubmit, per `skills/ooda-loop/DESIGN.md`.

**Architecture:** A skills-directory plugin at `~/.claude/skills/ooda-loop/` (= `claude-config/skills/ooda-loop/` via the existing repo↔`~/.claude` symlink) containing two independent SKILL.md files. The existing `agent-delegation-reminder.sh` UserPromptSubmit hook is rewired to force-invoke `ooda-loop:operate` every turn instead of its current generic reminder text.

**Tech Stack:** Markdown (SKILL.md), JSON (plugin.json), bash (hook script), jq.

## Global Constraints

- Plugin root: `skills/ooda-loop/` inside the `claude-config` repo (paths below are relative to repo root unless stated absolute)
- Exactly 2 skills: `operate` (decision-maker, fires every turn) and `report` (Act agents, fires at end of their work) — no third "observer" skill
- No time-based tracking anywhere in skill content (no wall-clock, no `date` dependency) — all Decide thresholds are count/signal-based
- Refutation-to-pivot threshold: exactly **3**, matching `systematic-debugging` Phase 4's threshold
- `ooda-loop:report` has exactly 2 mandatory fields: falsifiable result, out-of-scope signal. No cost/time field.
- Terminology: main is called "意思決定者" (decision-maker), never "中間管理職", throughout all skill content
- Ledger path is session-scratchpad-relative, never a git-repo-fixed path (must work outside a git repo)
- The hook change modifies the existing `agent-delegation-reminder.sh` (both the repo copy and the live `~/.claude/hooks/` copy) — it does not create a new hook registration in `settings.json`

---

### Task 1: Plugin manifest scaffold

**Files:**
- Create: `skills/ooda-loop/.claude-plugin/plugin.json`

**Interfaces:**
- Produces: a plugin named `ooda-loop@skills-dir` (per Claude Code's skills-directory plugin discovery), which Task 2 and Task 3's skills load under

- [ ] **Step 1: Verify the target doesn't already exist**

Run: `test -e "$HOME/claude-config/skills/ooda-loop/.claude-plugin" && echo EXISTS || echo MISSING`
Expected: `MISSING`

- [ ] **Step 2: Create the plugin manifest**

Create `skills/ooda-loop/.claude-plugin/plugin.json`:

```json
{
  "name": "ooda-loop",
  "description": "Forces the decision-maker (main) to never Act directly: every turn is classified as one-shot / continuing loop / new loop, judged (Orient), and decided (Decide) before dispatching all real work to Act agents.",
  "version": "0.1.0"
}
```

- [ ] **Step 3: Verify the JSON is valid**

Run: `jq empty "$HOME/claude-config/skills/ooda-loop/.claude-plugin/plugin.json" && echo VALID`
Expected: `VALID`

- [ ] **Step 4: Commit**

```bash
cd "$HOME/claude-config"
git add skills/ooda-loop/.claude-plugin/plugin.json
git commit -m "ooda-loop pluginのmanifestを追加"
```

---

### Task 2: `ooda-loop:operate` — decision-maker's control loop

**Files:**
- Create: `skills/ooda-loop/skills/operate/SKILL.md`

**Interfaces:**
- Consumes: `ooda-loop:report` output format (defined in Task 3) — this task's Step 5 dispatch instructions must tell Act agents to report in that exact format, so this task's content references Task 3's field names verbatim: 「合否結果」「根拠」「別クラスの兆候」
- Produces: the ledger file contract at `<scratchpad>/ooda-loop-ledger.md` with fields 状態/問題の分類/仮説履歴/現在の反証カウント/サイクル数 — Task 4's hook message must name this skill as `ooda-loop:operate`

- [ ] **Step 1: Verify the target doesn't already exist**

Run: `test -e "$HOME/claude-config/skills/ooda-loop/skills/operate/SKILL.md" && echo EXISTS || echo MISSING`
Expected: `MISSING`

- [ ] **Step 2: Create the skill**

Create `skills/ooda-loop/skills/operate/SKILL.md`:

```markdown
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
```

- [ ] **Step 3: Verify frontmatter is well-formed**

Run: `sed -n '1,4p' "$HOME/claude-config/skills/ooda-loop/skills/operate/SKILL.md"`
Expected:
```
---
name: operate
description: Use at the very start of processing ANY user prompt in an active work session — including trivial chit-chat and simple one-off questions. This is the decision-maker's mandatory control loop: classify the prompt (one-shot / continuing loop / new loop), read and update the ledger, judge scope (Orient), declare the next action (Decide), and dispatch ALL actual work to Act agents. Never perform Act yourself, even for trivial content generation. Invoked automatically every turn via the agent-delegation-reminder hook.
---
```

- [ ] **Step 4: Commit**

```bash
cd "$HOME/claude-config"
git add skills/ooda-loop/skills/operate/SKILL.md
git commit -m "ooda-loop:operate skillを追加（意思決定者の運転規律）"
```

---

### Task 3: `ooda-loop:report` — Act agents' report contract

**Files:**
- Create: `skills/ooda-loop/skills/report/SKILL.md`

**Interfaces:**
- Consumes: nothing from other tasks (self-contained format definition)
- Produces: the exact report field names (「合否結果」「根拠」「別クラスの兆候」) that Task 2's `operate` skill already references verbatim — must match exactly, no renaming

- [ ] **Step 1: Verify the target doesn't already exist**

Run: `test -e "$HOME/claude-config/skills/ooda-loop/skills/report/SKILL.md" && echo EXISTS || echo MISSING`
Expected: `MISSING`

- [ ] **Step 2: Create the skill**

Create `skills/ooda-loop/skills/report/SKILL.md`:

```markdown
---
name: report
description: Use at the end of any Act-phase work dispatched by ooda-loop:operate — before returning your final result. Structures your report into exactly two mandatory fields (falsifiable result + out-of-scope signal) so the decision-maker (main) can fact-check and re-orient without re-deriving your work.
---

# ooda-loop:report — Act の報告規律

## なぜこの形式が必要か

意思決定者(main)は Act の結果を直接読んで矛盾チェックと判断（Orient/Decide）を行う。あなたの報告が構造化されていないと、意思決定者は重要な兆候（別クラスの故障）を見落とすか、逆に全ての推論を鵜呑みにしてしまう。

## 報告に必ず含める2項目

### 1. falsifiable な合否基準に対する結果

dispatch プロンプトで与えられた合否基準（例:「`npm test` の出力に `7 passed` が出れば合格」）に対して:

- **合格 / 不合格 / 判定不能** のどれかを明言する
- その根拠を、サマリの言い換えではなく実際の出力（該当行そのもの、コマンドの実行結果）で示す
- 判定不能な場合は何が足りなくて判定できないかを書く

やってはいけない: 「たぶん直った」「動いているはず」のような自分の推論だけで合格を宣言すること。実行結果を見せる。

### 2. 依頼された作業範囲から外れた別クラスの兆候

調査・作業の過程で、dispatch された仮説やタスクとは**別クラス**の問題（元の分類に当てはまらない、新しい種類の故障や制約）に気づいたか:

- 気づいた場合: 具体的に何を見た（ログ、エラーメッセージ、挙動）かを書く。自分で対処しようとせず、そのまま報告する
- 気づかなかった場合: その旨を明示する（省略しない — 「別クラスの兆候なし」も意思決定者にとって意味のある情報）

## 含めないもの

- コスト概算（時間・tokens）— 意思決定者側の Decide 判断はこれを使わないため不要
- dispatch されていない追加提案（「ついでにこれも直しました」）— スコープ外の作業は別途報告し、意思決定者の判断を待つ

## 出力形式

```markdown
## Act Report

**合否結果**: 合格 | 不合格 | 判定不能
**根拠**: <実際の出力・該当行>

**別クラスの兆候**: あり — <具体的に何を見たか> | なし
```
```

- [ ] **Step 3: Verify frontmatter is well-formed**

Run: `sed -n '1,4p' "$HOME/claude-config/skills/ooda-loop/skills/report/SKILL.md"`
Expected:
```
---
name: report
description: Use at the end of any Act-phase work dispatched by ooda-loop:operate — before returning your final result. Structures your report into exactly two mandatory fields (falsifiable result + out-of-scope signal) so the decision-maker (main) can fact-check and re-orient without re-deriving your work.
---
```

- [ ] **Step 4: Commit**

```bash
cd "$HOME/claude-config"
git add skills/ooda-loop/skills/report/SKILL.md
git commit -m "ooda-loop:report skillを追加（Actの報告規律）"
```

---

### Task 4: Wire the hook to force `ooda-loop:operate` every turn

**Files:**
- Modify: `/c/Users/y-miyata/.claude/hooks/agent-delegation-reminder.sh` (live path, outside the repo — deploy target)
- Create: `skills/ooda-loop/../../hooks/agent-delegation-reminder.sh` → i.e. `/c/Users/y-miyata/claude-config/hooks/agent-delegation-reminder.sh` (repo copy — not yet tracked; this is the source of truth going forward)

**Interfaces:**
- Consumes: the skill name `ooda-loop:operate` produced by Task 2 — the injected message must reference this exact name
- Produces: a `hookSpecificOutput.additionalContext` string injected on every `UserPromptSubmit`

- [ ] **Step 1: Read the current live hook to confirm its exact structure before editing**

Run: `cat "/c/Users/y-miyata/.claude/hooks/agent-delegation-reminder.sh"`
Expected (current content, to be replaced in Step 2):
```bash
#!/usr/bin/env bash
# UserPromptSubmit hook: 毎回のユーザープロンプトに、適切なエージェントへの委譲を促す
# リマインダーを additionalContext として注入する（プロンプト本文の書き換えではない）。
# jq失敗はfail-open。

msg="適切なエージェントに適切にタスクを振るようにしてください。"
jq -n --arg m "$msg" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $m}}' 2>/dev/null
exit 0
```

- [ ] **Step 2: Write the new hook content to the repo (source of truth)**

Create `/c/Users/y-miyata/claude-config/hooks/agent-delegation-reminder.sh`:

```bash
#!/usr/bin/env bash
# UserPromptSubmit hook: 毎回のユーザープロンプトで ooda-loop:operate の運転規律を強制する。
# リマインダーを additionalContext として注入する（プロンプト本文の書き換えではない）。
# jq失敗はfail-open。

msg="ooda-loop:operate skill を呼び出し、その手順に従ってください。雑談・単純な質問であっても省略しないでください。"
jq -n --arg m "$msg" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $m}}' 2>/dev/null
exit 0
```

- [ ] **Step 3: Deploy the same content to the live hook path**

Run:
```bash
cp "/c/Users/y-miyata/claude-config/hooks/agent-delegation-reminder.sh" "/c/Users/y-miyata/.claude/hooks/agent-delegation-reminder.sh"
chmod +x "/c/Users/y-miyata/.claude/hooks/agent-delegation-reminder.sh"
```
Expected: no output (silent success)

- [ ] **Step 4: Verify the live hook now emits the new message**

Run: `bash "/c/Users/y-miyata/.claude/hooks/agent-delegation-reminder.sh"`
Expected:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "ooda-loop:operate skill を呼び出し、その手順に従ってください。雑談・単純な質問であっても省略しないでください。"
  }
}
```

- [ ] **Step 5: Commit the repo copy**

```bash
cd "$HOME/claude-config"
git add hooks/agent-delegation-reminder.sh
git commit -m "agent-delegation-reminder hookをooda-loop:operate呼び出しに書き換え"
```

Note: the live file at `/c/Users/y-miyata/.claude/hooks/` is outside the repo and is not part of this commit — Step 3 already deployed it directly.

---

### Task 5: Structural validation

**Files:**
- None created/modified — verification only

**Interfaces:**
- Consumes: the complete plugin tree from Tasks 1-4

- [ ] **Step 1: Dispatch the plugin validator**

Use the Agent tool with `subagent_type: plugin-dev:plugin-validator` and `model: sonnet`, prompt: "Validate the plugin at C:\Users\y-miyata\claude-config\skills\ooda-loop — check plugin.json schema correctness and that both skills/operate/SKILL.md and skills/report/SKILL.md have valid frontmatter (name, description) and are discoverable as a skills-directory plugin."

Expected: report with no structural errors (missing frontmatter fields, invalid JSON, wrong directory nesting). If it reports issues, fix them and re-dispatch before proceeding.

- [ ] **Step 2: Confirm runtime discovery (manual, next session)**

This cannot be verified within the current session — Claude Code loads skills-directory plugins at session start. Note for the human partner: after this plan is merged, start a **new** Claude Code session and confirm `ooda-loop:operate` and `ooda-loop:report` both appear when searching available skills (e.g. ask "what skills do you have named ooda-loop?"). Also confirm the `UserPromptSubmit` reminder text changed by sending any trivial message and checking the injected additionalContext mentions `ooda-loop:operate`.

- [ ] **Step 3: Final commit if Step 1 required fixes**

If Step 1 required any file changes, commit them:

```bash
cd "$HOME/claude-config"
git add skills/ooda-loop/
git commit -m "plugin-validator指摘への対応"
```

If Step 1 required no changes, skip this step — nothing to commit.
