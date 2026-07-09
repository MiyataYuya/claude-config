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
| `docs/`         | `~/.claude/docs/`         | 参照ドキュメント（effort-calibration / pr-practices / writing-rules） |
| `skills/`       | `~/.claude/skills/`       | ユーザースキル |
| `commands/`     | `~/.claude/commands/`     | カスタムスラッシュコマンド |

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
```

退避した `*.bak` に**このリポジトリに無い現行情報**が残っていないか確認し、あればリポジトリ側へ取り込んで
commit・push する。問題なければ `*.bak` は削除してよい。

## 経緯メモ
- 2026-07-06: Git方式で設計、職場PCで初期構築（`Initial Claude Code config`）。
- 2026-07-06 以降: 職場PCを `@~/.codex/AGENTS.md` import＋`docs/` 構成に刷新。
- 2026-07-09: `codex/AGENTS.md` と `docs/` を同期対象に追加、壊れた `agents` symlink を除去。
  自宅PC（旧CLAUDE.md のまま Drive スナップショット運用だった）を本リポジトリ運用へ移行（手順B）。
