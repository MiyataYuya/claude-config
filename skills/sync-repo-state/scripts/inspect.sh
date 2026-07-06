#!/usr/bin/env sh
# Read-only repo state inspection for the sync-repo-state skill.
# Mutates nothing except the local remote-tracking refs via `git fetch`.
# Portable POSIX sh (works in Git Bash on Windows and on macOS/Linux).
set -u

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "NOT_A_GIT_REPO"; exit 1; }

CUR=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

echo "=== current branch ==="
echo "$CUR"

# Fetch the current branch's upstream remote (default origin). Fetching a
# single relevant remote avoids aborting on an unrelated broken remote that
# `--all` would trip over.
REMOTE=$(git config --get "branch.$CUR.remote" 2>/dev/null)
[ -n "$REMOTE" ] || REMOTE=origin
echo "=== fetch ($REMOTE --prune) ==="
if git fetch "$REMOTE" --prune 2>&1; then
  echo "(fetch ok)"
else
  echo "FETCH_FAILED (offline? no remote? continuing with stale data)"
fi

echo "=== ahead/behind vs upstream ==="
# First line of -sb shows e.g. "## dev...origin/dev [behind 2]" or "[ahead 1, behind 3]"
git status -sb 2>/dev/null | head -1

echo "=== working tree (porcelain; empty = clean) ==="
git status --porcelain=v1

echo "=== tracking branches ==="
git branch -vv

echo "=== gone branches (merged remotes deleted) ==="
git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads \
  | grep '\[gone\]' || echo "(none)"

echo "=== integration branch hint: origin/HEAD ==="
git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null \
  || echo "(origin/HEAD not set — fall back to project config or conventional names)"

echo "=== local branches present ==="
git for-each-ref --format='%(refname:short)' refs/heads
