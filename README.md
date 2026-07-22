# claude-config — Claude Code / Codex ユーザー設定の拠点間同期

職場PC・自宅PC の2拠点で、ユーザーローカルの Claude Code / Codex 設定を **git で同期**するためのリポジトリ。
このリポジトリが **唯一の正（single source of truth）**。各PCでは `~/.claude` / `~/.codex` 配下から
このリポジトリ内の実体へ **シンボリックリンク**を張って使う。

- リモート: https://github.com/MiyataYuya/claude-config.git
- 対象OS: Windows（`%USERPROFILE%` = `~`）。**両PCとも同一ユーザー名を前提**（symlink は絶対パスのため）
- Google Drive への手動スナップショット方式は**廃止**（このリポジトリに一本化）

## 同期対象とリンク構成

| リポジトリ内 | リンク元（実際に読まれるパス） | 内容 |
|---|---|---|
| `settings.json` | `~/.claude/settings.json` | ユーザー設定。`enabledPlugins` / permissions / model / UI |
| `CLAUDE.md`     | `~/.claude/CLAUDE.md`     | Claude Code 固有指示（本体は下の AGENTS.md を import） |
| `codex/AGENTS.md` | `~/.codex/AGENTS.md`    | **個人ルールの単一ソース**。CLAUDE.md が `@~/.codex/AGENTS.md` で参照 |
| `docs/`         | `~/.claude/docs/`         | 参照ドキュメント（effort-calibration のみ。揮発しやすい詳細を置く） |
| `skills/`       | `~/.claude/skills/`       | ユーザースキル |
| `commands/`     | `~/.claude/commands/`     | カスタムスラッシュコマンド |
| `hooks/`        | `~/.claude/hooks/` 配下の**個別ファイル** | `settings.json` から参照される hook スクリプト（現在 `require-agent-model.sh` のみ） |

> `hooks/` はディレクトリごとではなく**ファイル単位でリンク**する。`~/.claude/hooks/` には
> 端末ローカルの実験用 hook（`main-mutation-meter.sh` 等、`settings.local.json` から参照）が
> 同居するため、ディレクトリを丸ごと差し替えるとそれらが消える。
> 同期対象は「`settings.json`（＝同期対象）が参照する hook」に限る。

### 同期しないもの（意図的に除外）
- 機密: `~/.claude/.credentials.json`, `~/.codex/auth.json`（`.gitignore` で保護）
- 端末ローカル: `history.jsonl`, `projects/`（**auto memory 含む**）, `sessions/`, 各種 cache, `plugins/` の実体
- Codex 本体設定 `~/.codex/{config.toml,rules/,skills/}` は**現状スコープ外**（端末固有パス/sandbox を含むため。揃えたくなったら追加する）

> プラグインは `settings.json` の `enabledPlugins` は同期されるが、**実体は端末ごとにインストール**が必要。
> pull 後に不足プラグインは `/plugin` から marketplace 追加 → install する（marketplace は `settings.json` 参照）。

## 日常運用

```bash
# 作業開始前（もう一方のPCの変更を取り込む）
git -C ~/claude-config pull

# 変更した側（設定・skill・ルールを編集したら）
git -C ~/claude-config add -A
git -C ~/claude-config commit -m "なぜ変更したかを書く"
git -C ~/claude-config push
```

`~/.claude` や `~/.codex` 配下の対象ファイルは symlink 経由でリポジトリ実体を指すので、
編集は普段どおり行えば `claude-config` に反映される。

## 新しいPCのセットアップ（手順B）

PowerShell を**管理者権限**（または開発者モード有効）で実行。`~` は `$HOME`。

```powershell
cd $HOME
git clone https://github.com/MiyataYuya/claude-config.git

# 既存の実体を退避（存在すれば）
Rename-Item "$HOME\.claude\settings.json" "settings.json.bak" -ErrorAction SilentlyContinue
Rename-Item "$HOME\.claude\CLAUDE.md"     "CLAUDE.md.bak"     -ErrorAction SilentlyContinue
Rename-Item "$HOME\.claude\skills"        "skills.bak"        -ErrorAction SilentlyContinue
Rename-Item "$HOME\.claude\commands"      "commands.bak"      -ErrorAction SilentlyContinue
Rename-Item "$HOME\.claude\docs"          "docs.bak"          -ErrorAction SilentlyContinue
Rename-Item "$HOME\.claude\agents"        "agents.bak"        -ErrorAction SilentlyContinue
Rename-Item "$HOME\.codex\AGENTS.md"      "AGENTS.md.bak"     -ErrorAction SilentlyContinue

# シンボリックリンクを張る
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\settings.json" -Target "$HOME\claude-config\settings.json"
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\CLAUDE.md"     -Target "$HOME\claude-config\CLAUDE.md"
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\skills"        -Target "$HOME\claude-config\skills"
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\commands"      -Target "$HOME\claude-config\commands"
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\docs"          -Target "$HOME\claude-config\docs"
New-Item -ItemType SymbolicLink -Path "$HOME\.codex\AGENTS.md"      -Target "$HOME\claude-config\codex\AGENTS.md"

# hook はファイル単位（ディレクトリを丸ごとリンクしない。上の注記を参照）
New-Item -ItemType Directory -Path "$HOME\.claude\hooks" -ErrorAction SilentlyContinue
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\hooks\require-agent-model.sh" -Target "$HOME\claude-config\hooks\require-agent-model.sh"
```

