# iOS Native Stack — Phase 1 Decision Record

> ⚠️ **SUPERSEDED by [flutter-stack.md](./flutter-stack.md).** Drinks Mate is now a single Flutter codebase, not two native apps. This doc is **retained as platform research**: its findings on iOS notification limits — the service extension being push-only (no at-delivery recompute for local notifications), the 64-pending ceiling, and the rolling-window re-arm pattern — are **framework-independent and still inform the Flutter notification design** (see flutter-stack.md → D4). Read the persistence/charts/icon/architecture decisions as historical context, not the chosen stack.

> **Audience note.** This is written for a lead who knows frontend/backend patterns but is *not* an iOS specialist. iOS-specific concepts are explained inline. Where a choice has an Android counterpart, the parity implication is called out explicitly — the two apps share *specifications and data semantics, not source* (see [README → parity contract](../README.md)).

## Summary

Phase 1 of Drinks Mate on iOS should be built as a **SwiftUI-first app targeting iOS 18.0**, using **Apple-native frameworks almost everywhere** and a **single, well-justified third-party dependency: GRDB.swift** for persistence. The deciding factors are the persistence constraints (C1) — first-class **migrations** and **Phase-2 sync-readiness** — where Apple's SwiftData is still too opinionated and migration-fragile for a schema we *know* will churn, and a raw-SQLite toolkit (GRDB) gives us explicit control over UUID keys, soft-delete, transactional writes, and date-range queries keyed off a configurable day boundary. The highest-risk area is **local notifications** (C2): iOS schedules notifications *ahead of time* and — critically — **`UNNotificationServiceExtension` does not work for local notifications** (remote-push only, confirmed against Apple docs), so "recompute recommended volume at delivery" cannot be done the way the design's platform note hopefully suggests. We solve this with a **rolling-window scheduler re-armed on every app foreground/log**, conditional content baked at schedule time, and a defensive accept-the-staleness strategy for the gap. Charts use **Swift Charts** (Apple-native, expresses everything the design needs including the dashed projected segment and red wash; dual-axis g/L + mmol/L needs the standard normalized-overlay workaround). Drink-icon two-shade tinting is done **without an SVG runtime library** — the live SVG renderers are either abandoned (SVGKit, last release 2021) or heavy; instead we ship each icon as two template layers and compute the two HSL shades at render time in Swift. Shared pure algorithms (C4) are isolated in a dependency-free `DrinksKit` Swift module verified against cross-platform JSON test vectors.

### Decisions at a glance

| # | Area | Decision | Key dependency | Confidence |
|---|------|----------|----------------|------------|
| D1 | UI framework | SwiftUI-first, min target **iOS 18.0**; UIKit only via representable escape hatches | none (first-party) | High |
| D2 | Architecture / state | Native **Observation** (`@Observable`) + lightweight MV/MVVM. **No TCA, no Redux clone.** | none (first-party) | High |
| D3 | Persistence | **GRDB.swift 7.x** (SQLite toolkit). SwiftData/Core Data/Realm rejected. | GRDB.swift | High |
| D4 | Local notifications | `UNUserNotificationCenter` + **rolling-window re-arming scheduler**; content baked at schedule time (service extension is NOT available for local notifs) | none (first-party) | High |
| D5 | Charts | **Swift Charts**; dual axis via normalized-overlay workaround | none (first-party) | High |
| D6 | Drink-icon tinting | **No SVG runtime lib.** Two template layers per icon + app-computed HSL ±15% shades | none (first-party) | Medium-High |
| D7 | Shared computation | Dependency-free `DrinksKit` module, verified against shared JSON fixtures | none (first-party) | High |

---

## D1 — UI framework: SwiftUI-first, min target iOS 18.0

- **Status:** Proposed
- **Area:** architecture / design-system
- **Constraint(s) addressed:** C5 (design system, dark mode, dynamic type, accessibility), C6 (two-taps-to-log, instant optimistic UI), enables C3/C2.

**Decision.** Build the app in **SwiftUI**, with **iOS 18.0** as the minimum deployment target. Drop to UIKit only behind `UIViewRepresentable`/`UIViewControllerRepresentable` for the rare control SwiftUI can't express well (none anticipated in Phase 1). No storyboards, no XIBs.

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| SwiftUI-first, iOS 18 min | ✅ chosen | Native dark mode + Dynamic Type + VoiceOver wiring, declarative optimistic UI, matches Compose on Android for structural parity |
| UIKit-first | ❌ rejected | More boilerplate for the exact things C5/C6 need (state-driven UI, accessibility, dark mode); slower to reach two-taps-to-log; diverges structurally from the Compose Android app |
| Hybrid (UIKit shell + SwiftUI screens) | ❌ rejected | No Phase 1 screen needs a UIKit container; adds complexity for nothing |
| iOS 17 min | ⚠️ considered | Would broaden reach slightly but buys nothing we need; iOS 18 is the modern Observation/Charts baseline |
| iOS 26 min | ❌ rejected | Too aggressive; needlessly excludes the ~14% still on iOS 18 |

