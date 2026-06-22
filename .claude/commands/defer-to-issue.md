# Defer-to-issue process for PR review

When you encounter a finding during PR review that the agent **cannot resolve
itself** because it requires human input, a file upload, a product decision,
or external context not present in the repository, defer it to a GitHub issue
rather than blocking the PR.

## Never-defer list — always FAIL the review for these

The following categories are NEVER deferrable. If in doubt, FAIL:

- Correctness bugs and missing edge-case handling in production code
- Parity Rulebook violations (`engineering/decisions/design-system.md` → Appendix):
  the Rulebook is law; ambiguity means block, not defer
- Phase-1 constraint breaches: `core` must stay pure Dart; no Phase-2 entities
  (`Account`, `Friendship`, `ShareSetting`); no banned dependencies
- Missing unit tests for new `core` computation

## Deferrable — only when blocked on human input

Defer a finding only when fixing it is **impossible without human input**:

- A UX or product decision where the spec lists multiple options and no choice
  was made (e.g. "which default unit — ml or oz — should the picker open to?")
- A missing asset (icon, image, font, fixture file) referenced in code but not
  yet committed — the agent cannot create design assets
- A missing or ambiguous spec: the code references behaviour not described
  anywhere in `design/` and the correct implementation is unclear
- An architectural scope question that requires a product owner decision
  (e.g. "should this feature extend into Phase 2?")

Do NOT defer: technical debt, low-priority nits, stylistic preferences,
deprecation warnings the agent could fix, or anything you could resolve yourself.

## How to defer

**Only create issues on `opened` or `reopened` events.** On `synchronize`
(a push to an existing PR), post the inline comment but SKIP issue creation —
the same PR will receive duplicate issues on every push otherwise.

### 1. Post an inline comment

On the relevant line, explain what is needed:

> "Deferred — this requires [human input / a design decision / a missing asset].
>  Will track in a new issue."

### 2. Create a GitHub issue (opened/reopened only)

```bash
gh issue create \
  --repo REPO \
  --title "Short descriptive title (from PR #N review)" \
  --body "**From review of PR #N**

**File:** path/to/file.dart:LINE

**What is needed:**
<describe the decision, asset, or input required>

**Context:**
<the code or spec excerpt that makes this necessary>" \
  --label "needs-input"
```

Replace `REPO` with the actual `owner/repo` string.
Do NOT add `agent-ready` — a human must supply the input and promote the issue.

### 3. Update the inline comment with the issue number

After `gh issue create` prints the issue URL, extract the issue number and
update (or re-post) the inline comment to say "Deferred — tracked in #N".

### 4. Verdict

Deferred findings do **not** count as FAIL. A FAIL verdict is only written
when there is at least one finding from the never-defer list.
