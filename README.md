# Drinks Mate — Design Documentation

This folder contains the design documentation for **Drinks Mate**, a mobile application for iOS and Android that helps people track their daily drink intake and stay properly hydrated.

These documents are intended to guide developers during implementation. They describe *what* the app should do and *why*, and fix the load-bearing technical decisions (native per platform, offline-first, phased rollout). Day-to-day implementation choices live with the engineering team.

## Documents

- [product-overview.md](./product-overview.md) — Vision, target users, and success criteria.
- [technical-architecture.md](./technical-architecture.md) — Platform strategy, offline-first model, and phase 1 / phase 2 boundary.
- [features.md](./features.md) — Functional scope by phase: what the app must do.
- [user-experience.md](./user-experience.md) — Screens, flows, and key interactions.
- [notifications.md](./notifications.md) — Reminder strategy and behaviour.
- [party-session.md](./party-session.md) — Opt-in Party Session: alcohol tracking with BAC estimation (phase 1).
- [data-model.md](./data-model.md) — What the app stores and how entities relate.
- [open-questions.md](./open-questions.md) — Decisions still to be made.

## At a glance

- **Two native apps**, one for iOS and one for Android. No shared cross-platform codebase.
- **Offline-first**, with a local database as the on-device source of truth. Core tracking works with no network and no account.
- **Two-phase rollout.** Phase 1 is the local-only MVP. Phase 2 adds opt-in accounts, cloud sync across devices, and friends with progress sharing.

See [technical-architecture.md](./technical-architecture.md) for the rationale behind these decisions.

## Document conventions

- **Must / should / may** are used in the RFC 2119 sense.
- Open questions are tagged inline as `[OPEN]` and collected in `open-questions.md`.
- Anything platform-specific is called out explicitly; otherwise behaviour applies to both iOS and Android.
- Features are tagged with their phase (Phase 1 or Phase 2). Phase 1 must ship as a complete product on its own.