**Rationale.** Every load-bearing C5 requirement — light/dark mode following the system, Dynamic Type at every size, VoiceOver end-to-end, calm ease-in-out motion with a reduce-motion fallback — is *first-class and low-effort in SwiftUI* and *manual and verbose in UIKit*. C6's "instant, optimistic, no spinner" logging is a natural fit for SwiftUI's state-driven re-render. **iOS 18** is chosen because (a) as of June 2026 iOS 26 is on ~79% of devices and iOS 18 on ~14%, so an iOS 18 floor reaches essentially the whole active base; (b) it gives a clean, mature **Observation** baseline (`@Observable`, see D2) without iOS 17's first-generation rough edges; and (c) Swift Charts (iOS 16+) and our persistence choice (GRDB, iOS 13+) both comfortably clear it, so the floor is driven by *platform maturity*, not by a single dependency. We deliberately do **not** let SwiftData dictate an iOS 17 floor, because we are not using it (D3).

**Parity implication.** SwiftUI ↔ Jetpack Compose are both declarative, state-driven UI toolkits — choosing SwiftUI keeps the *structure* of the two codebases analogous (view = function of state), which makes behavioural-parity review tractable. Visual parity is enforced separately by the shared design system (DM Sans on both, shared hex palette, custom icon family) — see `design-system.md`. The framework choice itself does not threaten parity.

**Phase-2 forward-constraint.** None. SwiftUI accommodates the Phase-2 account/sync/social surfaces without rework.

**Confidence & evidence.** High. iOS adoption figures from TelemetryDeck / Statista / MacRumors (June 2026: iOS 26 ≈79%, iOS 18 ≈14%). Swift Charts min iOS 16, SwiftData min iOS 17, GRDB min iOS 13 confirmed via vendor/Apple docs. SwiftUI's accessibility/dark-mode/Dynamic-Type support is long-established and first-party.

---

## D2 — App architecture / state management: native Observation, no framework

- **Status:** Proposed
- **Area:** architecture
- **Constraint(s) addressed:** C6 (instant optimistic UI), supports all of C0–C5.

**Decision.** Use Apple's **Observation** framework (`@Observable` model types, `@State`/`@Environment` for ownership) with a **lightweight MV / thin-MVVM** layering: SwiftUI views observe `@Observable` "store"/"model" objects that wrap the repositories (GRDB DAOs from D3). **No third-party architecture dependency** — specifically **no TCA (The Composable Architecture), no Redux/Elm clone, no RxSwift/Combine-heavy stack.**

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| Observation + light MV/MVVM | ✅ chosen | Proportionate to a 7-screen single-user offline app; zero dependency; native, testable |
| TCA (pointfree) | ❌ rejected | Powerful but heavyweight; large dependency + learning curve + boilerplate unjustified at this app size; would also diverge hard from Android's idioms |
| MVVM + Combine everywhere | ❌ rejected | Combine adds ceremony; Observation supersedes most of its UI-binding role on iOS 18 |
| Massive-View / no layering | ❌ rejected | Hurts testability of the C4 algorithms and the optimistic-update paths |

**Rationale.** The app is single-user, offline, 7 screens, append-mostly data. That is *not* a problem space that earns a formal unidirectional-data-flow framework. Observation gives precise, automatic view updates (so the C6 optimistic log — write to DB, model mutates, bar animates, no spinner — is a few lines) while keeping business logic in plain, unit-testable types. Pulling in TCA would add a substantial dependency and a paradigm that must be justified against a constraint — and none of C0–C6 demands it. The "minimal dependency footprint" instruction in the constraints points the same way.

**Parity implication.** Android's recommended idiom is ViewModel + StateFlow + Compose. SwiftUI Observation + thin view-models is the close structural analogue. Keeping both apps on their *native, idiomatic* state pattern (rather than forcing an exotic shared paradigm) is what the parity contract asks for: same user-visible behaviour, native means. The shared-behaviour guarantee comes from D7 (shared algorithm fixtures), not from matching the state framework.

**Phase-2 forward-constraint.** None. Sync in Phase 2 is a repository-layer concern (a sync engine feeding the same GRDB store); the Observation/view layer is unaffected because views already observe repositories, not the network.

