---
name: sync-repo-state
description: Use before starting work in any git repository — checks remote/local state and brings the repo up to date. Fetches with --prune, reports ahead/behind vs upstream, detects the integration branch, then proposes fast-forward updates and cleanup of merged [gone] branches. Trigger whenever the user asks to sync, get up to date, pull latest, "fetch して状態を見せて", "リモートとローカルの状態を確認", "最新化して", "作業を始められるように", or otherwise wants to align local with remote before working — even if they don't say "git". Always confirm before any destructive action (branch deletion, switching over a dirty tree).
---

# Sync Repo State

作業を始める前に「リモートとローカルがどうズレているか」を正しく把握し、安全に最新化する汎用ワークフロー。プロジェクト非依存。毎回この一連を手作業で回すのは面倒で抜けやすく、怠ると push 時に「リモートに未確認のコミットがありました」と弾かれて手戻りになる。**作業開始時にこの同期を確実に済ませ、その push 時の不意打ちを未然に潰す**のがこのスキルの主目的。

古い情報のまま判断するとブランチを取り違えたり未マージ作業を消したりする。だから **必ず最初に fetch --prune し、状態を読んでから動く**。そして取り返しのつかない操作（ブランチ削除・dirty なツリー上での切替・merge/rebase/破棄）は **実行前に必ず確認する**。

特に **現在ブランチや統合ブランチがリモートより behind / 乖離していないか** は最優先で確認し、目立つ形で報告する。ここを見落とすと、後の push で初めて遅れに気付くことになる。

## When to Use

- 「リモートとローカルの状態を確認して最新化して」「作業を始められるように」「sync」「pull latest」「get up to date」
- ブランチを切り替える前・新しい作業に入る前の同期確認
- ローカルが遅れている / 進んでいる / 乖離しているかを知りたいとき

## When NOT to Use

- git リポジトリでない（スクリプトが `NOT_A_GIT_REPO` を返す。普通の最新化質問として答える）
- 特定ブランチへの明示的な merge / rebase 実行依頼（これは同期確認ではなく統合作業）

## Workflow

### 1. 状態を集める（read-only）

バンドルされた検査スクリプトを実行する。**何も変更せず** fetch --prune と各種 status を一括取得する。

```sh
sh ~/.claude/skills/sync-repo-state/scripts/inspect.sh
```

Bash ツールが使えない環境なら、スクリプトと同じ内容を順に実行してよい（`git fetch --all --prune` を絶対に省かない）。fetch を飛ばすと ahead/behind の判断が古い情報になり全ての後続判断が狂う。

### 2. 統合ブランチを特定する

「作業を始める起点」になる統合ブランチを、次の優先順で決める。**プロジェクトの方針が generic 検出より優先**。

1. **プロジェクト設定** — 当該リポジトリの `CLAUDE.md` / `AGENTS.md` のブランチ戦略を読む（例: 「dev が開発の正、作業ブランチは dev から切る」と書いてあればそれが統合ブランチ）
2. **origin/HEAD** — `git symbolic-ref refs/remotes/origin/HEAD`（リモートのデフォルトブランチ）
3. **慣習名** — `main` → `master` → `develop` → `dev` → `trunk` の順で存在するもの

検出結果が曖昧／複数候補なら推測で進めず、ユーザーに確認する。

### 3. 状態を報告する

収集結果を簡潔な表で示す。最低限カバーするもの:

| 観点 | 報告内容 |
|------|----------|
| 現在ブランチ | ブランチ名と upstream に対する ahead/behind |
| 統合ブランチ | 名前と、そのローカルがリモートからどれだけ遅れ/進みか |
| 作業ツリー | staged / unstaged の変更があるか（dirty か clean か） |
| 未追跡ファイル | あればファイル名 |
| `[gone]` ブランチ | マージ済みでリモートが消えたローカルブランチ |

ahead/behind は意味が違うので区別して伝える:
- **behind のみ** → fast-forward で安全に追いつける
- **ahead のみ** → 未 push のローカルコミットがある（消さないよう注意）
- **乖離（both）** → ff できない。merge/rebase の判断が要るので **自動解決しない**

### 4. 提案して確認を取る（mutate する前に必ず）

報告に続けて、取れるアクションを提案し承認を得る。**デフォルトは安全側**:

- **現在ブランチが behind で ff 可能** → fast-forward 更新（`git merge --ff-only` / `git pull --ff-only`）。非破壊なので提案し、承認後に実行。乖離している場合は ff せず、merge か rebase かをユーザーに委ねる。
- **起点を統合ブランチにしたいが別ブランチにいる** → ツリーが clean な場合のみ切替を提案。dirty なら切り替えず、先にコミット/stash するか確認。
  - チェックアウトせずに統合ブランチを最新化したいとき（未コミット変更との衝突回避）は、ff 可能な前提で `git fetch origin --prune && git update-ref refs/heads/<統合> origin/<統合>` が使える。
- **`[gone]` ブランチの掃除** → `git branch -d <名前...>` を提案。`-d` はマージ済みのみ消す安全な削除。`-d` が未マージで拒否したら、その事実を伝えて `-D`（強制）を使うか確認する（安易に `-D` しない）。
- **未追跡 / 未コミットの変更** → 既定では触らない。明示依頼があるときだけ .gitignore 追加・削除・コミットを行う。

破壊的・不可逆な操作（ブランチ削除、dirty ツリー上の切替、merge/rebase/reset/checkout による破棄）は、ユーザーが明示的に承認するまで実行しない。

### 5. 実行して最終状態を報告

承認された操作だけを実行し、終わったら最終状態（現在ブランチ・残ブランチ・clean/dirty）を 1 行で示す。`git branch -d` 後は「`-d` で消えた＝マージ済みだった」事実も添えると、ユーザーが安全性を確認できる。

## Core Principles

- **Read before mutate.** fetch --prune → 状態把握 → 提案 → 承認 → 実行。順序を飛ばさない。
- **Ask before irreversible.** 削除・切替・破棄は確認してから。
- **Project over generic.** リポジトリの CLAUDE.md/AGENTS.md のブランチ戦略を generic 検出より優先。
- **Never silently resolve divergence.** 乖離は自動で merge/rebase せず、ユーザーに選ばせる。
- **Ground in fetched data, never confabulate.** ブランチの存在・状態・統合ブランチの判定は、**今このリポジトリで fetch --prune した実データ**（`git branch -vv` / `for-each-ref` / `origin/HEAD`）だけを根拠にする。セッション冒頭の表示・別リポジトリの記憶・以前の文脈から、存在しないブランチや「○○へ移行済み」といった経緯を推測・捏造しない。確認できないことは「未確認」と明示する。
