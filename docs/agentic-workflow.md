# Agentic workflow — operations guide

How Drinks Mate is set up for autonomous, test-gated, agent-driven development.
This is the runbook for the scaffolding added in the "agentic setup" change.

## The loop, end to end

```
GitHub Issue (agent-ready label or @claude mention)
        │
        ▼
.github/workflows/claude.yml  ──►  Claude reads CLAUDE.md + Parity Rulebook,
                                   branches, implements, opens a PR
        │
        ▼
.github/workflows/ci.yml          deterministic gate: format + analyze + test  (must pass)
.github/workflows/claude-review.yml  agentic review: inline comments on the diff
.github/workflows/security-review.yml  AI security scan
        │
        ▼
Branch protection  ──►  human approval  ──►  merge
```

The keystone is the **test suite** (`flutter/packages/core/test/`, `flutter/test/`): every other
layer trusts it. No agent change merges without the CI gate passing.

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

### 4. Create the `agent-ready` label
```bash
gh label create agent-ready --color 5319e7 --description "Dispatch an AI agent to implement this issue"
```

### 5. Turn on branch protection for `main`
Require the CI checks and at least one approving review before merge:

```bash
gh api -X PUT repos/:owner/:repo/branches/main/protection \
  -H "Accept: application/vnd.github+json" \
  -f 'required_status_checks[strict]=true' \
  -f 'required_status_checks[contexts][]=core package (pure Dart)' \
  -f 'required_status_checks[contexts][]=flutter app' \
  -F 'enforce_admins=true' \
  -F 'required_pull_request_reviews[required_approving_review_count]=1' \
  -F 'restrictions=null'
```

> Keep a human in the merge loop until you trust the pipeline. The agentic and
> security reviews advise; they do not auto-merge.

## Day-to-day

- **Create work:** open an issue with the *Agent task* template (auto-labels
  `agent-ready`), or comment `@claude <instruction>` on any issue/PR.
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
- **Poll-driven auto-dispatch** (a daemon that claims issues without a human
  mention/label) — only graduate to this once the test gate is trustworthy.
- **`core` NFC normalisation** — username validation needs NFC before the
  structural check; tracked as a TODO in `flutter/packages/core/lib/src/username.dart`.

## Why this shape

- One Flutter codebase ⇒ cross-platform computation parity holds by
  construction, so the old shared golden-vector suite collapses into ordinary
  `core` unit tests (seeded from the design docs' worked examples).
- Deterministic CI catches the bulk cheaply and with zero false positives;
  the AI review layer catches what static checks can't; humans gate the merge.