**Confidence & evidence.** High. Observation (`@Observable`) is a stable first-party framework (iOS 17+, mature on 18). The proportionality argument is a judgement call, but a well-established one for apps of this scope.

---

## D3 — Local persistence: GRDB.swift (SQLite toolkit)

- **Status:** Proposed
- **Area:** persistence
- **Constraint(s) addressed:** C1 (all of it), C0 (local source of truth, offline-first, no Phase-2 scaffolding), C4 (date-range/day-boundary queries).

**Decision.** Use **GRDB.swift (v7.x)** — a typed Swift toolkit over SQLite — as the local store. Model UUID string PKs, `createdAt`/`updatedAt`/`deletedAt` columns, money as integer minor units, all-metric storage, and the `partySessionId` FK directly in SQL via GRDB's `DatabaseMigrator`. **Reject SwiftData, Core Data, and Realm.**

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| **GRDB.swift 7.x** | ✅ chosen | Migrations are an explicit, ordered, code-reviewable first-class API; full SQL control over UUID PKs, soft-delete filters, date-range/day-boundary queries; transactional writes; sync-ready; actively maintained |
| SwiftData | ❌ rejected | Migration story (`SchemaMigrationPlan`/`VersionedSchema`) still the framework's weakest, history-fragile area; opaque store; would force iOS 17 floor; risk for a schema we *know* will churn hard in Phase 2 |
| Core Data | ❌ rejected | First-party and capable, but heavyweight `.xcdatamodeld` + mapping-model migrations are clumsier than GRDB's linear migrator; UUID-PK + soft-delete-everywhere ergonomics are worse; more friction for the cross-platform-parity SQL semantics |
| Realm | ❌ rejected | Now MongoDB/Atlas Device SDK; future stewardship uncertain post-Atlas-Device-Sync deprecation messaging; heavier object-DB model; pulls toward a sync stack we explicitly must *not* ship in Phase 1 |
| Raw SQLite C API | ❌ rejected | Reinvents what GRDB already gives safely (typed records, migrator, concurrency) |

**Rationale.** C1 names **migrations and sync-readiness as the deciding factors, weighted heavily** — and that is exactly where GRDB wins. GRDB's `DatabaseMigrator` is an explicit, ordered list of named migrations applied in sequence; adding a Phase-2 field/entity is a new migration block, fully diff-reviewable, with no hidden inference. Compare SwiftData, where schema evolution goes through `VersionedSchema` + `SchemaMigrationPlan` and **custom (data-reshaping) migrations remain the framework's most fragile, least-transparent surface** — a poor bet for a schema the design *guarantees* will churn (Phase 2 adds `Account`, `Friendship`, `ShareSetting`, sync fields, and more). GRDB also lets us express the C1 specifics cleanly: UUID text PKs, a `deletedAt IS NULL` filter baked into every UI query, transactional `write {}` blocks so a partial edit can never persist, and **date-range queries keyed off the configurable 05:00 day boundary** as plain parameterised SQL (the day-window math lives in `DrinksKit`, D7, and feeds the `WHERE consumedAt >= ? AND consumedAt < ?` bounds). Because it is "just SQLite," nothing about Phase-2 sync (a delta/LWW engine over `updatedAt`, propagating soft-deletes via `deletedAt`) is blocked — the design's whole data model was authored to be added-to without a destructive migration, and a transparent SQL store is the safest substrate for that. It is the *one* third-party dependency we take, and it is justified directly against the most heavily-weighted constraint.

**Parity implication.** **Strong positive.** Android's recommended store is **Room**, which is *also* SQLite with first-class migrations. GRDB ↔ Room means **both platforms persist to the same engine (SQLite) with the same logical schema, the same UUID keys, the same soft-delete and `updatedAt` semantics, and analogous explicit-migration mechanisms.** This is the lowest-risk possible parity posture for persistence: the two stores will behave identically for date-range queries, day-boundary bucketing, and snapshot immutability. (Had iOS used SwiftData and Android used Room, we'd be reconciling an opaque object store against a SQL store — a real divergence risk. GRDB removes it.)

**Phase-2 forward-constraint.** **Keeps Phase 2 fully open.** UUID PKs are the future cross-device key; `updatedAt` is the LWW basis; `deletedAt` propagates deletions without separate tombstones — exactly as `technical-architecture.md → Sync model` requires. A sync engine is added *above* GRDB later; no destructive migration. **Guardrail:** the Phase-2-only entities (`Account`, `Friendship`, `ShareSetting`) must **not** appear in any Phase 1 migration (C0/C1).

