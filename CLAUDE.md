# Drinks Mate — agent guide

Drinks Mate is a **single Flutter codebase** (iOS + Android), Phase 1 = local-only MVP.
The specs are the source of truth; this file tells you how to work in the repo.

## Repository layout

- `flutter/` — all the application code: the Flutter app (`flutter/lib`, `flutter/test`) and the pure-Dart `flutter/packages/core` package. All `flutter`/`dart` commands run from here (or from `flutter/packages/core`).
- `design/` — product/UX/data specs.
- `engineering/` — technical decisions and constraints.
- `docs/agentic-workflow.md` — how the agent/CI pipeline fits together.

## Read before you build

- `design/` — *what* the app does and *why* (product, UX, data model, notifications, party session).
- `engineering/phase-1-constraints.md` — the platform-neutral anchor (C0–C6). Every change must respect it.
- `engineering/decisions/flutter-stack.md` — the chosen stack (D1–D7) and *why* alternatives were rejected.
- `engineering/decisions/design-system.md` → **Appendix: Parity Rulebook** — the canonical numeric, rounding, unit, boundary, and validation rules. **This is law.**

## Non-negotiables

1. **The `core` package stays pure Dart.** No Flutter, Drift, or any other imports in `flutter/packages/core/`. Every C4 algorithm (BAC, hydration goal, pace/recommended-volume, username, day-boundary, icon HSL) lives there as pure functions.
2. **No ad-hoc math or rounding.** Numeric/rounding/unit/boundary behaviour must match the Parity Rulebook exactly. If a rule is ambiguous, stop and ask — do not guess.
3. **Compute in metric/canonical units** (ml, kg, cm, g/L). Imperial and formatting happen only at the display boundary.
4. **No Phase-2 scaffolding.** Accounts, sync, social, insights are out of scope. Do not add `Account`/`Friendship`/`ShareSetting` to any Phase-1 migration.
5. **Tests are the definition of done.** New `core` behaviour ships with unit tests seeded from the design docs' worked examples (e.g. the 0.362 g/L BAC example, 70 kg → 2100 ml goal).

## Definition of done (run before claiming a task is complete)

From the repo root:

```bash
# core package (pure Dart) — from repo root
(cd flutter/packages/core && dart format --output=none --set-exit-if-changed . && dart analyze --fatal-infos && dart test)

# flutter app — from repo root
(cd flutter && dart format --output=none --set-exit-if-changed . && flutter analyze && flutter test)
```

All three must pass (format clean, analyze clean, tests green). CI (`.github/workflows/ci.yml`) enforces the same gate; a red gate blocks merge.

## Conventions

- **Architecture:** Riverpod + repository over Drift; Drift types never reach widgets. Math stays in `core`, behind the repository.
- **Testing pyramid:** unit (≈60–70%, mostly `core`) → widget → golden (design-system parity) → integration (`integration_test`/Patrol). Target ≥80% coverage on `core`/services.
- **Generated code** (`*.g.dart`) is excluded from analysis and lint; don't hand-edit it.

## Subagents available (`.claude/agents/`)

- `feature-scaffolder` — scaffolds a new feature end-to-end: Drift table → DAO → domain model → repository → Riverpod provider → widget stub. Use when starting any new entity or screen.
- `test-author` — writes/maintains `core` test vectors from the design docs.
- `spec-auditor` — checks a change against the Parity Rulebook.
- `reviewer` — reviews a diff for correctness, parity, and constraint violations.

Delegate explicitly, e.g. "use the feature-scaffolder to scaffold DrinkEntry" or "use the spec-auditor subagent to check this BAC change".
