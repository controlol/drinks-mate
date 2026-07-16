# Phase 1 — Technical Constraints (shared anchor)

A distilled, **platform-neutral** list of what the Phase 1 build must satisfy, pulled from the `design/` folder. This is the contract the [Flutter stack decision](./decisions/flutter-stack.md) is written against. Where a line traces to a source doc, it is linked; the source doc wins on any disagreement.

## C0 — Load-bearing decisions already fixed by design

These are **not** open for research to revisit; they frame it.

- **Single Flutter codebase** targeting iOS and Android (Dart). Behavioural and visual parity hold by construction; the only intentional divergences are where the app defers to the OS (notification delivery, system text-scale factors, optional platform-adaptive nav). — [technical-architecture.md → Platforms](../design/technical-architecture.md#platforms), [flutter-stack.md](./decisions/flutter-stack.md)
- **Offline-first.** The core loop (log, today view, history, reminders) works fully with no network, on a device that has never been online. No UI may block on a network call. — [technical-architecture.md → Offline-first](../design/technical-architecture.md#offline-first)
- **Local database is the on-device source of truth.** It must support transactional writes, queries by date range, and schema migrations. — [technical-architecture.md → Offline-first](../design/technical-architecture.md#offline-first)
- **Phase 1 contains no server, no API, no auth, no sync scaffolding, no analytics/telemetry/crash reporting.** None of it may be present in the build. — [features.md → F7](../design/features.md#f7--local-first-storage), [technical-architecture.md → Phase 1](../design/technical-architecture.md#phase-1--local-only-mvp)
- **No login screen / no account prompt** anywhere in Phase 1.

## C1 — Persistence

The local store must support:

- **Stable, locally-generated UUID** primary keys on every record (becomes the Phase 2 cross-device key). — [technical-architecture.md → Sync model](../design/technical-architecture.md#sync-model-phase-2-design-constraints)
- **`createdAt` + `updatedAt` timestamps** on every record; `updatedAt` bumped on every edit.
- **Soft-delete** via a nullable `deletedAt`; soft-deleted rows filtered out of every UI query but retained.
- **Transactional writes** — a partially-applied edit must never leave an inconsistent state. — [data-model.md → Storage requirements](../design/data-model.md#storage-requirements)
- **Schema migrations** — Phase 2 will add fields/entities; the app's lifetime will see many migrations. Must be a first-class capability from day one.
- **Date-range queries** keyed off a configurable **day boundary** (default 05:00 local), used for daily totals, history buckets, and reminder pacing.
- Entities to model (Phase 1): `DrinkEntry`, `DrinkPreset`, `UserPreferences` (singleton), `UserProfile`, `PartySession`, `PartySessionPrice`, `Meal`. Phase-2-only entities (`Account`, `Friendship`, `ShareSetting`) **must not exist** in the build. — [data-model.md](../design/data-model.md)
- **Seeding on first launch:** default drink presets are inserted on first run; a "Reset to defaults" re-seeds missing ones. — [features.md → F14](../design/features.md#f14--drink-presets-and-customisation)
- **Money stored as integer minor units**; **all values stored metric**; display conversion (imperial, currency symbol, mmol/L) happens at the UI layer only. — [data-model.md → Units](../design/data-model.md#units), [→ Currency](../design/data-model.md#currency)
- **Immutable log:** preset values are snapshotted onto `DrinkEntry` at log time; editing a preset never mutates historical entries; `DrinkEntry` carries no FK to `DrinkPreset`. — [data-model.md → Snapshot semantics](../design/data-model.md#snapshot-semantics--log-immutability)

## C2 — Local notifications (no push infrastructure)

All notifications are **scheduled locally on-device**; Phase 1 has no push backend. — [notifications.md](../design/notifications.md)

- Four hydration-flow types, each independently toggleable: **hydration reminder** (interval-based, default 90 min, active hours default 08:00–22:00), **inactivity reminder** (once/day, noon), **weekly summary** (Sunday 20:00 local), **Party Mode** notifications (off by default, session-only). — [notifications.md → Notification types](../design/notifications.md#notification-types)
- **Inline quick-log action** on the notification that logs the default drink **without opening the app**, and resets the reminder timer.
- **Recompute the recommended volume at delivery time** (intake may have changed since scheduling) — the design explicitly calls for this. — [notifications.md → Platform notes](../design/notifications.md#platform-notes)
- **Anti-spam / conditional firing:** suppress when already at goal, when a drink was just logged, after 7 days of inactivity; no retry on dismiss. The fire-time predicate must be evaluated on-device at delivery, not pre-baked. — [notifications.md → Behaviour](../design/notifications.md#behaviour)
- **iOS-specific constraint to respect:** the 64-pending-local-notification ceiling → schedule a rolling window, not the whole month. — [notifications.md → Platform notes](../design/notifications.md#platform-notes)
- **Permission is optional:** declining leaves the app fully functional; settings reflect the missing OS permission and offer a deep link to system settings.
- **Lock-screen BAC visibility** is a per-user toggle (default ON) that must map to each platform's content-visibility mechanism. — [notifications.md → Lock-screen visibility](../design/notifications.md#lock-screen-visibility)

## C3 — Charts / data visualisation

- **History:** bar charts — hydration per day (with goal reference line + non-colour signal for below-goal bars), drinks per day, and conditionally alcoholic-drinks-per-day and peak-BAC-per-day with a session overlay band. Weekly + monthly ranges with paging. — [features.md → F4](../design/features.md#f4--history)
- **Party tab:** a **BAC line chart** with a solid (past→now) segment, a dashed projected segment with a low-opacity red wash behind it, a "now" reference line, a cap reference line, 24-hour local-time X axis rounded up to a tidy half hour, g/L primary + mmol/L secondary Y. — [party-session.md → BAC line chart](../design/party-session.md#bac-line-chart)
- All chart computation is **local**; charts are read-only.
- Accessibility: below-goal bars need a **non-colour** distinction; charts must work with screen readers.

## C4 — Shared computation (single implementation, exact to spec)

These are pure algorithms specified to the formula in `design/`. They live in one pure-Dart `core` package ([flutter-stack.md → D7](./decisions/flutter-stack.md#d7--shared-computation-pure-dart-core-package)), so outputs are identical across platforms **by construction**. What matters is correctness to spec; a single implementation means the platforms cannot diverge.

- **Hydration goal suggestion:** `30 ml × weight_kg`, rounded to nearest 100 ml. — [features.md → F2](../design/features.md#f2--daily-hydration-goal)
- **Pace / expected-intake** linear model and **recommended volume** (0.5-glass increments, clamp 0.5–2.0). — [notifications.md → Recommended volume](../design/notifications.md#recommended-volume-per-reminder)
- **BAC estimation:** grams of alcohol → Watson TBW *or* Widmark distribution (data-driven by available profile) → initial BAC → meal modifier (exponential decay, min across meals) → zero-order elimination (β = 0.15 g/L/h) → summation; g/L canonical, mmol/L = ×21.7. Includes the unspecified-gender conservative path, BMI-range warning, orphan-drink absorption (`t_zero` rule), and lazy 12-hour auto-end. — [party-session.md → BAC estimation algorithm](../design/party-session.md#bac-estimation-algorithm)
- **Username validation:** Unicode `L*`/digits/`_-.` whitelist, structural start/end rules, NFC normalisation, 3–30 chars. — [data-model.md → Username character rules](../design/data-model.md#username-character-rules)
- **Day-boundary bucketing** and 7-day rolling aggregates (daily average, days-on-goal).
- **Preset sort ranking:** given per-preset last-used timestamp and 30-day usage count (queried by the repository from `DrinkEntry.presetId`, never computed in `core`) plus `sortOrder`, a pure ranking function orders presets for the three sort modes (manual / recently used / most used), with `sortOrder`-ascending tie-break covering the unused / zero-count cohort. The DB aggregation query stays in the repository layer; only the ranking/sort itself is the `core` function. — [features.md → F14 Sort modes](../design/features.md#f14--drink-presets-and-customisation)

> Spec note: each formula is implemented once with the exact rounding/clamping rules from the [Parity Rulebook](./decisions/design-system.md#appendix--parity-rulebook). The worked examples in the design docs (e.g. the 0.362 g/L BAC sanity check, the 2100 ml goal) are **regression unit tests** that pin the spec.

## C5 — Design system (visual + behavioural parity by construction)

Flutter renders its own UI from one widget tree, so the visual layer is identical across platforms by construction; the requirements below are the spec the single implementation meets.

- **Typography:** DM Sans (single open-source family); display-weight tabular figures for headline numerics. Flutter bundles the font and honours OS text scaling. — [designer-brief.md → Typography](../design/designer-brief.md#typography)
- **Colour:** three named accents (azure, honey, emerald/mint) + semantic palette; **light + dark mode both ship at v1**; emerald quarantined to Party Mode. Every colour-encoded state needs a non-colour signal. — [designer-brief.md → Colour](../design/designer-brief.md#colour)
- **Drink icons:** bundled filled SVGs with a two-shade structure, **both shades derived at render time from a single `iconColor`** via an HSL lightness offset (±15%) — i.e. runtime SVG tinting, not pre-baked assets. — [designer-brief.md → Iconography](../design/designer-brief.md#iconography), [features.md → F14 Icons](../design/features.md#f14--drink-presets-and-customisation)
- **UI icon set** (~25 custom icons) and **illustrations** (flat + subtle gradient, object-led, no mascots) drawn as one visual family.
- **Motion:** calm, ease-in-out, no bounce/overshoot, reduce-motion fallback for every animation. — [designer-brief.md → Motion & feedback](../design/designer-brief.md#motion--feedback)
- **Haptics:** light on log, medium on goal-met celebration; nothing else.
- **Accessibility (non-negotiable):** accessible labels on all interactive elements, dynamic type at every system size, colour never the sole state signal, end-to-end VoiceOver (iOS) + TalkBack (Android). Flutter drives both via one `Semantics` tree — validate per platform (one a11y pass, not two). — [designer-brief.md → Accessibility integration](../design/designer-brief.md#accessibility-integration)
- **Navigation:** 3-tab bottom bar (Today / Party / History) with unified brand styling; either one Material bottom nav on both platforms or an optional platform-adaptive idiom (design call, [flutter-stack.md → D4/risks](./decisions/flutter-stack.md)); tab bar hidden for the S2 drawer and full-screen pushes.

## C6 — Cross-cutting non-functionals

- **Two-taps-to-log** performance budget: app launch → logged drink in ≤ 2 taps for the common case; logging must be instant (optimistic UI, no spinner). — [product-overview.md → Success criteria](../design/product-overview.md#success-criteria)
- **First-drink-in-60-seconds** including onboarding (< 30 s onboarding).
- **No telemetry** means crash/perf must be validated pre-release by other means (internal testing), since none ships in the product.
- **Localisation** is explicitly *later* (L4) — Phase 1 may be single-language, but money/units/time formatting still follow device locale conventions. — [features.md → Later](../design/features.md#later-post-phase-3)

## What the stack decision must deliver per concern

For each of persistence, notifications, charts, icon-rendering, and app architecture/state-management: a **named recommended package or platform API**, the **alternatives considered and why rejected**, the **parity implication** (mostly "none — one codebase", except where the app defers to the OS), and any **Phase-2 forward-constraint**. Default to first-party Flutter and minimal, mainstream, well-maintained packages unless a third-party library is clearly justified. See [flutter-stack.md](./decisions/flutter-stack.md).
