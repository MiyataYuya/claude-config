---
name: notion-diary
description: Automatic Notion diary recorder — on session start, ensures today's DiaryDB page exists; on session end, appends a 1-2 line Japanese summary of the work performed. Runs in a detached background `claude -p` so the main session's context is untouched.
---

# Notion Diary

## What it does
- **SessionStart** → checks Notion DiaryDB for a page titled `YYYY-MM-DD` (today). Creates it if missing.
- **Stop** (every assistant turn, with 60s cooldown per session) and **SessionEnd** (force fire, no cooldown) → reads the transcript, generates a 1-2 line Japanese work summary, and ensures today's page has **exactly one bullet per session** tagged `[#<sid_short>]`. Subsequent fires update the same bullet so the entry keeps reflecting the session's latest state.
- All hooks run as **detached background processes** (`nohup ... &`). The main Claude Code conversation continues immediately; no main-stream tokens are consumed.

## How it works (architecture)
```
Claude Code main session
   │ SessionStart / SessionEnd event
   ▼
~/.claude/hooks/notion-diary/{session-start,session-end}.sh
   │ exports CLAUDE_NOTION_DIARY_HOOK_BUSY=1
   │ nohup claude -p ... &   (detached, separate process, hidden window)
   ▼
helper `claude -p` instance
   │ inherits user Notion MCP auth (OAuth) and the sentinel env var
   │ when its own SessionStart fires → hook sees sentinel → exits 0 (no recursion)
   ▼
mcp__claude_ai_Notion__notion-{search,fetch,create-pages,update-page}
   ▼
DiaryDB (id 35c483a9-a896-80bc-bd7c-e97bc96077c2)
   data source: collection://35c483a9-a896-80cf-b562-000b544310e9
```

### Why detached spawn instead of running inline?
The user explicitly asked: *"メインストリームのトークンを圧迫しないように、モニター用のシェルを立てて、裏で記録する"*. The helper claude runs in a separate process with its own context — none of its tool calls, summaries, or reasoning consume the main conversation's tokens.

### Why no permission bypass?
The spawned claude is given an inline `--settings` JSON that allow-lists exactly five tools: `Read` + four `mcp__claude_ai_Notion__*` tools. Combined with `--allowedTools` and `--tools Read` (or empty), the surface is tight. No `--permission-mode bypassPermissions`.

### Why Stop *and* SessionEnd?
`SessionEnd` is not reliably triggered by `/exit` in all setups, so we cannot depend on it. Instead, `Stop` (which fires every turn) does the recording with a per-session 60s cooldown lock file at `state/<session_id>.lock`. The helper coalesces by inserting `[#<sid_short>]` into the bullet text and updating that same bullet on every fire. `SessionEnd` is still registered as a force-fire (`DIARY_FORCE=1` bypasses the cooldown) so that *if* it does fire, we get one final update; otherwise the last Stop fire already left a near-current summary.

## Files
| Path | Role |
| --- | --- |
| `~/.claude/hooks/notion-diary/session-start.sh` | SessionStart entrypoint |
| `~/.claude/hooks/notion-diary/record.sh`        | Stop / SessionEnd entrypoint (cooldown + coalesce) |
| `~/.claude/hooks/notion-diary/common.sh`        | Shared launcher (`start_diary_claude`) |
| `~/.claude/hooks/notion-diary/state/*.lock`     | Per-session cooldown timestamps |
| `~/.claude/hooks/notion-diary/logs/*.log,.err`  | Background process stdout / stderr |
| `~/.claude/settings.json` (`hooks.SessionStart`, `hooks.Stop`, `hooks.SessionEnd`) | Hook registration |

## Configuration knobs
Edit `common.sh`:
- `NOTION_DIARY_DB_ID` / `NOTION_DIARY_DATA_SOURCE_ID` — DiaryDB identifiers.
- `model="sonnet"` (5th positional arg to `start_diary_claude`) — pass `haiku` for cheaper/faster runs, `opus` for higher-quality summaries.
- `SPAWN_SETTINGS_JSON.permissions.allow` — additional tools the helper claude may use.

## Verifying it works
1. Start a new Claude Code session (or `/clear`). Within ~5 seconds:
   - `~/.claude/hooks/notion-diary/logs/session-start-<stamp>.log` should appear with `exists` or `created`.
   - Today's page should be visible in DiaryDB.
2. End the session (`/exit`, close terminal, etc.). Within ~30 seconds:
   - `session-end-<stamp>.log` should contain `ok`.
   - A new bullet `HH:MM - <Japanese summary>` should be on today's page.

## Troubleshooting
| Symptom | Check |
| --- | --- |
| No log file appears | `bash` is missing from PATH, or `claude` is not found. Run `bash ~/.claude/hooks/notion-diary/session-start.sh` manually. |
| `.err` shows `OAuth` / auth errors | The user-level Notion MCP OAuth session expired. Open the main app and re-auth, or run `claude mcp` to refresh. |
| `.err` shows permission denied for a Notion tool | Add the tool name to `SPAWN_SETTINGS_JSON.permissions.allow` in `common.sh`. |
| Hook never fires | Confirm `settings.json` has the `hooks.SessionStart` / `hooks.SessionEnd` blocks and that JSON is valid. |
| Infinite recursion (many helper processes) | The sentinel env var didn't propagate. Confirm `export CLAUDE_NOTION_DIARY_HOOK_BUSY=1` is reached before `nohup`. |
| Want to disable temporarily | Remove or comment out the `SessionStart` / `SessionEnd` entries in `~/.claude/settings.json`. |

## Manual one-shot test
From any shell with `bash`:
```bash
bash ~/.claude/hooks/notion-diary/session-start.sh </dev/null
ls -lt ~/.claude/hooks/notion-diary/logs/ | head
cat ~/.claude/hooks/notion-diary/logs/session-start-*.log | tail
```

For the Stop-style recorder, feed a transcript path on stdin (use `DIARY_FORCE=1` to bypass the 60s cooldown):
```bash
TX=$(ls -t ~/.claude/projects/*/*.jsonl 2>/dev/null | head -1)
printf '{"transcript_path":"%s","session_id":"manual-test","hook_event_name":"Stop"}' "$TX" \
  | DIARY_FORCE=1 bash ~/.claude/hooks/notion-diary/record.sh
ls -lt ~/.claude/hooks/notion-diary/logs/ | head
```

## Cost / cadence note
`Stop` would fire on every assistant turn, but the 60-second cooldown per `session_id` caps the rate. A 1-hour active session triggers at most ~60 helper-claude runs (worst case) and typically far fewer. The helper itself is cheap (small transcript window + a handful of Notion MCP calls). To trade quality for cost, switch the model from `sonnet` to `haiku` in `common.sh`.
