# Flutter Stack — Phase 1 Decision Record

> **Audience note.** Written for a lead who knows frontend/backend patterns (state management, repositories, ADRs, design tokens) but is *not* a native-mobile specialist. Platform-specific concepts are explained inline. This document **supersedes the two-native-app direction**: Drinks Mate is now a **single Flutter codebase** targeting iOS and Android. The earlier native research — [`ios-stack.md`](./ios-stack.md) and [`android-stack.md`](./android-stack.md) — is retained as **platform research that still informs the Flutter notification and OS-integration design**, not as the chosen architecture. See [README → parity contract](../README.md).

## Why this supersedes the native plan

The original architecture (C0) was **two independent native codebases** with parity enforced by a shared spec, a shared golden-file test-vector suite, and CI gating. The [validation report](../validation.md) found that sound but flagged its two hardest problems: **C4 cross-platform computation parity** ("the highest parity-risk surface" — BAC/pace/goal math that must be bit-for-bit identical across Swift and Kotlin, with a floating-point-determinism risk) and the **iOS/Android notification-model divergence** (P0-a/P0-b).

**A single Flutter/Dart codebase dissolves the first problem entirely and most of the second's parity dimension:** there is one implementation of every algorithm, one set of widgets, one design-system binding — so behavioural and visual parity hold *by construction* rather than by governance. The cost lands almost exclusively on **background notification scheduling**, which is precisely what the native decision was made to protect (see [technical-architecture.md → Why Flutter](../../design/technical-architecture.md#why-flutter-rather-than-two-native-apps)). That trade is judged worth it: the notification OS-limits are the *same* under Flutter (iOS cannot recompute at delivery either way), and the parity/maintenance saving is large and ongoing.

## Summary

Build Phase 1 as a **Flutter (stable channel) app on Dart 3**, **Material 3** with a fully custom design system, targeting **iOS 18.0+** and **Android `minSdk 26` / `targetSdk 36`** — the same OS floors the native docs settled on. Lean on **first-party Flutter + a small set of well-maintained, widely-used packages**: **Drift** for persistence (typed SQLite — the cross-platform analogue of GRDB/Room, same engine, same UUID/soft-delete/`updatedAt` semantics, first-class migrations), **flutter_local_notifications** (+ `timezone`) for the local-notification engine, **fl_chart** for History + the Party BAC chart, **flutter_svg** for the two-shade tinted drink icons (now trivial in Dart), **Riverpod** for state/DI, and a **dependency-free pure-Dart `core` package** for every C4 algorithm. Because there is one codebase, the C4 shared-fixture apparatus becomes ordinary unit tests, and the Swift-vs-Kotlin floating-point-determinism risk disappears. The **one genuinely harder area is notifications** (D4): iOS's "recompute at delivery" is impossible regardless of framework, and Android's fire-time recompute now runs through a Dart background isolate rather than a native receiver — so the recommended model is a **uniform rolling-window re-arm on both platforms**, which also closes the old P0-b parity gap. The **only hard "must be native" surface is in the explicitly-deferred Later bucket** (Apple Watch / Wear OS apps; Flutter does not target watchOS) — out of scope for Phases 1–3.

### Decisions at a glance

| # | Area | Decision | Key dependency | Confidence |
|---|------|----------|----------------|------------|
| D1 | UI framework | **Flutter (stable) + Dart 3**, Material 3 + custom design system; iOS 18 / Android minSdk 26, targetSdk 36 | Flutter SDK | High |
| D2 | Architecture / state | **Riverpod** + repository pattern over Drift; thin, testable view-models. No heavyweight framework. | flutter_riverpod | High |
| D3 | Persistence | **Drift** (typed SQLite). sqflite/Isar/Hive rejected. | drift | High |
| D4 | Local notifications | **flutter_local_notifications** + `timezone`; uniform rolling-window re-arm; background-isolate quick-log. Optional native fire-time recompute on Android. | flutter_local_notifications, timezone | Medium-High |
| D5 | Charts | **fl_chart** for History bars + BAC line; red wash via `CustomPainter` | fl_chart | High |
| D6 | Drink-icon tinting | **flutter_svg** + runtime two-shade HSL tint in pure Dart (`core`) | flutter_svg | High |
| D7 | Shared computation | Dependency-free pure-Dart **`core`** package; parity by construction; design fixtures become unit tests | none (in-house) | High |

