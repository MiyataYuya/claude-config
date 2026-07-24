---
name: retrospect
description: Use at the end of a task or session to retrospect on whether you assigned the right agent type / model tier (Fable / Opus / Sonnet / Haiku) to each piece of work — and to record a reusable "condition → tier" heuristic so future agent-selection choices are better. Also covers the surrounding effort levers (orchestration, review depth, verification) insofar as they are agent-assignment decisions. Trigger when the user asks to reflect on how the work went, whether the right agent/model was called, whether an approach was overkill or too thin, "この effort 適切だった?", "適切なエージェント呼べた?", "モデル選択合ってた?", "ultracode 役に立った?", "過剰だった?", "振り返って", "retrospect", "次はどう進めるべき", or invokes /retrospect. Also fitting right after finishing a substantial piece of work, before moving on.
---

# Agent-Selection Retrospect

## What this does and why

The point of this skill is **calibrating agent selection**: after finishing a task, judge honestly whether you assigned the right agent type — model tier (Fable / Opus / Sonnet / Haiku) — to each piece of work, and write the lesson somewhere that will change your next assignment. Over time, stop running mechanical work on expensive tiers and stop running design / security judgment on cheap ones.

This is **not** a "did the task succeed?" review. Success is table stakes and mostly already known by the time you get here. The question this skill answers is: *given how the work actually went, which agent tier should each piece have run on, and did the assignment you made match that?*

### The tiers (from `~/.codex/AGENTS.md`)

- **Haiku** — trivial mechanical work: simple greps, one-shot transcription, throwaway probes.
- **Sonnet** — mechanical / high-volume but low-judgment: exhaustive-read Explore, grep+read transcription, N-file same-shape edits, spec-fixed test rewrites, log-formatting/collection loops.
- **Opus** — mid-level investigation and implementation: real judgment needed but bounded stakes.
- **Fable** — high-judgment work: design decisions (Plan), auth / security / data logic, code review, adversarial passes.

The default failure mode is **spawning a subagent with no model param, so it silently inherits main (= the most expensive tier)** — plus the symmetric failure of running high-volume mechanical work on main instead of delegating it to Sonnet/Haiku. Catching both is exactly what this retrospect exists for.

The durable output lives in **`~/.claude/docs/effort-calibration.md`** — an accumulating playbook of "condition → recommended tier / assignment" heuristics. `~/.codex/AGENTS.md` points to it, so it gets consulted before assigning agents on a substantial task. A retrospect that doesn't update the playbook is wasted; the playbook is the whole point.

## When to run

- The user asks how the work went, whether the right agent/model was used, whether an approach was overkill or too thin, or invokes `/retrospect`.
- You just finished a substantial task (a feature, a non-trivial fix, an investigation) and are about to move on.

Skip it for trivial conversational turns — there's nothing to calibrate.

## The retrospect: judge on evidence, not vibes

The single most important rule: **base every verdict on what actually happened this session, not on how it felt.** This follows the user's "嘘禁止" rule. Before claiming a tier was too high or too low, cite the concrete evidence — which agent ran on which model, roughly how many tokens, what a review actually caught, where there was rework or backtracking, whether an agent failed or returned empty. If you can't point to evidence, say the verdict is uncertain.

### 1. The work actually done, piece by piece

List every distinct piece of work — each subagent spawned **and** the substantive work main did itself — and for each capture:

- **Phase / role**: scout·understand / implement / review / verify / ops / delegation-QA.
- **What it required**: mechanical transcription, vs bounded investigation, vs high-judgment (design / auth / review). This determines the *ideal* tier.
- **What it actually ran on**: the model tier used — and for spawns, whether a model param was set at all (an unset param means it silently inherited main).
- **Cost signal**: rough tokens, agent count, wall-clock, and whether the work succeeded / returned empty / needed redo.

### 2. Agent-selection verdict per piece (the core of this skill)

For EACH piece of work, rate the tier assignment **too-high / right / too-low**, with the evidence:

- **Right tier for the judgment level?** Mechanical work (grep, transcription, exhaustive Explore, same-shape edits, log loops) on Opus / Fable / main = too-high — reclaim it for Sonnet/Haiku. Design, auth / security, or review on Haiku / Sonnet = too-low — and this is the dangerous direction, the one that ships defects.
- **Should main have delegated it at all?** Work main did inline that was mechanical and high-volume should have gone to Sonnet/Haiku. (User rule: 3 consecutive mechanical direct-executions on main = violation; call it out here.)
- **Did an unset model param cause silent inheritance?** Flag every spawn that ran on main by default — even if the tier happened to be fine, the *habit* is the finding.
- **Did the review tier match the risk?** Shared / auth / security / data / irreversible changes need a Fable adversarial pass; isolated low-risk work does not. A review that caught a real would-ship defect justifies its tier; one that produced only nits was too-high.

