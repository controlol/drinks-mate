# Phase 1 Engineering Validation Report

> Independent, adversarial validation of the three Phase 1 technical-decision docs (`ios-stack.md`, `android-stack.md`, `design-system.md`) against `phase-1-constraints.md` (C0–C6) and the source `design/` folder.
> Reviewer stance: skeptical, not deferential. Load-bearing factual claims spot-checked against vendor docs / web (June 2026).
> Date: 2026-06-21.

---

## Verdict: **Sound with required fixes**

The three docs are well-researched, internally honest, and every recommended dependency is real, current (June 2026), and maintained — I verified the five most load-bearing claims (service-extension-is-push-only, GRDB 7.11.x, the 64-pending ceiling, DM Sans `tnum`, Vico/Style-Dictionary maintenance) and all held up. Constraint coverage is broad: C0–C6 are each addressed by at least one decision, the persistence parity posture (GRDB↔Room, both SQLite, shared semantics) is genuinely strong, and the shared-computation mechanism (`DrinksKit`/`:core` + shared golden fixtures) is the right answer to the highest parity risk. **However**, there is one substantive parity problem the docs under-resolve and several documentation gaps that must be closed before this is a buildable contract. The headline issue: the design's own anti-spam predicates are specified to run **at fire-time on-device** (notifications.md is explicit), Android implements exactly that, and iOS *cannot* — the iOS doc honestly flags this but the plan does not yet prove the at-goal / 7-day-inactivity suppression is behaviourally equivalent, and in the worst case iOS will fire reminders the design says must be suppressed. That, plus the under-specified HSL ±15% tint direction (now actually pinned in the design-system Rulebook but not cross-referenced by the platform docs) and a handful of undocumented divergences, are the required fixes.

---

## Foundedness findings