---

## D1 — UI framework: Flutter (stable) + Dart 3, Material 3 + custom design system

- **Status:** Proposed
- **Area:** architecture / design-system
- **Constraint(s) addressed:** C0 (single codebase), C5 (design system, dark mode, dynamic type, accessibility), C6 (two-taps-to-log, instant optimistic UI), enables C2/C3.

**Decision.** Build the whole app in **Flutter** on the **stable channel**, Dart 3, rendering its own UI (Impeller engine) rather than wrapping native widgets. Use **Material 3** as the component base with a fully custom theme (the design-system tokens drive `ThemeData`). Target **iOS 18.0** and **Android `minSdk 26` (Android 8.0) / `targetSdk 36` (Android 16)** — the same floors the native docs justified, retained for the same reasons (notification channels need API 26; Play mandates target 36 from 31 Aug 2026; iOS 18 reaches essentially the whole active base).

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| Flutter, single codebase | ✅ chosen | One implementation ⇒ visual + behavioural parity by construction; draws its own UI so the custom design system is pixel-identical across platforms; mature in 2026; covers every Phase 1 surface. |
| Two native apps (SwiftUI + Compose) | ❌ rejected (superseded) | The prior C0. Best OS integration, but doubles every feature and makes C4/C5 parity a standing governance cost — the risk the validation flagged hardest. |
| React Native | ❌ rejected | Bridges to native widgets (parity drift on the bespoke design system), JS runtime; Flutter's own-rendering model fits the "two platforms must look identical" brief better. |
| Kotlin Multiplatform + shared UI (Compose Multiplatform) | ❌ rejected for Phase 1 | Shared logic is production-stable, but CMP-on-iOS is younger than Flutter and the iOS toolchain cost is higher for a 7-screen app. |

**Rationale.** The product's defining engineering tension was **parity across two platforms** for a bespoke design system and a numerically-exact computation core. Flutter renders its own UI from one widget tree, so DM Sans, the exact palette, dark mode, motion curves, and the two-shade drink icons are *the same code* on both platforms — C5 parity stops being something to police and becomes a property of the build. Material 3 gives accessible, theme-able components to customise rather than build from scratch; Flutter honours OS dark mode, text scaling, and reduce-motion, and exposes a `Semantics` tree to VoiceOver/TalkBack. C6's optimistic logging is a natural fit (write to Drift, a Riverpod provider updates, the widget rebuilds, no spinner).

**Parity implication.** **This is the whole point.** One codebase ⇒ no cross-platform divergence to enforce for UI or logic. The residual, *intentional* divergences are where Flutter defers to the OS: notification delivery (D4), system text-scale factors, and any platform-adaptive nav idiom we opt into. Everything else matches by construction.

**Phase-2 forward-constraint.** None. Accounts/sync/social are ordinary Flutter surfaces; one codebase means each Phase 2 feature is built once.

**Confidence & evidence.** High. Flutter is a mature, first-party-supported cross-platform toolkit in 2026 with full Material 3, accessibility, and dark-mode support; iOS 18 / Android 26 floors and the Play target-36 timeline carry over verbatim from the native docs (already verified there).

---

## D2 — Architecture / state management: Riverpod + repository pattern

- **Status:** Proposed
- **Area:** architecture
- **Constraint(s) addressed:** C6 (instant optimistic UI), supports all of C0–C5.

**Decision.** Use **Riverpod** (`flutter_riverpod`) for state and dependency injection, with a **repository layer** wrapping Drift (D3) as the only thing view-models touch — Drift types never reach widgets. Screens watch providers exposing immutable state; actions call repository methods. Keep view-models thin and the C4 math in the `core` package (D7). **No heavyweight framework** beyond Riverpod.

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| Riverpod + repository | ✅ chosen | Compile-safe DI, testable providers, minimal ceremony; the structural analogue of the native MVVM/Observation choice; repository is the Phase-2 sync seam. |
| Bloc / flutter_bloc | ⚠️ viable | Excellent and explicit, but more event/state boilerplate than a 7-screen single-user app needs; Riverpod is lighter for the same UDF shape. |
| Provider / `setState` only | ❌ rejected | Provider is the older generation; raw `setState` doesn't scale to the repository/optimistic-update paths cleanly. |
| GetX | ❌ rejected | Over-broad (routing+DI+state+more), weaker testability and discipline. |

