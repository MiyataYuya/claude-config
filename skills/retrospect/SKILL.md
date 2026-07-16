---
name: retrospect
description: Use at the end of a task or session to retrospect on whether the effort spent was appropriate — the /effort level, orchestration approach (solo vs subagents vs workflow vs ultracode), model, review depth, and token/time cost — and to record a reusable calibration heuristic so future effort choices are better. Trigger when the user asks to reflect on how the work went, whether an approach was overkill or too thin, "この effort 適切だった?", "ultracode 役に立った?", "過剰だった?", "振り返って", "retrospect", "次はどう進めるべき", or invokes /retrospect. Also fitting right after finishing a substantial piece of work, before moving on.
---

# Effort Retrospect

## What this does and why

After finishing a task, judge honestly whether the effort you spent matched what the task needed, and write the lesson somewhere that will actually change your next effort choice. The goal is calibration: over time, stop under-powering risky work and stop over-powering trivial work.

The durable output lives in **`~/.claude/docs/effort-calibration.md`** — an accumulating playbook of "condition → recommended effort" heuristics. `~/.codex/AGENTS.md` points to it, so it gets consulted before choosing effort on a substantial task. A retrospect that doesn't update the playbook is wasted; the playbook is the whole point.

## When to run

- The user asks how the work went, whether an approach was overkill or too thin, or invokes `/retrospect`.
- You just finished a substantial task (a feature, a non-trivial fix, an investigation) and are about to move on.

Skip it for trivial conversational turns — there's nothing to calibrate.

## The retrospect: judge on evidence, not vibes

The single most important rule: **base every verdict on what actually happened this session, not on how it felt.** This follows the user's "嘘禁止" rule. Before claiming a lever was over- or under-powered, cite the concrete evidence — how many agents/workflows ran, roughly how many tokens, what the review actually caught, where there was rework or backtracking. If you can't point to evidence, say the verdict is uncertain.

Assess these four dimensions:

### 1. Task profile
What kind of work was it, and how much did it *deserve*?
- **Type**: bugfix / feature / refactor / docs / investigation / conversational.
- **Risk**: blast radius (shared vs isolated code), auth/security/data involvement, reversibility, whether others depend on it. High risk raises the appropriate effort floor.
- **Complexity & scope**: number of files/subsystems, how much was already known vs had to be discovered.

### 2. Effort actually spent (measure it)
- **/effort level** in play (auto / xhigh / ultracode / etc.).
- **Orchestration**: solo, individual subagents, a Workflow, ultracode. How many agents were spawned.
- **Model**, **review depth** (none / self / single reviewer / adversarial panel), and approximate **token cost** and **wall-clock**.

### 3. Verdict per lever
For each lever, rate **under-powered / appropriate / over-powered**, with the evidence:
- **Scout/understand** — did exploration find things a lighter pass would have missed, or did it re-derive things already known (e.g. root cause already in CLAUDE.md/memory)? Failed/empty subagents are a signal of waste.
- **Implement** — right-sized, or gold-plated / under-built?
- **Review** — did it catch a real defect you'd have shipped (worth it), or produce only nits (overkill)? A caught regression justifies a lot.
- **Verify** — enough to be confident, or ceremonial / skipped where it mattered?

Be willing to say "over-powered" even about impressive-looking work. The whole value of this skill is catching over-spend, which flattery hides.

### 4. Next-time heuristic
Distill one reusable line: **"<condition> → <recommended effort/approach>, because <evidence>"**. This is the takeaway that goes in the playbook. Make the condition general enough to match future tasks (task-type + risk), not specific to this one instance.

## Process

1. **Read the playbook** (`~/.claude/docs/effort-calibration.md`) first, so you can confirm, sharpen, or contradict existing heuristics rather than duplicating them.
2. **Gather session facts** — what was actually done: workflows/agents run and how many succeeded, rough token spend, review findings (real vs nits), rework/backtracks, verification performed.
3. **Present the retrospect** to the user using the output template below. Keep it tight; lead with the verdicts.
4. **Update the playbook** — see maintenance rules below. Do this every time; it's the point.

## Output template

```
## Retrospect: <task in a few words>

**Task profile**: <type> / risk <low|med|high> / <complexity note>
**Effort spent**: <effort level>, <orchestration + agent count>, <model>, review <depth>, ~<tokens>/<time>

**Verdict per lever** (evidence in parens):
- Scout/understand: <under|appropriate|over> — <evidence>
- Implement: <under|appropriate|over> — <evidence>
- Review: <under|appropriate|over> — <evidence>
- Verify: <under|appropriate|over> — <evidence>

**Next time**: <the reusable heuristic line>
```

## Playbook maintenance (keep it lean or it dies)

The playbook only stays useful if it stays short and true. When updating `~/.claude/docs/effort-calibration.md`:

- **Merge, don't append blindly.** If a matching heuristic exists, sharpen it (tighten the condition, update the date) instead of adding a near-duplicate. Place new rules under the matching theme section (スカウト/着手前 / 実装オーケストレーション / レビュー / 検証 / Ops・デプロイ / 委譲の品質管理).
- **Corroborate by tag, not narrative.** When a session confirms an existing rule, append only a `(YYYY-MM-DD caseID)` tag to its evidence list — plus at most a few words if the condition itself sharpened. Never append parenthetical case narratives; that habit once bloated the playbook to 33KB. Details belong in git history, not the playbook.
- **Contradict openly.** If this session's evidence contradicts an existing heuristic, revise it and note the change — don't leave both.
- **Trim.** Keep each heuristic to ~1-3 lines. If the file grows past a screenful, consolidate: prefer a few strong, general rules over many narrow ones. Drop rules that have never matched again.
- **Date entries** so stale advice is visible. Use the actual date (ask/derive; don't invent).
- **One condition, one recommendation, one why.** If you can't state the "why" from evidence, it's not ready to be a heuristic yet.

If a heuristic proves strong and repeats across several sessions, mention to the user that it might be worth promoting into `~/.codex/AGENTS.md` as a standing rule — but leave that to the user; don't edit AGENTS.md yourself beyond the one-line pointer.