| Claim (doc) | Status | Action |
| ----------- | ------ | ------ |
| `UNNotificationServiceExtension` is remote-push-only; no local-delivery code hook (iOS D4) | ✅ **VERIFIED** (Apple docs; multiple 2026 sources) | None — correct and load-bearing. Honest finding. |
| 64-pending local-notification ceiling, system keeps soonest 64 (iOS D4) | ✅ **VERIFIED** | None. |
| GRDB.swift 7.x current, actively maintained, v7.11.x June 2026 line (iOS D3) | ✅ **VERIFIED** (v7.11.1, 2026-06-18; cross-platform Android/Linux/Windows work ongoing) | None. The single 3rd-party iOS dep is well-founded. |
| SwiftData migration story is the weakest/most-fragile surface (iOS D3 rationale) | 🟡 **PLAUSIBLE, asserted** | Defensible and widely held, but it's a judgement, not a verified fact. Keep as rationale; do not present as settled. |
| Swift Charts has no native secondary Y axis; rescale-label workaround is exact since mmol/L = g/L×21.7 (iOS D5) | ✅ **SOUND** (linear rescale is exact) | None. Low-risk. |
| SVGKit last release 2021 / stale (iOS D6) | 🟡 **PLAUSIBLE** (not re-verified this pass) | Cheap to confirm at build time; conclusion (don't ship a runtime SVG lib) is right regardless. |
| Room 2.8.x current stable; Room 2.x in maintenance mode; Room 3.0 in `androidx.room3` (Android D3) | 🟡 **PLAUSIBLE / mostly asserted** | Accept; the "stay on stable 2.8.x, defer room3 as mechanical" call is sound. Verify exact patch at integration. |
| `SCHEDULE_EXACT_ALARM` denied-by-default Android 14+, user-revocable; `USE_EXACT_ALARM` Play-restricted (Android D4) | 🟡 **PLAUSIBLE, well-cited** | Accept; the graceful-inexact-fallback posture is correct. Confirm Play policy at submission (already an open Q in the doc). |
| WorkManager 15-min periodic minimum (Android D4) | ✅ **SOUND** (long-standing) | None. |
| Vico Compose-native, actively maintained 2.x in 2026, dashed lines via `DashPathEffect` (Android D5) | ✅ **VERIFIED** (releases June 2026) | None. Red-wash technique still a spike item (doc says so). |
| `android.icu` available API 24+, category constants differ from `java.lang.Character` (Android D7) | 🟡 **PLAUSIBLE, well-cited** | Accept; the "pin the rule set, not the ICU version" mitigation is the right one. |
| DM Sans (OFL-1.1) exposes `tnum` tabular figures (design D2) | ✅ **VERIFIED** | None — but confirm the *shipped build* includes `tnum` glyphs (doc already flags this; historical upstream gap). |
| Style Dictionary v4 is DTCG-forward-compatible; DTCG hit stable 2025.10 (design D1) | 🟡 **VERIFIED with nuance** | DTCG 2025.10 stable ✅, SD v4 has first-class DTCG support ✅ — BUT **full 2025.10 support is a SD v5 work-in-progress**, not complete in v4. **Fix:** soften the doc's implication that v4 fully tracks 2025.10; pin the exact `$value`/`$type` DTCG dialect SD v4 actually supports. |
| KMP business-logic production-stable since Nov 2023; Swift export still experimental (design D4) | ✅ **SOUND** | None. Correctly kept as a *deferred* option, not adopted (would violate C0 if used for shared source). |

**No invented versions, no abandoned dependencies adopted, no dead APIs relied on.** The docs are unusually disciplined about distinguishing verified fact from judgement. Good.

---

## Constraint coverage matrix (C0–C6)

| Constraint | Covered? | By | Gap / note |
| ---------- | -------- | -- | ---------- |
| **C0** Two native apps, offline-first, local source of truth, NO server/API/auth/sync/analytics, no login | ✅ Full | iOS D1–D3, Android D1–D3; both dependency manifests explicitly exclude FCM/analytics/crash/networking | Clean. Both manifests name the exclusions. See Scope section. |
| **C1** UUID PK, createdAt/updatedAt, soft-delete, transactional writes, migrations, day-boundary range queries, entity list, seeding, money-minor/metric, immutable snapshot log | ✅ Full | iOS D3 (GRDB), Android D3 (Room), Rulebook (money/units/boundary) | Strong on both. Snapshot immutability (no FK DrinkEntry→DrinkPreset) acknowledged both sides. **Minor:** neither platform doc explicitly walks the *seeding-on-first-launch / Reset-to-defaults* (C1) flow — implied but not stated. Low severity. |
| **C2** 4 notification types, quick-log-without-opening, recompute-at-delivery, anti-spam predicates at delivery, 64-pending, optional permission, lock-screen BAC toggle | ⚠️ **Partial — the crux** | iOS D4, Android D4, Rulebook | Android: full. iOS: **recompute-at-delivery and at-delivery predicate evaluation are NOT achievable** (intrinsic). iOS mitigates via re-arm. The four types, quick-log, 64-window, permission-optional, lock-screen toggle are all covered. **The predicate-at-delivery gap is the P0 below.** |
| **C3** History bars (goal line + non-colour below-goal), conditional alcohol/peak-BAC charts + session band, BAC line chart (solid+dashed+red wash+now+cap+rounded 24h X+dual g/L+mmol/L), all local, read-only, a11y/screen-reader | ✅ Full | iOS D5 (Swift Charts), Android D5 (Vico), design D3 | Both express every element. Dual-axis: iOS rescale-label (exact), Vico native dual axis. Red wash: both via custom Canvas if needed. **Undocumented divergence:** dual-axis *mechanism* differs (see parity matrix) — fine, but write it down. |
| **C4** Hydration goal, pace/recommended-volume, full BAC chain, username validation, day-boundary bucketing + 7-day aggregates — bit-comparable via shared vectors | ✅ Full | iOS D7 (`DrinksKit`), Android D7 (`:core`), design D4/D5 + Rulebook | Excellent. Rulebook transcribes every formula verbatim with pinned rounding. FP-determinism risk named and mitigated (assert on quantised outputs). The 0.362 g/L worked example is the seed fixture. **One gap:** see "orphan t_zero" parity note below — the rule is in the Rulebook but is a known divergence trap. |
| **C5** DM Sans + tnum, 3 accents + semantic + light/dark at v1 + emerald quarantine, two-shade icon HSL ±15%, ~25 UI icons + illustrations, calm motion + reduce-motion, haptics (light log / medium goal), a11y (labels, dynamic type, non-colour state, VoiceOver/TalkBack), 3-tab nav | ✅ Full | design D1–D3 + narratives, iOS D6, Android D6, both D1 | Comprehensive. Motion tokens, haptics, emerald lint-quarantine, non-colour-signal table all present. **Gap:** HSL ±15% *direction* (lighten vs darken) — under-specified in C5 and both platform docs, but **the design Rulebook DOES pin it** ("lighten if base L<50 else darken"). Platform docs must cross-reference that, see P1. |
| **C6** Two-taps-to-log, first-drink-60s/<30s onboarding, no-telemetry → pre-release internal validation, localisation later but locale-correct money/units/time | ✅ Mostly | iOS D1/D2, Android D1/D2, both notes | Optimistic-UI covered both sides. **Gap:** "no telemetry means validate reliability by internal testing" (C6 ∩ Android D4 reliability) has **no defined internal-test matrix / pass bar** — flagged as open on both the Android doc and here (P2). Locale formatting covered in Rulebook. |

**No constraint has zero coverage.** The only *partial* is C2's recompute/predicate-at-delivery on iOS, which is intrinsic, not an oversight — but the plan must still prove behavioural equivalence (P0).

---

## Parity matrix (the centerpiece)

Classification key: **A&D** = acceptable & documented · **A-undoc** = acceptable but undocumented (must be written down) · **PROBLEM** = real experience gap unresolved.

| Capability | iOS | Android | Class | Required action |
| ---------- | --- | ------- | ----- | --------------- |
| **Persistence engine** | GRDB (SQLite) | Room (SQLite) | **A&D** | None. Same engine, same UUID/soft-delete/updatedAt semantics, analogous explicit migrations. Best-case posture. |
| **Architecture / state** | Observation `@Observable` + thin MVVM | ViewModel/StateFlow + Repository + UDF | **A&D** | None. Both declarative; user never sees architecture. Both put C4 math behind a boundary (D7). |
| **Notifications — content recompute at delivery** | ❌ Cannot (service ext push-only); content baked at schedule, refreshed by re-arm | ✅ Recomputes in BroadcastReceiver at fire | **PROBLEM (bounded)** | **P0.** Intrinsic, but the user-visible gap (staler recommended-volume on iOS in the "app untouched for hours" case) needs an explicit bound + product sign-off. The *number* differs across platforms for the same real-world situation. See P0-a. |
| **Notifications — fire-time PREDICATE (at-goal / just-logged / 7-day-inactive suppression)** | Evaluated at **re-arm**, not at fire; mitigated by cancel-on-goal + short window + "no fire ≥7d past engagement" | Evaluated **at fire** in receiver (matches design verbatim) | **PROBLEM** | **P0-b — the sharpest issue.** `notifications.md` Behaviour + Inactive-user silence state predicates run *at fire-time on device*. iOS structurally cannot. The cancel-on-goal-re-arm covers the common path, but a user who crosses goal/7-day-inactive **without touching the app** can still receive up-to-N pre-armed iOS notifications the spec says must be suppressed. Android suppresses correctly. This is a genuine spec-conformance + parity gap. Must be explicitly bounded and blessed, OR the window N tightened so the leak is provably ≤ acceptable. |
| **Notifications — quick-log without opening app** | UNNotificationAction (non-foreground) → GRDB write → re-arm | PendingIntent → BroadcastReceiver → Room write | **A&D** | None. Same outcome. Both honour `defaultDrinkPresetId` fallback. |
| **Notifications — timing / reliability** | Pre-scheduled; reliably delivered; 64 ceiling | Exact-ish alarm; OEM battery-kill + App Standby can drop nudges | **A&D** | Documented both sides as intrinsic. **But** ensure product accepts: an Android user on an aggressive OEM may *miss* a nudge an iOS user gets; an iOS user may get a *staler* nudge. Both flagged; needs one combined parity note (currently split across two docs). See P1. |
| **Notifications — lock-screen BAC hide** | Withhold BAC string from body (no OS private-visibility equiv relied on) | `setVisibility(VISIBILITY_PRIVATE)` OS redaction | **A&D** | Same user outcome (BAC not shown when toggle off); mechanism differs; both docs say so. Matches design ("omit from body OR platform hidden-content style"). Fine. |
| **Charts — BAC line (solid+dashed+red wash+now+cap)** | Swift Charts: 2 LineMarks, RectangleMark wash, RuleMarks | Vico: line layers + DashPathEffect, Canvas wash, threshold lines | **A&D** | None. Same shapes from same `DrinksKit`/`:core` data. Wash is a spike item both sides. |
| **Charts — dual axis g/L + mmol/L** | Relabelled single axis (×21.7, exact) | Vico native start/end axis (×21.7 relabel) | **A-undoc** | **Write down** that iOS fakes the 2nd axis via labels while Android uses a real 2nd axis. Same numbers (×21.7 linear) so no user-visible difference — but it's an undocumented mechanism divergence. Low severity. |
| **Charts — below-goal non-colour signal** | per-bar foregroundStyle/symbol/overlay (hatch/marker) | Vico per-bar styling or Canvas overlay | **A-undoc** | Both *can* do it, neither doc commits to the **same** non-colour treatment (hatch vs marker vs pattern). Design Rulebook says "non-colour pattern/marker" but doesn't pick one. **Pick one shared treatment** so iOS and Android look the same. See P1. |
| **Icon two-shade tint — math** | HSL ±15% in `DrinksKit`, shared fixtures | HSL ±15% in `:core`, shared fixtures | **A&D** | Math shared. Good. BUT see next row. |
| **Icon two-shade tint — ±15% DIRECTION & colour space** | "L−15% / L+15% clamped" (D6) — direction not pinned in iOS doc | "lightness offset by ±15%" (D6) — direction not pinned in Android doc | **A-undoc → must fix** | **P1.** Each platform doc states the *magnitude* but not the *single fixed direction rule*. If iOS lightens the inner detail and Android darkens it (or they clamp differently at L extremes), the same drink renders differently. **The design Rulebook already pins this** ("lighten if base L<50 else darken; clamp [0,100]; sRGB→HSL; hex lowercase"). Both platform docs must cite that rule and add it to the shared fixtures. Until cited, this is an open divergence. |
| **Typography — DM Sans + tnum** | bundled, `tnum` forced, UIFontMetrics scaling | bundled, `tnum` forced, sp scaling | **A&D** | None. Same binaries, same feature flag. Absolute scale factors differ per OS at a given a11y setting — design doc correctly calls this acceptable. |
| **Colour / tokens** | Style Dictionary → .xcassets + Swift | Style Dictionary → values/ + values-night/ + Compose | **A&D** | None. One token source → both. Strong. |
| **Dark mode** | asset-catalog light/dark sets | values/ + values-night/ | **A&D** | None. Generated from same JSON pairs; ships at v1 both. |
| **Emerald quarantine** | `color.party.*` namespace + path-scoped lint | same lint mechanism | **A&D** | None. Same enforcement both platforms. |
| **a11y (labels / dynamic type / VoiceOver-TalkBack)** | SwiftUI `.accessibilityLabel`, Dynamic Type | Compose semantics, sp scaling | **A&D** | None. Shared label-key list + per-feature checklist. |
| **Motion / haptics** | impactLight log / impactMedium goal; ease-in-out tokens; reduce-motion | tick log / heavy-click goal; same tokens; reduce-motion | **A&D** | None. Haptic semantics + motion tokens shared via design D1/brief. |
| **Shared algorithms (BAC, pace, goal, username, bucketing)** | `DrinksKit` pure module + shared JSON fixtures | `:core` pure module + same fixtures | **A&D** | None — this is the central parity mechanism. CI-gating on shared fixtures is the contract. Watch FP determinism (mitigated by quantised asserts) and ICU-version skew (mitigated by pinning the rule set). |
| **BAC float/rounding determinism (Swift vs Kotlin)** | Double IEEE-754, assert on quantised outputs | Double IEEE-754, assert on quantised outputs | **A&D (with watch-item)** | Both docs name it; mitigation (pin op-order + rounding points in Rulebook, assert quantised) is correct. **Add fixtures at the rounding edges** (e.g. recommended-volume exactly on a 0.25-glass boundary; BAC just above/below the 80%-cap threshold) — both docs request this; make it a definition-of-done. |
| **Orphan-drink `t_zero` absorption** | in `DrinksKit` (C4) | in `:core` (C4) | **A&D (watch-item)** | Rule pinned in Rulebook (`t_zero = consumedAt + BAC_initial/β`). It's a known multi-branch divergence trap — ensure a fixture covers absorbed-vs-decayed boundary on both. |

### Adjudication of the named hot spots
1. **Service extension (iOS) vs receiver recompute (Android):** Real, user-visible — but **content** drift is small and self-correcting (P0-a, bounded). The sharper half is the **predicate** (P0-b): iOS can leak suppressed notifications. The proposed mitigation is *not* fully equivalent to Android's fire-time check; it's "good enough if N is small," which must be quantified and blessed.
2. **Timing/reliability (Android OEM kill vs iOS pre-schedule):** Intrinsic, documented both sides, accept — but consolidate into one shared parity note (P1).
3. **HSL ±15% under-spec:** Was the real risk; the **design Rulebook closes it**, but the platform docs don't reference the pinned direction. Fix by cross-reference + fixtures (P1).
4. **Float/rounding determinism:** Adequately handled by quantised-output asserts; just enforce edge fixtures (P2).
5. **Charting capability one platform can't express:** None found. Both express the full C3 set; only mechanism differs (dual-axis, wash), with identical numeric output. Below-goal signal needs a single shared treatment chosen (P1).

---

## Scope-discipline check

- ✅ **No server / API / auth / sync / analytics / crash reporting** leaked in. Both dependency manifests *explicitly* exclude FCM, analytics, crash SDKs, and all networking. iOS takes exactly **1** 3rd-party dep (GRDB); Android exactly **1** (Vico). Both justified against a constraint.
- ✅ **No Phase-2 entities** (`Account`, `Friendship`, `ShareSetting`) in any schema. Both D3 docs name them as forbidden guardrails.
- ✅ **Forward-compat present without building Phase 2:** UUID PKs, `updatedAt` (LWW basis), `deletedAt` (tombstone-free deletion) on every entity — exactly the `data-model.md` Sync-model requirement, with sync engines deferred to "above the repository." No sync code, no LWW engine, no network layer shipped.
- ✅ **No login screen / account prompt.** Onboarding (design brief S5) is profile-only, no account step.
- 🟡 **Minor watch:** iOS D4 and Android D4 both *mention* a possible Phase-2 push backend ("if Phase 2 adds push…"). This is forward-looking commentary only — no scaffolding — acceptable, but keep it as prose, not a TODO that invites early building.

**Scope discipline is clean.** This is one of the strongest aspects of the plan.

---

## Internal consistency

- ✅ **Icon tint math** agrees in *magnitude* across all three docs (HSL ±15%, shared module). **Inconsistency:** only the design-system Rulebook pins the *direction/clamp/colour-space*; the two platform docs leave it loose. Not a contradiction, but an incompleteness that must be reconciled (P1).
- ✅ **Shared test-vector mechanism** is described identically in all three (pure module + shared JSON golden fixtures, CI-gating, 0.362 g/L seed). iOS calls it `DrinksKit`, Android `:core`, design calls it "shared golden-file suite" — same thing, consistent.
- ✅ **Min-OS / device-base claims** are self-consistent within each doc and don't contradict each other (iOS 18 floor ≈ whole active base; Android minSdk 26 for notification channels). Different platforms, different floors — expected, not a conflict.
- ✅ **Lock-screen BAC** handling consistent: design says "omit from body OR platform hidden-content style"; iOS picks omit-from-body, Android picks VISIBILITY_PRIVATE — both within the spec's allowance.
- ✅ **mmol/L = ×21.7, β = 0.15, ethanol 0.789, round-to-100ml goal, 0.5-glass clamp** — consistent across iOS D7, Android D7, and the Rulebook. No numeric drift between docs.
- 🟡 **Day-boundary handling:** iOS D3 says day-window math lives in `DrinksKit` and feeds SQL bounds; Android D3 says the ViewModel/Repository computes `[start,end)` and passes as params. Same outcome, slightly different layer description — consistent enough, but confirm both compute the boundary from the **same `DrinksKit`/`:core` function** so DST/precision can't drift (Android D3 flags timestamp-representation as the risk; good).

No hard contradictions found.

---

## Required fixes (prioritised)

### P0 — must resolve before the plan is a buildable contract

**P0-a. Bound and bless the iOS recompute-at-delivery staleness gap.**
*Where:* `ios-stack.md` D4 + a new shared parity note; `notifications.md` cross-ref.
The design's "recompute recommended volume at delivery" (C2) is unachievable on iOS. The re-arm mitigation is sound but produces a *different number* than Android for the same real-world "app-untouched-for-hours" situation. Action: state the **maximum staleness** (≤ window length N × interval) explicitly, get product sign-off that the drift is acceptable, and make the iOS re-arm-on-every-(foreground|log|settings-change) a hard requirement, not a "should."

**P0-b. Prove the iOS fire-time PREDICATE is behaviourally equivalent to Android's — or tighten the window until the leak is provably acceptable.**
*Where:* `ios-stack.md` D4 (anti-spam section); reconcile against `notifications.md` Behaviour + Inactive-user silence (which specify *fire-time, on-device* evaluation).
This is the sharpest parity/spec-conformance gap. Android evaluates `enabled ∧ permission ∧ within-active-hours ∧ below-goal ∧ ≥interval-since-log ∧ not-7d-inactive` *at fire-time* (verbatim spec). iOS evaluates at re-arm, so a user who crosses goal **or** the 7-day-inactive line **without touching the app** can still receive up-to-N queued iOS notifications the spec says must be suppressed. Action: (1) quantify N and the worst-case leak; (2) confirm the "schedule nothing whose own fire-time is ≥7d past last engagement" bound and the cancel-on-goal-at-re-arm actually cover the documented cases; (3) get explicit product acceptance that the residual (≤ N notifications in the silent-crossing edge) is OK; (4) add this as a named, accepted divergence in both the iOS doc and a shared parity note. Without this, iOS will violate the anti-spam contract in a real (if narrow) case.

### P1 — must fix for true visual/behavioural parity

**P1-a. Cross-reference and enforce the pinned HSL ±15% tint rule in both platform docs.**
*Where:* `ios-stack.md` D6, `android-stack.md` D6 → cite `design-system.md` Rulebook "Two-shade icon tint" row.
The Rulebook pins direction ("lighten if base L<50 else darken"), colour space (sRGB→HSL), clamp ([0,100]), and hex casing. The platform docs don't reference it and state only the magnitude. Action: both D6 sections must cite the Rulebook rule verbatim and add `iconColor → {shadeA, shadeB}` fixtures (e.g. `#3b82f6`, plus an L<50 and an L>50 case, plus an L-extreme clamp case) to the shared vector suite. This is the difference between "icons match" and "icons subtly differ per platform."

**P1-b. Pick ONE shared below-goal non-colour treatment.**
*Where:* `design-system.md` D3/Rulebook non-colour-signal table; referenced by iOS D5 + Android D5.
Both docs say "hatch or marker or pattern" without committing. Action: choose a single treatment (e.g. diagonal hatch fill) and spec it once so the History charts look identical on both platforms; add to the parity checklist.

**P1-c. Consolidate the notification timing/reliability divergence into one shared parity note.**
*Where:* new shared section (or README parity contract), referenced by both D4s.
Currently the "Android may miss / iOS may go stale" divergence is split across two docs, each calling itself "the top item for validation." Action: write the single canonical statement of the intrinsic notification divergence (reliability vs freshness), with the agreed product stance, so it's one accepted decision rather than two half-statements.

**P1-d. Document the two A-undoc chart-mechanism divergences.**
*Where:* iOS D5 + Android D5.
Dual-axis (iOS relabel vs Vico native) and below-goal rendering path differ. Same numbers, but note them so a future reviewer doesn't mistake them for drift.

### P2 — should fix; lower risk

**P2-a. Define the no-telemetry pre-release reliability test matrix + pass bar.**
*Where:* `android-stack.md` D4 open Qs (and a shared QA note). C6 forbids telemetry, so notification reliability has no field signal — the internal-test OEM matrix (Xiaomi/MIUI, Huawei/EMUI, Samsung, OnePlus, Oppo) and a pass bar must be defined, not left open.

**P2-b. Add rounding-edge fixtures as a definition-of-done for C4.**
*Where:* `design-system.md` D4/D5, both D7s. Recommended-volume on a 0.25-glass boundary; BAC just above/below 80%-cap; goal at a .50 ml boundary (65kg→1950→2000); orphan absorbed-vs-decayed boundary; unspecified-gender path. Make "fixtures cover every branch" a checklist gate.

**P2-c. Soften the Style Dictionary v4 ⟷ DTCG-2025.10 claim.**
*Where:* `design-system.md` D1 + source-verification note. SD v4 has first-class DTCG support but **full 2025.10 support is a v5 WIP**. Pin the exact DTCG dialect v4 supports (`$value`/`$type`) so the pipeline isn't built against an assumed-complete spec level.

**P2-d. State the C1 seeding / Reset-to-defaults flow in both persistence docs.**
*Where:* iOS D3, Android D3. Implied but not written; cheap to add for completeness.

---

## Recommended follow-ups / open questions for the human lead

1. **Product decision (gates P0-a/P0-b):** Is it acceptable that, in the "user never opens the app for hours/days" edge, an iOS user can receive a slightly-stale recommended volume *and* up to N notifications that the anti-spam spec would suppress, while Android suppresses them correctly? If not acceptable, the iOS window N must shrink toward 1–2 (closer to Android's per-fire model) at the cost of more aggressive re-arming and a slightly higher chance of an empty queue if the app is force-quit. This is a genuine product trade, not an engineering detail.
2. **Optional `BGAppRefreshTask` top-up (iOS) and `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` prompt (Android):** both proposed as optional reliability enhancements. Decide whether either ships in Phase 1 or is deferred — they materially affect the reliability parity story.
3. **`USE_EXACT_ALARM` Play-policy qualification:** confirm a hydration reminder does *not* claim it (claiming without qualifying risks Play rejection). Product must accept inexact-by-default Android timing.
4. **Parity governance ownership:** the design-system doc proposes a CI-gated shared-fixture repo + per-feature checklist. Who owns the shared `vectors/` repo and the cross-platform CI that both apps gate on? This is the linchpin of C4 parity and currently has no named owner.
5. **Single source for the day-boundary function:** confirm iOS and Android both call the *same spec'd* `DrinksKit`/`:core` day-window function (not two hand-rolled date calcs) — the one place a subtle DST/precision drift could slip past the fixtures.

---

### Bottom line
The research is solid and honest; the dependencies are real and current; scope discipline is clean; and the shared-computation + token + persistence parity stories are strong. The plan is **not yet** a complete contract only because the iOS notification model cannot meet the design's at-delivery predicate spec, and that gap is currently flagged but not *resolved* (P0). Close P0-a/b and the four P1 items and this is buildable with confidence.
