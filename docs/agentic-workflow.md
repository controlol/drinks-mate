# Agentic workflow — operations guide

How Drinks Mate is set up for autonomous, test-gated, agent-driven development.
This is the runbook for the scaffolding added in the "agentic setup" change.

## The loop, end to end

```
GitHub Issue                              @claude comment
(agent-ready label, "Depends on …")       on any issue/PR
        │                                         │
        ▼                                         ▼
.github/workflows/dispatch-agent.yml      .github/workflows/claude.yml
  pick next UNBLOCKED ready issue,          interactive: respond to the
  claim it (agent-working), cap in-flight   mention right away
        │                                         │
        └────────────────┬────────────────────────┘
                         ▼
            Claude reads CLAUDE.md + Parity Rulebook,
            branches (claude/issue-N), implements, opens a PR
                         │
                         ▼ dispatcher swaps issue label:
                           agent-working → agent-pr-open
                           adds agent-ok to the PR
                         │
                         ▼
.github/workflows/ci.yml              deterministic gate: format + analyze + test
.github/workflows/claude-review.yml   agentic review: inline comments + verdict
.github/workflows/security-review.yml agentic security scan: inline comments + verdict
                         │ all three pass?
                         ▼
.github/workflows/auto-approve.yml    posts a bot approval automatically
.github/workflows/review-remediation.yml  (on failure) agent fixes findings, re-pushes
                         │
                         ▼
Branch protection  ──►  bot approval counts  ──►  merge  ──►  issue closes, queue slot frees
```

The keystone is the **test suite** (`flutter/packages/core/test/`, `flutter/test/`): every other
layer trusts it. No agent change merges without the CI gate passing.

### How work is ordered

There is no implicit ordering — you declare it with **dependencies**, and the
dispatcher enforces it:

- Each `agent-ready` issue states what it is **blocked by** — either GitHub's
  native "blocked by" relationship, or a `Blocked by #N` / `Depends on #N` line
  in the body. The dispatcher reads both.
- On each tick `dispatch-agent.yml` picks the **lowest-numbered ready issue
  whose blockers are all closed**, labels it `agent-working` (the claim), and
  runs Claude on it. At most `MAX_IN_FLIGHT` (default **2**) agent PRs may be
  open at once. The agent branches from `main` using the naming convention
  `claude/issue-N[-slug]`, so each agent sees all prior merged work.
- Two labels track a slot's lifecycle: `agent-working` (agent running, no PR
  yet) and `agent-pr-open` (PR open, awaiting review). Both count toward the
  cap. On success the dispatcher swaps them and adds `agent-ok` to the PR; on
  failure it removes `agent-working` so the issue re-queues on the next tick.
  A slot fully frees when the PR merges and `Closes #N` closes the issue.

So the order is: **set dependencies → label `agent-ready` → the dispatcher
serializes the rest.** Bump `MAX_IN_FLIGHT` in `dispatch-agent.yml` once you
want independent issues to run in parallel.

## Trust & triggers

This is a **public** repo, so the agent workflows (which run with secrets and a
write-capable token) are gated against prompt-injection from untrusted input.
The rules:

