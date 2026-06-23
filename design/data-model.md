# Data Model

This is a logical model — it describes the entities the app needs and their relationships, not a specific database schema. The engineering team chooses the storage technology (see [technical-architecture.md](./technical-architecture.md)).

The model is designed for phase 1 (local-only) but with phase 2 (cloud sync) constraints already baked in, so adding sync does not require a destructive migration.

## Entities

### DrinkEntry

A single recorded drink. Created via [features.md → F1 Log a drink](./features.md#f1--log-a-drink); displayed on [user-experience.md → S1 Today (home)](./user-experience.md#s1--today-home) and [→ S3 History](./user-experience.md#s3--history).

| Field          | Type                  | Notes                                                                          |
| -------------- | --------------------- | ------------------------------------------------------------------------------ |
| `id`           | string / UUID         | Stable identifier, generated locally. Becomes the cross-device key in phase 2. |
| `name`         | string \| null        | Snapshot of the preset's name at log time (e.g. "My Favourite IPA"). Null when no preset was used. |
| `beverageType` | enum / string         | One of the predefined beverage types (see below).                              |
| `volumeMl`     | integer               | Volume in millilitres. Must be > 0.                                            |
| `abvPercent`   | decimal \| null       | Alcohol by volume, %. Required for alcoholic beverage types, null otherwise.   |
| `priceMinor`   | integer \| null       | Snapshot of the price actually applied at log time, in the **minor unit** of the currency. Null if the drink had no money price (free, or paid in tokens — see `priceTokens`). |
| `currency`     | enum \| null          | Snapshot of the currency at log time. One of `EUR`, `USD`, `GBP`. Required when `priceMinor` is set; null otherwise. The currency travels with the entry so historical totals and per-currency aggregations remain meaningful even if the user later changes their preferred currency. |
| `priceTokens`  | integer \| null       | Snapshot of the token cost at log time, when the drink was paid for in tokens during a Party Session. Null otherwise. Mutually exclusive with `priceMinor` per drink: at most one of the two is non-null. |
| `tokenValueMinor` | integer \| null    | Snapshot of the token-to-money value at log time, in the minor unit of `tokenValueCurrency`. Lets historical totals show a money-equivalent for token-paid drinks even if the session's token configuration changes later. Null when `priceTokens` is null. |
| `tokenValueCurrency` | enum \| null    | Snapshot of the currency the token value was expressed in. Null when `priceTokens` is null. |
| `iconKey`      | string \| null        | Snapshot of the preset's icon key at log time. Null when no preset was used.   |
| `iconColor`    | string \| null        | Snapshot of the preset's icon colour at log time (hex, e.g. `#3b82f6`).        |
| `consumedAt`   | timestamp (with tz)   | When the drink was consumed. Defaults to "now" at logging time.                |
| `createdAt`    | timestamp             | When the entry was logged. Distinct from `consumedAt` for retroactive logs.    |
| `updatedAt`    | timestamp             | Updated on every edit. Used by phase 2 sync for last-writer-wins.              |
| `deletedAt`    | timestamp \| null     | Soft-delete marker. Null means the record is live; non-null means deleted.     |

Soft-deleted records are filtered out everywhere in the UI. They exist so that phase 2 sync can propagate deletions across devices without separate tombstone tracking.

### DrinkPreset

A named, pre-configured drink that the user can pick when logging. Functional spec: [features.md → F14 Drink presets and customisation](./features.md#f14--drink-presets-and-customisation). User-facing management: [user-experience.md → S4 Settings](./user-experience.md#s4--settings) ("Manage drinks") and [→ S2 Log drink](./user-experience.md#s2--log-drink) (preset picker + advanced editor).

| Field            | Type                  | Notes                                                                                  |
| ---------------- | --------------------- | -------------------------------------------------------------------------------------- |
| `id`             | string / UUID         | Stable identifier, generated locally.                                                  |
| `name`           | string                | Required. 3–30 characters. Allows Unicode letters `L*`, ASCII digits `0–9`, connectors (`_ - .`), and **ASCII space** — enables multi-word names like "Glass of water". Must start and end with a letter or digit. Rejects control characters, zero-width characters, emoji, and other symbols. See `validatePresetName()` in `core`. |
| `beverageType`   | enum                  | Required. One of the values in `BeverageType` (see below).                             |
| `volumeMl`       | integer               | Required, must be > 0.                                                                 |
| `abvPercent`     | decimal \| null       | Required when `beverageType` is alcoholic; null otherwise.                             |
| `regularPriceMinor` | integer \| null    | Optional. The user's **normal-day** price for this drink (the "menu price"), in the **minor unit** of the currency (cents for EUR/USD, pence for GBP). The major-unit value is `regularPriceMinor / 100`. |
| `regularCurrency`   | enum \| null       | One of `EUR`, `USD`, `GBP`. Required when `regularPriceMinor` is set; null otherwise. Defaults to `UserPreferences.currency` for new presets but is per-preset so changing the preference does not retroactively change preset prices. |
| `iconKey`        | string                | Required. References one of the bundled SVG icons.                                     |
| `iconColor`      | string                | Required. Hex colour (e.g. `#3b82f6`). Default per beverage type.                       |
| `isUserCreated`  | boolean               | `true` for user-created presets, `false` for app-seeded defaults.                       |
| `isHidden`       | boolean               | Default `false`. When `true`, the preset is excluded from quick-log and the log-drink picker but kept in the database. Lets users dismiss seeded defaults without losing the option to restore them. |
| `sortOrder`      | integer               | Per-user ordering for display. Lower values come first.                                 |
| `createdAt`      | timestamp             | Record creation time.                                                                  |
| `updatedAt`      | timestamp             | Updated on every edit. Used by phase 2 sync.                                           |
| `deletedAt`      | timestamp \| null     | Soft-delete marker, same semantics as `DrinkEntry`.                                    |

#### Seeded defaults

On first launch the database is seeded with the default preset list (see [features.md → F14 Drink presets and customisation](./features.md#f14--drink-presets-and-customisation)) using `isUserCreated = false`. The user can edit, hide, or delete them — there is no special protection. A "Reset to defaults" action in settings re-seeds any missing default presets.

#### Snapshot semantics — log immutability

The drink log is **immutable with respect to external changes**. This is a load-bearing principle:

- When a `DrinkEntry` is created from a preset, the resolved values (`name`, `beverageType`, `volumeMl`, `abvPercent`, `priceMinor`, `currency`, `iconKey`, `iconColor`) are **copied into the entry**.
- **Editing or deleting a preset never modifies historical entries.** If you rename "Light beer" to "IPA" today, last week's log still says "Light beer".
- `DrinkEntry` does not carry a foreign key back to `DrinkPreset`. The relationship is intentionally one-way at log time.
- The only path to change a `DrinkEntry` is a **direct, deliberate user edit** of that entry (see [features.md → F3 Today view](./features.md#f3--today-view)). Side-effect modifications from other entities are not allowed.

This keeps history accurate, makes preset deletion safe, avoids a sync ordering dependency in phase 2, and means historical analytics in phase 3 reflect what was actually logged at the time.

### BeverageType

Fixed enum, used as the classification axis on `DrinkPreset` and `DrinkEntry`. The list determines which seeded presets ship in F14 and which icons can be applied; user-created presets must pick from this list.

Non-alcoholic:

- `water`
- `coffee`
- `tea`
- `juice`
- `soft_drink`
- `milk`
- `non_alcoholic_beer` — visually a beer, classified as non-alcoholic. Contributes to hydration; never to the BAC estimate. Treated as fully alcohol-free for the purposes of this app — the small (<0.5%) residual alcohol some products contain is ignored, both for simplicity and because the pharmacokinetic effect at that dose is below the noise floor of the BAC model.
- `other`

Alcoholic (only logged during an active Party Session — see [party-session.md](./party-session.md)):

- `beer` — default ABV 5.0%
- `wine` — default ABV 12.0%
- `spirit` — default ABV 40.0%
- `cocktail` — no default ABV; user must enter it
- `other_alcohol` — user enters ABV

Each type has a display name, an icon, and an `isAlcoholic` flag. Alcoholic types contribute to the BAC estimate and **do not count toward hydration progress**. Non-alcoholic types contribute to hydration progress and do not affect BAC. The two flows are strictly disjoint — a beer is tracked, but it does not move the daily-water goal forward.

The list is fixed for phase 1 and phase 2. Custom user-defined types are a later iteration (L4 in features.md).

### UserPreferences

A single per-device record holding the user's settings. Edited via [user-experience.md → S4 Settings](./user-experience.md#s4--settings); functional contract in [features.md → F6 Settings](./features.md#f6--settings).

| Field                    | Type                  | Notes                                                       |
| ------------------------ | --------------------- | ----------------------------------------------------------- |
| `installedAt`            | timestamp             | Set once when the local database is first created on this device. Never changes thereafter. Used as a tie-breaker for the inactive-user silence rule (see [notifications.md → Inactive-user silence](./notifications.md#inactive-user-silence)) — `max(latestDrinkLog.consumedAt, installedAt)` is the user's "last engagement" time. |
| `username`               | string                | Set during onboarding. Min 3, max 30 characters. See "Username character rules" below. Used locally as a friendly label; reserved as the basis for friend discovery in phase 2. |
| `dailyGoalMl`            | integer               | Set during onboarding (suggested via `30 ml × weight_kg`, rounded to nearest 100 ml). Stored in metric; UI may display imperial. |
| `unitsDisplay`           | enum                  | `metric` (default) / `imperial`. Affects display only — all stored values are metric. |
| `currency`               | enum                  | `EUR` (default) / `USD` / `GBP`. Used as the default currency for new drink presets; affects how prices are displayed in aggregations. Stored prices on existing presets and entries are not changed when this preference changes. See "Currency" below. |
| `remindersEnabled`       | boolean               | Default true once the user has granted permission.          |
| `reminderStartTime`      | local time            | Default 08:00.                                              |
| `reminderEndTime`        | local time            | Default 22:00.                                              |
| `reminderIntervalMin`    | integer               | Default 90.                                                 |
| `dayBoundary`            | local time            | When a "day" starts for goal tracking and reminder scheduling. Default `05:00`. Configurable. |
| `defaultDrinkPresetId`   | string / UUID \| null | References one of the user's `DrinkPreset` records. Used by the notification quick-log action and as the "glass" unit in reminder recommendations. Must reference a non-alcoholic preset. Defaults to the seeded "Glass of water" preset's id. If the referenced preset is deleted, this falls back to null and the app uses the seeded "Glass of water" preset; if that too is missing, falls back to a hardcoded 200 ml water for the volume calculation and disables the notification quick-log action until the user picks a new default. |
| `inactivityReminderEnabled` | boolean            | Default `true`. Independent toggle for the once-per-day inactivity reminder. See [notifications.md → Notification types](./notifications.md#notification-types). |
| `weeklySummaryEnabled`   | boolean               | Default `true`. Independent toggle for the end-of-week summary notification. See [notifications.md → Notification types](./notifications.md#notification-types). |
| `bacOnLockScreenEnabled` | boolean               | Default `true`. When `true`, Party Mode notifications render the BAC value in full on the lock screen and in notification previews. When `false`, the BAC value is hidden from the visible body. See [notifications.md → Lock-screen visibility](./notifications.md#lock-screen-visibility). |
| `bacCapGramsPerL`        | decimal \| null       | Optional personal cap, stored canonically in g/L. Null means no cap is set. The UI shows g/L as primary and mmol/L as secondary. Persistent across sessions. |
| `updatedAt`              | timestamp             | Used by phase 2 sync.                                       |

**Phase 2 sync notes for `UserPreferences`.** `[OPEN]` — confirm which preferences travel across devices vs. stay per-device. Recommended split: `dailyGoalMl`, `unitsDisplay`, `currency`, `dayBoundary`, `defaultDrinkPresetId`, `bacCapGramsPerL`, and the notification-type toggles sync; the reminder schedule (`reminderStartTime`, `reminderEndTime`, `reminderIntervalMin`) stays per-device since a user's phone and tablet may want different windows. `installedAt` is per-device by definition.

#### UserProfile

Collected during onboarding ([user-experience.md → S5 Onboarding](./user-experience.md#s5--onboarding-first-launch-only)). Used by the hydration-goal suggestion ([features.md → F2](./features.md#f2--daily-hydration-goal)) and the Party Session BAC estimate ([party-session.md → Required user inputs](./party-session.md#required-user-inputs)).

| Field        | Type           | Notes                                                                                                  |
| ------------ | -------------- | ------------------------------------------------------------------------------------------------------ |
| `gender`     | enum           | `male` / `female` / `unspecified`. Asked for hydration calculations and BAC pharmacokinetics. Required. |
| `weightKg`   | decimal        | Required. Default `70` if the user accepts the suggestion without changing it.                         |
| `heightCm`   | decimal \| null | Optional. Improves BAC accuracy in Party Mode (enables the Watson TBW model). When null, BAC falls back to Widmark. |
| `birthDate`  | date \| null   | Optional during onboarding. **Required to use Party Mode** — for both the under-18 gate and as the Watson age input. The first attempt to start a Party Session prompts for it if missing. Birthday cannot be validated; the app trusts what is entered. |

The profile is conceptually part of preferences but kept as a separate logical record because it has different sensitivity and may have different sync rules in phase 2 (`[OPEN]` — confirm whether profile syncs to other devices).

### PartySession

A discrete drinking occasion. There is at most one active session (`endedAt IS NULL`) at any time. Functional spec: [features.md → F12 Party Session](./features.md#f12--party-session-opt-in). Behaviour and BAC algorithm: [party-session.md](./party-session.md). UI surface: [user-experience.md → S1 Today (home)](./user-experience.md#s1--today-home).

| Field         | Type                  | Notes                                                                                |
| ------------- | --------------------- | ------------------------------------------------------------------------------------ |
| `id`          | string / UUID         | Stable identifier, generated locally.                                                |
| `startedAt`   | timestamp (with tz)   | When the session was started (manually or via auto-start on logging an alcoholic drink). |
| `endedAt`     | timestamp \| null     | Null while active. Set when the session ends.                                        |
| `endReason`   | enum \| null          | `manual` or `auto_timeout`. Null while active.                                       |
| `useSessionPrices` | boolean          | Whether to apply this session's `PartySessionPrice` overrides when logging drinks. Toggled live during the session. Default `true` if any overrides exist at session start, else `false`. |
| `tokenName`        | string \| null   | Display label for the session's tokens (e.g. "Token", "Munt", "Drink ticket"). Null when tokens are not used in this session. Min 1, max 30 characters; same character whitelist as `username`. |
| `tokenValueMinor`  | integer \| null  | What one token is worth, in the minor unit of `tokenValueCurrency`. Optional even when `tokenName` is set — a session may use tokens without a defined money equivalent (in which case money totals exclude token-paid drinks). |
| `tokenValueCurrency` | enum \| null   | One of `EUR`, `USD`, `GBP`. Required when `tokenValueMinor` is set.                  |
| `createdAt`   | timestamp             | Record creation time.                                                                |
| `updatedAt`   | timestamp             | Updated on every change. Used by phase 2 sync.                                       |
| `deletedAt`   | timestamp \| null     | Soft-delete marker, same semantics as `DrinkEntry`.                                  |

#### Auto-end semantics

A session auto-ends 12 hours after the most recently logged alcoholic drink within the session (or 12 hours after `startedAt` if none were logged). The check is run lazily — on app foreground, today-view open, drink log, and settings open — and `endedAt` is set to the correct 12-hour mark, **not** to the time the app happened to notice. This keeps history correct even after long absences.

### PartySessionPrice

A per-session, per-preset price override. Lets the user set festival/party prices that differ from the regular menu price without ever modifying the underlying `DrinkPreset`. User-facing flow: [party-session.md → Pricing during a session](./party-session.md#pricing-during-a-session). Functional summary: [features.md → F12](./features.md#f12--party-session-opt-in).

| Field            | Type                  | Notes                                                                                  |
| ---------------- | --------------------- | -------------------------------------------------------------------------------------- |
| `id`             | string / UUID         | Stable identifier, generated locally.                                                  |
| `partySessionId` | string / UUID         | Foreign key to the session this override belongs to. Required.                         |
| `drinkPresetId`  | string / UUID         | Foreign key to the preset this override applies to. Required.                          |
| `priceMinor`     | integer \| null       | Money price for this drink during this session. Mutually exclusive with `priceTokens`. |
| `currency`       | enum \| null          | `EUR` / `USD` / `GBP`. Required when `priceMinor` is set; null otherwise.              |
| `priceTokens`    | integer \| null       | Token cost for this drink during this session. Mutually exclusive with `priceMinor`.   |
| `createdAt`      | timestamp             | Record creation time.                                                                  |
| `updatedAt`      | timestamp             | Updated on every edit. Used by phase 2 sync.                                           |
| `deletedAt`      | timestamp \| null     | Soft-delete marker, same semantics as `DrinkEntry`.                                    |

There is at most one live `PartySessionPrice` per `(partySessionId, drinkPresetId)` pair. Removing an override (deleting it or zeroing both price fields) means "this drink is logged at its regular price during this session, even when `useSessionPrices` is on".

#### Mutual exclusivity

Money and tokens are mutually exclusive **per override**, not per session. A session can mix them: beer priced in tokens, water priced in money. The constraint is just that any single drink in a session is *either* tokens *or* money, not both.

The mutual-exclusivity constraint is enforced at the validation layer; the storage layer simply has both columns nullable.

#### Snapshot at log time

When a `DrinkEntry` is logged during an active session and `useSessionPrices` is `true`, the price applied is the matching `PartySessionPrice` if one exists, falling back to the preset's `regularPrice*` otherwise. The values written into `DrinkEntry` (`priceMinor`/`currency` *or* `priceTokens`/`tokenValueMinor`/`tokenValueCurrency`) are snapshots — see "Snapshot semantics — log immutability" above.

### Meal

A meal logged within a `PartySession`. Influences the BAC modifier for drinks consumed inside the meal's active window. Algorithm and UI: [party-session.md → Meals](./party-session.md#meals). Functional summary: [features.md → F12](./features.md#f12--party-session-opt-in).

| Field            | Type                  | Notes                                                                                  |
| ---------------- | --------------------- | -------------------------------------------------------------------------------------- |
| `id`             | string / UUID         | Stable identifier, generated locally.                                                  |
| `partySessionId` | string / UUID         | Foreign key to the session this meal belongs to. Required.                             |
| `size`           | enum                  | `small` / `medium` / `large`.                                                          |
| `eatenAt`        | timestamp (with tz)   | When the meal was eaten. Defaults to "now" at logging, adjustable.                     |
| `createdAt`      | timestamp             | Record creation time.                                                                  |
| `updatedAt`      | timestamp             | Updated on every change. Used by phase 2 sync.                                         |
| `deletedAt`      | timestamp \| null     | Soft-delete marker, same semantics as `DrinkEntry`.                                    |

A session may have zero, one, or several meals. Meals do not exist outside a session — the food question is asked only in the alcohol context. We are not building a meal tracker.

#### Relationship to DrinkEntry

A `DrinkEntry` carries an explicit nullable foreign key `partySessionId` to `PartySession`. This is more reliable than inferring membership from `consumedAt` alone, because:

- Orphan drinks (logged when the user declined the start-session prompt) have `consumedAt` values in the past but explicitly belong to **no** session — they must not be auto-attached just because their timestamp later falls inside a session window.
- Absorbed orphan drinks (see [party-session.md → Absorbing orphan drinks](./party-session.md#absorbing-orphan-drinks-when-a-later-session-starts)) explicitly belong to a session whose `startedAt` is **after** the drink's `consumedAt` — pure timestamp-window logic would miss this.

Membership rules:

- A non-alcoholic drink's `partySessionId` is always null.
- An alcoholic drink logged during an active session: `partySessionId` set to that session at log time.
- An alcoholic drink logged when no session is active: `partySessionId = null` (orphan).
- When a new session starts and an orphan still has residual BAC (per the absorption rule in [party-session.md → Absorbing orphan drinks](./party-session.md#absorbing-orphan-drinks-when-a-later-session-starts)): the orphan's `partySessionId` is updated to the new session.
- Once set, `partySessionId` is not cleared by the auto-end of the session — the historical association is preserved.

When a user retroactively logs an alcoholic drink (i.e. with a past `consumedAt` typed in by the user) whose `consumedAt` falls inside an **already-ended** session window, the drink **attaches to that session** automatically — its `partySessionId` is set to the matching session at log time. Attaching the drink does **not** re-open the session's auto-end clock: `endedAt` and `endReason` stay as they were. Once a session has ended, it does not grow in time.

This rule applies only when the new drink's `consumedAt` falls strictly inside `[startedAt, endedAt)`. Drinks whose `consumedAt` falls before any session, after every session, or in a gap between sessions remain unattached (orphans), subject to the absorption rules described in [party-session.md → Absorbing orphan drinks](./party-session.md#absorbing-orphan-drinks-when-a-later-session-starts).

## Phase-2-only entities (defined here for forward-compatibility, not built in phase 1)

These entities **must not exist** in the phase 1 build. They are listed so the phase 1 schema does not collide with them later.

- `Account` — server-side identity record for a signed-in user.
- `Friendship` — the relationship between two accounts (status: pending / accepted).
- `ShareSetting` — per-friend control over what each friend can see.

Phase 2 design produces full schemas for these.

## Relationships (phase 1)

`DrinkEntry` carries one explicit foreign key: `partySessionId` (nullable, → `PartySession`). For non-alcoholic drinks and orphan alcoholic drinks it is null; for in-session and absorbed-orphan alcoholic drinks it points to the owning session. Membership rules are detailed under "Meal → Relationship to DrinkEntry".

`DrinkEntry` does **not** carry a foreign key to `DrinkPreset` — preset values are snapshotted onto the entry at log time per the immutability principle.

Other queries:

- **Daily totals** — live entries (`deletedAt IS NULL`) whose `consumedAt` falls within the day window defined by `UserPreferences.dayBoundary`.
- **Session membership** — `partySessionId` is authoritative; do not infer membership from `consumedAt` alone.

In phase 2, `DrinkEntry` records gain an implicit owner (the signed-in account) on the server side, but the local representation does not change.

## Derived values

The app computes, but does not persist:

- **Today's intake** — sum of `volumeMl` for live entries whose `consumedAt` falls within the current day window.
- **Goal progress** — today's intake divided by `dailyGoalMl`.
- **Pace** — for reminder logic: how the user's intake so far compares to a linear pace toward the goal across the active reminder window.

### Username character rules

All string values written to the database are properly escaped at the storage layer (this is a baseline expectation, not a username-specific rule). On top of that, the username has a character whitelist so it always renders predictably across platforms and fonts.

**Length:** 3–30 characters.

**Allowed:**
- Unicode letters (general category `L*`) — covers Latin, Cyrillic, Greek, CJK, etc., including accented forms (e.g. `é`, `ü`, `ç`). This supports international names without forcing English-only usernames.
- ASCII digits `0–9`.
- The three connector characters `_`, `-`, `.`.

**Disallowed:**
- Control characters (`Cc`), format characters (`Cf` — includes zero-width characters and bidirectional override marks that can spoof rendering), surrogates (`Cs`), private-use characters (`Co`), unassigned code points (`Cn`).
- All whitespace — usernames have no spaces.
- Emoji and other symbols (`So`, `Sk`).
- Combining marks (`Mn`, `Mc`) when not attached to a base letter.

**Structural rules:**
- Must start with a letter or digit (not `_`, `-`, or `.`).
- Must end with a letter or digit (not `_`, `-`, or `.`).

**Normalisation:**
- The username is **Unicode NFC-normalised** before being stored, so visually identical inputs produce the same stored bytes. Validation runs against the normalised form.

In phase 2, server-side rules will additionally enforce **uniqueness** and may further restrict against visually-confusable characters across scripts (a phase 2 concern, not relevant in phase 1 since usernames are local-only).

## Currency

Phase 1 supports three currencies: **EUR**, **USD**, **GBP**. The list is a fixed enum.

- `UserPreferences.currency` is the user's **preferred** currency. It is used as the default when creating a new preset and as the display currency in single-currency aggregations.
- Each `DrinkPreset.currency` is the currency that preset's price was entered in. Each `DrinkEntry.currency` is the currency at the moment the drink was logged.
- **No exchange rates, no conversion, no historical FX tracking.** A drink logged in GBP stays in GBP forever; the app never converts it to EUR. Aggregations across mixed currencies are shown grouped (e.g. "€42.50 + £8.00 this week") rather than summed.
- Changing `UserPreferences.currency` does not modify any existing preset or log entry. Future new presets pick up the new default.
- The currency symbol shown in the UI is derived from the value at display time: `EUR` → `€`, `USD` → `$`, `GBP` → `£`. The choice of symbol position (prefix vs suffix) and decimal separator follows platform locale conventions, not the currency itself.

Money is always stored in the **minor unit** as an integer (cents for EUR/USD, pence for GBP). This avoids floating-point rounding in totals.

## Units

All persisted values are stored in **metric**: `volumeMl` in millilitres, `weightKg` in kilograms, `heightCm` in centimetres, BAC in `g/L`. There is no per-record unit field — the storage unit is fixed by the schema.

Display conversion to imperial (fl oz, lb, in, °F where relevant) happens at the **UI layer only**, gated by `UserPreferences.unitsDisplay`. Algorithms (BAC, hydration progress, meal modifiers) operate exclusively in metric. This keeps the math and any future cross-device sync free of unit-conversion edge cases.

When the user enters a value in imperial in the UI (e.g. "12 fl oz"), the UI converts to metric before writing to the database. Round-tripping (imperial → metric → imperial) may lose minor precision; this is acceptable.

### Display precision

These rules apply whenever a numeric value is shown in the UI, regardless of the user's unit preference.

All rounding uses **half-away-from-zero** (round 0.5 up for positive values).

| Value | Metric display | Imperial display |
| ----- | -------------- | ---------------- |
| Volume | nearest integer ml | 1 decimal place (fl oz) |
| Mass | 1 decimal place (kg) | 1 decimal place (lb) |
| Height | 1 decimal place (cm) | nearest inch, split into ft + in |

### Imperial conversion constants

The app uses **US customary** units throughout (not UK imperial). All rounding uses half-away-from-zero.

**Volume — fl oz.**

| Direction | Constant | Result precision |
| --------- | -------- | ---------------- |
| ml → fl oz | **1 US fl oz = 29.5735295625 ml** (NIST) | 1 decimal place |
| fl oz → ml | same constant | nearest integer ml |

The UK imperial fl oz (28.4130625 ml) is explicitly not used.

**Mass — lb.**

| Direction | Constant | Result precision |
| --------- | -------- | ---------------- |
| kg → lb | **1 kg = 2.20462262185 lb** (international avoirdupois pound) | 1 decimal place |
| lb → kg | same constant | 3 decimal places (sub-gram accuracy for storage) |

**Height — ft/in.**

| Direction | Constant | Method | Result precision |
| --------- | -------- | ------ | ---------------- |
| cm → ft/in | **1 in = 2.54 cm** (exact international definition) | total_inches = round(cm / 2.54); feet = total_inches ÷ 12; inches = total_inches mod 12 | nearest inch (split into ft + in) |
| ft/in → cm | same constant | — | 1 decimal place |

## Storage requirements

- Data must persist across app restarts and device reboots.
- The app must work fully offline. This holds in both phases.
- Editing or deleting a `DrinkEntry` must be reflected in derived values immediately.
- The local database must support schema migrations — phase 2 will add new fields and entities, and we will not be the only ones adding migrations over the app's lifetime.
- Writes are transactional. A partially applied edit must never leave the database in an inconsistent state.

## Privacy

- Phase 1: all data is on-device. No identifiers tied to the user are collected.
- Phase 2: data leaves the device only after the user creates an account, which is always optional. The privacy policy and explicit consent flow are designed in phase 2.
- Analytics remain a non-goal in phase 1 (see F7). Any future opt-in analytics must never include drink-entry contents without separate explicit consent.
