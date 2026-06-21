# Android Native Stack — Phase 1 Decisions

> Scope: the Android half of the Drinks Mate Phase 1 (local-only MVP) build. Written against [phase-1-constraints.md](../phase-1-constraints.md); the constraint anchors (C0–C6) referenced throughout live there. Companion to `ios-stack.md` (not yet written) under the [parity contract](../README.md#the-parity-contract).
>
> **Date of research:** 2026-06-21. Versions and maintenance status verified as of that date (sources cited per decision).

## Summary

For an offline-first, single-user hydration tracker of this size, the Android build should lean almost entirely on **first-party Jetpack/AndroidX** and add only **one** third-party dependency (a charting library). The recommended spine is **Jetpack Compose** (UI) + **MVVM with unidirectional data flow via ViewModel/StateFlow** (architecture) + **Room** (persistence) + a **hybrid AlarmManager/WorkManager notification engine** + **Vico** (charts) + **Compose-native vector rendering** (icons) + a **pure-Kotlin `core` module** (shared computation). The single largest engineering risk on Android — and the single largest parity risk versus iOS — is **background notification reliability**: Android aggressively defers and kills background work, OEMs add their own non-standard battery killers, and exact-alarm scheduling now carries permission strings. That decision (D4) is the longest below and is honest about the limits.

A note for the non-Android reader: think of Android app development like building a web app where the *browser* (the OS) is hostile to anything that runs while the tab is backgrounded, every phone vendor ships a slightly different fork of that browser, and "schedule this to run at exactly 12:00" is a privilege the user can revoke. Most of the hard decisions here are about working *with* that hostility rather than against it.

### Decisions at a glance

| # | Area | Decision | Key third-party dep? |
| - | ---- | -------- | -------------------- |
| D1 | UI toolkit | **Jetpack Compose** (Material 3). `minSdk 26` (Android 8.0), `targetSdk 36` (Android 16). | No (AndroidX) |
| D2 | Architecture / state | **MVVM + UDF**: `ViewModel` + `StateFlow` immutable UI state, Repository over Room, Compose **Navigation 3**, Lifecycle. | No (AndroidX) |
| D3 | Persistence | **Room 2.8.x** (SQLite). UUID PKs, `createdAt/updatedAt/deletedAt`, `@Transaction`, **schema versioning with explicit + auto migrations**, day-boundary range queries. | No (AndroidX) |
| D4 | Notifications | **Hybrid**: `AlarmManager.setExactAndAllowWhileIdle` (inexact fallback) drives the next-reminder alarm; **BroadcastReceiver** recomputes volume + fire-predicate at delivery and quick-logs without opening the app; `WorkManager` only for the daily reschedule sweep + weekly summary. Notification **channels**, `POST_NOTIFICATIONS` runtime permission, BAC lock-screen visibility mapping. | No (AndroidX) |
| D5 | Charts | **Vico** (`com.patrykandpatrick.vico`) for history bars **and** the BAC line chart (dashed projected segment + red wash via custom Canvas decorations). | **Yes — Vico** (only 3rd-party dep) |
| D6 | Icons (2-shade tint) | **Compose-native vector rendering**: ship artwork as multi-path `VectorDrawable`/`ImageVector`, override the two path colours per-instance from one `iconColor` via an HSL ±15% offset computed at runtime. **No** SVG library. | No (AndroidX) |
| D7 | Shared computation | **Pure-Kotlin module** (`:core`), no Android deps, deterministic; drives BAC/pace/username/day-boundary; verified against shared cross-platform fixtures. ICU via `android.icu` (API 24+). | No (stdlib + android.icu) |

---

## D1 — UI toolkit: Jetpack Compose, minSdk 26 / targetSdk 36

- **Status:** Proposed
- **Area:** architecture (UI toolkit)
- **Constraint(s) addressed:** C5 (design system, dark mode, dynamic type, custom icon family, motion/reduce-motion, TalkBack), C6 (two-taps-to-log, instant optimistic UI)

**Decision.** Build the entire UI in **Jetpack Compose** with **Material 3**, on **Compose BOM `2026.04.01`** (Compose 1.11, stable). Set **`minSdk = 26`** (Android 8.0 Oreo) and **`targetSdk = 36`** (Android 16). Use Views/XML only where Compose has no native equivalent — for Phase 1 there is none required.

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| Jetpack Compose (Material 3) | ✅ chosen | Declarative state→UI maps directly onto the UDF architecture (D2); custom design system, per-instance icon tinting (D6), animated progress, and reduce-motion fallbacks are first-class; Google's recommended default for new apps in 2026. |
| Views / XML + Material Components | ❌ rejected | Imperative `findViewById`/adapter boilerplate fights the optimistic-UI loop; custom two-shade icon tinting and the bespoke design system are far more code; no new-app reason to choose it in 2026. |
| Hybrid (Compose islands in Views) | ❌ rejected | Adds interop complexity (two state models) for zero benefit on a greenfield app with no legacy Views to host. |

**minSdk rationale (be realistic about the 2026 device base).** `minSdk 26` (Android 8.0, 2017) is the practical floor for a modern Compose app: Compose itself requires `minSdk 21`, but **notification channels** — mandatory for C2 — were introduced in **API 26**, and `setExactAndAllowWhileIdle` Doze behaviour is sanest from 26 up. By mid-2026, devices below API 26 are a fraction of a percent of active Android and a vanishing share of the kind of user who installs a new lifestyle app. Going lower would force `NotificationChannel` branching and pre-Oreo background-execution shims for negligible reach. Going higher (e.g. `minSdk 29/31`) buys marginally simpler notification code but needlessly excludes a meaningful tail of mid/low-end devices — the opposite of the broad, low-friction reach this app wants. **`minSdk 26` is the sweet spot.**

**targetSdk rationale.** `targetSdk` is a *promise to the OS* that you've tested against that release's behaviour changes — higher is mandated, not optional. Google Play requires **new apps and updates to target API 35 (Android 15) today, and API 36 (Android 16) from 31 Aug 2026**. Since Phase 1 ships into that window, **target 36 now** to avoid an immediate forced bump and to face the exact-alarm/Doze behaviour changes head-on rather than inheriting legacy-compat behaviour that will be removed.

**Rationale.** Compose is the only choice that makes C5 cheap: the two-shade icon tint (D6), the animated pace bar, dark/light theming off the system setting, and TalkBack semantics are all declarative one-liners rather than custom view subclasses. It also makes C6's optimistic logging trivial — log writes flip a `StateFlow`, the bar animates, no spinner.

**Parity implication.** Compose (Android) and SwiftUI (iOS, recommended) are both declarative state→UI toolkits, so the two apps will be *structurally* similar, which lowers parity drift. But neither toolkit guarantees pixel parity — the C5 design system (DM Sans, exact hex, radii, motion curves) is what enforces visual parity, not the toolkit. That cross-platform enforcement lives in `design-system.md`, not here.

**Phase-2 forward-constraint.** None. Compose has no bearing on accounts/sync. If a Phase 2 desire for shared UI code ever arose, Compose Multiplatform is a forward path, but that is explicitly out of scope and not a Phase 1 commitment.

**Confidence & evidence.** **High.** Compose BOM `2026.04.01` confirmed stable with Navigation 3 stable in the same release ([Compose April '26 release](https://android-developers.googleblog.com/2026/04/jetpack-compose-april-2026-updates.html)). Play target-API timeline (API 35 now → 36 from 2026-08-31) confirmed ([Play target API requirements](https://developer.android.com/google/play/requirements/target-sdk)). Note: **Material 3 *Expressive* and Adaptive are still on alpha tracks** as of April 2026 — we use stable Material 3 and avoid the expressive/adaptive alpha surfaces.

---

## D2 — App architecture & state management: MVVM + unidirectional data flow

- **Status:** Proposed
- **Area:** architecture
- **Constraint(s) addressed:** C0 (offline-first, no network on the core loop), C1 (transactional reads/writes feeding the UI), C6 (instant optimistic UI), C5 (navigation idiom)

**Decision.** **MVVM with unidirectional data flow (UDF).** Each screen has a `ViewModel` exposing one immutable UI-state object via `StateFlow`; the UI is a pure function of that state and emits events back up. A **Repository** layer wraps Room and is the only thing the ViewModels touch — Room is never referenced from composables. Use Jetpack **Lifecycle** (`viewModelScope`, lifecycle-aware collection), **Navigation 3** for the back stack and the 3-tab structure, and Kotlin **coroutines/Flow** for all async. **No Hilt/Dagger** in Phase 1 — manual constructor injection via a small `AppContainer` is sufficient for an app this size and keeps the dependency count and build complexity down.

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| MVVM + UDF (ViewModel/StateFlow + Repository) | ✅ chosen | The Android-idiomatic, Google-recommended pattern; matches Compose's state model exactly; proportionate to a single-user offline app. |
| MVI with a full reducer framework (e.g. Orbit/Mavericks) | ❌ rejected | UDF *is* lightweight MVI already; a formal reducer framework is ceremony this app's handful of screens don't need, and adds a dependency. |
| MVC/MVP with imperative views | ❌ rejected | Doesn't fit Compose; reintroduces the imperative state-sync bugs Compose exists to remove. |
| Hilt for DI | ❌ rejected *for Phase 1* | Real benefit at scale, but for ~7 screens manual DI is less machinery, faster builds, no annotation processor. Re-evaluate at Phase 2 when sync/services multiply. |

**Rationale.** UDF gives C6 for free: a quick-log tap calls `repository.logDrink(...)` inside `viewModelScope`, the Room write returns, the new total flows into `StateFlow`, and the bar re-renders — all without blocking the main thread or showing a spinner. The Repository boundary is also the **seam Phase 2 sync slots into**: today it talks only to Room; in Phase 2 it can additionally enqueue sync ops without any UI change. For a non-Android lead: this is the same "view-model holds immutable state, view renders it, actions dispatch up" shape as Redux/MVU on the web — Android just spells the state container `ViewModel` and the observable `StateFlow`.

**Parity implication.** Architecture is internal; users never see it. iOS will use the analogous SwiftUI `@Observable`/MVVM shape. What matters for parity is that both put the C4 pure algorithms behind the same boundary (D7) so behaviour can't drift. No user-visible divergence from this choice. → "none" at the UX level.

**Phase-2 forward-constraint.** Keeps Phase 2 fully open and is in fact the enabler: the Repository is the documented insertion point for sync. The one forward-note: **don't leak Room types (entities, `Flow<RoomEntity>`) above the Repository** — map to domain models — so Phase 2 can change the storage/sync internals without a UI rewrite.

**Confidence & evidence.** **High.** ViewModel/StateFlow + Repository is the long-standing Google-recommended architecture; Navigation 3 confirmed stable (1.1.1) in the April 2026 Compose release ([Navigation 3](https://androidengineers.substack.com/p/navigation-3-the-future-of-android), [Compose April '26](https://android-developers.googleblog.com/2026/04/jetpack-compose-april-2026-updates.html)). The "no Hilt in Phase 1" call is a judgement proportionate to scope, not a verified fact — flagged as opinion.

---

## D3 — Local persistence: Room (SQLite)

- **Status:** Proposed
- **Area:** persistence
- **Constraint(s) addressed:** C1 (entire constraint), C0 (local source of truth, offline-first)

**Decision.** **Room `2.8.x`** (latest stable `2.8.4`, the AndroidX SQLite ORM). Model the C1 entities as `@Entity` classes with **`String` UUID** primary keys (app-generated `UUID.randomUUID().toString()`), `createdAt`/`updatedAt`/`deletedAt` columns, money as `INTEGER` minor units, all values metric. Every cross-row mutation runs inside a Room `@Transaction`. Migrations are **first-class from v1**: `@Database(version = 1)` with an explicit `MigrationTestHelper`-backed test, using Room **auto-migrations** for additive changes and hand-written `Migration` objects where renames/data moves are needed. UI queries always filter `deletedAt IS NULL`; daily/range queries take an explicit `[dayStart, dayEnd)` computed from the configurable day boundary and passed as bound parameters.

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| **Room** (AndroidX over SQLite) | ✅ chosen | First-party, SQLite-backed, **migrations are a first-class API** (versioned + auto + tested), `@Transaction` gives ACID, compile-time-checked SQL for day-range queries, no licensing/maintenance risk, zero added third-party surface. |
| SQLDelight | ❌ rejected | Excellent (SQL-first, KMP-friendly) but a third-party dep with no advantage here; migrations are `.sqm` files you hand-write and version manually — more discipline, not less; the KMP angle is moot since C0 fixes "no shared codebase". |
| Realm / Atlas Device SDK | ❌ rejected | Object DB, **not SQLite**; migration story is weaker and Realm's long-term maintenance/ownership has been turbulent (MongoDB-era deprecation signals). Its built-in sync would tempt us to violate C0 ("no sync scaffolding in Phase 1"). |
| Raw SQLite / SQLDelight-less SQLiteOpenHelper | ❌ rejected | All the migration/transaction burden by hand, no compile-time query checking; pure cost. |

**Rationale (migrations + sync-readiness weighted heavily, per the brief).**
- **Migrations as first-class (the deciding factor).** C1 says the app's lifetime will see *many* migrations and Phase 2 will add fields/entities. Room makes schema version a database-level property, generates auto-migrations for additive changes, and — critically — exports a JSON schema per version so migrations can be **unit-tested against real old→new upgrades** (`MigrationTestHelper`). SQLDelight can migrate too, but the safety net (tested, auto-generated additive migrations) is weaker and more manual. This is exactly the capability the brief says to weigh most.
- **Sync-readiness (must not block Phase 2).** Room imposes nothing that blocks last-writer-wins sync: UUID PKs are app-generated strings (cross-device-stable from day one), `updatedAt` is a plain column, soft-delete is a nullable timestamp. Because `DrinkEntry` carries no FK to `DrinkPreset` (snapshot immutability, C1), there's no sync-ordering dependency to untangle later. Room stays out of the way.
- **Transactions.** `@Transaction` / `withTransaction { }` gives the ACID guarantee C1 demands (a partial edit can't leave inconsistent state) — e.g. logging a drink that also absorbs orphan party-drinks is one atomic unit.
- **Day-boundary range queries.** The configurable 05:00 boundary is *not* baked into SQL; the ViewModel/Repository computes the `[start,end)` instants for "today" and passes them as parameters, so changing the boundary is a query-arg change, not a migration. UTC/zoned instants are stored as epoch millis (or ISO-8601 text) to keep range comparisons total-order-correct across DST.

For the non-Android reader: Room is "an ORM over SQLite with compile-time-checked queries and a real migrations framework," much like a typed query builder + migration tool on the backend. Nothing exotic.

**Parity implication.** **Indirect but important.** iOS will likely use SwiftData or GRDB — a *different* engine — so the two stores are not byte-identical. Parity is preserved at the **semantic** level: identical entity fields, identical UUID-string format, identical metric-only storage, identical soft-delete and snapshot rules (all fixed in C1/`data-model.md`, which both platforms implement). The risk to watch is **timestamp representation and rounding** (e.g. millisecond precision, timezone handling at the day boundary) — both platforms must agree on the exact instant a "day" starts. This is a shared-fixture concern (see D7).

**Phase-2 forward-constraint.** None blocking — it actively *enables* Phase 2. Forward-note: keep Room types behind the Repository (D2) and **do not** add any of the Phase-2-only entities (`Account`, `Friendship`, `ShareSetting`) to the schema in Phase 1 (C0 forbids their presence). Reserve schema version numbers; the first Phase 2 migration will add sync metadata additively.

**Confidence & evidence.** **High.** Room `2.8.4` confirmed current stable; Room 2.x is in **maintenance mode** (bugfix/patch only) and **Room 3.0** exists in a *new* package (`androidx.room3`) — we deliberately stay on stable 2.8.x for Phase 1 and treat the 3.0 migration as a later, mechanical package move ([Room releases](https://developer.android.com/jetpack/androidx/releases/room), [Room 3.0 blog](https://android-developers.googleblog.com/2026/03/room-30-modernizing-room.html)). Auto-migration refinements and KMP support (2.7+) confirmed but KMP is not needed here.

---

## D4 — Local notification scheduling (the hardest area, highest parity risk)

- **Status:** Proposed
- **Area:** notifications
- **Constraint(s) addressed:** C2 (entire constraint), plus the C4 recommended-volume recompute

**Decision.** A **hybrid, single-alarm rolling design**:

1. **One pending exact alarm at a time** for the *next* hydration reminder, scheduled via **`AlarmManager.setExactAndAllowWhileIdle(...)`** (fires through Doze). Request **`USE_EXACT_ALARM`** *only if* the app qualifies under Play policy; otherwise request **`SCHEDULE_EXACT_ALARM`** and **gracefully degrade to inexact** (`setAndAllowWhileIdle` / `setWindow`) when the permission is absent. We do **not** schedule the whole day up front — each fire reschedules the next, matching the "reset timer on log / cancel on goal" rules.
2. **A `BroadcastReceiver`** is the alarm target. At delivery it **opens Room, re-evaluates the full fire-time predicate on-device** (enabled? permission granted? within active hours? below goal? ≥ interval since last log? not inactive ≥7 days?), and only then **recomputes the recommended volume** (C4 pace formula) and posts the notification. If the predicate fails it posts nothing and just schedules the next alarm.
3. **The inline quick-log action** is a second `BroadcastReceiver` (a `PendingIntent` on the notification action) that **writes a `DrinkEntry` directly via Room without launching an Activity**, then cancels the notification, resets the reminder timer, and reschedules. No UI is shown.
4. **`WorkManager`** handles only the *non-exact, periodic* jobs: a daily "reschedule the day's first alarm after the day-boundary rollover" sweep, and the **weekly summary** (Sunday 20:00) and **noon inactivity** reminders — these tolerate WorkManager's ~minutes-of-slack and benefit from its reboot-persistence and Doze-friendliness.
5. **Reboot/update persistence:** a `BootReceiver` (`RECEIVE_BOOT_COMPLETED`) reschedules the next alarm after a reboot (alarms don't survive reboot); WorkManager jobs survive reboot on their own.

**Notification channels.** Create channels at first launch: `hydration` (default importance), `inactivity`, `weekly_summary`, and `party` (the BAC channel). A channel is, for the non-Android reader, a **user-controllable category** — once created, the *user* owns its importance, sound, and lock-screen behaviour from system Settings, and the app can't override them. The C2 requirement "user should control the channel from system settings" is satisfied by definition. We never recreate a channel to change its settings (the OS ignores that).

**Permissions.**
- **`POST_NOTIFICATIONS`** (runtime permission, **Android 13+**): requested at the contextually-right moment (onboarding step 5, or first reminder enable), not at cold launch. Declining leaves the app fully functional (C2); Settings shows the missing-permission state and deep-links to system notification settings via `Settings.ACTION_APP_NOTIFICATION_SETTINGS`.
- **Exact-alarm permission (Android 12+/13+):** `SCHEDULE_EXACT_ALARM` is **denied by default from Android 14** for newly installed apps and is **user-revocable**; `USE_EXACT_ALARM` is install-granted and *not* revocable **but Play restricts it to specific app categories** (alarm clocks, calendars, etc.). A hydration reminder is **unlikely to qualify** for `USE_EXACT_ALARM`, so the safe posture is: request `SCHEDULE_EXACT_ALARM`, check `AlarmManager.canScheduleExactAlarms()` at runtime, and **fall back to inexact scheduling** when it's not granted. We design the UX to *not depend* on to-the-minute precision (a reminder at 14:32 vs 14:30 is fine), which means inexact is an acceptable default and exact is an enhancement.

**Doze / battery-optimisation / OEM reality (honest limits).** Even with `setExactAndAllowWhileIdle`, Android imposes a **rate limit (~once per ~9–15 min per app) on exact-while-idle alarms in Doze**, which is well within our 90-min cadence, so the hydration interval is safe. The real threats are: (a) **App Standby buckets** deprioritising a rarely-opened app's background work, and (b) **aggressive OEM battery managers** (Xiaomi/MIUI, Huawei/EMUI, Samsung, OnePlus, Oppo) that kill or freeze backgrounded apps regardless of standard APIs. Mitigations: optionally prompt the user to **exclude the app from battery optimisation** (`ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`) — which we surface as an optional reliability toggle in settings, *not* a hard requirement — and treat any missed reminder as non-fatal (the app's value survives a dropped nudge). **We cannot guarantee minute-accurate delivery on every device. This is stated plainly in the risks section and is the headline parity risk vs iOS.**

**Lock-screen BAC visibility (C2).** The `bacOnLockScreenEnabled` toggle maps to **per-notification `setVisibility(...)`** on the party channel: `VISIBILITY_PUBLIC` (full BAC shown on lock screen) when ON, `VISIBILITY_PRIVATE` (system hides the body behind "Contents hidden" on the lock screen) when OFF. Because channel-level lock-screen settings are user-owned, we set per-notification visibility and document that the user's own channel setting can further restrict it.

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| Hybrid: AlarmManager (exact-ish) + BroadcastReceiver recompute + WorkManager periodic | ✅ chosen | Only design that meets *all* of C2: delivery-time recompute, quick-log-without-opening, conditional firing, channels, reboot persistence, and graceful permission degradation. |
| WorkManager only | ❌ rejected | **15-minute minimum periodic interval** and best-effort timing make it unsuitable for a precise 90-min cadence and timer-reset-on-log; fine for the slack-tolerant weekly/inactivity jobs, which is why it's kept *only* for those. |
| AlarmManager only | ❌ rejected | No reboot persistence without extra plumbing, no Doze-friendly periodic story; worse for the slack-tolerant jobs. The hybrid uses each tool where it's strongest. |
| Foreground service to keep a live timer | ❌ rejected | Wildly disproportionate (persistent notification, battery cost, Play scrutiny) for occasional reminders; user-hostile. |
| Firebase Cloud Messaging / push | ❌ rejected | **Violates C0/C2** outright — Phase 1 has no backend and notifications must be local. |

**Rationale.** The constraint set is unusually demanding: notifications must (a) recompute *content* at delivery (intake changed since scheduling), (b) re-check a *predicate* at delivery (don't fire if at goal / just logged / inactive), and (c) **log a drink from the notification without opening the app**. (a) and (b) force a code path that runs *at fire time*, which is exactly what a `BroadcastReceiver` triggered by an alarm gives us — content and predicate are computed in the receiver against live Room data, never pre-baked. (c) is a classic `PendingIntent`→`BroadcastReceiver`→Room write. WorkManager can't do (a)/(b) with the needed timing, so it's relegated to the jobs that don't need precision. This is the minimal design that satisfies C2 without a backend.

**Parity implication. This is the biggest parity risk in the whole app, and it is intrinsic, not a choice we can engineer away.** iOS and Android have *fundamentally different* local-notification models:
- **iOS** pre-schedules notifications with `UNUserNotificationCenter`, capped at **64 pending**, and recompute-at-delivery requires a Notification Service Extension (and even then only mutates *content*, not the fire predicate as freely).
- **Android** can recompute *everything* in a receiver at fire time but pays for it with **OEM-dependent delivery reliability**.

Net: **Android can make smarter last-millisecond decisions; iOS delivers more reliably but with staler content and a hard pending-count ceiling.** The *user-visible outcome* we standardise is the **behaviour spec in C2/notifications.md** (when a reminder fires, what it says, the quick-log action), implemented per-platform with the C4 shared formulas (D7) so the *numbers* match. What we *cannot* fully equalise is **exact delivery timing and reliability** — an Android user on an aggressive OEM may miss a nudge an iOS user would get, and vice-versa an iOS user may get a slightly stale recommended volume. This divergence must be **documented and accepted**, and is the top item for the validation pass to scrutinise.

**Phase-2 forward-constraint.** None. Local scheduling is independent of accounts/sync. If Phase 2 ever adds server-driven push, it layers on top without disturbing the local engine. Forward-note: the receiver already reads live Room state, so it will transparently honour synced preference changes once sync exists.

**Confidence & evidence.** **High on the API mechanics, medium on real-world reliability** (reliability is device/OEM-dependent and cannot be fully verified without a device-lab matrix). Verified: `SCHEDULE_EXACT_ALARM` denied-by-default from Android 14 and user-revocable; `USE_EXACT_ALARM` install-granted/non-revocable but **Play-policy-restricted to specific categories** ([exact alarms denied by default](https://developer.android.com/about/versions/14/changes/schedule-exact-alarms), [schedule alarms guide](https://developer.android.com/develop/background-work/services/alarms)); WorkManager 15-min periodic minimum and Doze-respecting behaviour, recommended for deferrable reliable work ([WorkManager releases](https://developer.android.com/jetpack/androidx/releases/work), [Doze & App Standby](https://developer.android.com/training/monitoring-device-state/doze-standby)). Notification channels mandatory since API 26; `POST_NOTIFICATIONS` runtime since API 33 — standard, well-documented.

---

## D5 — Charts: Vico

- **Status:** Proposed
- **Area:** charts
- **Constraint(s) addressed:** C3 (history bars + goal reference line + non-colour below-goal signal; BAC line chart with solid+dashed segments, red wash, now/cap reference lines, dual g/L + mmol/L axes), C5 (TalkBack accessibility)

**Decision.** Use **Vico** (`com.patrykandpatrick.vico:compose` + `:compose-m3`), a Compose-native, actively-maintained Cartesian chart library, for **both** the History bar charts and the Party BAC line chart. The bespoke parts of the BAC chart — the **dashed projected segment**, the **low-opacity red wash** behind the projection, the **"now" and cap reference lines**, and the **dual-axis** g/L (primary) + mmol/L (secondary) — are expressed via Vico's line styling (`DashPathEffect`), background/decoration layers, and its start/end axis API, dropping to a **Compose `Canvas` decoration** for the wash region if needed. We accept a single third-party dependency here because hand-rolling a full charting layer (axes, scaling, paging, tick selection) is disproportionate and bug-prone.

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| **Vico** | ✅ chosen | Compose-native, Cartesian-focused (exactly our chart set: bars + line), actively maintained (2.x), supports dashed lines via `DashPathEffect`, background shaders/decorations for the red wash, multi-axis for g/L + mmol/L, and custom Canvas escape hatches. |
| YCharts (`co.yml`) | ❌ rejected | Also Compose-native and maintained, broader chart types (pie/donut we don't need), but **less flexible line decoration**; expressing the dashed+wash+dual-axis combo is more of a fight than in Vico. Kept as fallback if Vico blocks. |
| Hand-rolled Compose `Canvas` | ❌ rejected *as the primary* | Total control (and we *will* use Canvas for the wash specifically), but rebuilding axis scaling, tick selection, weekly/monthly paging, and accessibility for *every* chart is a large, error-prone surface — not justified when Vico covers 90% and we can Canvas the last 10%. |
| MPAndroidChart | ❌ rejected | The classic library, but **View-based** (not Compose), interop-heavy, and effectively in low-maintenance mode; wrong fit for an all-Compose app. |

**Can the chosen approach actually express the hard BAC chart?** Yes, with a documented split:
- **Solid (past→now) + dashed (now→end) line:** Vico draws the line; the two segments are rendered as two line layers (or one line with a per-segment `DashPathEffect` applied to the projected x-range). **Verified** that Vico supports dashed lines via Canvas `DashPathEffect` in line specs.
- **Low-opacity red wash behind the projection:** drawn as a **background decoration** — either Vico's background shader clipped to the `x > now` region, or, as the reliable fallback, a Compose `Canvas` rectangle (≈8–10% red, per the brief) drawn *behind* the chart for the projected x-range. This is the one piece most likely to need the Canvas escape hatch; it is low-risk because it's a static rectangle keyed to the "now" x-coordinate.
- **"now" vertical line + cap horizontal dashed line:** Vico threshold/reference-line decorations.
- **Dual Y axis (g/L primary, mmol/L secondary):** Vico supports independent start and end axes; mmol/L = g/L × 21.7 is a pure axis relabel, so the secondary axis is the primary axis × 21.7.
- **X axis = 24h local time, rounded up to a tidy half-hour, auto tick spacing:** Vico value formatters + our own tick-step logic (from C3) feed it.

**Workaround stated honestly:** if Vico's clipped background shader proves awkward for the red wash, we draw the wash and the "now" line directly on a Compose `Canvas` layered behind the Vico chart, aligning x-coordinates via the chart's value→pixel mapping. This is a known, small amount of custom code, not a blocker.

**Accessibility (C3/C5).** Charts are read-only; the **non-colour below-goal signal** (a pattern/hatch or a marker on bars under the goal line) is drawn via Vico's per-bar styling or a Canvas overlay, and each chart carries a **content-description summary** for TalkBack (e.g. "Hydration per day, 5 of 7 days at goal") since per-bar screen-reader traversal in charts is limited.

**Rationale.** Vico is the only option that is simultaneously Compose-native, Cartesian-specialised (we need exactly bars + one line, no exotic chart types), actively maintained in 2026, and flexible enough to express the dashed/wash/dual-axis BAC chart with a small Canvas assist. It justifies its place as the **single** third-party dependency: the alternative (hand-rolling) is materially more code and risk for the same result.

**Parity implication.** iOS will use **Swift Charts**, a *different* library, so charts are re-implemented, not shared. Parity is enforced by the **C3 spec** (same series, same reference lines, same dual units, same dashed-projection + red-wash semantics) and the **C4 shared computation** that produces the *data points* (BAC curve, daily buckets) — identical inputs in, identical numbers out (D7). Visual styling parity (colours, dash pattern, wash opacity) is governed by `design-system.md`. The risk is cosmetic drift in tick placement / rounding; mitigated by specifying the tick algorithm once (C3) and implementing it in shared-spec terms.

**Phase-2 forward-constraint.** None. Charts are read-only views over local data; sync/accounts don't touch them.

**Confidence & evidence.** **Medium-High.** Vico's Compose-native, multiplatform, actively-maintained status and dashed-line capability are confirmed ([Vico GitHub](https://github.com/patrykandpatrick/vico), [Vico catalog](https://www.jetpackcompose.app/compose-catalog/vico), [dashed-line example](https://codepal.ai/code-generator/query/7gSOWWTA/create-dashed-line-chart-jetpack-compose-vico-library)). YCharts confirmed alive as fallback ([YCharts GitHub](https://github.com/codeandtheory/YCharts)). The one **assumption to validate in code** is the exact red-wash-behind-projection technique — confidence is high that the Canvas fallback works even if the Vico-native shader path doesn't, so the *outcome* is not at risk, only the cleanliness of the implementation. **Pin the Vico version** at integration time (2.x stable) and re-verify it isn't on an alpha track.

---

## D6 — SVG / vector icons with runtime two-shade tinting

- **Status:** Proposed
- **Area:** icons
- **Constraint(s) addressed:** C5 (two shades derived at render time from ONE `iconColor` via HSL ±15%, custom artwork not Material Symbols, crisp at 24–32px in a scrolling list)

**Decision.** Ship the drink artwork as **multi-path Android `VectorDrawable` / Compose `ImageVector`** assets (each icon = a silhouette path + an inner-detail path), and **tint the two paths per-instance at render time** from the single `iconColor`: compute `shadeA = iconColor` and `shadeB = HSL(iconColor) with lightness offset by ±15%`, then render the two paths with those two colours. In Compose this is done by building/overriding the `ImageVector`'s path colours from the runtime-computed pair (or by drawing the two paths in a `Canvas`/`VectorPainter` with explicit colours). **No SVG runtime library** (no AndroidSVG, no Coil-SVG). The HSL math lives in the shared `:core` module (D7) so iOS uses the identical formula.

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| **Compose-native vector rendering, two paths tinted per-instance** | ✅ chosen | The *only* approach that cleanly supports **two** shades from **one** colour at render time; vectors stay crisp at any px; no third-party dep; HSL offset is shared with iOS. |
| `VectorDrawable` + `setTint` / `tintList` | ❌ rejected | **Single-tint only** — `DrawableCompat.setTint` recolours the *whole* drawable one colour. Confirmed limitation; cannot produce two shades from one input without per-path manipulation (which is what the chosen option does, just in Compose). |
| Pre-baked two-tone PNG/asset variants | ❌ rejected | Violates C5 ("not pre-baked assets"); can't honour an arbitrary user-picked `iconColor`; multiplies asset count by every colour. |
| Coil-SVG / AndroidSVG runtime SVG | ❌ rejected | Adds a third-party dep whose Android renderer (`androidsvg`) is a documented rendering pain point; SVG decoding gives a single bitmap with **no per-instance two-shade tint hook** from one colour. Wrong tool. |
| Material Symbols | ❌ rejected | C5 explicitly requires **custom artwork**, single visual family, not Material Symbols. |

**How the two-shade tint works (for the non-Android reader).** A `VectorDrawable` is Android's equivalent of an inline SVG — XML paths the OS rasterises crisply at any size. Each drink icon is authored with **two named paths** (outer silhouette, inner detail). At render time we take the preset's one `iconColor`, derive a second colour by nudging its **HSL lightness by ±15%** (lighter inner detail or darker, per the brief), and paint path 1 with the base colour and path 2 with the derived colour. Because it's vector, it's pixel-sharp at 24–32px in the scrolling preset list (C5). The artwork is converted from the designer's SVGs to VectorDrawables once at build time (Android Studio's importer); the *tinting* is fully runtime and per-instance.

**Rationale.** C5's requirement is specifically **two shades from one colour value, at render time** — that rules out single-tint `VectorDrawable` and pre-baked assets, and an SVG library buys nothing because none of them expose a "split this into two paths and tint each from an HSL offset" primitive. Doing it in Compose with the vector paths we already control is the minimal, dependency-free, crisp-at-any-size answer, and it puts the colour math in shared code so it can't drift from iOS.

**Parity implication.** **High parity, by construction — if the HSL math is shared.** The exact same `iconColor → (shadeA, shadeB)` transform must run on both platforms; otherwise the two-tone icons subtly differ. Mitigation: the **HSL ±15% offset is a C4-class pure function in `:core`** (D7), verified against shared fixtures (sample `iconColor` → expected two output hexes). iOS implements the identical formula. Vector artwork itself is the *same source SVGs* converted per-platform (VectorDrawable on Android, SF-importable/SwiftUI `Path` on iOS), governed by `design-system.md`.

**Phase-2 forward-constraint.** None. Icons are pure presentation; `iconKey`/`iconColor` are already snapshotted onto entries (C1) and sync as plain strings.

**Confidence & evidence.** **High.** `VectorDrawable` single-tint limitation and the per-path programmatic workaround are confirmed ([Android: tint vector with two+ colours](https://www.androidbugfix.com/2022/06/android-how-to-set-tint-on-vector.html), [VectorDrawable reference](https://developer.android.com/reference/android/graphics/drawable/VectorDrawable)); Coil-SVG's reliance on `androidsvg` and its rendering-pain-point reputation confirmed ([Coil SVG docs](https://coil-kt.github.io/coil/svgs/), [renderer discussion](https://github.com/coil-kt/coil/issues/3090)). The exact Compose API for overriding individual `ImageVector` path colours per-instance is an **implementation detail to pin during the spike** (override path `fill`/`SolidColor` when building the vector, or draw via `VectorPainter`/`Canvas`) — confidence is high that one of these works since both are standard Compose drawing; flagged as the one thing to prototype first.

---

## D7 — Shared computation strategy (Android side)

- **Status:** Proposed
- **Area:** shared-computation
- **Constraint(s) addressed:** C4 (BAC, pace/recommended-volume, username validation incl. NFC + Unicode categories, day-boundary bucketing; verified against shared test vectors), plus the D6 HSL tint

**Decision.** Put **every C4 pure algorithm in a standalone `:core` Gradle module** — plain Kotlin, **no Android UI/Room dependencies**, deterministic, side-effect-free. It exposes: BAC estimation (grams→Watson/Widmark→meal modifier→elimination→summation, g/L canonical, mmol/L = ×21.7), pace/expected-intake and recommended-volume (0.5-glass, clamp 0.5–2.0), username validation (Unicode `L*`/digits/`_-.` whitelist + structural rules + **NFC normalisation**), day-boundary bucketing + 7-day aggregates, and the D6 HSL ±15% tint transform. The module is driven by a **shared cross-platform fixtures file** (the worked examples in `party-session.md` — e.g. the **0.362 g/L** two-beer sanity check — become canonical JSON test vectors), and the Android JUnit tests assert against those same vectors the iOS tests use. For Unicode, use **`android.icu`** APIs (available API 24+, comfortably under our `minSdk 26`) for category checks and NFC, **not** `java.lang.Character`.

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| **Pure-Kotlin `:core` module + shared JSON fixtures, `android.icu` for Unicode** | ✅ chosen | Isolates the highest parity-risk code, makes it trivially unit-testable against the *same* vectors as iOS, no Android coupling, NFC/categories from a known-versioned ICU. |
| Algorithms inline in ViewModels/repositories | ❌ rejected | Buries parity-critical math next to UI/IO, hard to test in isolation, invites drift and accidental Android-API coupling. |
| Kotlin Multiplatform shared with iOS (one source) | ❌ rejected | **Violates C0** ("no shared application codebase"). We share *specifications and test vectors*, not source. |
| `java.lang.Character.getType` for Unicode categories | ❌ rejected | Its category numbering **differs from ICU** and its Unicode-version coverage lags; using `android.icu` keeps Android aligned with a known ICU/CLDR version and reduces cross-platform category-edge drift. |

**Rationale.** C4 is explicitly *"the highest parity risk surface"* and demands bit-for-bit-comparable outputs. The only robust way to guarantee that is to (1) isolate the math so nothing platform-specific can leak in, and (2) **test both platforms against one set of fixtures**. A pure module makes both cheap. The worked examples already in the design docs are gifts — they become the fixtures, so the spec, the iOS test, and the Android test all check the same numbers. Floating-point determinism is a real concern (BAC chains several multiplies/exponentials): we pin the **order of operations** and **rounding points** in the spec (e.g. round recommended volume to nearest 0.5 *after* the deficit calc; keep BAC in `Double` g/L and only convert to mmol/L at display) so both platforms round at the same places.

**Unicode/ICU availability concern (called out per the brief).** Username rules need Unicode **general-category** classification (`L*`, reject `Cc/Cf/Cs/Co/Cn/Mn/Mc/So/Sk`) and **NFC** normalisation. On Android this is best served by **`android.icu.*`** (`UCharacter.getType`, `Normalizer2.getNFCInstance()`), exposed since **API 24** — safely below our `minSdk 26`. Two honest caveats: (a) **`android.icu`'s category constants differ from `java.lang.Character`'s** (e.g. value 17 skipped), so the validator must consistently use the ICU enum, matching what iOS's ICU does; and (b) **the bundled ICU/CLDR version advances with each Android release**, so a brand-new code point assigned in a newer Unicode version could classify differently on an old vs new device — a negligible edge for a 3–30 char username whitelist, but documented. iOS's Foundation also rides ICU; pinning the *rule* (which categories are allowed) rather than relying on identical ICU versions keeps them aligned.

**Parity implication.** **This module is the primary parity-enforcement mechanism for C4.** Same inputs → same outputs is *verified*, not hoped: both platforms run the shared fixtures in CI-equivalent test suites. Residual risks are floating-point edge cases (mitigated by pinned op-order/rounding) and ICU version skew (mitigated by pinning the rule set). Everything else flows from one specification.

**Phase-2 forward-constraint.** None — these are pure functions independent of sync. Forward-benefit: when Phase 2 syncs data across devices, a synced record recomputes to the *same* derived values on any device because the algorithm is shared-spec'd and deterministic.

**Confidence & evidence.** **High.** `android.icu` (subset of ICU4J) available from API 24 with `UCharacter`/`Normalizer2`, and the ICU-vs-`Character.getType` category mismatch and per-release ICU/CLDR versioning are confirmed ([Android i18n support](https://developer.android.com/guide/topics/resources/internationalization), [UCharacter](https://developer.android.com/reference/android/icu/lang/UCharacter), [android.icu Normalizer](https://developer.android.com/reference/android/icu/text/Normalizer)). The "pure module + shared fixtures" pattern is standard practice; flagged as the single most important thing to get right for parity.

---

## Dependency manifest

The guiding rule (per the brief): **first-party AndroidX by default; every third-party dependency justified against a constraint.** The result is exactly **one** non-AndroidX runtime dependency (Vico).

| Dependency | Version (verify at integration) | First-party? | Justification |
| ---------- | ------------------------------- | ------------ | ------------- |
| `androidx.compose:compose-bom` | `2026.04.01` | ✅ AndroidX | UI toolkit (D1). Pins all Compose artifact versions. |
| `androidx.compose.material3:material3` | via BOM (stable, **not** expressive/adaptive alpha) | ✅ AndroidX | Design-system base components (D1, C5). |
| `androidx.navigation3:*` (Navigation 3) | `1.1.1` | ✅ AndroidX | 3-tab nav + back stack (D2, C5). Stable as of April 2026. |
| `androidx.lifecycle:lifecycle-viewmodel-compose` + `runtime-compose` | latest stable | ✅ AndroidX | ViewModel/StateFlow + lifecycle-aware collection (D2). |
| `androidx.room:room-runtime` + `room-compiler` (KSP) | `2.8.4` | ✅ AndroidX | Persistence, migrations, transactions (D3, C1). Stay on stable 2.x; defer the room3 package move. |
| `androidx.work:work-runtime-ktx` (WorkManager) | latest stable 2.x | ✅ AndroidX | Slack-tolerant periodic jobs: daily reschedule sweep, weekly summary, noon inactivity (D4, C2). |
| `org.jetbrains.kotlinx:kotlinx-coroutines-*` | latest stable | ✅ (Kotlin/JetBrains, foundational) | Coroutines/Flow underpinning async + StateFlow (D2). Effectively part of the Kotlin baseline. |
| **`com.patrykandpatrick.vico:compose` + `:compose-m3`** | **2.x stable (pin at integration; reject if alpha)** | ❌ **third-party** | **Charts (D5, C3).** Justified: hand-rolling axes/scaling/paging/dual-axis for the history bars *and* the dashed-projection BAC line is disproportionate and bug-prone; Vico is Compose-native, Cartesian-specialised, and actively maintained. The single third-party runtime dep. |
| `android.icu.*` | platform (API 24+) | ✅ platform | Unicode category + NFC for username validation (D7, C4). No artifact — part of the OS. |

**Test-only (not shipped in the app):**

| Dependency | Justification |
| ---------- | ------------- |
| `androidx.room:room-testing` (`MigrationTestHelper`) | Test every schema migration old→new (D3). |
| JUnit + (optional) `kotlinx-serialization-json` for fixtures | Run the shared C4 test vectors against `:core` (D7). |

Deliberately **excluded** in Phase 1: Hilt/Dagger (manual DI suffices, D2), Coil-SVG/AndroidSVG (D6), Realm/SQLDelight (D3), MPAndroidChart/YCharts (D5), Firebase/FCM and **any** analytics/crash-reporting SDK (forbidden by C0). No networking library of any kind ships in Phase 1.

---

## Risks & open questions

1. **Background-notification reliability is the headline risk and the top parity divergence (D4).** Even with correct exact-alarm + Doze-aware code, **OEM battery managers** (Xiaomi, Huawei, Samsung, OnePlus, Oppo, etc.) can freeze or kill a backgrounded app and silently drop reminders, and **App Standby** deprioritises rarely-opened apps. We *cannot* guarantee minute-accurate delivery across the device fleet. iOS's pre-scheduled model is more reliably delivered but has the 64-pending ceiling and staler delivery-time content. **Net: the two platforms will not have identical reminder reliability/timing.** Validation must accept this as an inherent divergence, and product should treat a missed nudge as non-fatal. *Open:* do we add the optional "ignore battery optimisations" prompt, and where in the UX? Do we want an internal **device-lab reliability matrix** (top OEM skins) before shipping, given C6 forbids telemetry that would otherwise surface failures in the field?

2. **Exact-alarm permission posture (D4).** A hydration app likely **does not qualify for `USE_EXACT_ALARM`** under Play policy. The plan relies on `SCHEDULE_EXACT_ALARM` (user-revocable, denied-by-default on 14+) with **graceful inexact fallback**. *Open:* confirm with Play policy that we *don't* claim `USE_EXACT_ALARM` (claiming it without qualifying risks rejection), and confirm product is fine with inexact-by-default timing.

3. **No telemetry + reliability-critical background work (C6 ∩ D4).** Because C0/C6 forbid crash/analytics reporting, we have **no field signal** when reminders silently fail. All reliability validation must happen **pre-release via internal testing**. *Open:* what's the internal-testing matrix and pass bar?

4. **Floating-point determinism for C4/BAC parity (D7).** Multi-step BAC math (Watson/Widmark → meal `exp()` decay → elimination → summation) can diverge between Kotlin `Double` and Swift `Double` at ULP level if op-order or rounding points differ. *Open:* finalise the spec's pinned operation order and rounding boundaries, and add fixtures at the rounding edges (e.g. recommended-volume exactly on a 0.25-glass boundary; BAC just above/below a cap-80% threshold).

5. **ICU version skew for usernames (D7).** Android's bundled ICU/CLDR advances per OS release; a code point newly assigned in a later Unicode version could classify differently on an old vs new device, and `android.icu` category constants differ from `java.lang.Character`. Low practical impact for a 3–30 char whitelist, but the validator must use `android.icu` consistently and the *rule set* (not a specific ICU version) is the contract. *Open:* pin the exact allowed/denied category list as a shared fixture so iOS and Android agree independent of ICU build.

6. **BAC red-wash + dashed-projection in Vico (D5).** High confidence the *outcome* is achievable (Canvas fallback always works), but the cleanest implementation (Vico-native clipped background shader vs Compose Canvas overlay) is unproven until the spike. *Open:* prototype the BAC chart first to confirm the wash technique and pin the Vico version (reject if only alpha is available).

7. **Compose path-colour override for two-shade icons (D6).** The exact API to set the two `ImageVector` path colours per-instance at runtime needs a quick spike (override `SolidColor` fills when building the vector, or draw via `VectorPainter`/`Canvas`). Outcome low-risk; pick the cleanest API early. *Open:* validate it stays crisp and cheap when 10–20 tinted icons scroll in the preset list.

8. **Room 2.x maintenance mode vs Room 3.0 (D3).** We intentionally ship on stable **2.8.x**; **Room 3.0** lives in a new package (`androidx.room3`). *Open:* note the eventual (mechanical) package migration as Phase-2-era tech-debt; it's additive, not destructive.

---

### Sources

- [Google Play target API level requirements](https://developer.android.com/google/play/requirements/target-sdk) · [Play target-API help](https://support.google.com/googleplay/android-developer/answer/11926878)
- [Schedule exact alarms denied by default (Android 14)](https://developer.android.com/about/versions/14/changes/schedule-exact-alarms) · [Schedule alarms guide](https://developer.android.com/develop/background-work/services/alarms) · [Doze & App Standby](https://developer.android.com/training/monitoring-device-state/doze-standby) · [WorkManager releases](https://developer.android.com/jetpack/androidx/releases/work)
- [Jetpack Compose April '26 release](https://android-developers.googleblog.com/2026/04/jetpack-compose-april-2026-updates.html) · [Compose BOM mapping](https://developer.android.com/develop/ui/compose/bom/bom-mapping) · [Navigation 3](https://androidengineers.substack.com/p/navigation-3-the-future-of-android)
- [Room releases](https://developer.android.com/jetpack/androidx/releases/room) · [Room 3.0 blog](https://android-developers.googleblog.com/2026/03/room-30-modernizing-room.html) · [Room KMP setup](https://developer.android.com/kotlin/multiplatform/room)
- [Vico GitHub](https://github.com/patrykandpatrick/vico) · [Vico catalog](https://www.jetpackcompose.app/compose-catalog/vico) · [Vico dashed-line example](https://codepal.ai/code-generator/query/7gSOWWTA/create-dashed-line-chart-jetpack-compose-vico-library) · [YCharts GitHub](https://github.com/codeandtheory/YCharts)
- [VectorDrawable two-colour tint limitation](https://www.androidbugfix.com/2022/06/android-how-to-set-tint-on-vector.html) · [VectorDrawable reference](https://developer.android.com/reference/android/graphics/drawable/VectorDrawable) · [Coil SVG decoder](https://coil-kt.github.io/coil/svgs/) · [Coil SVG renderer issue](https://github.com/coil-kt/coil/issues/3090)
- [Android internationalization support](https://developer.android.com/guide/topics/resources/internationalization) · [android.icu UCharacter](https://developer.android.com/reference/android/icu/lang/UCharacter) · [android.icu Normalizer](https://developer.android.com/reference/android/icu/text/Normalizer)