退避した `*.bak` に**このリポジトリに無い現行情報**が残っていないか確認し、あればリポジトリ側へ取り込んで
commit・push する。問題なければ `*.bak` は削除してよい。

## クラウドセッションへの展開（スマホ / Claude Code on the web）

クラウドセッションは毎回まっさらなコンテナで起動し、ユーザースコープ設定（`~/.claude` / `~/.codex`）は
同期されない（読まれるのはリポジトリにコミットされた設定のみ）。そこで環境（Environment）の
**セットアップスクリプト**（Claude Code 起動前に実行される）で本リポジトリを clone し、
`scripts/bootstrap-cloud.sh` が PC と同じ symlink 構成をコンテナ内に再現する。
個人ルールは各プロジェクト CLAUDE.md の `@~/.codex/AGENTS.md` import が解決することで効く。
`settings.json`（permissions / model）はクラウド側の管理設定が優先されるため対象外。

### 設定手順（一度だけ）
1. claude.ai/code → 環境セレクタ（クラウドアイコン）→ 対象環境にホバー → 設定アイコンで環境設定を開く
2. **Environment variables** に `GH_TOKEN=<本リポジトリ読み取り可のPAT>` を1行追加（クォート不要）。
   本リポジトリが private の間は必須（セットアップスクリプトはセッションの GitHub 認証プロキシより前に
   走るため、認証は PAT で行う）。public 化すれば不要
3. **Setup script** に以下を設定:

```bash
#!/bin/bash
git clone --depth 1 "https://x-access-token:${GH_TOKEN}@github.com/MiyataYuya/claude-config.git" ~/claude-config 2>/dev/null || true
bash ~/claude-config/scripts/bootstrap-cloud.sh
```

4. 各プロジェクトリポジトリの CLAUDE.md 冒頭に `@~/.codex/AGENTS.md` を1行追加する。
   PC では既存 symlink が、クラウドではセットアップスクリプトが置いたファイルが解決する
   （import 先が無い環境では import は未解決のまま無視されることをクラウドセッション上で確認済み。
   公式ドキュメント上は未記載）

### 運用メモ
- 環境スナップショットは**約7日キャッシュ**され、その間は新セッションでもセットアップスクリプトは
  再実行されない → ルール変更が即座には反映されない。即時反映したいときはセットアップスクリプトを
  編集して保存する（スクリプト変更・許可ホスト変更でキャッシュが再構築される）
- 検証: 新しいクラウドセッションで `ls -la ~/.claude ~/.codex` を実行し、symlink と
  プロジェクト CLAUDE.md の import 解決（個人ルールが効いているか）を確認する

## 経緯メモ
- 2026-07-06: Git方式で設計、職場PCで初期構築（`Initial Claude Code config`）。
- 2026-07-06 以降: 職場PCを `@~/.codex/AGENTS.md` import＋`docs/` 構成に刷新。
- 2026-07-09: `codex/AGENTS.md` と `docs/` を同期対象に追加、壊れた `agents` symlink を除去。
  自宅PC（旧CLAUDE.md のまま Drive スナップショット運用だった）を本リポジトリ運用へ移行（手順B）。
- 2026-07-09: クラウドセッション（スマホ / Claude Code on the web）でも個人ルールを効かせるため
  `scripts/bootstrap-cloud.sh` を追加。環境のセットアップスクリプトから呼び出す。
- 2026-07-10: 陳腐化対策として docs を整理。安定ルール（writing-rules / pr-practices）は
  AGENTS.md へ統合し、揮発しやすい `claude-code-operations-guide.md` は削除。`docs/` は
  実態が更新される `effort-calibration.md` のみ残す（コールドで腐るファイルを持たない方針）。
