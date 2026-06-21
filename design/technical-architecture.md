# Technical Architecture

This document captures the high-level technical direction for Drinks Mate. It does not prescribe specific libraries — those choices belong to the engineering team — but it does fix the load-bearing decisions that the rest of the design depends on.

## Platforms

Drinks Mate is built as **two dedicated native applications**:

- **iOS** — native (Swift / SwiftUI recommended, but final stack is engineering's call).
- **Android** — native (Kotlin / Jetpack Compose recommended, but final stack is engineering's call).

There is no shared cross-platform codebase. The two apps share **specifications** (this folder) and **data model semantics**, not source code.

### Why native rather than cross-platform

- Best-in-class platform integration for notifications, background scheduling, and system-settings deep links — all of which the reminder feature relies on.
- Predictable behaviour against future OS-level changes (background execution, notification permissions, health platform APIs).
- Lower long-term maintenance risk for an app whose value depends on reliable, OS-respectful background reminders.

The trade-off is that every feature must be implemented twice. Both apps must reach behavioural parity per phase before that phase ships.

## Offline-first

The app is **offline-first**. The core tracking loop — logging drinks, viewing today's progress, viewing history, receiving reminders — must work fully without any network connection, on a device that has never been online.

Concretely:

- All user data is stored in a **local database** on the device. The choice of database is engineering's (e.g. SQLite via GRDB or Room; or a higher-level option). The chosen database must support transactional writes, simple queries by date range, and schema migrations.
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

- Specific iOS / Android frameworks (SwiftUI vs UIKit, Compose vs XML).
- Specific local database (SQLite, Realm, SwiftData, Room, etc.).
- Phase 2 backend stack, hosting, or auth provider — designed in phase 2.
- CI / CD, distribution, signing — engineering team decisions.
