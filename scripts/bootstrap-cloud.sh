#!/bin/bash
# クラウドコンテナ(Claude Code on the web / Codex cloud)に claude-config を展開する。
# 環境(Environment)のセットアップスクリプトから呼ぶ。冪等なので何度実行してもよい。
#
# クラウドセッションはユーザースコープ設定(~/.claude, ~/.codex)を同期しないため、
# 本リポジトリを clone して PC と同じ symlink 構成をコンテナ内に再現する。
# 個人ルールは各プロジェクト CLAUDE.md の `@~/.codex/AGENTS.md` import 経由で効く。
#
# private リポジトリの場合は環境変数 GH_TOKEN(repo 読み取り可の PAT)を環境設定で渡す。

set -u

REPO_DIR="$HOME/claude-config"
REPO_URL="https://github.com/MiyataYuya/claude-config.git"

# GH_TOKEN があれば認証付き URL を使う(取得時のみ。remote には残さない)
AUTH_URL="$REPO_URL"
if [ -n "${GH_TOKEN:-}" ]; then
  AUTH_URL="https://x-access-token:${GH_TOKEN}@github.com/MiyataYuya/claude-config.git"
fi

if [ -d "$REPO_DIR/.git" ]; then
  # スナップショット再利用時は clone 済みなので最新化だけ行う。
  # オフライン/認証失敗でも既存 checkout で続行(古いルール > ルールなし)
  git -C "$REPO_DIR" pull --ff-only "$AUTH_URL" main \
    || echo "warn: pull failed; using existing checkout" >&2
else
  git clone --depth 1 "$AUTH_URL" "$REPO_DIR" || {
    echo "error: claude-config を clone できない (public 化するか GH_TOKEN を設定する)" >&2
    exit 1
  }
  # トークン入り URL をスナップショットに残さない
  git -C "$REPO_DIR" remote set-url origin "$REPO_URL"
fi

# PC と同じ symlink 構成(README「同期対象とリンク構成」参照)。
# settings.json はクラウド側の管理設定が優先されるため意図的にリンクしない
mkdir -p "$HOME/.codex" "$HOME/.claude"
ln -sf  "$REPO_DIR/codex/AGENTS.md" "$HOME/.codex/AGENTS.md"
ln -sf  "$REPO_DIR/CLAUDE.md"       "$HOME/.claude/CLAUDE.md"
ln -sfn "$REPO_DIR/skills"          "$HOME/.claude/skills"
ln -sfn "$REPO_DIR/commands"        "$HOME/.claude/commands"
ln -sfn "$REPO_DIR/docs"            "$HOME/.claude/docs"

echo "claude-config bootstrapped: $(git -C "$REPO_DIR" rev-parse --short HEAD)"
