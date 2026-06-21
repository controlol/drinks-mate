# Technical Architecture

This document captures the high-level technical direction for Drinks Mate. It does not prescribe specific libraries — those choices belong to the engineering team — but it does fix the load-bearing decisions that the rest of the design depends on.

## Platforms

Drinks Mate is built as a **single Flutter application** (Dart) targeting both **iOS** and **Android** from one codebase. Flutter renders its own UI, so the bespoke design system, the computation core, and every screen are written once and run on both platforms. See [engineering/decisions/flutter-stack.md](../engineering/decisions/flutter-stack.md) for the concrete stack (persistence, notifications, charts, state) and [engineering/phase-1-constraints.md → C0](../engineering/phase-1-constraints.md#c0--load-bearing-decisions-already-fixed-by-design).

### Why Flutter

- **Parity by construction.** The product's defining engineering risk is keeping a bespoke design system *and* a numerically-exact computation core (hydration pace, BAC) identical across platforms. One Flutter codebase makes behavioural and visual parity a property of the build, and removes cross-platform computation drift (which, with two native codebases, would include Swift-vs-Kotlin floating-point determinism) as a risk class.
- **Lower long-term maintenance.** Every feature, across all phases, is built once instead of twice.
- **The OS-integration trade is narrow.** Native development's main draw is notification/background-scheduling integration, but those OS limits are framework-independent (iOS cannot recompute a local notification at delivery in Swift *or* Dart), and Flutter reaches the same notification, channel, permission, and lock-screen APIs. The one genuine gap is at the post-Phase-3 *Later* horizon: Flutter does not target watchOS and has limited Wear OS support, so any future watch/wearable app (L2) would be a native satellite — out of scope for Phases 1–3.

The trade-off accepted: where the app defers to the OS (notification *delivery* timing/reliability, system text-scale factors), behaviour follows each platform; everything else is identical by construction.

## Offline-first

The app is **offline-first**. The core tracking loop — logging drinks, viewing today's progress, viewing history, receiving reminders — must work fully without any network connection, on a device that has never been online.

Concretely:

- All user data is stored in a **local database** on the device. The chosen store (Drift, a typed SQLite layer — see [flutter-stack.md → D3](../engineering/decisions/flutter-stack.md#d3--local-persistence-drift-typed-sqlite)) must support transactional writes, simple queries by date range, and schema migrations.
- The app must not block the UI on any network call.
- A network outage must not affect any phase 1 functionality.

Even after phase 2 ships, the local database remains the **source of truth on the device**. Sync reconciles, it does not replace.

## Phasing

The product ships in two phases. The phase boundary is a hard line: phase 1 must be fully functional and shippable on its own, with no scaffolding visible to the user that hints at unfinished phase 2 work.

### Phase 1 — Local-only MVP

Everything described in [features.md → Phase 1 — Local-only MVP](./features.md#phase-1--local-only-mvp). The app works fully offline, with no account, no server, no social features.

- No login screen, no "create account" prompt.
- No analytics or telemetry unless explicitly approved (see [open-questions.md](./open-questions.md)).
- No backend infrastructure.

### Phase 2 — Accounts, sync, and social

Adds opt-in cloud functionality on top of phase 1. A user who never creates an account continues to get the full phase 1 experience unchanged.

- **Account creation.** The user can create an account from settings. Creating an account is always optional.
- **Cloud sync.** Once the user has an account, their local data syncs to the server. The user can install the app on a new device, log in, and recover their data.
- **Friends.** Users can add other users as friends.
- **Progress sharing.** Friends can see each other's progress against their daily goals. Granularity, opt-in defaults, and what specifically is shared are deferred to the phase 2 design pass.

See [features.md → Phase 2 — Accounts, cloud sync, and social](./features.md#phase-2--accounts-cloud-sync-and-social) for the functional requirements and [open-questions.md](./open-questions.md) for the decisions phase 2 still needs.

## Sync model (phase 2 design constraints)

Sync is a phase 2 feature, but the phase 1 data model must not paint us into a corner. The local data model in [data-model.md](./data-model.md) is designed so that phase 2 sync can be added without a destructive migration.

Constraints that apply already in phase 1:

- Every record has a **stable, locally generated identifier** (UUID). This becomes the cross-device key in phase 2.
- Every record has a **`createdAt` and `updatedAt`** timestamp. These give phase 2 a basis for last-writer-wins reconciliation, which is sufficient for this app's data shape (single-user, append-mostly).
- Deletion is a **soft-delete** (a `deletedAt` timestamp on the record), not a hard-delete. This lets phase 2 propagate deletions without having to track tombstones separately. Soft-deleted records are filtered out everywhere in the UI.

Things explicitly **not** required in phase 1:

- No server. No API. No auth. No queue of pending sync operations. Phase 1 must not contain any of this scaffolding.

## Privacy and data ownership

- Phase 1: all data lives on-device. The app collects nothing.
- Phase 2: data leaves the device only when the user opts in by creating an account. The privacy policy and explicit consent flow are part of the phase 2 design.

## What this document does not decide

- Detailed package versions and the in-app architecture — see [engineering/decisions/flutter-stack.md](../engineering/decisions/flutter-stack.md).
- Phase 2 backend stack, hosting, or auth provider — designed in phase 2.
- CI / CD, distribution, signing — engineering team decisions.
