# Agent pipeline performance report — issues #94–#105

Forensic analysis of the autonomous dispatch → implement → review → remediate pipeline
(`.github/workflows/dispatch-agent.yml`, `ci.yml` `review`/`security` jobs,
`review-remediation.yml`, `claude-comment.yml`) for the 12 issues closed since #94, reconstructed
from GitHub Actions run logs (Claude Code verbose `stream-json` transcripts), PR reviews, and issue
comments. All 12 mapped 1:1 to PRs #107–#118.

## Methodology notes (read before the numbers)

- **"Number of rolls"** is interpreted as `num_turns` from each run's final `result` event (one
  turn ≈ one assistant message / tool-call round-trip). This term isn't native to Claude Code
  vocabulary, so treat the mapping as an assumption.
- **"Compact" / compaction** means an actual `compact_boundary` system event (context got
  auto-summarized mid-run) — not the literal string "compact" appearing in a slash-command list.
- **Subagents** are counted via distinct `task_id`s on `task_started` system events (deduped —
  the same block can repeat across streamed JSON deltas). "Skills" (the Claude Code `Skill` tool)
  are a *different* mechanism from the project's `.claude/agents/*` subagents (`test-author`,
  `spec-auditor`, `feature-scaffolder`, `reviewer`), which are invoked via the `Task` tool's
  `subagent_type` field, not the `Skill` tool.
- **Blind spot (important):** `dispatch-agent.yml` runs with full streamed output
  (`show_full_output: true`), so its logs contain every turn, subagent, and rate-limit event.
  `review-remediation.yml` and interactive `@claude` comment runs (`claude-comment.yml`) run with
  `show_full_output: false` — their logs contain **only** the init message and the final `result`
  summary. Turn count and cost are recoverable for every run; subagent/compaction/rate-limit detail
  is **only** recoverable for the 12 initial implementation passes, not for remediation or
  interactive-fix runs. No output artifact is uploaded that would fill this gap.
- **Log truncation gotcha:** `gh run view --log` silently truncated two of the longer job logs
  (~1.7MB/2.5MB) mid-transcript. The full transcript required `gh api repos/.../actions/jobs/{id}/logs`
  directly. Worth knowing for any future pull.
- Timestamps for run→issue mapping were verified by cross-referencing each PR's `createdAt` against
  the triggering run's execution window — GitHub Actions' `displayTitle` for a
  `pull_request: closed`-triggered dispatch run reflects the *previous* issue's title (the one that
  freed the queue slot), not the issue actually implemented inside that run. This was a real
  ambiguity worth flagging: naively matching by displayed title would have mis-attributed issue
  #105's implementation to issue #104's run.

## API overload / rate-limiting — direct answer to "how often, how long"

**Zero.** Across all 12 initial implementation runs (the only runs where this is fully observable)
and the 2 remediation runs for issue #103 (`is_error: false`, no error text), there is no
`overloaded_error`, no HTTP 429/529, no non-null `api_error_status`, and no `rate_limit_info.status`
other than `"allowed"`. Every run's single periodic `rate_limit_event` showed `status: "allowed"`
on the `five_hour` window (with `overageStatus: "rejected"` / `org_level_disabled` — the
organization has usage overage disabled, but no run ever hit the point of needing it). **Total
time spent waiting on API overload across the entire batch: 0 seconds.** The 3 hidden-output runs
for issue #95 also completed with `is_error: false` and no error text, so nothing suggests overload
there either, though granular retry/backoff detail can't be confirmed for those specific runs.

## Per-issue summary

