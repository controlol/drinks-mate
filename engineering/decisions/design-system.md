# Design System & Cross-Platform Parity

Drinks Mate ships as **two independent native codebases** (iOS native, Android native) with **no shared application code** — that constraint is load-bearing and not revisited here. The job of this document is therefore *not* "how do we share UI code" but "how do we share **specifications** so the two native implementations stay in lockstep, visually and behaviourally." The recommendation is a three-legged stool: (1) a **platform-neutral design-token source of truth** compiled to native artifacts with **Style Dictionary v4** (following the now-stable W3C DTCG token format), so colour/spacing/type/motion cannot drift; (2) **DM Sans** bundled identically on both platforms with the tabular-figures OpenType feature explicitly enabled, mapped onto each platform's font-scaling mechanism; (3) for the high-risk C4 shared computation (BAC, pace, goal, username validation, day-boundary bucketing), a **language-neutral algorithm spec plus a shared golden-file test-vector suite** that *both* native test suites run against — chosen over Kotlin Multiplatform shared logic for Phase 1, with KMP flagged as a deferrable option. All of this is held together by a lightweight **parity governance process** and the copy-pasteable **Parity Rulebook** in the appendix. This document is written against [phase-1-constraints.md](../phase-1-constraints.md) (especially C4, C5, C6) and the parity contract in the [engineering README](../README.md).

## Decisions at a glance

| # | Decision | Choice | Confidence |
| - | -------- | ------ | ---------- |
| D1 | Design tokens as single source of truth | **Style Dictionary v4** (DTCG-format JSON) → iOS asset catalog + Swift, Android resources + Compose theme | High |
| D2 | Typography parity | **DM Sans** (OFL-1.1 variable font) bundled on both; `tnum` tabular figures forced for headline numerics; map to Dynamic Type / Android `sp` scaling | High |
| D3 | Icon & illustration asset pipeline | **One source SVG set**; runtime two-shade tinting from single `iconColor` via shared HSL ±15% lightness math; SVG→native vector at build time | High |
| D4 | Shared-computation parity mechanism | **Language-neutral spec + shared golden-file test vectors** run by both native suites; **not** KMP for Phase 1 (KMP deferred, re-evaluate Phase 2) | High |
| D5 | Parity governance | **Per-feature parity checklist + shared Parity Rulebook** (rounding/units/boundaries); shared fixtures are CI-gating | High |
| — | Accessibility parity | Specified once in the token/spec layer; checked per-platform via a shared a11y checklist (narrative section) | High |
| — | Dark mode + emerald quarantine | Light/dark token pairs ship at v1; emerald is a Party-only token namespace, lint-enforced (narrative section) | High |

---

## D1 — Design tokens as the single source of truth

- **Status:** Proposed
- **Area:** design-system
- **Constraint(s) addressed:** C5 (colour, typography, motion, spacing), C6 (localisation/format follow device but tokens are device-neutral)

**Decision.** Author all platform-neutral visual primitives — colour (azure / honey / emerald + the semantic palette, each as a **light+dark pair**), spacing scale, corner radii, the type scale, elevation, and motion specs (durations + easing curves) — as **DTCG-format JSON token files** in a small dedicated repo/folder, and compile them with **Style Dictionary v4** into per-platform artifacts: an **iOS asset catalog (`.xcassets`) plus a generated Swift constants file** for non-colour tokens, and **Android resources (`colors.xml`, `dimens.xml`) plus a generated Kotlin/Compose theme file**. Tokens are generated, never hand-typed twice.

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| Style Dictionary v4 (DTCG JSON → native) | ✅ chosen | Mature, the de-facto standard token build system; ships built-in iOS-swift and Android transforms; forward-compatible with the now-stable DTCG format. |
| Hand-maintained parallel definitions (Swift + Kotlin edited by hand) | ❌ rejected | Guarantees drift: two hand-edited colour tables diverge the first time someone tweaks a hex and forgets the other side. No single source of truth = no parity. |
| Figma-plugin-only export (e.g. Tokens Studio direct-to-platform) | ❌ rejected as primary | Couples the build to a design-tool plugin and a designer's manual export step; fine as an *input* feeding the JSON, but the committed JSON + SD build must be the source of truth so CI owns it, not a person. |
| Roll-our-own codegen script | ❌ rejected | Reinvents Style Dictionary's transforms (hex→UIColor, dp/sp, dark-mode set handling) with less coverage and no community maintenance. |