**Rationale.** The app is single-user, offline, append-mostly, ~7 screens — it doesn't earn a formal reducer framework. Riverpod gives precise rebuilds (so the C6 optimistic log is a few lines), constructor-free DI for swapping repositories in tests, and keeps business logic in plain, unit-testable Dart. The repository boundary is exactly where Phase 2 sync slots in without touching the UI — the same seam both native docs called out.

**Parity implication.** None (internal; one codebase). The C4 algorithms sit behind the repository in `core`, so even internal structure can't drift.

**Phase-2 forward-constraint.** None — the repository is the documented sync insertion point; a sync engine feeds the same Drift store.

**Confidence & evidence.** High. Riverpod is a mainstream, actively-maintained Flutter state library in 2026; the proportionality argument mirrors the native docs' "no TCA / no Hilt" calls.

---

## D3 — Local persistence: Drift (typed SQLite)

- **Status:** Proposed
- **Area:** persistence
- **Constraint(s) addressed:** C1 (all of it), C0 (local source of truth, offline-first, no Phase-2 scaffolding), C4 (date-range / day-boundary queries).

**Decision.** Use **Drift** (formerly Moor) — a typed reactive persistence layer over SQLite — as the local store. Model UUID `TEXT` primary keys, `createdAt` / `updatedAt` / `deletedAt` columns, money as integer minor units, all-metric storage, the `partySessionId` FK, and the C1 entity set. Use Drift's **schema versioning + stepwise migrations** (with the generated schema snapshots its migration tooling produces), `transaction {}` for atomic multi-row edits, and parameterised `[dayStart, dayEnd)` range queries computed from the configurable 05:00 boundary (the day-window math lives in `core`, D7).

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| **Drift** | ✅ chosen | Typed, compile-checked SQL; **first-class migrations** with generated schema snapshots and a migration test harness; transactions; reactive queries that feed the optimistic UI; pure SQLite so Phase-2 sync layers cleanly on top. The Flutter analogue of GRDB/Room. |
| sqflite | ❌ rejected | Raw SQLite with no typing, no migration framework, no query checking — re-implements what Drift gives safely. |
| Isar / ObjectBox | ❌ rejected | Fast NoSQL object stores, but not relational SQLite; migration + sync-readiness story is weaker for a schema we *know* will churn, and they pull toward their own ecosystems. |
| Hive | ❌ rejected | Key-value, no relational queries or transactional multi-entity edits; wrong shape for date-range/day-boundary aggregation. |

**Rationale.** C1 weights **migrations and Phase-2 sync-readiness** most heavily, and that is exactly where Drift wins: schema version is a first-class property, migrations are explicit and testable, and because it's "just SQLite," nothing about a later delta/LWW sync engine over `updatedAt` (propagating soft-deletes via `deletedAt`) is blocked. Drift expresses every C1 specific cleanly — UUID text PKs, a `deletedAt IS NULL` filter on every UI query, `transaction {}` so a partial edit can never persist, and day-boundary range queries as parameterised SQL. **Parity bonus over the native plan:** previously iOS (GRDB) and Android (Room) were two SQLite stores kept in semantic lockstep by spec; now there is *one* store and *one* schema, so the "timestamp representation / DST drift at the day boundary" watch-item the native docs flagged simply cannot occur.

**Phase-2 forward-constraint.** Keeps Phase 2 fully open: UUID PKs are the future cross-device key, `updatedAt` is the LWW basis, `deletedAt` propagates deletions tombstone-free — exactly the `technical-architecture.md` sync-model requirement. **Guardrail:** the Phase-2-only entities (`Account`, `Friendship`, `ShareSetting`) must not appear in any Phase 1 migration (C0/C1).

