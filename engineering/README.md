# Drinks Mate — Engineering Decisions

This folder is where the engineering team **investigates, researches, and records the technical decisions** that turn the `design/` specifications into a shippable app. The `design/` folder says *what* the app must do and *why*; this folder decides *how* it gets built and pins those choices down so they don't drift over time.

> **Current direction:** Drinks Mate is built as a **single Flutter codebase** for iOS and Android — see [decisions/flutter-stack.md](./decisions/flutter-stack.md). This superseded the original two-native-app plan; the per-platform research ([decisions/ios-stack.md](./decisions/ios-stack.md), [decisions/android-stack.md](./decisions/android-stack.md)) is retained as input that still informs the Flutter notification and OS-integration design.

## Scope of this pass

This first pass researches **Phase 1 only** — the local-only MVP described in [../design/technical-architecture.md → Phasing](../design/technical-architecture.md#phasing). Phase 2 (accounts, sync, social) and Phase 3 (insights) are out of scope here, except where a Phase 1 choice must not paint Phase 2 into a corner (those forward-constraints are already captured in the design docs and are flagged where relevant).

## Parity — now by construction

Drinks Mate ships as **one Flutter codebase** for iOS and Android — see [../design/technical-architecture.md → Platforms](../design/technical-architecture.md#platforms). Because Flutter renders its own UI from one widget tree and the algorithms live in one pure-Dart `core` package, **behavioural and visual parity hold by construction** — they are a property of the build, not an ongoing governance task. This is the single biggest reason for the Flutter direction: it dissolves the cross-platform computation-drift risk (the [validation report's](./validation.md) highest-risk surface) and the visual-divergence risk.

What remains is **correctness to spec** and the handful of places the app **deliberately defers to the OS**: notification *delivery* timing/reliability, system text-scale factors, and any optional platform-adaptive nav idiom. Those intentional divergences must be documented and produce the spec'd user-visible outcome.

[phase-1-constraints.md](./phase-1-constraints.md) is the **shared anchor** every decision doc is written against. Read it first.

## Documents

- [phase-1-constraints.md](./phase-1-constraints.md) — Distilled, platform-neutral list of the Phase 1 technical requirements pulled from `design/`. The anchor for everything else.
- [decisions/_template.md](./decisions/_template.md) — Decision-record template (lightweight ADR).
- [decisions/flutter-stack.md](./decisions/flutter-stack.md) — **The current stack:** Flutter — architecture/state, persistence, notifications, charts, icon rendering, shared computation, dependencies.
- [decisions/design-system.md](./decisions/design-system.md) — Design system + the platform-neutral **Parity Rulebook** (rounding, units, boundaries, formula constants). Still the canonical spec the single implementation meets.
- [decisions/ios-stack.md](./decisions/ios-stack.md) — *Superseded.* iOS native research, retained for the platform-specific notification/OS-integration findings that inform the Flutter design.
- [decisions/android-stack.md](./decisions/android-stack.md) — *Superseded.* Android native research, retained for the same reason.
- [validation.md](./validation.md) — Validation pass over the (superseded) native plan; its findings on the Flutter switch are noted in its banner.

## How decisions are recorded

Each substantive choice is written as a decision record (see the template): the decision, the options considered, the rationale, the parity implication, and the Phase-2 forward-constraint if any. A recommendation with no rejected alternatives is a red flag — if there was genuinely no choice, say why.
