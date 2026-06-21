# Drinks Mate — Engineering Decisions

This folder is where the engineering team **investigates, researches, and records the technical decisions** that turn the `design/` specifications into two shippable native apps. The `design/` folder says *what* the app must do and *why*; this folder decides *how* it gets built and pins those choices down so they don't drift over time.

## Scope of this pass

This first pass researches **Phase 1 only** — the local-only MVP described in [../design/technical-architecture.md → Phasing](../design/technical-architecture.md#phasing). Phase 2 (accounts, sync, social) and Phase 3 (insights) are out of scope here, except where a Phase 1 choice must not paint Phase 2 into a corner (those forward-constraints are already captured in the design docs and are flagged where relevant).

## The parity contract

Drinks Mate ships as **two independent native codebases** (iOS + Android) with **no shared application code** — see [../design/technical-architecture.md → Platforms](../design/technical-architecture.md#platforms). The two apps share *specifications and data-model semantics*, not source.

That makes **behavioural and visual parity a first-class engineering concern, not an afterthought.** Every decision in this folder must answer: *will an iOS user and an Android user get the same experience?* Where the platforms force a divergence (e.g. notification scheduling APIs), the divergence must be deliberate, documented, and produce the same user-visible outcome.

[phase-1-constraints.md](./phase-1-constraints.md) is the **shared anchor** every research doc is written against. Read it first.

## Documents

- [phase-1-constraints.md](./phase-1-constraints.md) — Distilled, platform-neutral list of the Phase 1 technical requirements pulled from `design/`. The anchor for everything else.
- [decisions/_template.md](./decisions/_template.md) — Decision-record template (lightweight ADR).
- [decisions/ios-stack.md](./decisions/ios-stack.md) — iOS native stack: architecture, persistence, notifications, charts, icon pipeline, dependencies.
- [decisions/android-stack.md](./decisions/android-stack.md) — Android native stack: architecture, persistence, notifications, charts, icon pipeline, dependencies.
- [decisions/design-system.md](./decisions/design-system.md) — Cross-platform design system and the mechanism for keeping the two apps visually and behaviourally consistent.
- [validation.md](./validation.md) — Validation pass: checks each recommendation is solidly founded, Phase-1-scoped, and parity-preserving.

## How decisions are recorded

Each substantive choice is written as a decision record (see the template): the decision, the options considered, the rationale, the parity implication, and the Phase-2 forward-constraint if any. A recommendation with no rejected alternatives is a red flag — if there was genuinely no choice, say why.
