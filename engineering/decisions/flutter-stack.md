# Flutter Stack — Phase 1 Decision Record

> **Audience note.** Written for a lead who knows frontend/backend patterns (state management, repositories, ADRs, design tokens) but is *not* a native-mobile specialist. Platform-specific concepts are explained inline.

## Summary

Drinks Mate is a **single Flutter codebase** for iOS and Android. Build Phase 1 as a **Flutter (stable channel) app on Dart 3**, **Material 3** with a fully custom design system, targeting **iOS 18.0+** and **Android `minSdk 26` / `targetSdk 36`**. Lean on **first-party Flutter + a small set of well-maintained, widely-used packages**: **Drift** for persistence (typed SQLite — first-class migrations, transactions, Phase-2 sync-ready), **flutter_local_notifications** (+ `timezone`) for the local-notification engine, **fl_chart** for History + the Party BAC chart, **flutter_svg** for the two-shade tinted drink icons, **Riverpod** for state/DI, and a **dependency-free pure-Dart `core` package** for every C4 algorithm.

Because there is one codebase, behavioural and visual parity hold **by construction**: every algorithm is implemented once and every screen is drawn once. The **one genuinely harder area is notifications** (D4): iOS provides no hook to run code when a *local* notification delivers, so the recommended-volume content is baked at schedule time and refreshed by a **uniform rolling-window re-arm on both platforms**. The **only hard "must be native" surface is in the explicitly-deferred Later bucket** (Apple Watch / Wear OS apps; Flutter does not target watchOS) — out of scope for Phases 1–3.

### Decisions at a glance

| # | Area | Decision | Key dependency | Confidence |
|---|------|----------|----------------|------------|
| D1 | UI framework | **Flutter (stable) + Dart 3**, Material 3 + custom design system; iOS 18 / Android minSdk 26, targetSdk 36 | Flutter SDK | High |
| D2 | Architecture / state | **Riverpod** + repository pattern over Drift; thin, testable view-models. No heavyweight framework. | flutter_riverpod | High |
| D3 | Persistence | **Drift** (typed SQLite). sqflite/Isar/Hive rejected. | drift | High |
| D4 | Local notifications | **flutter_local_notifications** + `timezone`; uniform rolling-window re-arm; background-isolate quick-log | flutter_local_notifications, timezone | Medium-High |
| D5 | Charts | **fl_chart** for History bars + BAC line; red wash via `CustomPainter` | fl_chart | High |
| D6 | Drink-icon tinting | **flutter_svg** + runtime two-shade HSL tint in pure Dart (`core`) | flutter_svg | High |
| D7 | Shared computation | Dependency-free pure-Dart **`core`** package; parity by construction; design fixtures become unit tests | none (in-house) | High |

---

## D1 — UI framework: Flutter (stable) + Dart 3, Material 3 + custom design system

- **Status:** Proposed
- **Area:** architecture / design-system
- **Constraint(s) addressed:** C0 (single codebase), C5 (design system, dark mode, dynamic type, accessibility), C6 (two-taps-to-log, instant optimistic UI), enables C2/C3.

**Decision.** Build the whole app in **Flutter** on the **stable channel**, Dart 3, rendering its own UI (Impeller engine) rather than wrapping native widgets. Use **Material 3** as the component base with a fully custom theme (the design-system tokens drive `ThemeData`). Target **iOS 18.0** and **Android `minSdk 26` (Android 8.0) / `targetSdk 36` (Android 16)**: notification channels require API 26; Play mandates target 36 from 31 Aug 2026; iOS 18 reaches essentially the whole active base.

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| Flutter, single codebase | ✅ chosen | One implementation ⇒ visual + behavioural parity by construction; draws its own UI so the custom design system is pixel-identical across platforms; mature in 2026; covers every Phase 1 surface. |
| Two native apps (SwiftUI + Compose) | ❌ rejected | Best OS integration, but doubles every feature and makes the bespoke design system *and* the numerically-exact computation core a standing cross-platform parity cost. |
| React Native | ❌ rejected | Bridges to native widgets (parity drift on the bespoke design system), JS runtime; Flutter's own-rendering model fits the "two platforms must look identical" brief better. |
| Kotlin Multiplatform + Compose Multiplatform | ❌ rejected for Phase 1 | Shared logic is production-stable, but CMP-on-iOS is younger than Flutter and the iOS toolchain cost is higher for a 7-screen app. |