**Confidence & evidence.** High. GRDB is actively maintained — latest release v7.11.x as of June 2026 (Swift Package Index / GitHub releases), 8.5k★, ongoing cross-platform (Android/Linux/Windows) work; min iOS 13, Swift 6.1+. SwiftData migration fragility corroborated by multiple 2026 practitioner write-ups (Michael Tsai's blog, "SwiftData in Production" Medium) and Apple's own WWDC25 "schema migration" session existing precisely because it's hard. Realm = Atlas Device SDK status confirmed via MongoDB's product direction.

---

## D4 — Local notifications: UNUserNotificationCenter + rolling-window re-arming scheduler

- **Status:** Proposed
- **Area:** notifications
- **Constraint(s) addressed:** C2 (all of it).

**Decision.** Use Apple's **`UNUserNotificationCenter`** with local `UNCalendarNotificationTrigger`/`UNTimeIntervalNotificationTrigger`s. Implement a **rolling-window scheduler** that keeps at most a small batch of upcoming notifications pending and **re-arms the whole window on every app foreground, every drink log, every settings change, and every notification delivery** (via the app-launched-from-action path). The quick-log action uses a **notification category + action** that runs in the background. **Critically: do NOT plan on a notification service extension to recompute content at delivery — it is not available for local notifications** (Apple: service extensions modify *remote* notifications only). Content is therefore **baked at schedule time** and the staleness gap is managed by keeping the window short and re-arming aggressively.

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| `UNUserNotificationCenter` + rolling window, content baked at schedule time | ✅ chosen | Only viable local-only design; respects the 64 ceiling; re-arming makes baked content "fresh enough" |
| Notification **service** extension to recompute volume at delivery | ❌ rejected (not possible) | `UNNotificationServiceExtension` fires **only for remote push with `mutable-content:1`** — it never runs for local notifications. Phase 1 has no push backend. Confirmed in Apple docs. |
| Schedule the whole day/month up front | ❌ rejected | Blows the **64-pending ceiling** (system keeps soonest 64, silently drops the rest) and bakes content that's hours/days stale |
| Background task (BGTaskScheduler) to refresh content just-in-time | ⚠️ partial / unreliable | iOS gives no guaranteed wake immediately before a notification fires; can't be relied on for "recompute at delivery." Usable only as an opportunistic top-up, not the mechanism |

**Rationale — this is the highest-risk area, so concretely:**

*The core iOS reality.* iOS local notifications are **scheduled ahead of time**; the OS fires them even if the app is killed. There is **no on-device hook that runs your code at the moment a *local* notification delivers** (the service extension is push-only). So the design's hopeful platform note ("recompute the recommended volume at delivery, e.g. via a notification service extension") **cannot be implemented as written for a no-backend Phase 1.** We must instead make the *scheduled* content correct enough and refresh it often.

*Rolling-window scheduler.* On every trigger point (app foreground, any drink log including the quick-log action, settings change), we:
1. Cancel all pending hydration/inactivity reminders we own (keep weekly-summary separate).
2. Recompute "now," today's intake, goal, pace deficit, and the recommended volume **using the live DB** (the C4 pace formula in `DrinksKit`, D7).
3. Schedule the **next N reminders only** (e.g. N ≈ 8–16: enough to cover a likely period of app-closure, far under the 64 ceiling), at `interval` spacing inside active hours, each carrying content computed for *its own* expected fire time, plus the inactivity-noon and Sunday-20:00 weekly entries.
4. Re-arm fully next time the app is touched.

Because logging a drink resets the timer *and* re-arms the window, the common case (user opens app, logs, leaves) always reschedules with fresh content. The only staleness window is "user neither opened the app nor logged for several reminder intervals" — and the recommended-volume drift there is small and self-correcting (the next reminder, computed from live intake, fixes it). This is the honest, documented limitation.

*The 64-pending ceiling.* Keeping N small (≪64) and re-arming on every interaction means we never approach the cap; we treat the cap as a hard guardrail, not a target.

*Anti-spam / conditional firing — the hard part.* Because content/fire-time is baked, the "suppress if already at goal / just logged / 7-days-inactive" predicates must be **enforced at re-arm time, not at fire time** (since we can't run code at local-fire). The strategy:
- **At-goal / just-logged / pace:** every drink log re-arms the window and, when intake crosses the goal, **cancels all remaining same-day hydration + inactivity reminders** outright. So a notification that *would* be wrong never remains pending. The "≥ interval since last log" rule is satisfied structurally because the post-log re-arm sets the next fire to `lastLog + interval`.
- **7-day inactivity:** computed at every re-arm as `days_inactive = floor((now − max(lastLog.consumedAt, installedAt)) / 1 day)`. If ≥ 7 we schedule nothing. **Residual edge case:** a user who silently crosses the 7-day mark *without opening the app* may still have up-to-N pre-scheduled notifications in the queue that fire. We mitigate by keeping N small and by scheduling **no notification whose own fire time is ≥ 7 days past last engagement** (we can compute that bound at schedule time). This bounds the leak to at most the window length, which is acceptable and should be flagged for validation.
- **At-most-once (inactivity/day, weekly/week):** enforced by scheduling exactly one calendar trigger per period and de-duping at re-arm.

*Quick-log action without opening the app.* Define a `UNNotificationCategory` with a `UNNotificationAction` (options **not** `.foreground`) titled e.g. "Log water · 200 ml". Handling it in `UNUserNotificationCenterDelegate`'s `didReceive` writes a `DrinkEntry` for `defaultDrinkPresetId` directly to GRDB, then re-arms the window — all in the background. (If `defaultDrinkPresetId` is missing per the data-model fallback, the action is omitted and we fall back to the seeded water preset / disable the action, per `UserPreferences` spec.)

*Lock-screen BAC visibility.* Map `bacOnLockScreenEnabled` to the notification's `interruptionLevel`/content: when ON, BAC renders in the body; when OFF, set the Party-Mode notification's content so the sensitive value is omitted from the visible body (iOS doesn't expose Android's per-notification "private visibility" identically, so we achieve the same *user-visible outcome* by **withholding the BAC string from the body** rather than relying on an OS redaction flag). This is a deliberate, documented divergence in mechanism, identical in outcome.

*Permission-optional.* Request authorization before scheduling; if declined, the app is fully functional, Settings shows the missing permission and deep-links to `UIApplication.openNotificationSettingsURLString`.

**Parity implication.** **Mechanism diverges, outcome must not.** Android recomputes content *at delivery* in an `AlarmManager`/`WorkManager` broadcast receiver — it genuinely *can* refresh recommended volume the moment the notification fires. iOS **cannot** (no local-delivery hook). The user-visible consequence: on iOS the recommended-volume number can be slightly staler than on Android in the rare "app untouched for hours" case. We close the gap behaviourally — both platforms use the **same `DrinksKit` pace/recommended-volume algorithm (D7)** and the same firing predicates; iOS just evaluates them at re-arm instead of at fire. **This is the single biggest deliberate iOS/Android divergence in Phase 1 and the top item for the validation pass to scrutinise.** Lock-screen BAC hiding is a second, smaller mechanism divergence (withhold-from-body vs OS private-visibility) with identical outcome.

**Phase-2 forward-constraint.** None that blocks. If Phase 2 ever adds a push backend, a *real* service extension could then do true at-delivery recompute — but nothing in this Phase 1 design prevents or complicates that.

**Confidence & evidence.** High on the constraints, High on the limitation. The service-extension-is-push-only fact and the 64-pending ceiling are both confirmed against Apple's official documentation (UNNotificationServiceExtension page; UNUserNotificationCenter "system keeps soonest-firing 64" note). The rolling-window re-arm pattern is the standard community solution to both.

---

## D5 — Charts: Swift Charts

- **Status:** Proposed
- **Area:** charts
- **Constraint(s) addressed:** C3 (history bar charts + BAC line chart), C5 (non-colour signal, accessibility).

**Decision.** Use **Swift Charts** (Apple, iOS 16+) for both the History bar charts and the Party BAC line chart. Express the BAC chart's **solid past + dashed projected segments** as two `LineMark` series with different `lineStyle`; the **low-opacity red wash** behind the projection as a `RectangleMark` (or `RuleMark`-bounded area) on the plot region right of "now"; the **"now"** and **cap** lines as `RuleMark`s. Implement **dual-axis g/L + mmol/L** via the standard normalized-overlay workaround (Swift Charts has no native secondary Y axis).

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| Swift Charts | ✅ chosen | First-party, expresses every C3 element; great accessibility (audio graphs/VoiceOver) out of the box; zero dependency |
| DGCharts / Charts (Daniel Gindi) | ❌ rejected | Capable but a large UIKit-era dependency; unjustified when Swift Charts covers the spec |
| Hand-rolled Canvas/Path charts | ❌ rejected | Reinvents axes, ticks, accessibility; high effort, worse a11y |
| SwiftUICharts (various) | ❌ rejected | Smaller community libs, variable maintenance; no advantage over first-party |

**Rationale.** C3 needs: grouped/annotated bar charts with a **goal reference line** and a **non-colour below-goal signal**; weekly/monthly paging; a **session overlay band**; and the BAC line chart with **solid+dashed segments, a red wash, "now" + cap reference lines, a tidy 30-min-rounded 24h X axis, and dual g/L + mmol/L Y**. Swift Charts covers all of it natively: `BarMark` + `RuleMark` (goal line) + per-bar `foregroundStyle`/`symbol`/overlay for the non-colour below-goal distinction (e.g. a hatched fill or a small marker so colour is never the sole signal — satisfying C5); `RectangleMark` for the session band and the red projection wash; two `LineMark` series (one `.solid`, one dashed via `StrokeStyle(dash:)`) for the BAC line; `RuleMark` for "now" and cap; `chartXAxis`/`chartXScale` for the rounded 24h ticks. The **one gap is a true secondary Y axis** (g/L primary + mmol/L secondary): Swift Charts doesn't support independent dual axes, but mmol/L = g/L × 21.7 is a **pure linear rescale**, so the standard workaround — render the data on the g/L scale and add a second `AxisMarks(position: .trailing)` whose labels are the g/L tick values × 21.7 — gives a correct, non-misleading second axis with no second data series. This is well-understood and low-risk. Swift Charts also gives **audio-graph / VoiceOver chart support for free**, directly serving C5's "charts must work with screen readers."

**Parity implication.** Android will use a Compose charting solution (e.g. Vico) to draw the *same* chart shapes from the *same* computed data. Charts are read-only and all computation is local and shared-by-spec (the BAC series and bar buckets come from `DrinksKit`, D7), so both platforms plot identical numbers. The **visual encoding rules** (dashed projection, red wash opacity ~8–10%, below-goal non-colour signal, axis formatting) are specified in the design system and must be matched on both — that's a design-system parity item, not a framework one. Confirmed feasible on both sides.

**Phase-2 forward-constraint.** None.

**Confidence & evidence.** High. Swift Charts capabilities (dashed `LineMark`, `RectangleMark`, `RuleMark`, axis customization) confirmed via Apple docs and current practitioner guides; the no-native-dual-axis limitation and the normalized/rescaled-label workaround are confirmed across Apple Developer Forums and tutorials (2025–2026). Because mmol/L is a fixed linear multiple of g/L, the workaround is exact, not approximate.

---

## D6 — Drink-icon SVG rendering with runtime two-shade tinting: no SVG runtime library

- **Status:** Proposed
- **Area:** icons / design-system
- **Constraint(s) addressed:** C5 (two shades from one `iconColor` via HSL ±15%, 24–32 px, scrolling lists).

**Decision.** Do **not** ship a runtime SVG renderer. Instead, **at build time** convert each filled drink icon's two elements (silhouette + inner detail) into a tintable vector asset — **template PDF/asset-catalog images (one per layer) or compiled `Path`s** — and **at render time compute the two shades in Swift** from the single `iconColor`: convert the hex to HSL, derive `shadeDark = L−15%` and `shadeLight = L+15%` (clamped), and tint each layer with its shade. Render as two stacked `Image(...).renderingMode(.template).foregroundStyle(shade)` layers (or a small SwiftUI `Canvas`/`Shape` that fills two paths). Bundle the colour math in `DrinksKit` (D7) so iOS and Android compute identical shades.

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| Two template layers + app-computed HSL shades (no SVG lib) | ✅ chosen | Exactly meets the "two shades from one colour via HSL offset" spec; native, fast in scrolling lists; zero dependency; shade math is shareable for parity |
| SVGKit (parse SVG at runtime) | ❌ rejected | **Last tagged release 2021** — stale for a 2026 build; CoreAnimation/WebKit-heavy; can't cleanly apply *two computed* shades to *one* SVG without DOM surgery per instance; perf risk at 24–32px in lists |
| SF Symbols (hierarchical/palette) for the drink icons | ❌ rejected | (a) Custom artwork isn't SF Symbols; (b) **hierarchical mode gives opacity-derived shades, not an HSL ±15% lightness pair** — wrong model; palette mode needs two arbitrary colours you'd still compute yourself, so it buys nothing over template layers |
| Pre-baked two-shade PNGs per colour | ❌ rejected | Colour is user-choosable ("any colour" picker) — pre-baking is impossible; spec explicitly says *runtime* tinting, not pre-baked |
| Other SVG libs (PocketSVG, Macaw, SwiftSVG) | ❌ rejected | Macaw/SwiftSVG effectively unmaintained; PocketSVG yields `CGPath`s (closer to our path approach) but still a dependency we don't need given the simple, fixed icon set |

**Rationale.** The C5 requirement is precise and unusual: **two shades derived at render time from ONE `iconColor` via an HSL lightness offset (±15%)**, on a *fixed, bundled* icon set, at 24–32 px, in scrolling lists. That is *not* a general SVG-rendering problem — it's a "fill two known shapes with two computed tints" problem, which Apple's native template-image tinting solves directly and fastest. The honest finding from verification is that the live runtime-SVG options are a poor fit: **SVGKit's last release is 2021** (a maintenance red flag we won't take on for a flagship visual element), and SF Symbols' hierarchical rendering produces *opacity* steps, not the *HSL-lightness* pair the design specifies — so neither the obvious "use a library" nor the obvious "use SF Symbols" path actually satisfies the spec. Converting the artwork to template layers (a one-time design/build step — the designer already delivers the icons as two-shade SVGs) lets us keep the SVG source as the *authoring* format while shipping a render format that tints natively and per-instance with zero dependency. Because the icon slot list is fixed (`glass`, `bottle`, `can`, `mug`, …), a `Path`/template-image asset catalog is entirely tractable.

**Parity implication.** **Parity-critical and well-handled.** The *shade computation* (hex → HSL → ±15% L → two colours, with identical rounding/clamping) must produce **bit-identical shades** on iOS and Android, or the same drink renders subtly different colours across platforms. We guarantee this by putting the HSL math in `DrinksKit` (D7) and verifying it against shared test vectors (a fixed set of `iconColor` → `{shadeDark, shadeLight}` fixtures). Android renders the *same* two-layer artwork (vector drawables) tinted with the *same* computed shades. The artwork itself is one shared asset family (design system).

**Phase-2 forward-constraint.** None.

**Confidence & evidence.** Medium-High. SVGKit 2021 staleness confirmed by fetching its GitHub repo. SF Symbols hierarchical = opacity-based (not HSL) confirmed via Apple HIG / WWDC21 custom-symbols material. The template-layer + computed-shade approach is standard and low-risk; the *Medium* qualifier is only because the exact asset format (compiled `Path` vs template PDF vs symbol image set) is an implementation detail to settle during the icon-pipeline build, and the designer's final artwork structure (clean two-subpath separation) must support clean layer separation. Flagging the HSL-rounding parity as a must-test item.

---

## D7 — Shared computation strategy (iOS side): dependency-free `DrinksKit`, verified against shared fixtures

- **Status:** Proposed
- **Area:** shared-computation
- **Constraint(s) addressed:** C4 (BAC, pace/recommended-volume, hydration goal, username validation, day-boundary bucketing & 7-day aggregates), supports D4/D6.

**Decision.** Isolate every C4 pure algorithm in a standalone, **dependency-free Swift module `DrinksKit`** (a local SPM target), with **no UIKit/SwiftUI/GRDB imports** — pure functions over plain value types. Drive its tests from **shared cross-platform JSON test-vector fixtures** committed once and consumed by *both* the iOS and Android test suites. The worked examples already in the design docs (e.g. the **0.362 g/L** Watson sanity check in `party-session.md`; the `30 ml × weight` goal; the pace/recommended-volume formula; the username whitelist rules) become the canonical fixtures.

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| Pure `DrinksKit` module + shared JSON fixtures | ✅ chosen | Cleanly testable; same fixtures run on both platforms → guarantees bit-comparable outputs; no UI/DB coupling |
| Algorithms scattered in view-models | ❌ rejected | Hard to test in isolation; invites iOS/Android drift; couples math to UI |
| Share a real binary (e.g. Rust/KMP core) across platforms | ❌ rejected | Violates C0 "no shared application codebase / two independent native apps"; over-engineered for these formulas |

**Rationale.** C4 is explicitly the **highest parity-risk surface**: BAC, pace, day-boundary bucketing, and username validation must be **bit-for-bit comparable** across platforms. The only robust way to prevent drift between two independently-written native implementations is a **shared test oracle**: one set of input→output vectors that *both* native implementations must satisfy. So the iOS strategy is (1) implement each formula as a pure function with explicit rounding/clamping rules transcribed verbatim from the design (e.g. ethanol density 0.789, Watson/Widmark coefficients, β = 0.15 g/L/h, mmol/L = ×21.7, round-to-nearest-100 ml goal, 0.5-glass increment clamp 0.5–2.0, NFC normalisation + `L*`/digits/`_-.` whitelist + start/end structural rules + 3–30 length, day-window math at the configurable 05:00 boundary), and (2) verify against the shared fixtures in CI. Keeping `DrinksKit` free of GRDB/SwiftUI imports means the same functions are reused by the D4 scheduler (pace/recommended-volume), the D6 icon shading (HSL math also lives here), the Party tab (BAC), and History (bucketing) — one source of truth per algorithm. Tricky edge cases the fixtures must pin down: unspecified-gender conservative path, BMI-range warning thresholds, orphan-drink `t_zero` absorption rule, lazy 12-hour auto-end, and Unicode normalisation corner cases.

**Parity implication.** **This is the central parity mechanism for the whole product.** Identical fixtures + identical specified rounding ⇒ identical outputs. The fixtures are the contract; any iOS/Android disagreement is a test failure, not a production surprise. (Note one genuine cross-language watch-item for validation: **floating-point and rounding determinism** — Swift `Double` vs Kotlin `Double` are both IEEE-754, but the fixtures should assert on *rounded/quantised* outputs, e.g. BAC to 2–3 dp and volumes to integers, not raw floats, so platform FP noise can't cause spurious mismatches.)

**Phase-2 forward-constraint.** None — Phase 2 adds *new* algorithms (sync reconciliation) but the Phase 1 pure-function + shared-fixture pattern extends naturally.

**Confidence & evidence.** High. This is a well-established pattern; the only real risk (FP/rounding determinism across languages) is named and mitigated by asserting on quantised outputs. The design docs already contain worked numbers to seed the fixtures.

---

## Dependency manifest

The deliberate posture is **first-party Apple frameworks for everything except persistence**. Final third-party SPM packages:

| Package | Version | Justification (tied to a constraint) |
| ------- | ------- | ------------------------------------ |
| **GRDB.swift** | 7.x (≥ 7.11, the June 2026 line) | **Only** third-party dependency. Justified against C1's most heavily-weighted factors — first-class explicit migrations and Phase-2 sync-readiness — and against persistence **parity with Android Room** (both SQLite). No first-party option (SwiftData/Core Data) matches its migration transparency for a schema we know will churn. |

Everything else is first-party / in-house and carries **no external dependency**:
- **SwiftUI, Observation** (D1, D2) — UI + state.
- **UserNotifications** (`UNUserNotificationCenter`) (D4) — local notifications.
- **Swift Charts** (D5) — all charts.
- **Native template-image / `Path` tinting** (D6) — drink icons; *explicitly avoids* an SVG runtime lib (SVGKit rejected as stale).
- **`DrinksKit`** (D7) — in-house pure-algorithm SPM module, no dependencies.

Total external dependencies: **1**.

---

## Risks & open questions

1. **[HIGH — top validation item] iOS cannot recompute notification content at delivery.** `UNNotificationServiceExtension` is push-only; there is no local-delivery code hook. The rolling-window re-arm (D4) makes content "fresh enough," but a user who neither opens the app nor logs for several intervals will get a slightly stale recommended-volume number — a **deliberate iOS/Android divergence** (Android *can* recompute in its broadcast receiver). Validation should confirm the staleness is acceptable and that the firing **predicates** (at-goal, just-logged, 7-day-inactive) are genuinely enforced at re-arm.
2. **[MED] 7-day-inactivity leak through pre-scheduled notifications.** Because notifications are pre-armed, a user who silently crosses the 7-day mark *without touching the app* could still receive up-to-N queued reminders. Mitigated by a short window N and by not scheduling any notification whose fire time is ≥ 7 days past last engagement. Validation should bound and bless this.
3. **[MED] Drink-icon shade parity (HSL ±15%).** The hex→HSL→±15%L→two-colour math must be bit-identical on iOS and Android (D6/D7). Needs explicit shared fixtures and a decision on rounding/clamping at the L-channel extremes. Also depends on the designer delivering icons with clean two-subpath (silhouette/detail) separation so the layers tint independently.
4. **[MED] Floating-point/rounding determinism across Swift and Kotlin (C4).** Both IEEE-754, but fixtures must assert on **quantised** outputs (BAC to fixed dp, volumes to integers) to avoid spurious cross-platform mismatches. Named in D7.
5. **[LOW] Swift Charts dual-axis is a workaround, not native.** The mmol/L second axis is a relabelled g/L axis (exact, since ×21.7 is linear). Low risk, but worth a visual-QA check that the secondary ticks land on sensible numbers.
6. **[LOW] Lock-screen BAC hiding mechanism differs from Android.** iOS withholds the BAC string from the body; Android can use per-notification private visibility. Same user-visible outcome, different mechanism — confirm both satisfy the `bacOnLockScreenEnabled` spec.
7. **[LOW] GRDB longevity.** Single-maintainer-led OSS (very actively maintained as of 2026, but worth noting). Mitigated because it's "just SQLite": worst case, migrating off GRDB to another SQLite layer is mechanical, and the on-disk schema (the asset we actually care about for Phase 2 sync) is standard SQLite regardless.
8. **[OPEN] Background top-up of the notification window.** Whether to add an opportunistic `BGAppRefreshTask` to re-arm the window while the app is backgrounded (can't be relied on, but could reduce staleness for engaged-but-not-opening users). Proposed as a possible enhancement, not a Phase 1 requirement.