**Confidence & evidence.** High. Drift is a mature, actively-maintained typed SQLite layer for Dart/Flutter with documented migration and migration-testing support; SQLite underneath means worst-case portability is mechanical. Pin the exact version at integration.

---

## D4 — Local notifications: flutter_local_notifications + uniform rolling-window re-arm

- **Status:** Proposed
- **Area:** notifications
- **Constraint(s) addressed:** C2 (all of it).

**Decision.** Use **flutter_local_notifications** (with the **`timezone`** package for correct local `zonedSchedule`) as the local-notification engine: notification channels, the inline **quick-log action** handled in a **background Dart isolate** (`@pragma('vm:entry-point')` callback that writes to Drift without opening the app), permission requests, and lock-screen visibility mapping. Adopt a **uniform rolling-window re-arming scheduler on both platforms**: keep a small batch (N ≈ 8–16, well under iOS's 64-pending ceiling) of upcoming reminders scheduled with content baked at schedule time, and **re-arm the whole window on every app foreground, every drink log (incl. the quick-log action), and every settings change**. Anti-spam predicates (at-goal / just-logged / 7-day-inactive) are evaluated **at re-arm**, and crossing the goal **cancels** remaining same-day reminders. Optionally, on Android only, add true **fire-time recompute** via a native `BroadcastReceiver` (platform channel) or a headless-isolate alarm plugin — treated as an *enhancement*, not the baseline.

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| flutter_local_notifications + uniform rolling-window re-arm | ✅ chosen | Single behaviour on both platforms ⇒ parity by construction; respects iOS's 64 ceiling; re-arming keeps baked content fresh enough; quick-log via background isolate is supported. |
| flutter_local_notifications + Android-only native fire-time recompute | ⚠️ enhancement | Matches the *old* Android advantage (recompute at delivery), but reintroduces a platform divergence and native glue; keep as an optional top-up, not the baseline. |
| Push/FCM-driven content | ❌ rejected | Violates C0/C2 — Phase 1 has no backend; notifications must be local. |
| Foreground service / persistent isolate timer | ❌ rejected | Disproportionate and battery-hostile for occasional reminders; unnecessary (see [the background-timer analysis](../validation.md) — reminders delegate the clock to the OS). |

**Rationale — this is the hardest area, so concretely:**

*The iOS reality is framework-independent.* iOS local notifications are scheduled ahead of time and there is **no on-device hook that runs your code when a *local* notification delivers** (the service extension is push-only). So "recompute the recommended volume at delivery" cannot be done on iOS in native Swift *or* in Flutter. Content must be baked at schedule time and refreshed by re-arming — identical to the native iOS plan.

*Why uniform re-arm on both platforms.* Under the native plan, Android *could* recompute at fire-time in a Kotlin `BroadcastReceiver`, which is exactly the **P0-b parity gap** the validation flagged: Android suppressed/refreshed at fire-time while iOS could not, so the two platforms behaved differently in the "app untouched for hours/days" edge. Standardising on the **rolling-window re-arm on both** makes the behaviour identical and **closes P0-b by construction** — both platforms now have the same (small, bounded) staleness and the same predicate-evaluation point. The recommended-volume drift is small and self-correcting (the next reminder, computed from live data at the next re-arm, fixes it), and the same `core` pace formula (D7) drives both.

*Quick-log without opening the app.* flutter_local_notifications supports a background-invoked action callback (`onDidReceiveBackgroundNotificationResponse`, annotated `@pragma('vm:entry-point')`). It runs in a **background isolate** that opens Drift, writes a `DrinkEntry` for `defaultDrinkPresetId`, and re-arms — no UI shown. (If `defaultDrinkPresetId` is missing per the data-model fallback, the action falls back to the seeded water preset or is omitted.)

*Anti-spam at re-arm.* `7-day inactivity`: computed at every re-arm; schedule **no notification whose own fire time is ≥ 7 days past last engagement**, bounding the silent-crossing leak to ≤ the window length. `at-goal / just-logged`: every log re-arms, and crossing goal cancels remaining same-day reminders, so a notification that *would* be wrong never stays pending. `at-most-once` (inactivity/day, weekly/week): one calendar trigger per period, de-duped at re-arm.

*Channels, permission, lock-screen.* Create channels (`hydration`, `inactivity`, `weekly_summary`, `party`) at first launch — flutter_local_notifications exposes the Android channel API and the iOS categories/actions. Request `POST_NOTIFICATIONS` (Android 13+) / iOS authorization at the contextually-right moment; if declined the app stays fully functional and Settings deep-links to system notification settings (via a small `app_settings`-style channel). Map `bacOnLockScreenEnabled` to Android `Visibility.private` and, on iOS, to **withholding the BAC string from the body** — same user-visible outcome as the native plan.

**Parity implication.** **Improved vs the native plan.** The biggest documented divergence (Android fire-time recompute vs iOS re-arm) is *removed* by choosing the uniform model. The remaining intrinsic divergence is **delivery reliability** — Android OEM battery-killers (Xiaomi/Huawei/Samsung/etc.) and App Standby can still drop a backgrounded nudge, exactly as in native Android; this is an OS/vendor property, not a Flutter one. Treat a missed nudge as non-fatal.

**Phase-2 forward-constraint.** None blocking. If Phase 2 adds a push backend, a real iOS service extension and server-driven content could be layered on without disturbing the local engine.

**Confidence & evidence.** Medium-High. flutter_local_notifications is the de-facto Flutter local-notification package (scheduling, channels, background action callbacks, `zonedSchedule` with `timezone`); the iOS service-extension limit and the 64-pending ceiling are confirmed in the native research and carry over unchanged. The background-isolate quick-log path and the optional Android native fire-time recompute are the two things to **spike first**, since background isolates are the part of the Flutter notification story most prone to platform-edge surprises.

---

## D5 — Charts: fl_chart

- **Status:** Proposed
- **Area:** charts
- **Constraint(s) addressed:** C3 (History bars + BAC line chart), C5 (non-colour signal, accessibility).

**Decision.** Use **fl_chart** for both the History bar charts and the Party BAC line chart. Express the BAC chart's **solid past + dashed projected** segments as two line series (`dashArray` on the projection); the **low-opacity red wash** behind the projection and the **session overlay band** via a `CustomPainter` / background painter keyed to the "now" x-coordinate; the **"now"** and **cap** lines as extra lines / `ExtraLinesData`. Dual-axis **g/L + mmol/L** is the same manual relabel as native (mmol/L = g/L × 21.7, exact linear), rendering the right-side titles as the left-axis values × 21.7.

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| fl_chart | ✅ chosen | Widely-used, actively-maintained Flutter chart lib; covers bars + line, dashed lines, reference lines, and a `CustomPainter` escape hatch for the red wash; no native interop. |
| Syncfusion Flutter Charts | ❌ rejected | Very capable but a heavier dependency with licensing considerations; fl_chart covers the spec. |
| graphic (grammar of graphics) | ❌ rejected | Powerful but a different mental model and heavier than needed for a fixed, small chart set. |
| Hand-rolled `CustomPaint` for everything | ❌ rejected as primary | Reinvents axes/ticks/paging; we *will* use `CustomPainter` for the wash only, layered with fl_chart. |

**Rationale.** C3 needs goal-referenced bar charts with a non-colour below-goal signal, weekly/monthly paging, a session overlay band, and the BAC line chart (solid+dashed, red wash, now/cap rules, rounded 24h X, dual units). fl_chart expresses all of it natively, with the red wash as the one piece most likely to need the `CustomPainter` escape hatch — low-risk, since it's a static rectangle keyed to the "now" x. The **non-colour below-goal signal** (a single chosen treatment — e.g. a diagonal hatch) is drawn once and applies on both platforms, resolving the old P1-b "pick one shared treatment" item by construction.

**Parity implication.** None — one chart implementation. The data points come from `core` (D7); the visual encoding is one set of widgets.

**Phase-2 forward-constraint.** None — charts are read-only over local data.

**Confidence & evidence.** Medium-High. fl_chart's bars/lines/dashed/reference-line/`CustomPainter` capabilities are well-established; pin the version at integration and **spike the red-wash + dashed-projection BAC chart first** (the one piece carrying implementation risk, exactly as on native).

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

**Rationale.** What was a fiddly, *parity-critical* problem on native — the hex→HSL→±15% math had to be **bit-identical** across Swift and Kotlin or the same drink rendered different colours, with shared fixtures to police it (the old P1-a) — is now a single Dart function used by the single renderer. Flutter computes colours and tints vectors easily; this is one of the areas Flutter is *strictly simpler* than the native plan. The two-subpath authoring requirement on the designer's SVGs is unchanged.

**Parity implication.** None to enforce — one HSL function, one renderer. (The Rulebook's pinned direction/clamp/colour-space rule is still the spec the function implements.)

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
| Keep the cross-platform golden-fixture + dual-implementation harness | ❌ rejected (obsolete) | There is only one implementation now — the cross-platform-drift machinery and the Swift-vs-Kotlin FP-determinism risk no longer exist. The *fixtures* remain valuable as regression tests, just not as a parity gate. |

**Rationale.** C4 was named the **highest parity-risk surface** specifically because two independently-written native implementations of the BAC chain (Watson/Widmark branch, meal min-modifier, orphan `t_zero`, rounding) could silently disagree, and Swift/Kotlin floating-point noise could cause spurious mismatches. **A single Dart implementation removes that entire risk class:** the BAC curve, the pace deficit, the goal, the username rules, and the icon shades are computed once, so "do iOS and Android agree?" is no longer a question. The design's worked examples still earn their keep — as ordinary regression fixtures that pin the spec — but the elaborate shared-vector CI gate the native plan needed is retired. Keep `core` free of Flutter/Drift imports so it's reused by the D4 scheduler, the D6 icon shading, the Party tab, and History.

**Parity implication.** **Eliminated as a concern.** This is the single largest simplification from the Flutter switch.

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

Deliberately **excluded** in Phase 1 (unchanged from the native scope): any networking/HTTP client, FCM/push, analytics, crash reporting — none ship in Phase 1 (C0). No account/sync/social packages.

---

## Risks & open questions

1. **[HIGH — spike first] Background-isolate notification paths.** The quick-log background action and any Android fire-time recompute run in a background Dart isolate that must open Drift and write. This is the part of the Flutter notification story most prone to platform-edge surprises (isolate lifecycle, DB access from a background isolate). Prototype it before committing the D4 design.
2. **[MED] Android delivery reliability (unchanged from native).** OEM battery-killers and App Standby can still drop a backgrounded nudge; Flutter doesn't change this OS/vendor behaviour. Treat missed nudges as non-fatal; consider an optional "ignore battery optimisations" prompt. With C6 forbidding telemetry, reliability must be validated by an internal OEM device matrix pre-release.
3. **[MED] iOS at-delivery recompute is impossible (framework-independent).** Same limit as native iOS. Mitigated by the uniform rolling-window re-arm; bound the staleness (≤ window length) and get product sign-off — but note the **uniform model means iOS and Android now behave the same here**, closing the old P0-b.
4. **[MED] Accessibility via Flutter `Semantics`.** Flutter re-implements the accessibility tree rather than using native widgets; VoiceOver/TalkBack coverage is generally good but occasionally needs manual `Semantics` work. Validate end-to-end against the C5 a11y checklist (now a single pass, not two).
5. **[LOW] fl_chart red-wash + dashed projection.** High confidence the outcome is achievable (`CustomPainter` fallback always works); spike the BAC chart to confirm the cleanest approach.
6. **[LOW → Later] watchOS / Wear OS wall.** Flutter does not target watchOS and Wear OS support is limited; the post-Phase-3 **L2** wearable/watch features would need native satellite apps (and HealthKit/Health Connect via the `health` plugin). Out of scope for Phases 1–3, but the one place the Flutter ecosystem genuinely can't reach.
7. **[LOW] Platform-adaptive nav idiom.** Flutter renders one bottom nav for both platforms by default; decide whether to adapt to each platform's idiom (Cupertino tab bar on iOS) or use one brand-styled Material nav everywhere. Either is fine; it's a design call, not a constraint.
</content>
</invoke>