**Rationale.** The product's defining engineering tension is **parity across two platforms** for a bespoke design system and a numerically-exact computation core. Flutter renders its own UI from one widget tree, so DM Sans, the exact palette, dark mode, motion curves, and the two-shade drink icons are *the same code* on both platforms — C5 parity is a property of the build rather than something to police. Material 3 gives accessible, theme-able components to customise rather than build from scratch; Flutter honours OS dark mode, text scaling, and reduce-motion, and exposes a `Semantics` tree to VoiceOver/TalkBack. C6's optimistic logging is a natural fit (write to Drift, a Riverpod provider updates, the widget rebuilds, no spinner).

**Parity implication.** **This is the whole point.** One codebase ⇒ no cross-platform divergence to enforce for UI or logic. The residual, *intentional* divergences are where Flutter defers to the OS: notification delivery (D4), system text-scale factors, and any platform-adaptive nav idiom we opt into.

**Phase-2 forward-constraint.** None. Accounts/sync/social are ordinary Flutter surfaces; one codebase means each Phase 2 feature is built once.

**Confidence & evidence.** High. Flutter is a mature, first-party-supported cross-platform toolkit in 2026 with full Material 3, accessibility, and dark-mode support; the iOS 18 / Android 26 floors and the Play target-36 timeline are current as of June 2026.

---

## D2 — Architecture / state management: Riverpod + repository pattern

- **Status:** Proposed
- **Area:** architecture
- **Constraint(s) addressed:** C6 (instant optimistic UI), supports all of C0–C5.

**Decision.** Use **Riverpod** (`flutter_riverpod`) for state and dependency injection, with a **repository layer** wrapping Drift (D3) as the only thing view-models touch — Drift types never reach widgets. Screens watch providers exposing immutable state; actions call repository methods. Keep view-models thin and the C4 math in the `core` package (D7). **No heavyweight framework** beyond Riverpod.

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| Riverpod + repository | ✅ chosen | Compile-safe DI, testable providers, minimal ceremony; clean repository seam for Phase-2 sync. |
| Bloc / flutter_bloc | ⚠️ viable | Excellent and explicit, but more event/state boilerplate than a 7-screen single-user app needs; Riverpod is lighter for the same UDF shape. |
| Provider / `setState` only | ❌ rejected | Provider is the older generation; raw `setState` doesn't scale to the repository/optimistic-update paths cleanly. |
| GetX | ❌ rejected | Over-broad (routing+DI+state+more), weaker testability and discipline. |

**Rationale.** The app is single-user, offline, append-mostly, ~7 screens — it doesn't earn a formal reducer framework. Riverpod gives precise rebuilds (so the C6 optimistic log is a few lines), constructor-free DI for swapping repositories in tests, and keeps business logic in plain, unit-testable Dart. The repository boundary is exactly where Phase 2 sync slots in without touching the UI.

**Parity implication.** None (internal; one codebase). The C4 algorithms sit behind the repository in `core`.

**Phase-2 forward-constraint.** None — the repository is the documented sync insertion point; a sync engine feeds the same Drift store.

**Confidence & evidence.** High. Riverpod is a mainstream, actively-maintained Flutter state library in 2026; the proportionality argument fits the app's scope.

---

## D3 — Local persistence: Drift (typed SQLite)

- **Status:** Proposed
- **Area:** persistence
- **Constraint(s) addressed:** C1 (all of it), C0 (local source of truth, offline-first, no Phase-2 scaffolding), C4 (date-range / day-boundary queries).

**Decision.** Use **Drift** (formerly Moor) — a typed reactive persistence layer over SQLite — as the local store. Model UUID `TEXT` primary keys, `createdAt` / `updatedAt` / `deletedAt` columns, money as integer minor units, all-metric storage, the `partySessionId` FK, and the C1 entity set. Use Drift's **schema versioning + stepwise migrations** (with the generated schema snapshots its migration tooling produces), `transaction {}` for atomic multi-row edits, and parameterised `[dayStart, dayEnd)` range queries computed from the configurable 05:00 boundary (the day-window math lives in `core`, D7).

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| **Drift** | ✅ chosen | Typed, compile-checked SQL; **first-class migrations** with generated schema snapshots and a migration test harness; transactions; reactive queries that feed the optimistic UI; pure SQLite so Phase-2 sync layers cleanly on top. |
| sqflite | ❌ rejected | Raw SQLite with no typing, no migration framework, no query checking — re-implements what Drift gives safely. |
| Isar / ObjectBox | ❌ rejected | Fast NoSQL object stores, but not relational SQLite; migration + sync-readiness story is weaker for a schema we *know* will churn, and they pull toward their own ecosystems. |
| Hive | ❌ rejected | Key-value, no relational queries or transactional multi-entity edits; wrong shape for date-range/day-boundary aggregation. |

