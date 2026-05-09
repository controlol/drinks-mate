# Features

This document lists the functional scope of Drinks Mate, organised by phase. The phase boundary is described in [technical-architecture.md → Phasing](./technical-architecture.md#phasing): phase 1 must ship as a complete product on its own.

## Phase 1 — Local-only MVP

Phase 1 is the full product as far as a phase-1-only user is concerned. There is no account, no server, no social functionality, and no UI scaffolding that hints at unfinished phase 2 work.

### F1 — Log a drink

The user can record a drink by:

- Picking a **drink preset** (default or custom — see F14). The preset supplies name, beverage type, volume, ABV, icon, and optional price. The user can adjust volume or ABV before confirming.
- Adjusting the **time** of consumption. Defaults to "now"; the user can adjust to log retroactively.

Logging must be reachable in at most two taps from the home screen for the most common cases (e.g. tapping the "Glass of water" quick-log preset on the today view).

### F2 — Daily hydration goal

- The user has a daily intake goal expressed in millilitres.
- The goal is set during onboarding as part of profile creation (see [user-experience.md → S5 Onboarding](./user-experience.md#s5--onboarding-first-launch-only)). The onboarding flow pre-fills a **personalised suggestion** of `30 ml × weight_kg`, rounded to the nearest 100 ml — based on the clinical rule of thumb for adult daily water intake. For the default 70 kg user, this gives **2100 ml**. The user can accept the suggestion or override it.
- The user can change the goal in settings at any time after onboarding.
- Progress toward the goal resets at the **day boundary**, which is configurable in settings and defaults to **05:00 local time**. The day boundary applies to both goal tracking and reminder scheduling — see [notifications.md → Configuration](./notifications.md#configuration).
- The suggestion is informational only and does not constitute medical advice. Conditions like pregnancy, kidney disease, or specific clinical diets are not factored in.

### F3 — Today view

The home screen shows:

- Current intake total versus the daily goal (with a visual progress indicator).
- A list of drinks logged today, ordered by time, each showing beverage type, volume, and time.
- A primary action to log a new drink.
- Quick-log shortcuts: a small horizontal row of drink presets (see F14). Initially seeded with common defaults (e.g. Glass of water, Cup of coffee); over time the row promotes the user's most-used presets to the top.

The user can edit or delete an entry from the today view (e.g. logged the wrong size).

### F4 — History

The history view supports a **weekly** and **monthly** time-range selector with pagination (this week, last week, etc.). Each range renders a set of bar charts plus the existing per-day drill-down. All computation is local; no aggregation runs anywhere except on the device.

#### Hydration charts (always shown)

- **Hydration per day** — bar chart of total intake in litres for each day in the range, with the user's daily goal drawn as a horizontal reference line. Bars below the line are visually distinct from bars at or above it (using a non-colour signal too, per the accessibility rule in [user-experience.md → Accessibility](./user-experience.md#accessibility)).
- **Drinks per day** — bar chart of the total number of logged drinks per day in the range.

Both charts use the user's configured **day boundary** (default 05:00) for the per-day buckets, consistent with how the daily goal works.

#### Alcohol charts (shown only when relevant)

The alcohol charts appear only when the user has at least one `PartySession` whose window intersects the selected range. For users who never use Party Mode, history shows only the hydration charts.

- **Alcoholic drinks per day** — bar chart of the count of alcoholic drink entries per day.
- **Maximum estimated BAC per day** — bar chart of the daily peak of the BAC estimate, in g/L (with the user's cap drawn as a reference line if one is set, mmol/L shown alongside in tooltips). The peak is computed by sampling the BAC curve from the session(s) on that day; days with no session show no bar (not zero — to avoid implying the estimate ran and produced 0 g/L).
- **Session overlay** — both alcohol charts get a shaded background band under the time-axis range covered by each `PartySession` (`startedAt` to `endedAt`). On the weekly chart this is a horizontal band spanning the relevant days; on the monthly chart it is a per-day marker under days touched by a session. The overlay makes the visual link between "session was active" and "BAC + drink counts" explicit at a glance.

Maximum-BAC bars are clearly labelled as estimates everywhere they appear — same disclaimer rule as the live BAC display in [party-session.md → Important: this is an estimate](./party-session.md#important-this-is-an-estimate-not-a-measurement).

#### Day drill-down

Tapping any day on any chart drills into that day, showing total intake, goal, the drink list, and (when relevant) any `PartySession` summary including peak BAC, total alcoholic drinks, and meals logged.

### F5 — Reminder notifications

See [notifications.md → Notification types](./notifications.md#notification-types) for full detail. In short, phase 1 has four independently-toggleable notification types:

- **Hydration reminder** (default ON) — fires at the configured interval (default 90 min) during active hours (default 08:00–22:00) when the user is below goal and at least `interval` has passed since the last log. Recommends a specific volume in 0.5-glass increments, computed from the user's pace deficit (min 0.5 glass, max 2). Copy adapts when the previous reminder was missed (acknowledges the gap kindly without nagging). Reaching the goal cancels remaining same-day reminders. Notifications expose a **quick-log action** to log the user's default drink without opening the app.
- **Inactivity reminder** (default ON) — once-per-day, at noon local (snapped into active hours), when the user has logged nothing today and is not silenced by the inactive-user rule (≥ 7 days since the last engagement, where engagement is the most recent log or the install date — whichever is more recent). See [notifications.md → Inactive-user silence](./notifications.md#inactive-user-silence).
- **Weekly summary** (default ON) — once-per-week on Sunday 20:00 local, telling the user how many of the seven days they hit their goal (e.g. "5/7"). Tapping opens the History view scoped to the past week.
- **Party Mode notifications** (default OFF) — two opt-in notifications introduced by Party Mode (approaching cap, sober estimate). See [party-session.md → Notifications during a session](./party-session.md#notifications-during-a-session).

All notifications are scheduled locally on the device. Phase 1 has no push infrastructure. Anti-spam rules are baked in: no notification fires when it would be redundant (e.g. user just logged a drink, user already hit goal today, user dismissed without acting → no retry).

### F6 — Settings

The settings screen exposes every persisted preference. The canonical grouping, ordering, and labels live in [user-experience.md → S4 Settings](./user-experience.md#s4--settings). This is a functional summary; if anything here disagrees with S4, S4 wins.

1. **Hydration**
   - **Daily goal** — suggested during onboarding from `30 ml × weight_kg` rounded to the nearest 100 ml; 2100 ml for the default 70 kg user. Editable.
   - **Day boundary** — default 05:00 local time.
2. **Reminders** — see [notifications.md](./notifications.md).
   - Master on/off.
   - Active hours (default 08:00–22:00).
   - Interval (default 90 min).
   - Inactivity reminder toggle (default ON).
   - Weekly summary toggle (default ON).
   - **Default drink** — reference to one of the user's drink presets; restricted to non-alcoholic. Defaults to the seeded "Glass of water" preset. Used by the notification quick-log action and as the "glass" unit in the per-reminder recommended-volume calculation.
3. **Drinks**
   - **Manage drinks** — create, edit, hide, delete, and reorder drink presets (see F14).
4. **Profile** — used by the goal suggestion and the BAC algorithm in Party Mode. See [data-model.md → UserProfile](./data-model.md#userprofile).
   - Gender (male / female / unspecified).
   - Weight (kg).
   - Height (cm, optional).
   - Birthday (optional but required to use Party Mode).
5. **Party Mode**
   - Personal cap (g/L, optional).
   - "Approaching cap" notification toggle (default OFF).
   - "Sober estimate" notification toggle (default OFF).
   - **"Show BAC on lock screen"** toggle (default ON).
   - Reference legal limits (informational only).
6. **Display & format**
   - **Units** — **metric by default** (millilitres, kilograms, centimetres, °C). The user can switch the display to imperial (fl oz, lb, in, °F); conversion happens at the UI layer only. See [data-model.md → Units](./data-model.md#units).
   - **Currency** — `EUR` (default), `USD`, or `GBP`. Used as the default for new drink presets and as the display currency in single-currency aggregations. Existing presets and historical entries are never retroactively changed. See [data-model.md → Currency](./data-model.md#currency).
7. **About / version**.

### F7 — Local-first storage

- All data is stored in a **local database** on the device. See [data-model.md → Storage requirements](./data-model.md#storage-requirements).
- The app must be fully usable without an account and without a network connection.
- **No analytics or telemetry in phases 1 or 2.** Drinks Mate ships without any telemetry, crash reporting, or usage analytics in the early phases. This is a fixed product decision and not revisited until a later phase.
- The local database remains the on-device source of truth in phase 2 as well — sync layers on top of it, it does not replace it.

### F14 — Drink presets and customisation

Drink presets are named, pre-configured shortcuts that combine a beverage type, a volume, an ABV, an optional price, and an icon + colour. They are the **primary way the user enters drinks** — both via quick-log on the today view and via the log-drink screen.

#### Default presets (shipped with the app)

Seeded into the local database on first launch. The user can edit, hide, or delete them.

Non-alcoholic:

| Name                   | Beverage type | Volume | Icon       |
| ---------------------- | ------------- | ------ | ---------- |
| Glass of water         | water         | 200 ml | glass      |
| Bottle of water (0.5L) | water         | 500 ml | bottle     |
| Can of water (0.33L)   | water         | 330 ml | can        |
| Glass of tea           | tea           | 250 ml | mug        |
| Cup of coffee          | coffee        | 200 ml | mug        |
| Espresso               | coffee        | 30 ml  | small_cup  |
| Glass of juice         | juice         | 200 ml | glass      |
| Glass of lemonade      | soft_drink    | 200 ml | glass      |
| Glass of milk          | milk          | 200 ml | glass      |
| Alcohol-free beer (0.33L) | non_alcoholic_beer | 330 ml | beer_glass |

Alcoholic (visible only when Party Mode is active — see [party-session.md](./party-session.md)):

| Name                   | Beverage type | Volume | ABV | Icon       |
| ---------------------- | ------------- | ------ | --- | ---------- |
| Small beer (0.2L)      | beer          | 200 ml | 5%  | plastic_cup |
| Beer (0.33L)           | beer          | 330 ml | 5%  | beer_glass |
| Glass of wine          | wine          | 175 ml | 12% | wine_glass |
| Shot of spirit         | spirit        | 30 ml  | 40% | shot_glass |

The 200 ml beer reflects the typical festival pour, which is smaller than the standard café glass.

#### Custom presets

The user can create their own presets from settings (see F6). A custom preset has:

- **Name** — required, free text. Same character rules as username (3–30 chars, see [data-model.md → Username character rules](./data-model.md#username-character-rules)). `[OPEN]` — confirm length range for preset names; could be more permissive than usernames.
- **Beverage type** — required. Pick from the predefined list. Determines whether the drink contributes to hydration or BAC.
- **Volume (ml)** — required, must be > 0.
- **Alcohol percentage (ABV %)** — required for alcoholic beverage types, hidden / null for non-alcoholic.
- **Regular price** — optional. The user's normal-day "menu price" for this drink. Stored per-preset together with the **currency** in which the price was entered. The user's preferred currency (set in settings) is used as the default for new presets but is per-preset and per-entry on the record. Phase 1 supports `EUR`, `USD`, and `GBP`. The app does not convert between currencies and does not track exchange rates — see [data-model.md → Currency](./data-model.md#currency). Price + currency are copied to each `DrinkEntry` at log time so historical totals stay accurate even if the preset or the user's preferred currency changes later. Per-session override prices (festival / party prices) live separately on the session — see [F12 — Party Session](#f12--party-session-opt-in) and [party-session.md → Pricing during a session](./party-session.md#pricing-during-a-session).
- **Icon** — picked from the bundled set of SVG icons (see below).
- **Icon colour** — picked from a small palette of brand-friendly colours; an "any colour" picker is also available.

#### Icons

The app ships a set of simple monochrome SVG icons that can be tinted at render time:

`glass`, `bottle`, `can`, `mug`, `small_cup`, `wine_glass`, `beer_glass`, `plastic_cup`, `cocktail`, `shot_glass`, plus a small set of generics. The `plastic_cup` icon is used by the small festival beer preset. `[OPEN]` — finalise the icon set with the designer (artwork, not the list).

Icons are monochrome so they accept the `iconColor` tint cleanly. Default colours per beverage type pre-fill the picker (e.g. water → blue, coffee → brown, tea → green) but the user can pick anything.

#### Where presets appear

- **Today view (S1):** the quick-log row shows a small selection of presets — the user's most-used ones, with seeded defaults until usage data accumulates.
- **Log-drink screen (S2):** the full preset list is shown as the primary picker. Tapping a preset pre-fills volume + beverage type + ABV; the user can still tweak volume or ABV before confirming.
- **Settings:** a "Manage drinks" section lets the user reorder, edit, hide, delete, and create presets.
- **Notification quick-log:** the user's chosen default preset is logged when the notification action is tapped.

#### Storage and historical accuracy

Resolved values (name, volume, ABV, price, icon, colour) are **snapshotted** onto each `DrinkEntry` at log time. Editing or deleting a preset later does **not** modify already-logged entries. See [data-model.md → Snapshot semantics — log immutability](./data-model.md#snapshot-semantics--log-immutability).

### F12 — Party Session (opt-in)

A session-based feature in phase 1 that lets the user track alcoholic drinks during a discrete drinking occasion and see an estimated blood alcohol concentration (BAC). BAC is shown in **g/L** as the primary unit, with **mmol/L** alongside as a secondary unit.

- The user explicitly **starts** a party session from the today view. There is at most one active session at a time.
- A session **ends** in one of two ways:
  - Manually, by tapping "End session".
  - Automatically, **12 hours after the most recently logged alcoholic drink** (or after `startedAt` if none were logged). The auto-end is computed lazily — no background timer is required.
- **Party Mode requires a birthday.** Onboarding collects gender + weight (and optionally height + birthday). If birthday is missing when the user first tries to start a session, the app prompts for it (with height as a skippable bonus). If the resulting age is under 18, the app shows a friendly message and lets the user re-enter the date — birthdays cannot be validated, and the gate is informational rather than enforcement.
- BAC algorithm is **data-driven**: Watson TBW model when both height and birthday are present, Widmark fallback otherwise.
- During an active session: the log-drink flow gains alcoholic beverage types (`beer`, `wine`, `spirit`, `cocktail`, `other_alcohol`) with default ABV values the user can override per entry; the today view gains a clearly-labelled "estimate" section showing current BAC, projected decay, and optional cap progress.
- A single, skippable **meal prompt** at session start (Small / Medium / Large / Skip), with the option to add or edit a meal during the session. Meals reduce the absorbed BAC of drinks consumed within their active window. There is **no** per-drink food prompt.
- **Session-scoped pricing.** Each session can carry per-drink price overrides that replace the user's regular menu prices for the duration of the session — money or token-based. The user's underlying drink presets are never modified by Party Mode actions. At session start, the user can copy prices from the most recently ended session in one tap. During the session, a "Manage prices" view lets them edit overrides; a toggle switches session pricing on/off live without losing the values. Session totals show money (grouped by currency) and tokens separately. See [party-session.md → Pricing during a session](./party-session.md#pricing-during-a-session) and [data-model.md → PartySessionPrice](./data-model.md#partysessionprice).
- Logging an alcoholic drink while no session is active **prompts** the user to start a session — never starts one implicitly. The user can decline; the drink is logged either way.
- The user can set a personal cap (g/L, with the mmol/L equivalent shown), persistent across sessions. The cap is a personal goal, not a safety threshold.
- Two optional session-only notifications: "approaching cap" and "estimated BAC back to 0".
- The estimate **must always** be presented as an estimate. The UI must never frame it as a fitness-to-drive indicator. See [party-session.md](./party-session.md) for the full spec, the algorithm, the disclaimer requirements, and references.

## Phase 2 — Accounts, cloud sync, and social

Phase 2 layers opt-in cloud features on top of the phase 1 product. Detailed designs (UI flows, server API, conflict resolution, privacy copy) are produced when phase 2 design begins; the items below are the committed scope.

### F8 — Account creation and sign-in (Phase 2)

- A user can create an account from settings. Account creation is **always optional**.
- A user who never creates an account continues to get the full phase 1 experience unchanged.
- A signed-in user can sign out, which stops sync but preserves their local data.
- `[OPEN]` — auth method (email + password, magic link, social login). To be decided in the phase 2 design pass.

### F9 — Cloud sync (Phase 2)

- For signed-in users, local drink entries and preferences sync to the server.
- The user can install the app on a new device, sign in, and recover their data.
- The local database remains the source of truth on each device. The server reconciles between devices using the rules in [technical-architecture.md → Sync model](./technical-architecture.md#sync-model-phase-2-design-constraints) and [data-model.md](./data-model.md).
- Sync runs in the background and never blocks the UI. The app remains fully usable offline for signed-in users too.

### F10 — Friends (Phase 2)

- A signed-in user can send and accept friend requests with other signed-in users.
- A user can remove a friend.
- `[OPEN]` — discovery method (username, email invite, share link). To be decided in the phase 2 design pass.

### F11 — Progress sharing with friends (Phase 2)

- A signed-in user can share their daily progress with their friends.
- Friends can see each other's progress against their daily goals.
- The user is in control of what they share and can revoke sharing at any time. Defaults must err on the side of privacy: no sharing happens by default until the user opts in.
- `[OPEN]` — exactly what is shared (just the goal-met indicator? the percentage? individual entries?). To be decided in the phase 2 design pass.

## Phase 3 — Insights

Phase 3 introduces analysis of the user's own logged data. No new data collection — phase 3 features run entirely against the data the user has already accumulated locally (and synced via phase 2 if applicable).

### F13 — Beverage categorisation insights (Phase 3)

- Show breakdown of the user's drink intake by beverage type over a chosen time range (e.g. "60% water, 25% coffee" over the last week / month).
- Visualised as a chart on the history view or as a dedicated insights view.
- `[OPEN]` — exact visualisation and time-range options designed when phase 3 begins.

## Later (post phase 3)

Worth keeping in mind so the architecture does not preclude these:

- **L1 — Smart reminders.** Adapt reminder timing based on the user's logged behaviour (skip reminders shortly after a logged drink, increase frequency if the user is behind pace).
- **L2 — Wearable / health platform integration.** Apple Health, Google Health Connect, watch apps.
- **L3 — Custom beverages.** User-defined drink presets with a custom name, default size, and optionally an icon or colour.
- **L4 — Localisation.** Multi-language support.

## Explicit non-features

- No calorie, sugar, or caffeine tracking.
- No medical advice or health recommendations beyond the user's own configured goal.
- No public / non-friend social feed. Sharing is between accepted friends only.
