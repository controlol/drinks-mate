# Design System & Parity Rulebook

Drinks Mate is a **single Flutter codebase**, so the visual layer is drawn once from one widget tree and is identical across iOS and Android by construction. This document defines the **design-system source of truth** (tokens → one Flutter `ThemeData`, DM Sans, the icon pipeline) and the **[Parity Rulebook](#appendix--parity-rulebook)** — the canonical spec of every rounding, unit, boundary, and formula constant the implementation must follow. It is written against [phase-1-constraints.md](../phase-1-constraints.md) (especially C4, C5, C6) and the [engineering README](../README.md). The C4 computation itself lives in the pure-Dart `core` package — see [flutter-stack.md → D7](./flutter-stack.md#d7--shared-computation-dependency-free-pure-dart-core-package).

## Decisions at a glance

| # | Decision | Choice | Confidence |
| - | -------- | ------ | ---------- |
| D1 | Design tokens as single source of truth | **DTCG-format JSON tokens** → generated Dart `ThemeData` (colour light/dark pairs, spacing, radii, type scale, motion) | High |
| D2 | Typography | **DM Sans** (OFL-1.1 variable font) bundled in the app; `tnum` tabular figures forced for headline numerics; honours OS text scaling | High |
| D3 | Icon & illustration asset pipeline | **One source SVG set**; runtime two-shade tinting from single `iconColor` via HSL ±15% math in `core`; rendered with flutter_svg | High |
| D4 | Computation source of truth | **One pure-Dart `core` package**; design worked-examples are regression unit tests | High |
| D5 | Design-system governance | **Per-feature checklist + the Parity Rulebook** (rounding/units/boundaries) as the canonical numeric spec | High |
| — | Accessibility | One `Semantics` tree; shared label-key list; colour never the sole signal | High |
| — | Dark mode + emerald quarantine | Light/dark token pairs in `ThemeData`; emerald is a Party-only token namespace, lint-enforced | High |

---

## D1 — Design tokens as the single source of truth

- **Status:** Proposed
- **Area:** design-system
- **Constraint(s) addressed:** C5 (colour, typography, motion, spacing), C6 (localisation/format follow device but tokens are device-neutral)

**Decision.** Author all visual primitives — colour (azure / honey / emerald + the semantic palette, each as a **light+dark pair**), spacing scale, corner radii, the type scale, elevation, and motion specs (durations + easing curves) — as **DTCG-format JSON token files**, and generate a **Dart token/theme file** from them (via Style Dictionary's Dart/Flutter output or a small codegen step) that builds the app's `ThemeData` (light and dark). Tokens are generated, never hand-typed in widgets.

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| DTCG JSON tokens → generated Dart theme | ✅ chosen | One declarative source for colour/spacing/type/motion; the design handoff stays tool-neutral (DTCG is a stable W3C format); a token change is one edit that flows into `ThemeData`. |
| Hand-authored Dart theme constants only | ⚠️ acceptable | Simpler with no build step, but loses the tool-neutral token source the designer can own; fine as a fallback if the codegen proves heavy. |
| Figma-plugin-only export (e.g. Tokens Studio direct-to-code) | ❌ rejected as primary | Couples the build to a design-tool plugin and a manual export; fine as an *input* feeding the JSON, but the committed JSON must be the source of truth so CI owns it, not a person. |
| Magic numbers scattered in widgets | ❌ rejected | No single source; the bespoke palette/scale drifts the first time someone hard-codes a hex. |

**Rationale.** The brief fixes DM Sans and a single colour system *specifically* to keep the look coherent (C5). Tokens make that real: "azure-500 light = #xxxxxx / dark = #yyyyyy" is authored once and compiled into the Flutter theme, so light/dark and the whole scale come from one place. Motion tokens (duration + cubic-bezier control points) live here too, which is what makes "calm ease-in-out, no bounce" a spec rather than a guess — Flutter maps the curve onto its animation API from those numbers. The DTCG token format reached its first stable version (2025.10) in October 2025, so the authoring format is not a moving target.

**Parity implication.** None to enforce — one theme drives the one app. (The token source is also the easiest review surface: a colour change is a single JSON diff.)

**Phase-2 forward-constraint.** None negative. Phase 2 adds no visual surface the token model can't absorb; new tokens are additive, and any rebrand or themed surface is a JSON edit.

**Confidence & evidence.** High. DTCG format hit first stable (2025.10) per the W3C Design Tokens Community Group; Style Dictionary v4 is current, actively maintained, and can emit Dart/Flutter output. Verified June 2026.

---

## D2 — Typography (DM Sans + scaling behaviour)

- **Status:** Proposed
- **Area:** design-system
- **Constraint(s) addressed:** C5 (DM Sans, tabular figures for headline numerics, dynamic type at every size), C6 (locale formatting)

**Decision.** Bundle **DM Sans** (SIL OFL-1.1, the 2023 variable font: weight axis 100–700 + optical-size `opsz` axis) as a Flutter asset (declared in `pubspec.yaml`). Define the type scale as tokens (D1) and expose them through the `ThemeData` `TextTheme`. For the headline numerics — the Today intake value and the Party BAC value — **force the OpenType tabular-figures feature** via `TextStyle(fontFeatures: [FontFeature.tabularFigures()])` so digits are fixed-width and don't jitter when the value changes. Honour the OS text-size setting through `MediaQuery.textScaler` (the Flutter default) so type scales at every accessibility size.

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| Bundle DM Sans + explicit tabular figures | ✅ chosen | One open-source family gives the intended typographic identity; tabular figures are an explicit C5 requirement; OFL-1.1 permits embedding/redistribution. |
| Use the platform system font (SF Pro / Roboto) | ❌ rejected | Violates C5; the brief chose DM Sans for a specific "big numeric" feel the system fonts don't give. |
| DM Sans but default (proportional) figures | ❌ rejected | Proportional digits make the headline value shift horizontally as it changes (`1.4 L`→`1.1 L`), which the brief rules out for the display numerics. |
| Static per-weight DM Sans files instead of the variable font | ⚠️ acceptable fallback | Works if variable-font + `opsz` handling is awkward, but multiplies bundle size; prefer the variable font. |

**Rationale.** Tabular figures matter because the intake and BAC numbers update live; without fixed-width digits the value visibly jumps. Honouring `textScaler` rather than fixed pixel sizes satisfies the non-negotiable "dynamic type at every system size" rule. The type scale is a token (D1), so the base sizes have one source.

**Parity implication.** None — one font, one theme, one set of feature flags.

**Phase-2 forward-constraint.** None. Localisation is explicitly later (C6/L4); DM Sans covers Latin well and can be extended per-script later without changing the scale model.

**Confidence & evidence.** High. DM Sans is OFL-1.1 (embedding/redistribution permitted) and the 2023 variable version exposes weight + `opsz` axes and the tabular-figures feature; Flutter supports `FontFeature.tabularFigures()` and `MediaQuery.textScaler`. Verified June 2026 via Google Fonts and the googlefonts/dm-fonts repo. Confirm at integration that the shipped DM Sans build includes `tnum` glyphs (a historical upstream gap); pin a build that has it.

---

## D3 — Icon & illustration asset pipeline

- **Status:** Proposed
- **Area:** icons / design-system
- **Constraint(s) addressed:** C5 (drink icons two-shade runtime-tinted from single `iconColor` via HSL ±15%; ~25 UI icons + illustrations as one visual family)

**Decision.** Maintain **one master set of source SVGs** (the ~10 drink icons, ~25 UI icons, and the illustrations) as the single authoring source, rendered with **flutter_svg** (or precompiled `vector_graphics`). The **two-shade drink-icon tint is computed at render time from the single `iconColor`** using one **HSL lightness-offset function** (±15%) in the `core` package: the silhouette uses `iconColor`, the inner detail uses `iconColor` with lightness shifted by the fixed offset, clamped. The exact HSL conversion and offset are pinned in the [Parity Rulebook](#appendix--parity-rulebook). UI icons and illustrations are static (non-tinted or single-tinted) and ship from the same source. See the rendering decision in [flutter-stack.md → D6](./flutter-stack.md#d6--drink-icon-two-shade-tinting-flutter_svg--runtime-hsl-in-dart).

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| One source SVG set + shared tint math in `core` | ✅ chosen | Single authoring source; vectors scale crisply at 24–32 px; runtime tint matches C5's "derived at render time, not pre-baked" requirement. |
| Pre-baked PNG/raster assets per colour | ❌ rejected | The colour is user-chosen (any-colour picker) — pre-baking is impossible; also non-vector. |
| Pre-baked two-shade SVGs per beverage default colour | ❌ rejected | Breaks the "any colour" requirement and the single-`iconColor`-derives-both-shades rule. |

**Rationale.** C5 is specific: both shades must be *derived at render time* from one `iconColor` via an HSL ±15% lightness offset. Putting the offset math in `core` and rendering with flutter_svg keeps geometry and colour in one place. The detail to confirm with the designer is that each drink icon is authored with **two clean subpaths** (silhouette / inner detail) so the two fills can be tinted independently.

**Parity implication.** None — one tint function, one renderer.

**Phase-2 forward-constraint.** None. New beverage types/icons are additive to the source set; the snapshot model stores `iconKey` + `iconColor` on each entry, so historical rendering stays stable.

**Confidence & evidence.** High for the pipeline shape; SVG rendering and HSL tinting are routine in Flutter/Dart. The HSL offset is pinned to one definition in the Rulebook because "HSL ±15%" is under-specified until the colour space, rounding, and clamp behaviour are fixed.

---

## D4 — Computation source of truth

- **Status:** Proposed
- **Area:** shared-computation
- **Constraint(s) addressed:** C4 (BAC, pace/recommended-volume, hydration goal, username validation, day-boundary bucketing)

**Decision.** Implement every C4 algorithm **once, in the pure-Dart `core` package** ([flutter-stack.md → D7](./flutter-stack.md#d7--shared-computation-dependency-free-pure-dart-core-package)), with the **exact rounding/unit rules from the [Parity Rulebook](#appendix--parity-rulebook)**. Back each with **unit-test fixtures** seeded by the design docs' worked examples — notably the **BAC 0.362 g/L** two-beer example and the **2100 ml** default-goal example — and add fixtures at every branch and rounding edge.

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| One `core` implementation + worked-example unit tests | ✅ chosen | Single source for the BAC chain, pace, goal, username rules, day-boundary math; cleanly testable; reused across the app. |
| Algorithms inline in view-models | ❌ rejected | Buries parity-critical math next to UI/IO and makes it hard to test in isolation. |
| Port a third-party BAC/units library | ❌ rejected | A library's rounding/model choices would diverge from the spec, which is already fully defined in `design/`. |

**Rationale.** C4 has many branch points — the Watson-vs-Widmark selection, the meal modifier (exponential decay, **min** across meals), zero-order elimination (β=0.15), per-drink summation, g/L→mmol/L (×21.7), the unspecified-gender conservative path, the BMI-range warning, the orphan `t_zero` absorption rule, and the lazy 12-hour auto-end. Each is a place a number can be subtly wrong. Implementing them once with the Rulebook's pinned rounding, and pinning each with a fixture, turns a wrong number into a failing test.

**Fixture format.** One group per algorithm, each fixture a small record of `{ name, inputs, expected }` with the *exact* canonical values (metric, g/L, integer minor units) — never display-formatted strings. Coverage is the thing to watch: exercise every branch (Watson vs Widmark, each gender path incl. unspecified→conservative, meal min-modifier with ≥2 meals, orphan absorbed vs decayed, day-boundary edges, every username rule) and the rounding edges (recommended-volume on a 0.25-glass boundary, BAC just above/below the 80%-cap threshold, the goal at a .50 ml boundary). Pin the order of operations and rounding points so results are stable.

**Parity implication.** None — one implementation.

**Phase-2 forward-constraint.** None negative — Phase 2 adds new pure functions (sync reconciliation) to the same package.

**Confidence & evidence.** High. Pure-package + unit-test is standard Dart practice; the worked numbers to seed the tests already exist in the design docs.

---

## D5 — Design-system governance

- **Status:** Proposed
- **Area:** design-system / shared-computation
- **Constraint(s) addressed:** C4, C5, C6

**Decision.** Keep the design system honest with (1) a **per-feature checklist** every feature PR satisfies before it is "done"; (2) the **Parity Rulebook** (appendix) as the canonical source for every rounding, unit-conversion, formatting, and boundary rule; (3) **CI-gated `core` unit tests** so a computation regression can't merge.

**Per-feature checklist (definition of done for any user-facing feature).**

- [ ] Visual values come from tokens / `ThemeData` (D1) — no hard-coded colours/spacing/radii/durations.
- [ ] Typography uses a scale token + correct tabular-figures state for any live numerics (D2).
- [ ] Any C4 computation is covered by `core` unit tests, and they're green (D4).
- [ ] Every rounding/unit/format/boundary touched is the one in the Parity Rulebook (appendix) — no ad-hoc rounding.
- [ ] Accessibility: every interactive element has a `Semantics` label (from the shared label-key list); state is never colour-only; text tested at the smallest and largest system sizes; VoiceOver/TalkBack pass.
- [ ] Dark mode: both light and dark token pairs verified; emerald appears **only** on Party surfaces.
- [ ] Motion: uses the shared duration/easing tokens; reduce-motion fallback present.
- [ ] Copy strings (notification phrasings, glass formatting, disclaimers) match the spec sets verbatim.

**Rationale.** The rounding/unit rules are the easiest things to get subtly wrong (is the goal rounded half-up or banker's? is mmol/L ×21.7 rounded before or after display?), so pulling them into one copy-pasteable rulebook the implementation follows verbatim is the highest-leverage governance act. CI-gating the `core` tests makes the numeric half non-negotiable rather than aspirational.

**Parity implication.** This is the connective tissue: D1–D4 produce the source of truth; D5 ensures it's actually *used* and verified per feature.

**Phase-2 forward-constraint.** None. The checklist extends naturally to sync/accounts features in Phase 2.

**Confidence & evidence.** High — this is process, not technology; the only risk is enforcement discipline, which CI-gating mitigates.

---

## Accessibility (narrative)

The C5 a11y rules are non-negotiable; Flutter drives both VoiceOver and TalkBack from one `Semantics` tree.

- **Labels:** maintain a **shared list of accessibility-label keys** (one logical label per interactive element — `log_drink_button`, `progress_card`, `status_pill`, `bac_value`, etc.) wired via the `Semantics` widget / `semanticsLabel`, so the spoken experience is defined in one place.
- **Dynamic type / font scaling:** covered by D2 — the app honours the system size via `textScaler`; the checklist requires testing at the smallest and largest sizes for layout breakage.
- **Colour-never-sole-signal:** enforced at the *component* level — every colour-encoded state ships with a paired non-colour signal that is part of the component: the status pill carries a **text label** (`On pace`/`Behind`/`Ahead`), goal-met carries an **icon + text** alongside the colour, and below-goal history bars carry a **non-colour pattern/marker**. Because honey (brand) and the behind-pace amber are both warm, the behind-pace state *must* lean on its label/icon, not hue alone — a specific trap called out in the Rulebook.
- **VoiceOver / TalkBack:** an end-to-end screen-reader pass is a per-feature checklist item (D5); the shared label keys keep the spoken experience equivalent on both OSes.
- **Pace marker & high-contrast:** the pace tick uses a non-fill-colour treatment visible against both fill states; high-contrast users get strengthened contrast on bar fill, tick, and pill — these are the load-bearing glanceable elements and are spec'd as token variants.

## Dark mode & the emerald-quarantine rule (narrative)

Light and dark both ship at v1, following the system setting (C5). Every colour token is authored as a **light+dark pair** (D1) and both `ThemeData` brightnesses are generated from them, so dark mode is not hand-picked.

The **emerald-quarantine rule** ("azure + honey mix freely across hydration UI; emerald/mint is confined to Party Mode and never appears on Today, History, or Settings") is enforced structurally:

- Emerald lives in a **separate token namespace** (e.g. `color.party.*`) distinct from the general accent tokens.
- A **lint/grep CI check** fails the build if a `color.party.*` token (or the emerald hex) is referenced from a non-Party screen module, so the rule can't quietly erode.
- The one sanctioned exception — mint accents permitted in the **goal-met celebration confetti** — is an explicit allowlist entry, documented so it isn't mistaken for a breach.

Dark-mode behaviour of the Party emerald accent (depth shift vs mint surface tint) is an open *design* question (see brief); whatever the designer picks becomes a token pair.

---

## Appendix — Parity Rulebook

Concrete, copy-pasteable rules the implementation **must** follow exactly. Numbers are pulled from the design docs; the source is cited. Implement these verbatim; cover each with a `core` unit test (D4). All computation is in **metric / canonical units**; formatting is applied only at the display boundary.

### Rounding & numeric rules

| Rule | Exact behaviour | Source |
| ---- | --------------- | ------ |
| **Hydration goal** | `dailyGoalMl = round_to_nearest(30 × weightKg, 100)`. 70 kg → 2100 ml. Round-half logic must be pinned (use round-half-up on the ml value; document and test the .50 boundary, e.g. 65 kg → 1950 → **2000**). | data-model §UserPreferences; user-experience S5; C4 |
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
| **Two-shade icon tint** | silhouette = `iconColor`; inner detail = `iconColor` with **HSL lightness offset ±15%**, computed in a pinned colour space (sRGB→HSL), lightness clamped to [0,100], converted back and hex-formatted lowercase. Direction of the ±15% (lighten vs darken) must be one fixed rule (e.g. lighten if base L<50 else darken). | designer-brief §Iconography; features F14; C5 |

> **Unspecified gender** uses the **female** factor/coefficients throughout (conservative = higher estimate), and the BAC display shows the explanatory footnote. **BMI warning** (Watson path only): warn if BMI<17 (any), BMI>67 male, BMI>80 female/unspecified. Warning is informational; the estimate still displays. (party-session §Required inputs, Step 2.)

### Unit-conversion & money rules

| Rule | Exact behaviour | Source |
| ---- | --------------- | ------ |
| **Storage unit** | All persisted values metric: `volumeMl`, `weightKg`, `heightCm`, BAC in g/L. No per-record unit field. | data-model §Units |
| **Imperial display** | Conversion to fl oz / lb / in happens **only at the UI layer**, gated by `unitsDisplay`. Algorithms never see imperial. Imperial→metric→imperial round-trip may lose minor precision (accepted). | data-model §Units |
| **Volume conversion** | **1 US fl oz = 29.5735295625 ml** (NIST). US fluid ounce used throughout (not UK imperial fl oz = 28.4130625 ml). `mlToFlOz` result rounded to **1 decimal place** (round-half-away-from-zero). `flOzToMl` result rounded to the **nearest millilitre**. | features F6; data-model §Units |
| **Mass conversion** | **1 kg = 2.20462262185 lb** (international avoirdupois pound). `kgToLb` result rounded to **1 decimal place**. `lbToKg` result rounded to **3 decimal places** (sub-gram accuracy for storage). | features F6; data-model §Units |
| **Height conversion** | **1 inch = 2.54 cm** (exact international definition). `cmToFtIn`: total inches = `round(cm / 2.54)` (nearest inch), then split into `feet = totalInches ÷ 12` and `inches = totalInches mod 12`. `ftInToCm` result rounded to **1 decimal place**. | features F6; data-model §Units |
| **Metric display precision** | Metric volume: round to the nearest **integer ml**. Metric mass: **1 decimal place** (kg). Metric height: **1 decimal place** (cm). | features F6; data-model §Units |
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
| **Username length** | 3–30 characters (after NFC normalisation). `tokenName` shares the same whitelist (1–30). | data-model §Username rules |
| **Username allowed chars** | Unicode letters `L*` + ASCII digits `0–9` + connectors `_ - .`. | data-model §Username rules |
| **Username disallowed** | Control `Cc`, format `Cf` (incl. zero-width / bidi), surrogates `Cs`, private-use `Co`, unassigned `Cn`, all whitespace, emoji/symbols `So`/`Sk`, unattached combining marks `Mn`/`Mc`. | data-model §Username rules |
| **Username structure** | Must **start** with a letter or digit; must **end** with a letter or digit (not `_ - .`). | data-model §Username rules |
| **Username normalisation** | **NFC-normalise before storing**; validate against the normalised form. | data-model §Username rules |
| **DrinkPreset name** | 3–30 characters. Allowed: Unicode letters `L*`, ASCII digits `0–9`, connectors `_ - .`, and **ASCII space** ` `. Must start and end with a letter or digit. Rejects control chars, zero-width, emoji, and other symbols. Spaces between words are permitted (e.g. "Glass of water"). Implemented as `validatePresetName()` in `core`. | data-model §DrinkPreset |
| **Glass-count copy formatting** | 0.5 → `half a glass`; 1 → `a glass`; 1.5 → `1.5 glasses`; 2 → `2 glasses`. Noun follows the default drink's **beverage type** ("of water"/"of tea"), never the preset display name. | notifications §Glass formatting |
| **BAC display** | Always labelled an **estimate**; g/L primary, mmol/L secondary; persistent disclaimer while a session is active; cap never framed as a safety/legal line. | party-session §Important; §Display units |

### Non-colour-signal rules (a11y)

| State | Required non-colour signal | Source |
| ----- | -------------------------- | ------ |
| On pace / Behind / Ahead | **Text label** in the status pill (not colour alone) | designer-brief §Accessibility; user-experience S1 |
| Goal met | **Icon + text label** alongside the colour change | designer-brief §Accessibility |
| History bar below daily goal | **Non-colour pattern/marker** in addition to colour | C3; designer-brief §Colour |
| Behind-pace amber vs honey CTA | Must be distinguishable by **label/icon**, since both are warm hues | designer-brief §Colour |
| Pace tick on progress bar | **Non-fill-colour treatment**, visible against both fill states | designer-brief §Layout primitives |

---

### Source verification notes (June 2026)

- **DTCG format** — the **Design Tokens Format Module** reached first stable version **2025.10** (Oct 2025). **Style Dictionary v4** is current and actively co-maintained and can emit Dart/Flutter output. (styledictionary.com; w3.org/community/design-tokens)
- **DM Sans** — SIL OFL-1.1; 2023 variable font (weight 100–700 + `opsz`); exposes the tabular-figures OpenType feature. Confirm the shipped build includes `tnum` glyphs at integration. (Google Fonts; googlefonts/dm-fonts)
- **Flutter** — `FontFeature.tabularFigures()`, `MediaQuery.textScaler`, and `Semantics` are stable first-party APIs; flutter_svg is the standard SVG renderer. (api.flutter.dev)
</content>