**Rationale.** C1 weights **migrations and Phase-2 sync-readiness** most heavily, and that is exactly where Drift wins: schema version is a first-class property, migrations are explicit and testable, and because it's "just SQLite," nothing about a later delta/LWW sync engine over `updatedAt` (propagating soft-deletes via `deletedAt`) is blocked. Drift expresses every C1 specific cleanly — UUID text PKs, a `deletedAt IS NULL` filter on every UI query, `transaction {}` so a partial edit can never persist, and day-boundary range queries as parameterised SQL. One store and one schema means the day-boundary timestamp handling (a place DST/precision can bite) has a single source of truth.

**Phase-2 forward-constraint.** Keeps Phase 2 fully open: UUID PKs are the future cross-device key, `updatedAt` is the LWW basis, `deletedAt` propagates deletions tombstone-free — exactly the `technical-architecture.md` sync-model requirement. **Guardrail:** the Phase-2-only entities (`Account`, `Friendship`, `ShareSetting`) must not appear in any Phase 1 migration (C0/C1).

**Confidence & evidence.** High. Drift is a mature, actively-maintained typed SQLite layer for Dart/Flutter with documented migration and migration-testing support; SQLite underneath means worst-case portability is mechanical. Pin the exact version at integration.

---

## D4 — Local notifications: flutter_local_notifications + uniform rolling-window re-arm

- **Status:** Proposed
- **Area:** notifications
- **Constraint(s) addressed:** C2 (all of it).

