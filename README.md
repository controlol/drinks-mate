# Drinks Mate

A mobile app for iOS and Android that helps people track their daily drink
intake and stay properly hydrated — fast logging, steady-intake nudges, and an
honest picture of *what* you drink, not just how much. It also includes an
opt-in **Party Session** with on-device blood-alcohol (BAC) estimation.

Built as a **single Flutter codebase**, **offline-first** (a local database is
the on-device source of truth — core tracking works with no account and no
network), and shipped in phases. **Phase 1** (current scope) is a complete
local-only MVP; Phase 2 later adds opt-in accounts, cloud sync, and social
features.

> **Not a medical device.** Drinks Mate does not give medical advice. The BAC
> figure is always presented as an estimate and must never be used to decide
> whether it is safe or legal to drive.

## Status

Pre-implementation. The product and engineering decisions are fully specified,
and the project is **scaffolded** — a Flutter app shell, the pure-Dart
computation `core` package with its seeded test suite, CI, and the
agent/CI tooling are in place. Feature/UI implementation has not started yet.

## Repository layout

This is a monorepo. Specs, code, and tooling are deliberately separated:

| Path | What's here |
|------|-------------|
| [`design/`](./design) | **What** the app does and **why** — product vision, UX, features, data model, notifications, the Party Session/BAC spec. The source of truth. |
| [`engineering/`](./engineering) | **How** it's built — the Phase-1 constraints (C0–C6), the decision records (Flutter stack D1–D7), and the **[Parity Rulebook](./engineering/decisions/design-system.md#appendix--parity-rulebook)** (the canonical numeric/rounding/boundary spec). |
| [`flutter/`](./flutter) | All application code: the Flutter app ([`flutter/lib`](./flutter/lib), [`flutter/test`](./flutter/test)) and the dependency-free pure-Dart [`flutter/packages/core`](./flutter/packages/core) package (BAC, hydration, pace, username). |
| [`docs/`](./docs) | Engineering runbooks — see [`agentic-workflow.md`](./docs/agentic-workflow.md). |
| `.claude/`, `.github/`, `.mcp.json`, `.vscode/` | Agent/CI/editor tooling (see [The agentic workflow](#the-agentic-workflow)). |
| [`CLAUDE.md`](./CLAUDE.md) | The agent guide: conventions and the definition of done. |

## Tech stack

Flutter (stable) + Dart 3, Material 3 with a custom design system. Targets iOS
18 / Android `minSdk 26`. Key packages (see
[`engineering/decisions/flutter-stack.md`](./engineering/decisions/flutter-stack.md)):

- **Riverpod** — state / DI (repository pattern over Drift)
- **Drift** — typed SQLite persistence
- **flutter_local_notifications** + **timezone** — local reminders
- **fl_chart** — history bars + the BAC chart
- **flutter_svg** — two-shade tinted drink icons
- **`core`** (in-house, pure Dart) — every computation, so iOS/Android results
  are identical by construction

## Getting started

### Prerequisites

- The Flutter SDK (Dart 3.4+). If you installed it via the VS Code extension,
  make sure its `bin` is on your `PATH` so `flutter`/`dart` work in a terminal
  and the Dart MCP server can launch — see
  [docs/agentic-workflow.md → MCP servers](./docs/agentic-workflow.md#mcp-servers).

### Run the app

```bash
cd flutter
flutter pub get
flutter run        # pick a device/emulator
```

In VS Code, press **F5** (the `Drinks Mate (debug)` launch config) or run the
**Flutter: run app** task.

### Run the tests

The test suite is the project's safety net — see [Conventions](#conventions).

```bash
# core package (pure Dart)
(cd flutter/packages/core && dart test)

# flutter app (widget tests)
(cd flutter && flutter test)
```

In VS Code, run the **Test: all** task (it's the default test task).

## The agentic workflow

This repo is set up for AI-agent-assisted development, gated by tests. In short:
a GitHub Issue (label `agent-ready`, or an `@claude` mention) dispatches an agent
that implements against `CLAUDE.md` + the Parity Rulebook and opens a PR; the PR
is then gated by CI (format + analyze + test), an agentic review, and a security
scan before a human merges. Local work uses the same standards plus the
specialised subagents in `.claude/agents/`.

Full details, one-time setup, and next steps are in
**[docs/agentic-workflow.md](./docs/agentic-workflow.md)**.

## Conventions

These are enforced by CI and expected of every change (human or agent) — the
full list is in [`CLAUDE.md`](./CLAUDE.md):

1. **The `core` package stays pure Dart** — no Flutter/Drift imports. Every
   algorithm lives there as pure functions.
2. **No ad-hoc math or rounding** — numeric/unit/boundary behaviour must match
   the [Parity Rulebook](./engineering/decisions/design-system.md#appendix--parity-rulebook)
   exactly.
3. **Tests are the definition of done** — new `core` behaviour ships with unit
   tests whose expected values trace to the design docs' worked examples.
4. **No Phase-2 scaffolding** — accounts, sync, and social are out of scope.

Definition of done (also enforced in CI):

```bash
(cd flutter/packages/core && dart format --output=none --set-exit-if-changed . && dart analyze && dart test)
(cd flutter               && dart format --output=none --set-exit-if-changed . && flutter analyze && flutter test)
```