**Rationale.** The brief fixes DM Sans and a single colour system *specifically to avoid platform divergence* (C5). That intent is only real if the values live in exactly one place. Style Dictionary turns "azure-500 light = #xxxxxx / dark = #yyyyyy" into both an iOS colour set (with the light/dark variants the asset catalog natively supports) and an Android `values/` + `values-night/` pair from the *same* JSON line, so a colour change is one edit that lands on both platforms identically. The DTCG token format reached its first stable version (2025.10) in October 2025, so this is no longer a moving target. Motion tokens (duration + cubic-bezier control points) also live here, which is what makes "calm ease-in-out, no bounce" a *shared spec* rather than two independent guesses; each platform maps the curve onto its native animation API but from one set of numbers.

**Parity implication.** This is the primary parity mechanism for the *visual* layer. iOS and Android render from generated artifacts derived from one token file, so colour, spacing, radii, and motion durations are identical by construction. The only divergence is the rendering API (UIColor/SwiftUI Color vs Compose Color), not the value. A token diff in a PR is reviewable as a single change affecting both apps.

**Phase-2 forward-constraint.** None negative. Phase 2 (accounts/sync) adds no new visual surface that the token model can't absorb; new tokens are additive. Keeping tokens generated rather than hand-coded actually *helps* Phase 2 because any rebrand or themed surface is a JSON edit, not a two-codebase sweep.

**Confidence & evidence.** High. Style Dictionary v4 is current and actively maintained (co-maintained by Tokens Studio), ships built-in `ios-swift` and Android name/snake transforms, and is explicitly DTCG-forward-compatible. DTCG format hit first stable (2025.10) per the W3C Design Tokens Community Group. Verified June 2026 via Style Dictionary docs and the DTCG announcement.

---

## D2 — Typography parity (DM Sans + scaling behaviour)

- **Status:** Proposed
- **Area:** design-system
- **Constraint(s) addressed:** C5 (DM Sans both platforms, tabular figures for headline numerics, dynamic type at every size), C6 (locale formatting)

**Decision.** Bundle **DM Sans** (SIL OFL-1.1, the 2023 variable font: weight axis 100–700 + optical-size `opsz` axis) as an app resource in *both* apps from the same font binaries. Define the type scale as tokens (D1). For the headline numerics — the Today intake value and the Party BAC value — **force the OpenType tabular-figures feature (`tnum`)** so digits are fixed-width and don't jitter when the value changes. Map the token type scale onto **iOS Dynamic Type** (custom font via `UIFontMetrics`-scaled text styles / SwiftUI `.dynamicTypeSize`) and **Android font scaling** (`sp` units, Compose `Typography` honouring system font scale), so a given semantic style scales equivalently on both.

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| Bundle DM Sans on both + explicit `tnum` | ✅ chosen | One open-source family removes the biggest source of typographic drift; tabular figures are an explicit C5 requirement; OFL-1.1 permits embedding/redistribution. |
| Use each platform's system font (SF Pro / Roboto) | ❌ rejected | Directly violates C5; SF Pro and Roboto have different metrics, so layouts and the "big numeric" feel diverge — exactly what the brief chose DM Sans to prevent. |
| DM Sans but rely on default (proportional) figures | ❌ rejected | Proportional digits cause the headline value to shift horizontally as it changes (`1.4 L`→`1.1 L`), which the brief explicitly rules out for the display numerics. |
| Static per-weight DM Sans files instead of the variable font | ⚠️ acceptable fallback | Works if a platform's variable-font + opsz handling is awkward, but multiplies bundle size and weight management; prefer the variable font, fall back per-platform only if needed. |

**Rationale.** The brief picked DM Sans *specifically* so iOS and Android don't diverge on type — so the parity-critical detail is that **both apps embed the identical font binaries** (committed alongside the tokens, or vendored per app from the same source) and both enable `tnum` on the same set of styles. Tabular figures matter because the intake and BAC numbers update live; without fixed-width digits the value visibly jumps, and it would jump *differently* on each platform. Mapping the scale onto each platform's native scaling mechanism (rather than a fixed pixel size) satisfies the non-negotiable "dynamic type at every system size" rule while keeping the *relative* scale identical — the token defines the base size and the platform applies the user's scale factor.