**Decision.** Use **flutter_local_notifications** (with the **`timezone`** package for correct local `zonedSchedule`) as the local-notification engine: notification channels, the inline **quick-log action** handled in a **background Dart isolate** (`@pragma('vm:entry-point')` callback that writes to Drift without opening the app), permission requests, and lock-screen visibility mapping. Adopt a **uniform rolling-window re-arming scheduler on both platforms**: keep a small batch (N ≈ 8–16, well under iOS's 64-pending ceiling) of upcoming reminders scheduled with content baked at schedule time, and **re-arm the whole window on every app foreground, every drink log (incl. the quick-log action), and every settings change**. Anti-spam predicates (at-goal / just-logged / 7-day-inactive) are evaluated **at re-arm**, and crossing the goal **cancels** remaining same-day reminders.

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| flutter_local_notifications + uniform rolling-window re-arm | ✅ chosen | Single behaviour on both platforms ⇒ parity by construction; respects iOS's 64 ceiling; re-arming keeps baked content fresh enough; quick-log via background isolate is supported. |
| flutter_local_notifications + Android-only native fire-time recompute | ⚠️ enhancement | A native `BroadcastReceiver` could recompute content at delivery on Android, but that reintroduces a platform divergence and native glue for marginal freshness benefit; keep as an optional top-up, not the baseline. |
| Push/FCM-driven content | ❌ rejected | Violates C0/C2 — Phase 1 has no backend; notifications must be local. |
| Foreground service / persistent isolate timer | ❌ rejected | Disproportionate and battery-hostile for occasional reminders; unnecessary — reminders delegate the clock to the OS scheduler. |

**Rationale — this is the hardest area, so concretely:**

*The iOS reality is framework-independent.* iOS local notifications are scheduled ahead of time and there is **no on-device hook that runs your code when a *local* notification delivers** (the notification service extension is push-only). So "recompute the recommended volume at delivery" is not possible on iOS in Swift *or* Dart. Content is baked at schedule time and refreshed by re-arming.

*Why uniform re-arm on both platforms.* Choosing the same rolling-window re-arm on iOS and Android makes the behaviour identical: both have the same (small, bounded) content staleness and evaluate the anti-spam predicate at the same point (re-arm). The recommended-volume drift is small and self-correcting — the next reminder, computed from live data at the next re-arm, fixes it — and the same `core` pace formula (D7) drives both.

*Quick-log without opening the app.* flutter_local_notifications supports a background-invoked action callback (`onDidReceiveBackgroundNotificationResponse`, annotated `@pragma('vm:entry-point')`). It runs in a **background isolate** that opens Drift, writes a `DrinkEntry` for `defaultDrinkPresetId`, and re-arms — no UI shown. (If `defaultDrinkPresetId` is missing per the data-model fallback, the action falls back to the seeded water preset or is omitted.)

*Anti-spam at re-arm.* `7-day inactivity`: computed at every re-arm; schedule **no notification whose own fire time is ≥ 7 days past last engagement**, bounding the silent-crossing leak to ≤ the window length. `at-goal / just-logged`: every log re-arms, and crossing goal cancels remaining same-day reminders, so a notification that *would* be wrong never stays pending. `at-most-once` (inactivity/day, weekly/week): one calendar trigger per period, de-duped at re-arm.

*Android exact-alarm posture.* On Android 14+, exact alarms (`SCHEDULE_EXACT_ALARM`) are denied by default and user-revocable, and `USE_EXACT_ALARM` is Play-restricted to specific app categories a hydration reminder is unlikely to qualify for. Design the UX to *not* depend on to-the-minute precision (a reminder at 14:32 vs 14:30 is fine), so inexact scheduling is an acceptable default and exact is an enhancement. flutter_local_notifications exposes the scheduling-mode options for this.

*Channels, permission, lock-screen.* Create channels (`hydration`, `inactivity`, `weekly_summary`, `party`) at first launch — flutter_local_notifications exposes the Android channel API and the iOS categories/actions. Request `POST_NOTIFICATIONS` (Android 13+) / iOS authorization at the contextually-right moment; if declined the app stays fully functional and Settings deep-links to system notification settings. Map `bacOnLockScreenEnabled` to Android `Visibility.private` and, on iOS, to **withholding the BAC string from the body** — the BAC value is hidden when the toggle is off, by the same user-visible outcome on both.

**Parity implication.** The one intrinsic divergence is **delivery reliability** — Android OEM battery-killers (Xiaomi/Huawei/Samsung/etc.) and App Standby can drop a backgrounded nudge; this is an OS/vendor property Flutter does not change. Treat a missed nudge as non-fatal.

**Phase-2 forward-constraint.** None blocking. If Phase 2 adds a push backend, a real iOS service extension and server-driven content could be layered on without disturbing the local engine.

**Confidence & evidence.** Medium-High. flutter_local_notifications is the de-facto Flutter local-notification package (scheduling, channels, background action callbacks, `zonedSchedule` with `timezone`); the iOS service-extension limit, the 64-pending ceiling, and the Android exact-alarm policy are current Apple/Android/Play constraints (June 2026). The background-isolate quick-log path is the thing to **spike first**, since background isolates are the part of the Flutter notification story most prone to platform-edge surprises.

---

## D5 — Charts: fl_chart

- **Status:** Proposed
- **Area:** charts
- **Constraint(s) addressed:** C3 (History bars + BAC line chart), C5 (non-colour signal, accessibility).

**Decision.** Use **fl_chart** for both the History bar charts and the Party BAC line chart. Express the BAC chart's **solid past + dashed projected** segments as two line series (`dashArray` on the projection); the **low-opacity red wash** behind the projection and the **session overlay band** via a `CustomPainter` / background painter keyed to the "now" x-coordinate; the **"now"** and **cap** lines as extra lines / `ExtraLinesData`. Dual-axis **g/L + mmol/L** is a manual relabel (mmol/L = g/L × 21.7, exact linear), rendering the right-side titles as the left-axis values × 21.7.

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| fl_chart | ✅ chosen | Widely-used, actively-maintained Flutter chart lib; covers bars + line, dashed lines, reference lines, and a `CustomPainter` escape hatch for the red wash; no native interop. |
| Syncfusion Flutter Charts | ❌ rejected | Very capable but a heavier dependency with licensing considerations; fl_chart covers the spec. |
| graphic (grammar of graphics) | ❌ rejected | Powerful but a different mental model and heavier than needed for a fixed, small chart set. |
| Hand-rolled `CustomPaint` for everything | ❌ rejected as primary | Reinvents axes/ticks/paging; we *will* use `CustomPainter` for the wash only, layered with fl_chart. |

**Rationale.** C3 needs goal-referenced bar charts with a non-colour below-goal signal, weekly/monthly paging, a session overlay band, and the BAC line chart (solid+dashed, red wash, now/cap rules, rounded 24h X, dual units). fl_chart expresses all of it, with the red wash as the one piece most likely to need the `CustomPainter` escape hatch — low-risk, since it's a static rectangle keyed to the "now" x. The **non-colour below-goal signal** is a single chosen treatment (e.g. a diagonal hatch) drawn once.

**Parity implication.** None — one chart implementation. The data points come from `core` (D7); the visual encoding is one set of widgets.

**Phase-2 forward-constraint.** None — charts are read-only over local data.

**Confidence & evidence.** Medium-High. fl_chart's bars/lines/dashed/reference-line/`CustomPainter` capabilities are well-established; pin the version at integration and **spike the red-wash + dashed-projection BAC chart first** (the one piece carrying implementation risk).

---

## D6 — Drink-icon two-shade tinting: flutter_svg + runtime HSL in Dart

- **Status:** Proposed
- **Area:** icons / design-system
- **Constraint(s) addressed:** C5 (two shades from one `iconColor` via HSL ±15%, 24–32 px, scrolling lists).

**Decision.** Ship each drink icon as an SVG with two elements (silhouette + inner detail) and render with **flutter_svg** (or precompiled `vector_graphics`), tinting the two paths **per-instance at render time** from the single `iconColor`: silhouette = `iconColor`, inner detail = `iconColor` with **HSL lightness offset ±15%** (clamped), using the pinned direction rule from the Parity Rulebook. The HSL math lives in `core` (D7). Apply per-path colour via flutter_svg's `colorMapper` / theme, or by drawing the two paths in a small `CustomPainter`.

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| flutter_svg + runtime two-shade HSL tint | ✅ chosen | Vector-crisp at any size; two computed shades from one colour is trivial in Dart; no pre-baking; one implementation. |
| Pre-baked two-tone assets per colour | ❌ rejected | Colour is user-chosen ("any colour" picker) — pre-baking is impossible; spec requires *runtime* tinting. |
| Material/Cupertino icon fonts | ❌ rejected | C5 requires custom artwork as one visual family, and icon fonts can't carry a two-shade HSL pair. |

**Rationale.** Deriving two shades from one `iconColor` is a single Dart function used by the single renderer: convert the hex to HSL, offset lightness by ±15% (per the Rulebook's pinned direction/clamp), and paint each path. Flutter computes colours and tints vectors easily, so this is straightforward. The two-subpath authoring requirement on the designer's SVGs (clean silhouette/detail separation) is the only thing to confirm with the designer.

**Parity implication.** None to enforce — one HSL function, one renderer.

**Phase-2 forward-constraint.** None — `iconKey` / `iconColor` are snapshotted onto entries (C1) and sync as plain strings.

**Confidence & evidence.** High. flutter_svg is the standard Flutter SVG renderer; runtime per-path tinting and HSL math are routine in Dart. The one implementation detail to confirm in a quick spike is the cleanest per-path recolour API (`colorMapper` vs `CustomPainter`) and that it stays cheap when 10–20 tinted icons scroll.

---

## D7 — Shared computation: dependency-free pure-Dart `core` package

- **Status:** Proposed
- **Area:** shared-computation
- **Constraint(s) addressed:** C4 (BAC, pace/recommended-volume, goal, username validation, day-boundary bucketing + 7-day aggregates), supports D4/D6.

**Decision.** Put every C4 algorithm in a standalone **pure-Dart `core` package** with **no Flutter imports** — pure functions over plain value types: BAC estimation (grams → Watson/Widmark → meal modifier → zero-order elimination β=0.15 → summation; g/L canonical, mmol/L = ×21.7), pace/recommended-volume (0.5-glass increments, clamp 0.5–2.0), hydration goal (`30 ml × weight`, round to 100), username validation (Unicode `L*`/digits/`_-.`, NFC, 3–30), day-boundary bucketing + 7-day aggregates, and the D6 HSL tint. Implement each formula with the **exact rounding/clamping rules transcribed verbatim from the [Parity Rulebook](./design-system.md#appendix--parity-rulebook)**, and back them with unit tests seeded by the design docs' worked examples (the **0.362 g/L** BAC example, the **2100 ml** goal, the username structural cases).

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| Pure-Dart `core` package + unit tests from the design fixtures | ✅ chosen | One implementation ⇒ outputs are identical across platforms by construction; cleanly testable; reused by D4/D6/charts/Party tab. |
| Algorithms scattered in view-models | ❌ rejected | Hard to test in isolation; couples math to UI. |
| Dual implementation + shared golden-vector CI gate | ❌ rejected | Machinery to guard a cross-platform drift that cannot occur in a single codebase. The worked examples are still kept — as ordinary regression tests. |

**Rationale.** The BAC chain has many branch points (Watson/Widmark, the meal min-modifier, orphan `t_zero`, rounding) where an implementation can get a number subtly wrong. A single Dart implementation behind unit tests pins each formula to its spec — the BAC curve, the pace deficit, the goal, the username rules, and the icon shades are computed once, so there is no "do iOS and Android agree?" question to answer. Keep `core` free of Flutter/Drift imports so it's reused by the D4 scheduler, the D6 icon shading, the Party tab, and History. Watch one detail: pin the order of operations and rounding points so the regression fixtures (especially edge cases — recommended-volume on a 0.25-glass boundary, BAC near the 80%-cap threshold, the orphan absorbed-vs-decayed boundary, the unspecified-gender path) lock the spec down.

**Parity implication.** Not a concern — one implementation.

**Phase-2 forward-constraint.** None — Phase 2 adds new algorithms (sync reconciliation) as more pure functions.

**Confidence & evidence.** High. Pure-package + unit-test is standard Dart practice; the worked numbers to seed the tests already exist in the design docs.

---

## Dependency manifest

The posture is **Flutter + a small set of mainstream, actively-maintained packages**, every one justified against a constraint. Pin exact versions at integration.

| Package | Role | Justification (constraint) |
| ------- | ---- | -------------------------- |
| **drift** (+ `drift_dev`, `sqlite3_flutter_libs`) | Persistence (D3) | C1 — typed SQLite, first-class migrations, transactions, Phase-2 sync-ready. |
| **flutter_riverpod** | State / DI (D2) | C6 — optimistic UI, testable repositories. |
| **flutter_local_notifications** | Local notifications (D4) | C2 — scheduling, channels, background quick-log action. |
| **timezone** | Correct local `zonedSchedule` (D4) | C2 — day-boundary/active-hours correctness across DST. |
| **fl_chart** | Charts (D5) | C3 — History bars + BAC line chart. |
| **flutter_svg** (or `vector_graphics`) | Drink icons (D6) | C5 — two-shade runtime-tinted SVG icons. |
| **permission_handler** / `app_settings` (small) | Notification permission + settings deep-link (D4) | C2 — permission-optional, deep link to system settings. |
| **`core`** (in-house, pure Dart) | Shared computation (D7) | C4 — all algorithms; no external deps. |

Deliberately **excluded** in Phase 1: any networking/HTTP client, FCM/push, analytics, crash reporting — none ship in Phase 1 (C0). No account/sync/social packages.

---

## Risks & open questions

1. **[HIGH — spike first] Background-isolate notification paths.** The quick-log background action runs in a background Dart isolate that must open Drift and write. This is the part of the Flutter notification story most prone to platform-edge surprises (isolate lifecycle, DB access from a background isolate). Prototype it before committing the D4 design.
2. **[MED] Android delivery reliability.** OEM battery-killers and App Standby can drop a backgrounded nudge; Flutter doesn't change this OS/vendor behaviour. Treat missed nudges as non-fatal; consider an optional "ignore battery optimisations" prompt. With C6 forbidding telemetry, reliability must be validated by an internal OEM device matrix pre-release.
3. **[MED] iOS at-delivery recompute is impossible.** No code runs when a local notification delivers. Mitigated by the uniform rolling-window re-arm; bound the staleness (≤ window length) and get product sign-off.
4. **[MED] Accessibility via Flutter `Semantics`.** Flutter re-implements the accessibility tree rather than using native widgets; VoiceOver/TalkBack coverage is generally good but occasionally needs manual `Semantics` work. Validate end-to-end against the C5 a11y checklist.
5. **[LOW] fl_chart red-wash + dashed projection.** High confidence the outcome is achievable (`CustomPainter` fallback always works); spike the BAC chart to confirm the cleanest approach.
6. **[LOW → Later] watchOS / Wear OS wall.** Flutter does not target watchOS and Wear OS support is limited; the post-Phase-3 **L2** wearable/watch features would need native satellite apps (and HealthKit/Health Connect via the `health` plugin). Out of scope for Phases 1–3, but the one place the Flutter ecosystem genuinely can't reach.
7. **[LOW] Platform-adaptive nav idiom.** Flutter renders one bottom nav for both platforms by default; decide whether to adapt to each platform's idiom (Cupertino tab bar on iOS) or use one brand-styled Material nav everywhere. Either is fine; it's a design call, not a constraint.
</content>