| Workflow | Fires for | Gate |
|----------|-----------|------|
| `claude.yml` (`@claude` comments) | comment author is `OWNER` / `MEMBER` (not `COLLABORATOR` — that doesn't guarantee write access) | `author_association` check |
| `claude-review.yml`, `security-review.yml` (PRs) | PR by the **owner**, or from a pipeline **`claude/*`** branch in this repo, or a PR a maintainer has labelled **`agent-ok`** | `author_association` + head-branch + label |
| `dispatch-agent.yml` (queue) | issues labelled `agent-ready` | applying labels already requires triage/write access |

Net effect: a stranger's comment or fork PR **cannot** start an agent run. To run
the AI review/security on someone else's PR, a maintainer adds the `agent-ok`
label (re-runs on each push while the label is present). Interactive `@claude`
only responds to trusted authors.

> **Defense in depth (recommended):** also enable GitHub's native
> *Settings → Actions → General → "Require approval for all outside
> collaborators"* so even non-AI workflows (e.g. CI, which executes PR code)
> don't run on untrusted PRs without a maintainer's click.

## One-time setup

### 1. Add the auth secret(s)

**`claude.yml` and `claude-review.yml`** authenticate with a **Claude Pro/Max
subscription**. Generate a long-lived OAuth token locally (Pro/Max only) and
store it as a repo secret:

```bash
claude setup-token                          # opens an OAuth flow, prints a token
gh secret set CLAUDE_CODE_OAUTH_TOKEN       # paste the token when prompted
```

**`security-review.yml`** uses a separate action (`anthropics/claude-code-security-review`)
whose subscription-token support is unconfirmed; it expects a pay-as-you-go API key:

```bash
gh secret set ANTHROPIC_API_KEY             # paste the key when prompted
```

> Trade-offs: subscription runs count against your Pro/Max usage limits (shared
> with interactive Claude Code), so heavy per-PR automation competes with your
> own usage — switch the two action workflows back to
> `anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}` if you'd rather bill
> per-token. If you don't want the API key at all, drop `security-review.yml`.
> Bedrock/Vertex are also supported by `claude-code-action` (see its docs).

### 2. Install the Claude GitHub App
Run `/install-github-app` from Claude Code, or install the app from the GitHub
Marketplace and grant it this repo. This lets `anthropics/claude-code-action`
post comments and open PRs.

### 3. Claude Code config (already committed — no action needed)
`.claude/settings.json` is committed and shared: it pre-approves safe commands
(fewer permission prompts) and turns on the `PostToolUse` auto-format hook
(`.claude/hooks/format-dart.sh`). Both local sessions and cloud
`claude-code-action` runs pick it up automatically. Put any personal,
machine-specific overrides in `.claude/settings.local.json` (gitignored).

### 4. Create the queue + trust labels
```bash
gh label create agent-ready    --color 5319e7 --description "Queued for the agent dispatcher to implement"
gh label create agent-working  --color fbca04 --description "Dispatcher claimed this issue; agent is currently running"
gh label create agent-pr-open  --color 0052cc --description "Agent PR open, awaiting review"
gh label create agent-ok       --color 0e8a16 --description "Greenlit: run the AI review/security workflows on this PR"
gh label create needs-input    --color e4e669 --description "Needs human input, decision, or asset before the agent can proceed"
```
`dispatch-agent.yml` manages `agent-working` and `agent-pr-open` automatically
— you only ever apply `agent-ready` (the issue template does this for you).
`agent-ok` is added automatically to agent PRs by the dispatcher; it can also
be applied manually to greenlight a third-party PR for the review workflows
(see [Trust & triggers](#trust--triggers)).
The dispatcher is **event-driven** — labelling an issue `agent-ready` (or a PR
merging, which frees a slot) kicks it off within seconds, with a low-frequency
cron (`7,37 * * * *`) as a backstop since GitHub throttles short schedules. Like
all workflows it only runs from the **default branch**, so this takes effect
once merged to `main`.

### 5. Enable Actions to approve PRs

`auto-approve.yml` uses `GITHUB_TOKEN` to post an approving review. GitHub
blocks this by default:

**Settings → Actions → General → "Allow GitHub Actions to create and approve
pull requests"** → enable.

Without this, the auto-approve step fails silently with a 403 and agent PRs
still need a human to click Approve.

### 6. Turn on branch protection for `main`

Require the CI checks, the review checks, and at least one approving review
before merge. The bot approval from `auto-approve.yml` satisfies that last
requirement for agent PRs:

```bash
gh api -X PUT repos/:owner/:repo/branches/main/protection \
  -H "Accept: application/vnd.github+json" \
  -f 'required_status_checks[strict]=true' \
  -f 'required_status_checks[contexts][]=core package (pure Dart)' \
  -f 'required_status_checks[contexts][]=flutter app' \
  -f 'required_status_checks[contexts][]=review' \
  -f 'required_status_checks[contexts][]=security' \
  -F 'enforce_admins=true' \
  -F 'required_pull_request_reviews[required_approving_review_count]=1' \
  -F 'restrictions=null'
```

Adding `review` and `security` as required checks means a failing AI review or
security scan blocks merge directly — not just as advisory comments.

> **Merge:** once all four status checks are green, `auto-approve.yml` posts a
> bot approval and the PR can be merged without any human interaction. Enable
> auto-merge on the PR (`gh pr merge --auto --squash`) or let the agent do it
> in the dispatch prompt if you want fully hands-off merging.

## Day-to-day

- **Create work:** open an issue with the *Agent task* template (auto-labels
  `agent-ready`), set its **Depends on** if it must wait for other issues, or
  comment `@claude <instruction>` on any issue/PR for an immediate, interactive
  run.
- **Deferred review findings:** when the code reviewer finds something it cannot
  fix without human input (missing design asset, unresolved spec ambiguity,
  product decision), it opens a `needs-input` issue instead of failing the PR.
  Supply the required input in the issue, then add `agent-ready` when ready for
  the agent to act on it. Do NOT add `agent-ready` yourself until the input is
  complete — the dispatcher picks up `agent-ready` issues immediately.
- **Order a batch:** label everything `agent-ready`, then express the chain with
  dependencies (native "blocked by" or `Blocked by #N` in the body). The
  dispatcher releases them one at a time as their blockers merge — no need to
  withhold labels manually.
- **Dispatch now / unstick:** run the *Agent dispatcher* workflow manually
  (Actions → Agent dispatcher → Run workflow) — optionally pass an issue number
  to force it past the queue. If a claim is stuck (PR closed without merging, or
  a stalled run), remove whichever slot label is present (`agent-working` if the
  agent never finished, `agent-pr-open` if the PR was closed without merging) to
  re-queue the issue.
- **Definition of done** (what agents and CI both enforce) — from repo root:
  ```bash
  (cd flutter/packages/core && dart format --output=none --set-exit-if-changed . && dart analyze --fatal-infos && dart test)
  (cd flutter              && dart format --output=none --set-exit-if-changed . && flutter analyze && flutter test)
  ```
- **Local review:** ask Claude to "use the reviewer subagent on my diff" or run
  `/code-review` before pushing.

## MCP servers

Project-scoped MCP servers are declared in `.mcp.json` (committed, so every
contributor and cloud run gets the same set). Currently enabled:

- **`dart`** — the official Dart & Flutter MCP server (`dart mcp-server`). Gives
  agents structured tools to run tests, analyze and fix errors, format, manage
  `pubspec.yaml` deps, search pub.dev, and introspect a running app. This is what
  lets an agent drive the definition-of-done loop through tools rather than raw
  shell. Requires the Flutter SDK's `dart` on PATH (see step 0 below).
- **`context7`** — current, version-accurate docs for Flutter/Dart and the
  stack (Drift, Riverpod, fl_chart, …) via `npx @upstash/context7-mcp`. Counters
  stale-training-data answers. (Optional: set a Context7 API key for higher rate
  limits.)

> **Step 0 — `dart` on PATH.** The Dart MCP server is launched as bare `dart`,
> so the Flutter SDK's `bin` must be on PATH. If you installed via the VS Code
> extension it may not be — add it once:
> ```powershell
> [Environment]::SetEnvironmentVariable("Path",
>   [Environment]::GetEnvironmentVariable("Path","User") + ";C:\Users\luc.appelman\develop\flutter\flutter\bin", "User")
> ```
> If Claude Code doesn't see the project root, add `"--force-roots-fallback"` to
> the `dart` server's `args`.

**Deliberately not enabled yet — mobile-automation MCPs.** These drive a
simulator/emulator/device for integration & E2E tests, so they only earn their
keep once there's real UI and `integration_test`/Patrol flows (and they need
that toolchain installed, or they just fail to start). When that lands, add one:

```jsonc
// merge into .mcp.json → mcpServers
"mobile": { "command": "npx", "args": ["-y", "@mobilenext/mobile-mcp@latest"] }
// or an Appium-based server: appium/appium-mcp, @mobilepixel/mcp
```

`mcp_flutter` (runtime introspection + simulator/device screenshots) is the
other one to consider for visual, agent-driven UI work at that stage.

## What's intentionally NOT here yet (next steps)

- **Integration tests** (`integration_test` + Patrol) and a nightly cron job —
  add once there are real user flows; wire into `ci.yml` (placeholder noted there).
- **Golden tests** for design-system parity — add with the first real widgets;
  pin DPR and bundle DM Sans to avoid flakiness.
- **Coverage thresholds** — enforce ≥80% on `core`/services once the suite is
  fleshed out (e.g. via a coverage check step or a service like Codecov).
- **Parallel dispatch** — `MAX_IN_FLIGHT` is 2, allowing two agent PRs open
  simultaneously. Independent issues with no shared files run safely in parallel;
  issues that touch the same code should use `Blocked by` dependencies to stay
  serial. Raise or lower the cap in `dispatch-agent.yml` as the queue grows.
- **`core` NFC normalisation** — username validation needs NFC before the
  structural check; tracked as a TODO in `flutter/packages/core/lib/src/username.dart`.

## Why this shape

- One Flutter codebase ⇒ cross-platform computation parity holds by
  construction, so the old shared golden-vector suite collapses into ordinary
  `core` unit tests (seeded from the design docs' worked examples).
- Deterministic CI catches the bulk cheaply and with zero false positives;
  the AI review layer catches what static checks can't; humans gate the merge.