**Parity implication.** High parity by construction: same font, same scale tokens, same OpenType feature flags. The residual divergence is that iOS and Android apply *different absolute* scale factors at a given accessibility setting (the OSes don't use identical multipliers), which is acceptable and expected — both honour the user's chosen size; what stays identical is the typeface, the relative scale, and digit behaviour. The parity check is: same style token → same family/weight/`tnum` state on both, and headline numerics never reflow.

**Phase-2 forward-constraint.** None. Localisation is explicitly later (C6/L4); DM Sans covers Latin well and the family can be extended or supplemented per-script later without changing the scale model.

**Confidence & evidence.** High. DM Sans is OFL-1.1 (embedding/redistribution permitted), available from Google Fonts, and the 2023 variable version exposes weight + `opsz` axes and the tabular-figures OpenType feature. Both iOS (Core Text / SwiftUI font features) and Android/Compose support enabling OpenType `tnum`. Verified June 2026 via Google Fonts and the googlefonts/dm-fonts repo. Note: confirm at implementation time that the exact build of DM Sans shipped includes `tnum` glyphs (a historical issue tracked upstream); if a given build lacks it, pin a build that has it.

---

## D3 — Icon & illustration asset pipeline

- **Status:** Proposed
- **Area:** icons / design-system
- **Constraint(s) addressed:** C5 (drink icons two-shade runtime-tinted from single `iconColor` via HSL ±15%; ~25 UI icons + illustrations as one visual family)

**Decision.** Maintain **one master set of source SVGs** (the ~10 drink icons, ~25 UI icons, and the illustrations) in the shared design repo as the single authoring source. At build time, convert each SVG to the platform-native vector format — **iOS: SVG → PDF or SF-Symbol-style template / SwiftUI `Path`-backed vector or asset-catalog vector** ; **Android: SVG → Android Vector Drawable (`importVectorDrawable` / `vectordrawable`)**. The **two-shade drink-icon tint is computed at render time on both platforms from the single `iconColor`** using one **shared, spec'd HSL lightness-offset function** (±15%): the silhouette uses `iconColor`, the inner-detail shade uses `iconColor` with lightness shifted by a fixed offset, clamped. The exact HSL conversion and offset are part of the Parity Rulebook so both platforms produce the *same two hexes* from the same input. UI icons and illustrations are static (non-tinted or single-tinted) and just need to ship identically.

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| One source SVG set → per-platform vector at build time, shared tint math | ✅ chosen | Single authoring source keeps the two apps pixel-identical; vectors scale crisply at 24–32 px; runtime tint matches C5's "derived at render time, not pre-baked" requirement. |
| Pre-baked PNG/raster assets per colour | ❌ rejected | The colour is user-chosen (any colour picker) — pre-baking is impossible; also non-vector and would diverge across densities. |
| Pre-baked two-shade SVGs per beverage default colour | ❌ rejected | Breaks the "any colour" requirement and the single-`iconColor`-derives-both-shades rule; doubles asset count and invites drift. |
| Independent icon redraws per platform | ❌ rejected | Two artists/exports = guaranteed visual divergence; defeats the "one cohesive visual system across both platforms" goal. |

**Rationale.** C5 is unusually specific here: both shades must be *derived at render time* from one `iconColor` via an HSL ±15% lightness offset. That makes the tint a **shared algorithm** (belongs in the Parity Rulebook and the test vectors of D4), not an asset decision — the risk is that iOS and Android implement HSL conversion or the clamp slightly differently and the second shade ends up a different hue/lightness on each platform. Authoring the geometry once as SVG and converting at build time removes the geometry-divergence risk; specifying the tint math once removes the colour-divergence risk. The detailed *rendering* mechanism (how each platform applies two fills to one vector) is the concern of the per-platform stack docs; this doc owns the **shared authoring source** and the **shared tint math**.

**Parity implication.** High. Same SVG geometry → near-identical vectors; same tint function → identical two hexes from a given `iconColor`. The drink-icon tint function must be covered by shared test vectors (e.g. `#3b82f6` → silhouette `#3b82f6`, inner `#<computed>`), so a tint divergence is caught in CI, not by eye. Illustrations and UI icons are static and ship from the same source, so they match trivially.

**Phase-2 forward-constraint.** None. New beverage types/icons in later phases are additive to the source set. The snapshot model already stores `iconKey` + `iconColor` on each entry, so historical rendering stays stable regardless of later icon edits.

**Confidence & evidence.** High for the pipeline shape (SVG→vector toolchains are standard on both platforms). Medium-specific on the exact iOS vector path (asset-catalog vector vs PDF vs runtime path) — that's a per-platform stack-doc decision; this doc's load-bearing claim is the single source + shared tint math, which is platform-independent. The HSL offset must be pinned to one definition (see Rulebook) because "HSL ±15%" is under-specified until the colour space, rounding, and clamp behaviour are fixed.

---

## D4 — Shared-computation parity mechanism (the biggest behavioural risk)

- **Status:** Proposed
- **Area:** shared-computation
- **Constraint(s) addressed:** C4 (BAC, pace/recommended-volume, hydration goal, username validation, day-boundary bucketing must be bit-for-bit comparable across platforms)

**Decision.** Specify each C4 algorithm **once, in a language-neutral algorithm spec** (prose + pseudocode + the exact rounding/unit rules from the Parity Rulebook), and back it with a **shared golden-file test-vector suite**: a set of versioned JSON fixtures (`inputs → expected outputs`) committed in the shared repo, which **both** the iOS test suite (XCTest/Swift Testing) and the Android test suite (JUnit/Kotlin) load and assert against. The design docs' worked examples — notably the **BAC 0.362 g/L** two-beer example and the **2100 ml** default-goal example — become the seed fixtures. A feature's two implementations are "done" only when both pass the identical fixture set. **Implement-twice-against-shared-vectors is preferred over Kotlin Multiplatform** for Phase 1.

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| Language-neutral spec + shared golden test vectors, implemented twice | ✅ chosen | Keeps the two-native-codebases constraint intact; the *behaviour* (not the code) is shared; fixtures are CI-gating so drift is impossible to merge; cheap, no new runtime/toolchain. |
| Kotlin Multiplatform shared `:computation` module (pure logic only) | ⚠️ viable, deferred | KMP for *business logic* is production-stable (since Nov 2023, used by Netflix/Cash App). Would guarantee identical code. But it injects a Kotlin/Native toolchain, a `.framework` build step, and Swift-interop surface into the iOS build for a *small* set of pure functions — cost > benefit at Phase 1 scope. Re-evaluate if C4 grows. |
| Implement twice with *no* shared vectors | ❌ rejected | This is the status quo that produces drift; the BAC chain alone (Watson/Widmark branch, meal min-modifier, orphan `t_zero`, rounding) has dozens of divergence points. Unacceptable for the highest-risk surface. |
| Port a third-party BAC/units library per platform | ❌ rejected | Two different libraries = two different rounding/model choices; defeats parity and the spec is already fully defined in `design/`. |

**Rationale.** C4 is called out as "the highest parity risk surface," and the BAC algorithm proves it: grams-of-alcohol → data-driven Watson-vs-Widmark branch → meal modifier (exponential decay, **min** across meals) → zero-order elimination (β=0.15) → per-drink summation → g/L→mmol/L (×21.7), plus the unspecified-gender conservative path, the BMI-range warning thresholds, the orphan `t_zero` absorption rule, and lazy 12-hour auto-end. Every one of those is a place two hand-written implementations can silently disagree. A *shared test vector suite* makes disagreement a **failing build** rather than a production bug, while respecting the load-bearing "no shared application code" rule — we share *test data and a spec*, not source. KMP would also solve it (and is genuinely production-ready for pure logic in 2026), but it pulls a Kotlin/Native framework and Swift-interop layer into the iOS app for a handful of pure functions; that's a real toolchain and forward-constraint cost for a Phase-1 scope where the function set is small and fully specified. The pragmatic call is: **spec + vectors now; revisit KMP only if the shared-computation surface grows enough that maintaining two implementations becomes the larger cost.**

**Fixture format.** One directory per algorithm, versioned, each fixture a small JSON object of `{ "name", "inputs", "expected" }` with the *exact* canonical values (metric, g/L, integer minor units) — never platform-formatted strings. Example:

```json
// vectors/bac/watson_two_beers.json
{
  "name": "Worked example — 75kg/180cm/30y male, 2×250ml @5% ABV, no meal",
  "spec_ref": "party-session.md#worked-example-sanity-check",
  "inputs": {
    "profile": { "gender": "male", "weightKg": 75, "heightCm": 180, "ageYears": 30 },
    "drinks": [
      { "volumeMl": 250, "abvPercent": 5.0, "consumedAtOffsetMin": 0 },
      { "volumeMl": 250, "abvPercent": 5.0, "consumedAtOffsetMin": 0 }
    ],
    "meals": [],
    "betaGperLh": 0.15,
    "atOffsetMin": 0
  },
  "expected": {
    "model": "watson",
    "alcoholGramsPerDrink": 9.86,
    "totalAlcoholGrams": 19.73,
    "tbwLitres": 43.93,
    "bacInitialGperL": 0.362,
    "bacMmolPerL": 7.85
  }
}
```

```json
// vectors/goal/default_70kg.json
{ "name": "Default goal for 70kg", "inputs": { "weightKg": 70 }, "expected": { "dailyGoalMl": 2100 } }
```

```json
// vectors/username/structural_rules.json
{ "name": "Leading dot rejected", "inputs": { "raw": ".alice" }, "expected": { "valid": false, "reason": "must_start_with_letter_or_digit" } }
```

The suite must publish, per algorithm, the **agreed numeric tolerance** (see Rulebook — most outputs are exact after the specified rounding; intermediate floats compare to a stated epsilon). Both platforms run the *same* files via a tiny per-platform loader; adding a fixture is a one-file PR that both apps pick up.

**Parity implication.** This *is* the behavioural-parity mechanism. As long as both test suites are CI-gating on the shared fixtures, the two implementations cannot diverge on any covered input without a red build. Coverage is the risk: the fixtures must exercise every branch (Watson vs Widmark, each gender path incl. unspecified→conservative, meal min-modifier with ≥2 meals, orphan absorbed vs decayed, day-boundary edges, every username rule). Uncovered branches are the only place drift can hide — so coverage is itself a governance checklist item (D5).

**Phase-2 forward-constraint.** None negative, and a positive: the spec+vectors approach keeps the door open to *later* extracting a KMP module if Phase 2 grows the shared logic, because the vectors already define the contract that module must satisfy. Choosing KMP now would be the heavier-to-reverse decision.

**Confidence & evidence.** High. Golden-file/test-vector parity is a standard technique for keeping independent implementations honest (used across language ports, crypto, codecs). KMP-for-business-logic production-readiness in 2026 is confirmed (stable since Nov 2023; Netflix/Cash App/McDonald's in production; Swift export still experimental, targeting stable 2026) — which is *why* it's kept as a credible deferred option rather than dismissed. Verified June 2026 via kotlinlang.org and KMP production-readiness write-ups.

---

## D5 — Parity governance (process + rulebook)

- **Status:** Proposed
- **Area:** design-system / shared-computation
- **Constraint(s) addressed:** C4, C5, C6 and the parity contract (README)

**Decision.** Adopt a lightweight, enforced parity process: (1) a **per-feature parity checklist** that both platform PRs must satisfy before a feature is "done"; (2) the shared **Parity Rulebook** (appendix) as the canonical source for every rounding, unit-conversion, formatting, and boundary rule; (3) **shared naming conventions** so token names, fixture names, and a11y label keys read identically across repos; (4) **CI gating on the shared test vectors (D4)** so behavioural drift can't merge.

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| Per-feature checklist + shared rulebook + CI-gated vectors | ✅ chosen | Cheap, explicit, and turns "are they the same?" from a judgment call into a checklist + a green build. |
| Trust two teams to keep parity by communication | ❌ rejected | Parity is the README's first-class concern; informal sync is exactly how rounding/locale rules silently diverge. |
| Single shared design-system team owning both implementations | ⚠️ org-dependent | Helps, but doesn't remove the need for the checklist/rulebook/vectors; orthogonal to this decision. |

**Per-feature parity checklist (definition of done for any user-facing feature).**

- [ ] Visual tokens used come from generated artifacts (D1) — no hand-coded colours/spacing/radii/durations.
- [ ] Typography uses a scale token + correct `tnum` state for any live numerics (D2).
- [ ] Any C4 computation is covered by shared test vectors, and **both** suites are green on them (D4).
- [ ] Every rounding/unit/format/boundary touched is the one in the Parity Rulebook (appendix) — no ad-hoc rounding.
- [ ] Accessibility: every interactive element has a label (from the shared label-key list); state is never colour-only; dynamic type tested at min and max; VoiceOver/TalkBack pass.
- [ ] Dark mode: both light and dark token pairs verified; emerald appears **only** on Party surfaces.
- [ ] Motion: uses the shared duration/easing tokens; reduce-motion fallback present.
- [ ] Copy strings (notification phrasings, glass formatting, disclaimers) match the spec sets verbatim.
- [ ] Screenshot diff (iOS vs Android) reviewed for the feature's key screens; deliberate divergences (native nav idioms) noted.

**Rationale.** The README makes parity a first-class engineering concern; a process is what operationalises that. The rounding/unit rules are the easiest things to diverge on (is the goal rounded with round-half-up or banker's rounding? is mmol/L ×21.7 rounded to 2 dp before or after display?), so pulling them into one copy-pasteable rulebook both teams implement verbatim is the highest-leverage governance act. CI-gating the vectors is what makes the behavioural half non-negotiable rather than aspirational.

**Parity implication.** This is the connective tissue: D1–D4 produce shared artifacts/specs; D5 ensures they're actually *used* and verified per feature on both sides.

**Phase-2 forward-constraint.** None. The checklist extends naturally to sync/accounts features in Phase 2.

**Confidence & evidence.** High — this is process, not technology; the only risk is enforcement discipline, which CI-gating mitigates.

---

## Accessibility parity (narrative)

The C5 a11y rules are non-negotiable on both platforms; the parity strategy is to **specify them once and check them per-platform**, not to re-derive them independently.

- **Labels:** maintain a **shared list of accessibility-label keys** (one logical label per interactive element — `log_drink_button`, `progress_card`, `status_pill`, `bac_value`, etc.) so both apps wire the *same semantics*, even though iOS sets them via `accessibilityLabel`/SwiftUI `.accessibilityLabel` and Android via `contentDescription`/Compose `semantics`. The label *text* is spec'd; the API differs.
- **Dynamic type / font scaling:** covered by D2 — both apps honour the system size at every step; the checklist requires testing at the smallest and largest system sizes for layout breakage.
- **Colour-never-sole-signal:** enforced at the *token + component* level — every colour-encoded state ships with a paired non-colour signal that is part of the component spec, not left to each platform: the status pill carries a **text label** (`On pace`/`Behind`/`Ahead`), goal-met carries an **icon + text** alongside the colour, and below-goal history bars carry a **non-colour pattern/marker** in addition to the colour. Because honey (brand) and the behind-pace amber are both warm, the behind-pace state *must* lean on its label/icon, not hue alone — this is a specific parity trap and is called out in the Rulebook.
- **VoiceOver / TalkBack:** end-to-end screen-reader passes are a per-feature checklist item (D5); the shared label keys keep the spoken experience equivalent.
- **Pace marker & high-contrast:** the pace tick uses a non-fill-colour treatment visible against both fill states; high-contrast users get strengthened contrast on bar fill, tick, and pill — these are the load-bearing glanceable elements and are spec'd as token variants, not per-platform guesses.

The parity check for a11y is the checklist item plus the shared label-key list; divergence shows up as a missing or differently-keyed label.

## Dark mode parity & the emerald-quarantine rule (narrative)

Light and dark both ship at v1, following the system setting (C5). Parity here is a direct consequence of D1: **every colour token is authored as a light+dark pair**, and Style Dictionary emits an iOS colour *set* (asset catalog's native light/dark variants) and an Android `values/` + `values-night/` pair from the same JSON. Neither platform hand-picks dark values, so they match by construction. The check is: no colour literal appears outside the generated artifacts.

The **emerald-quarantine rule** ("azure + honey mix freely across hydration UI; emerald/mint is confined to Party Mode and never appears on Today, History, or Settings") is enforced structurally rather than by vigilance:

- Emerald lives in a **separate token namespace** (e.g. `color.party.*`) distinct from the general accent tokens.
- A **lint/grep CI check** in each repo fails the build if a `color.party.*` token (or the emerald hex) is referenced from a non-Party screen module. This is the same mechanism on both platforms (a path-scoped token-usage check), so the rule can't be honoured on one platform and broken on the other.
- The one sanctioned exception — mint accents permitted in the **goal-met celebration confetti** — is an explicit allowlist entry, documented so it isn't mistaken for a quarantine breach.

Dark-mode behaviour of the Party emerald accent (depth shift vs mint surface tint) is an open *design* question (see brief); whatever the designer picks becomes a token pair and inherits the same generated-parity guarantee.

---

## Appendix — Parity Rulebook

Concrete, copy-pasteable rules both platforms **must** implement identically. Numbers are pulled from the design docs; the source is cited. Implement these verbatim; cover each with a shared test vector (D4). All computation is in **metric / canonical units**; formatting is applied only at the display boundary.

### Rounding & numeric rules

| Rule | Exact behaviour | Source |
| ---- | --------------- | ------ |
| **Hydration goal** | `dailyGoalMl = round_to_nearest(30 × weightKg, 100)`. 70 kg → 2100 ml. Round-half logic must be pinned (use round-half-up on the ml value; document and vector the .50 boundary, e.g. 65 kg → 1950 → **2000**). | data-model §UserPreferences; user-experience S5; C4 |
| **Recommended volume (glasses)** | `glasses_rounded = round(glasses_raw × 2) / 2` (nearest 0.5), then `clamp(_, 0.5, 2.0)`. Minimum 0.5 even when on/ahead of pace; maximum 2.0. | notifications §Recommended volume; C4 |
| **Expected intake / pace** | `elapsed_active_min = max(0, min(active_window_min, t_now − active_start))`; `expected_intake_ml = goal_ml × (elapsed_active_min / active_window_min)`. Same formula drives the Today pace tick and the reminder deficit. | notifications §Recommended volume; user-experience S1 |
| **BAC: grams of alcohol** | `alcohol_grams = volume_ml × (abv_percent / 100) × 0.789`. (ethanol density 0.789 g/mL) | party-session Step 1 |
| **BAC: Watson TBW** | male: `2.447 − 0.09516×age + 0.1074×height_cm + 0.3362×weight_kg`; female/unspecified: `−2.097 + 0.1069×height_cm + 0.2466×weight_kg`. `age_years = floor((today − birthDate)/365.25)`. | party-session Step 2 |
| **BAC: Widmark r** | r = 0.68 male, 0.55 female, **0.55 unspecified (conservative)**. Used only when height missing. | party-session Step 2 |
| **BAC: initial (Watson)** | `(alcohol_grams × 0.806) / TBW_L × meal_modifier`. (0.806 = water fraction of whole blood) | party-session Step 3 |
| **BAC: initial (Widmark)** | `alcohol_grams / (weight_kg × r) × meal_modifier`. | party-session Step 3 |
| **Meal modifier** | per meal: if `Δt<0` → 1.00; else `1.00 − (1.00 − peak) × exp(−Δt/τ)`. peak/τ: small 0.95/1.5h, medium 0.85/2.5h, large 0.75/3.5h. Across meals take **min**. Clamp implicitly in [peak, 1.00]. | party-session §Meals |
| **BAC: elimination** | `BAC(t) = max(0, BAC_initial − β × (t − t_drink))`, β = **0.15 g/L per hour**. Sum per-drink contributions at current time. | party-session Steps 4–5 |
| **BAC → mmol/L** | `mmol_per_L = g_per_L × 21.7`. g/L is canonical; mmol/L is display-only. | party-session Step 6; C4 |
| **Orphan absorption** | per orphan: `t_zero = consumedAt + BAC_initial / β`; absorb iff `t_zero > new session startedAt`, else stays decayed orphan. | party-session §Absorbing orphan drinks |
| **Session auto-end** | `endedAt = (most recent in-session alcoholic drink's consumedAt, or startedAt if none) + 12h`. Set to the exact 12h mark, **not** discovery time; computed lazily. | party-session §Auto-end; data-model |
| **Approaching-cap trigger** | fires when a logged drink pushes estimated BAC past **80%** of `bacCapGramsPerL`. | party-session §BAC goal |
| **Two-shade icon tint** | silhouette = `iconColor`; inner detail = `iconColor` with **HSL lightness offset ±15%**, computed in a pinned colour space (sRGB→HSL), lightness clamped to [0,100], converted back and hex-formatted lowercase. Direction of the ±15% (lighten vs darken) must be one fixed rule (e.g. lighten if base L<50 else darken) so both platforms pick the same second shade. | designer-brief §Iconography; features F14; C5 |

> **Unspecified gender** uses the **female** factor/coefficients throughout (conservative = higher estimate), and the BAC display shows the explanatory footnote. **BMI warning** (Watson path only): warn if BMI<17 (any), BMI>67 male, BMI>80 female/unspecified. Warning is informational; the estimate still displays. (party-session §Required inputs, Step 2.)

### Unit-conversion & money rules

| Rule | Exact behaviour | Source |
| ---- | --------------- | ------ |
| **Storage unit** | All persisted values metric: `volumeMl`, `weightKg`, `heightCm`, BAC in g/L. No per-record unit field. | data-model §Units |
| **Imperial display** | Conversion to fl oz / lb / in happens **only at the UI layer**, gated by `unitsDisplay`. Algorithms never see imperial. Imperial→metric→imperial round-trip may lose minor precision (accepted). | data-model §Units |
| **Money storage** | Integer **minor units** (cents for EUR/USD, pence for GBP). Major value = `priceMinor / 100`. No floats in totals. | data-model §Currency |
| **No FX conversion** | Currencies never converted. Mixed-currency aggregations shown **grouped** (`€42.50 + £8.00`), never summed. Symbols: EUR→€, USD→$, GBP→£. | data-model §Currency |
| **Currency symbol position & decimal separator** | Follow **device locale** conventions, not the currency. (So formatting may legitimately differ by device locale — this is the one place display is allowed to differ; the *amount* must not.) | data-model §Currency; C6 |
| **Token money-equivalent** | Only shown if `tokenValueMinor` set on the session; otherwise token spend is not summed in money. | party-session §Pricing |

### Boundary, time & validation rules

| Rule | Exact behaviour | Source |
| ---- | --------------- | ------ |
| **Day boundary** | Default **05:00 local**, configurable. Daily totals, history buckets, reminder pacing, and goal tracking all key off the same day-window. A drink's day = the window `[dayBoundary, next dayBoundary)` containing its `consumedAt` (local). | data-model; notifications; C1/C4 |
| **Active hours** | Default **08:00–22:00 local**. Reminder interval default **90 min**. | notifications §Configuration |
| **Inactive-user silence** | `last_engagement = max(latestDrink.consumedAt, installedAt)`; `days_inactive = floor((now − last_engagement)/1 day)`; suppress **all** notifications if `days_inactive ≥ 7`. Evaluated at fire-time on-device. | notifications §Inactive-user silence |
| **Reminder fire predicate** | All true: reminders enabled + permission; not inactive; within active hours; intake **< goal** today; ≥ interval since last log. Recompute recommended volume **at delivery time**. | notifications §Behaviour; C2 |
| **Inactivity reminder** | Fires at **noon (12:00 local)**, snapped to active-hours start if noon is outside; once/day; only if zero drinks logged today; subject to silence rule. | notifications §Notification types |
| **Weekly summary** | **Sunday 20:00 local**, snapped into active hours; once/week; **ISO week** (Mon–Sun); subject to silence rule. | notifications §Notification types |
| **Username length** | 3–30 characters (after NFC normalisation). Same whitelist applies to `DrinkPreset.name` (3–30) and `tokenName` (1–30). | data-model §Username rules |
| **Username allowed chars** | Unicode letters `L*` + ASCII digits `0–9` + connectors `_ - .`. | data-model §Username rules |
| **Username disallowed** | Control `Cc`, format `Cf` (incl. zero-width / bidi), surrogates `Cs`, private-use `Co`, unassigned `Cn`, all whitespace, emoji/symbols `So`/`Sk`, unattached combining marks `Mn`/`Mc`. | data-model §Username rules |
| **Username structure** | Must **start** with a letter or digit; must **end** with a letter or digit (not `_ - .`). | data-model §Username rules |
| **Username normalisation** | **NFC-normalise before storing**; validate against the normalised form. | data-model §Username rules |
| **Glass-count copy formatting** | 0.5 → `half a glass`; 1 → `a glass`; 1.5 → `1.5 glasses`; 2 → `2 glasses`. Noun follows the default drink's **beverage type** ("of water"/"of tea"), never the preset display name. | notifications §Glass formatting |
| **BAC display** | Always labelled an **estimate**; g/L primary, mmol/L secondary; persistent disclaimer while a session is active; cap never framed as a safety/legal line. | party-session §Important; §Display units |

### Non-colour-signal rules (a11y, must match both platforms)

| State | Required non-colour signal | Source |
| ----- | -------------------------- | ------ |
| On pace / Behind / Ahead | **Text label** in the status pill (not colour alone) | designer-brief §Accessibility; user-experience S1 |
| Goal met | **Icon + text label** alongside the colour change | designer-brief §Accessibility |
| History bar below daily goal | **Non-colour pattern/marker** in addition to colour | C3; designer-brief §Colour |
| Behind-pace amber vs honey CTA | Must be distinguishable by **label/icon**, since both are warm hues | designer-brief §Colour |
| Pace tick on progress bar | **Non-fill-colour treatment**, visible against both fill states | designer-brief §Layout primitives |

---

### Source verification notes (June 2026)

- **Style Dictionary v4** — current, actively co-maintained; built-in iOS-swift + Android transforms; DTCG-forward-compatible. **DTCG Format Module** reached first stable version **2025.10** (Oct 2025). (styledictionary.com; w3.org/community/design-tokens)
- **DM Sans** — SIL OFL-1.1; 2023 variable font (weight 100–700 + `opsz`); exposes tabular-figures (`tnum`) OpenType feature. Confirm the shipped build includes `tnum` glyphs at integration. (Google Fonts; googlefonts/dm-fonts)
- **Kotlin Multiplatform (business logic)** — production-stable since Nov 2023 (Netflix/Cash App/McDonald's); kept as a deferred option for the shared-computation layer only, not for UI; Swift export still experimental, targeting stable in 2026. (kotlinlang.org)