| # | Title | Impl. wall-clock | Turns | Cost | Subagents | Skills | Compaction | API overload waits | Remediation cycles | Complexity* |
|---|-------|---:|---:|---:|---|---|---:|---:|---:|---:|
| [#94](https://github.com/controlol/drinks-mate/issues/94) | Wire `checkAndApplyAutoEnd` into 5 trigger points | 56m22s | 94 | $13.43 | 3 (general-purpose, test-author, spec-auditor) | none | 0 | 0 | 0 | 3 |
| [#95](https://github.com/controlol/drinks-mate/issues/95) | Today view stale after backgrounding/day-boundary | 13m6s (+3 fix rounds, ~8.6h span) | 32 (+103+111+48) | $3.22 (+$21.49) | 2 initial (test-author, spec-auditor); not observable for fix rounds | none | 0 | 0 | **3** (1 auto-failed silently, 2 human-triggered succeeded) | 4 |
| [#96](https://github.com/controlol/drinks-mate/issues/96) | Logged-drink toast never auto-dismisses | 14m0s | 35 | $3.26 | 2 (test-author, spec-auditor) | none | 0 | 0 | 0 | 1 |
| [#97](https://github.com/controlol/drinks-mate/issues/97) | `NotificationService.initialize()` never called | 10m57s | 39 | $2.55 | 2 (general-purpose, spec-auditor) | none | 0 | 0 | 0 | 1 |
| [#98](https://github.com/controlol/drinks-mate/issues/98) | Meal prompt fires per-drink, not once | 17m12s | 56 | $4.77 | 2 (general-purpose, spec-auditor) | none | 0 | 0 | 0 | 2 |
| [#99](https://github.com/controlol/drinks-mate/issues/99) | Rename "Log a drink" grid → "Quick Log" | 17m43s | 66 | $4.11 | 2 (test-author, spec-auditor) | none | 0 | 0 | 0 | 1 |
| [#100](https://github.com/controlol/drinks-mate/issues/100) | Entry edit sheet opens near-full height | 17m51s | 48 | $3.66 | 2 (test-author, spec-auditor) | none | 0 | 0 | 0 | 2 |
| [#101](https://github.com/controlol/drinks-mate/issues/101) | Discard zero-drink sessions; allow delete | 34m27s | 117 | $13.00 | 3 (general-purpose ×2, spec-auditor) | none | 0 | 0 | 0 | 3 |
| [#102](https://github.com/controlol/drinks-mate/issues/102) | Allow naming a party session | 48m49s | 104 | $19.19 | 3 (general-purpose, test-author, spec-auditor) | none | 0 | 0 | 0 | 3 |
| [#103](https://github.com/controlol/drinks-mate/issues/103) | Tappable BAC card, chart empty-state, tap-inspect | 40m24s (+2 fix rounds, ~37m) | 106 (+43+33) | $10.53 (+$7.68) | 3 initial; not observable for fix rounds | none | 0 | 0 | **2** (both automated, both succeeded) | 4 |
| [#104](https://github.com/controlol/drinks-mate/issues/104) | Alcohol quick-log widget + sticky button | 39m35s | 93 | $12.39 | 2 (test-author, spec-auditor) | none | 0 | 0 | 0 | 3 |
| [#105](https://github.com/controlol/drinks-mate/issues/105) | History day drill-down expand-on-tap | 47m59s | 111 | $14.76 | 2 (test-author, spec-auditor) | none | 0 | 0 | 0 | 3 |

\* Complexity (1–5) is **my inference**, not a measured value — based on issue scope, diff surface,
turn count, and whether a remediation round was needed. There's no logged "complexity score" in the
pipeline.

**Totals:** initial-pass cost ≈ **$104.87**, all-in (incl. remediation) ≈ **$134.04** across 12
issues; initial-pass turns ≈ **901**, all-in ≈ **1,239**; 28 subagent invocations confirmed in
initial passes (always 2–3 per issue, drawn from `general-purpose`, `test-author`,
`spec-auditor` — matching CLAUDE.md's documented delegation pattern); **zero** Skill-tool
invocations, **zero** compaction events, **zero** API-overload waits anywhere.

## The two issues that needed remediation

### #95 — Invalidate day-window providers on app resume (the hard one)

One underlying coupling caused two sequential regressions before it was fully fixed, spanning
~8.6 hours real time (not agent compute time):

1. **Initial pass** (13m6s, 32 turns, $3.22): wired 5 day-window provider invalidations into
   `AppLifecycleState.resumed` — correct for the stated bug, but had a side effect: it also
   re-ran `reminderReschedulerProvider` on every app resume, indefinitely postponing the
   hydration reminder for anyone who checks their phone often. **Caught by CI review.**
2. **Automated remediation attempt** (`review-remediation.yml`, 22m45s, 103 turns, $6.29):
   the SDK call itself reported success, but **no fix ever landed** — no commit appeared between
   the original and 6 hours later. The workflow's success signal is "did a summary file get
   written," and it wasn't, so it correctly posted "Automated remediation failed," but silently —
   103 turns and $6.29 were spent producing nothing.
3. ~5 hours later the repo owner manually commented `@claude continue working on the remediation`.
   **Human-triggered fix** (28m17s, 111 turns, $9.46) shipped a suppression fix — but it
   over-corrected, unable to distinguish "resume re-emitted the same total" from "a genuine
   day-boundary rollover that happens to re-emit the same total," silently dropping the once-daily
   inactivity reminder on zero-intake days. **Caught by CI review again** (a new regression).
4. Owner commented `@claude fix the new issues in the comments of this PR`. **Second human-triggered
   fix** (14m9s, 48 turns, $5.74) added a day-start signal that always changes across a real
   boundary, closing the gap. Final review/security passed clean.

**Category of fixes:** correctness bugs (state-invalidation side effects), not Parity Rulebook or
test-coverage issues. **Still-open concerns at merge:** none — final review found nothing.

### #103 — Tappable BAC card / chart empty-state (2 automated remediation cycles, no human needed)

Both cycles were the automated `review-remediation.yml` path and both succeeded on their own:

1. **Initial pass** (40m24s, 106 turns, $10.53) built the tappable card/chart. CI review found a
   **correctness bug**: `_BacLineChartCardState` had no `didUpdateWidget`, so a tap-to-inspect
   marker could survive a series rescale and point at nothing (e.g. tap the empty-state line, then
   log a drink).
2. **Remediation cycle 1** (27m36s, 43 turns, $6.15): added `didUpdateWidget` clearing the marker
   on `alcoholicEntries`/`meals` changes. Fixed and shipped.
3. Because this pushed a commit directly to the PR branch, **two CI runs fired in parallel** under
   different concurrency groups (`pull_request: synchronize` vs. the remediation workflow's own
   `workflow_dispatch`) — reviewing the *identical* diff. Since `review` is an LLM judgment, not a
   deterministic check, the two runs disagreed: one passed, the other caught a second **correctness
   bug** the first missed — the same class of stale-marker bug, this time triggered by editing
   weight/gender in Settings (the marker-clearing guard didn't watch `widget.profile`).
4. **Remediation cycle 2** (9m5s, 33 turns, $1.53): added `widget.profile` to the clearing
   condition. Fixed and shipped; final review passed clean.

**Category of fixes:** both correctness bugs (missing widget-rebuild invalidation), same root
class, not Parity Rulebook or security issues. **Still-open concerns at merge (deliberately
deferred, not bugs):**
- A tick-interval boundary ambiguity in the BAC chart's empty-state window (spec says "under ~3h,"
  code hardcodes exactly 3h) — flagged twice across both review rounds as a genuine spec ambiguity
  needing a human product decision, not remediated.
- A code comment saying two `InkWell`s are "nested" when they're actually non-overlapping siblings
  — cosmetic, no behavior impact, left as-is.

## The other 10 issues — all clean, single-pass

#94, #96, #97, #98, #99, #100, #101, #102, #104, #105 all passed `review` and `security` on the
first CI run, no remediation, no human intervention. A handful of non-blocking advisory notes were
raised by the reviewer but explicitly judged non-issues or pre-existing/out-of-scope:
- **#94:** a pre-existing zero-drink-session-discard gap (already tracked as #101) became more
  load-bearing but wasn't a new defect.
- **#98:** a code comment slightly overstated the party-session-lifecycle step ordering.
- **#101:** `spec-auditor` caught 2 test-coverage gaps *during* implementation (before the PR was
  even opened), so nothing reached review unresolved.
- **#102:** a cosmetic grapheme-vs-rune counting nuance in a text field's `maxLength`, and a
  pre-existing (not-this-PR) unguarded migration-upgrade risk noted for awareness.
- **#104:** a small, harmless duplication of a toast-display helper instead of reusing the shared one.

No PR in the batch has any comment indicating something is *still* wrong at the time of merge,
except the two explicitly-deferred product-decision items on #103 noted above.