Be willing to say "too-high" even about impressive-looking work — catching over-spend is what flattery hides. Be just as willing to say "too-low" when cheap-tier work touched something that deserved judgment; under-powering risky work is the costlier error.

### 3. Surrounding levers (only as agent-assignment decisions)

Effort level, orchestration (solo / subagents / Workflow / ultracode), and verification depth matter here *because they are agent-assignment decisions*. Note them only insofar as they change the tier picture:

- **Orchestration**: did fanning out to N agents pay off, or would solo-on-one-tier have been right? Failed/empty subagents are a waste signal.
- **Verify**: thick enough where it mattered, thin where it didn't — and did verification need its own agent or fit on main?

Don't re-litigate task success beyond what's needed to justify a tier verdict.

### 4. Next-time heuristic (phrased as tier assignment)

Distill one reusable line: **"<condition> → <tier / assignment>, because <evidence>"**. The condition must be general enough to match future tasks (task-type + judgment-level + risk), and the recommendation must name the **tier** (Fable / Opus / Sonnet / Haiku) or the **delegate-vs-keep-on-main** decision. That is the takeaway that goes in the playbook.

Target shape:
- "N-ファイル同型編集 → Sonnet 委譲（main/Opus は too-high）, because …"
- "auth 境界のロジック変更 → Fable で実装 + Fable adversarial review, because 安価層は…を見逃した"
- "根本原因が既に文書化済み → scout は Haiku/Sonnet solo grep で足り、理解 Workflow は過剰, because …"

## Process

1. **Read the playbook** (`~/.claude/docs/effort-calibration.md`) first, so you can confirm, sharpen, or contradict existing tier heuristics rather than duplicating them.
2. **Gather session facts** — which agents ran on which tier, how many succeeded, rough token spend, review findings (real vs nits), rework/backtracks, and what main did inline.
3. **Present the retrospect** using the output template below. Lead with the per-piece tier verdicts.
4. **Update the playbook** — see maintenance rules below. Do this every time; it's the point.

## Output template

```
## Retrospect: <task in a few words>

**Work done** (piece → what it required → tier it ran on):
- <phase/spawn>: <mechanical | bounded-investigation | high-judgment> → <tier used>{ · model param unset → inherited main}
- ... (one line per spawn AND per substantive main-inline task)

**Agent-selection verdict** (evidence in parens):
- <phase/spawn>: <too-high | right | too-low> — <actual vs ideal tier + evidence>
- ... (if no agents were spawned, say so explicitly, then judge whether some work should have been delegated to a cheaper tier)

**Surrounding levers**: orchestration <note> · review depth <note> · verify <note> — only where they change the tier picture

**Next time**: <condition> → <tier / delegate-or-keep decision>, because <evidence>
```

## Playbook maintenance (keep it lean or it dies)

The playbook only stays useful if it stays short and true. When updating `~/.claude/docs/effort-calibration.md`:

- **Phrase agent-selection heuristics as "condition → tier".** Name the tier (Fable / Opus / Sonnet / Haiku) or the delegate-vs-keep-on-main decision explicitly — a heuristic that names no tier and no assignment isn't doing this skill's job. Place it under `実装オーケストレーション` (which already carries the tier-assignment rules) or the matching theme section (スカウト/着手前 / レビュー / 検証 / Ops・デプロイ / 委譲の品質管理).
- **Merge, don't append blindly.** If a matching heuristic exists, sharpen it (tighten the condition, update the date) instead of adding a near-duplicate.
- **Corroborate by tag, not narrative.** When a session confirms an existing rule, append only a `(YYYY-MM-DD caseID)` tag to its evidence list — plus at most a few words if the condition itself sharpened. Never append parenthetical case narratives; that habit once bloated the playbook to 33KB. Details belong in git history, not the playbook.
- **Contradict openly.** If this session's evidence contradicts an existing heuristic, revise it and note the change — don't leave both.
- **Trim.** Keep each heuristic to ~1-3 lines. Prefer a few strong, general tier rules over many narrow ones. Drop rules that never match again.
- **Date entries** with the actual date (ask/derive; don't invent).
- **One condition, one tier recommendation, one why.** If you can't state the "why" from evidence, it's not ready to be a heuristic yet.

If a tier heuristic proves strong and repeats across several sessions, mention to the user that it might be worth promoting into `~/.codex/AGENTS.md` as a standing rule — but leave that to the user; don't edit AGENTS.md yourself beyond the one-line pointer.
