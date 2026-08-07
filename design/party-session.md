# Party Session (Phase 1)

A Party Session is an opt-in, session-based feature in phase 1. While a session is active, the user can log alcoholic drinks and see an **estimate** of their current blood alcohol concentration (BAC). The user can also set a personal cap and see when they are approaching it.

**Related docs.** Functional summary: [features.md → F12 Party Session](./features.md#f12--party-session-opt-in). Storage: [data-model.md → PartySession](./data-model.md#partysession), [→ PartySessionPrice](./data-model.md#partysessionprice), [→ Meal](./data-model.md#meal). Profile inputs: [data-model.md → UserProfile](./data-model.md#userprofile). UI surface: [user-experience.md → S7 Party](./user-experience.md#s7--party) (top-level tab; carries the active-session view and the start CTA), [→ S2 Log drink](./user-experience.md#s2--log-drink) (alcoholic types appear).

## Why session-based

Alcohol consumption is bursty — it happens on specific occasions, not continuously. An always-on "alcohol mode" would add visual noise on the many days when a user has zero alcohol. A session frames the experience: explicit start, explicit (or automatic) end, BAC UI present only when it is actually relevant.

## Display units

- **Primary unit: BAC in g/L** (the conventional everyday unit; equivalent to promille, ‰).
- **Secondary unit: mmol/L** shown alongside, smaller, as a scientifically grounded equivalent.

Example: `0.36 g/L` *(≈ 7.85 mmol/L, estimate)*.

Internally the app stores and computes BAC in `g/L`. The mmol/L value is derived for display only.

## Important: this is an estimate, not a measurement

The app produces an estimate based on published pharmacokinetic models. Real BAC depends on factors the app cannot know (genetics, recent food intake, medications, illness, hydration, drink absorption rate). Estimates can be off by tens of percent in either direction.

These rules are non-negotiable in the UI:

- The estimated BAC must **always** be presented as an estimate (e.g. "~0.33 g/L (estimate) · ≈ 7.2 mmol/L").
- The app **must never** be presented as a tool for deciding whether someone is fit to drive, operate machinery, or do anything else where BAC matters legally or medically.
- A clear, persistent disclaimer must be visible during an active session: this is informational only; do not use it as a basis for driving decisions.
- The user's chosen cap is a personal goal, not a safety threshold.

## Session lifecycle

### Lifecycle diagram

```mermaid
stateDiagram-v2
    [*] --> NoSession
    NoSession --> StartingPrompt: Tap Start party session
    NoSession --> StartingPrompt: Log alcoholic drink (prompt)
    StartingPrompt --> ProfilePrompt: Birthday missing
    ProfilePrompt --> Under18Notice: age < 18
    Under18Notice --> ProfilePrompt: Re-enter date
    ProfilePrompt --> MealPrompt: Birthday OK
    StartingPrompt --> MealPrompt: Birthday already set
    MealPrompt --> NamePrompt: Skip or pick size
    NamePrompt --> PricingPrompt: Skip or enter name
    PricingPrompt --> Active: Skip / Copy from last / Configure
    Active --> Active: Log drink / meal / edit price / edit name
    Active --> Ended: Tap End session (manual) · has ≥1 drink
    Active --> Ended: 12h since last alcoholic drink (auto_timeout) · has ≥1 drink
    Active --> NoSession: Tap End session (manual) · 0 drinks → discarded
    Active --> NoSession: 12h since startedAt (auto_timeout) · 0 drinks → discarded
    Ended --> [*]
    Ended --> NoSession: User starts another session
    Ended --> [*]: User deletes the session (drinks detach)
```

### Starting a session

- The user taps **"Start party session"** on the [Party tab](./user-experience.md#s7--party).
- **If birthday is missing from the profile:** the app prompts for it. The same prompt offers a skippable height field. The user can cancel without starting a session. If the entered birthday makes the user under 18, the app **notifies the user** with an honest, non-accusatory message ("Party Mode requires you to be 18 or older. If you entered your birthday incorrectly, you can try again.") and lets them re-enter the date. There is no retry limit — the birthday cannot be validated either way, and adding friction does not change that.
- **If birthday is present and the user is 18+:** the session starts without further profile prompts.
- The start flow includes a single, skippable **meal prompt** (see "Meals" below). It is the only food question the app ever asks during a session.
- The start flow also includes an optional, skippable **name** field (e.g. "Sarah's birthday"), stored on `PartySession.name`. Skipping leaves it unset — the past-sessions list falls back to showing just the date/range. The name can be added or changed at any later point too, not just at start: from the Party tab while the session is active, or from [S9](./user-experience.md#s9--party-session-log)'s ended-mode header once it has ended.
- A session has a `startedAt` timestamp and is the *active* session until it ends. There is at most one active session at a time.

### During a session

- The [Party tab](./user-experience.md#s7--party) displays the active-session view: current estimated BAC, projected decay, optional cap progress, drinks-this-session count and total grams of alcohol.
- The log-drink flow ([user-experience.md → S2 Log drink](./user-experience.md#s2--log-drink)) shows the alcoholic beverage types alongside the non-alcoholic ones.
- Session-only notifications (approaching cap, sober estimate) are eligible to fire — see "Notifications during a session" below.

### Ending a session

A session ends in one of two ways:

1. **Manually.** The user taps **"End session"** on the [Party tab](./user-experience.md#s7--party). `endReason = manual`.
2. **Automatically.** The session auto-ends **12 hours after the most recently logged alcoholic drink** (or 12 hours after `startedAt` if no alcoholic drinks were logged). `endReason = auto_timeout`. `endedAt` is set to that 12-hour mark, not to the time the app happened to notice.

12 hours is long enough that an evening followed by sleeping in counts as one session, and short enough that a session doesn't bleed into the next day for someone who logged a single beer at lunch.

When a session ends:

- The Party tab reverts to its no-active-session state (full-width "Start party session" button + past sessions list).
- The alcoholic beverage types disappear from the log-drink flow (the user can still log non-alcoholic drinks as normal).
- The session and its drinks remain visible in history — **unless** it had zero alcoholic drinks, in which case it is discarded instead of kept; see "Zero-drink sessions are never saved" below.

#### Zero-drink sessions are never saved

If, at the moment a session would end (manual tap **or** the 12-hour auto-timeout check), it has **zero alcoholic drinks** — none logged in-session and none absorbed as orphans — the session is discarded instead: it is soft-deleted immediately, with no confirmation prompt, and the Party tab goes straight to the no-active-session state. It never appears in the past-sessions list or history. This covers the case of starting a session and never getting around to logging anything. See [data-model.md → PartySession → Zero-drink sessions are discarded](./data-model.md#zero-drink-sessions-are-discarded-not-saved).

**Deliberate: meals do not exempt a session from discard.** A session can carry meals with zero drinks (a user can log a meal before logging any alcohol). The zero-drinks check above is drink-count-only — a meal-only session is still discarded silently, and its meal record is lost along with it. Considered and accepted: this is a rare, low-stakes edge case, not worth interrupting the flow for a confirmation prompt.

#### Deleting a session

Only an **ended** session can be deleted — there is no delete affordance on the active session; end it first. Delete is offered from [S9](./user-experience.md#s9--party-session-log)'s ended-mode header only — the single entry point for this action (the past-sessions list row carries no delete affordance; tapping a row there only opens S9), with a confirmation prompt (same pattern as deleting a drink entry). Deleting a session soft-deletes the `PartySession` row and **detaches** every drink that belonged to it — each entry's `partySessionId` is cleared, turning them back into ordinary orphan drinks. The drinks are never deleted themselves and remain visible in today's log / history exactly as any other orphan. See [data-model.md → PartySession → Deleting a session](./data-model.md#deleting-a-session).

### Auto-end is computed lazily

We do not run a background timer. The auto-end check runs whenever:

- The app is foregrounded.
- The Today, Party, or History tab is opened.
- A drink is logged.
- Settings are opened.

If the check determines the active session should have ended, it ends it retroactively (with `endedAt` set to the correct 12-hour mark, not "now"). This means a user who closes the app for a week and returns will not see a still-active session: if the session had logged drinks, it shows up correctly-ended in history; if it had zero drinks (started, then abandoned), it is discarded per "Zero-drink sessions are never saved" above and the user simply lands on the no-active-session state.

### Logging alcohol when no session is active

This section describes the **Party tab's** dedicated "Log alcohol" action, which blocks on the prompt below before the drink is recorded. Logging alcohol from Today (the quick-log grid tile or the S2 drawer) works differently — see [Logging from Today](#logging-from-today-quick-log-tile-and-s2-drawer) below.

```mermaid
flowchart TD
    A[User logs alcoholic drink · no active session] --> B[Prompt: Start party session?]
    B -->|Start party session| C{Profile complete?}
    C -->|Birthday missing| D[Prompt for birthday + optional height]
    D -->|age >= 18| E[Session starts at consumedAt]
    D -->|age < 18| F[Friendly under-18 notice → re-enter]
    F --> D
    C -->|Birthday present| E
    E --> G[Drink recorded · partySessionId set]
    E --> H[Absorb earlier orphans whose BAC > 0]
    B -->|Don't start a session| I[Drink recorded as orphan · partySessionId = null]
```

The app **does not** silently start a session. When the user logs an alcoholic drink while no session is active, the app explicitly **asks** them whether to start a party session for it:

- A confirmation prompt appears with two clear choices: **"Start party session"** or **"Don't start a session"**.
- If the user chooses to start a session: the session begins at the drink's `consumedAt` time, the drink is recorded, and BAC tracking takes over. If profile inputs are missing (first-ever alcohol log), the prompt to enter them comes next, and the session only starts after the user provides them.
- If the user chooses not to start a session: the drink is recorded as an **orphan drink** and is visible in [today's drinks log](./user-experience.md#s6--today-drinks-log) and history, but no session is created and no BAC estimate is shown.

The choice is presented every time alcohol is logged outside an active session via the Party tab — we never assume the answer for the user. The decision to drink, and the decision to track that drink in a session with a BAC estimate, are deliberately kept separate.

#### Logging from Today (quick-log tile and S2 drawer)

Today's quick-log grid tiles and the [S2 log-drink drawer](./user-experience.md#s2--log-drink) log an alcoholic entry **immediately**, never blocking on a start-session prompt — consistent with every other drink's 1–3 tap flow (see [Flow 2](./user-experience.md#flow-2--quick-log-most-common)).

- **No active session:** the drink logs as an orphan, and its toast offers **"Start session"** in place of the usual Undo (one action fits a toast). Tapping it starts a session and absorbs the drink immediately, since its BAC hasn't decayed yet. Left un-started, the drink stays an orphan but isn't locked out — any later session still absorbs it under the normal rule (see [Absorbing orphan drinks](#absorbing-orphan-drinks-when-a-later-session-starts)). To remove it instead, delete it from [S6](./user-experience.md#s6--today-drinks-log).
- **A session is already active:** the drink attaches to it directly, same as the Party tab's own "Log alcohol" action, and the BAC estimate updates. The toast is ordinary — Undo, no "Start session".

### Absorbing orphan drinks when a later session starts

```mermaid
flowchart TD
    A[New session starts at startedAt] --> B[Find all orphan alcoholic drinks · partySessionId = null]
    B --> C{For each orphan}
    C --> D[Compute BAC_initial from profile]
    D --> E[t_zero = consumedAt + BAC_initial / β]
    E --> F{t_zero > startedAt?}
    F -->|Yes| G[Absorb · set orphan.partySessionId = new session]
    F -->|No| H[Stay orphan · BAC fully decayed]
    G --> I[Show user: included N earlier drinks]
    H --> I
```

When the user later starts a session (manually, or by accepting the prompt on a subsequent alcohol log), any pre-existing orphan drinks whose alcohol is **still pharmacokinetically active** are absorbed into the new session.

The rule is applied **per orphan drink**:

- For each orphan drink, compute its individual `BAC_initial` using the user's profile (Step 3 of the algorithm).
- Compute the time at which that individual contribution would decay to zero: `t_zero = consumedAt + BAC_initial / β` — valid as-is whenever that drink's absorption rate `r` (Step 4) exceeds `β`, per [Step 6's emergent property](#step-6--current-bac-pooled-across-drinks-and-absorption-windows): the total consumedAt-to-zero duration is unaffected by the absorption window, only the shape of the curve in between is. In the rare case `r <= β`, the drink never accumulates residual BAC at all — use `t_zero = consumedAt` (it never absorbs into a later session).
- If `t_zero > startedAt` of the new session, the orphan still has residual BAC and is absorbed: the drink's `consumedAt` falls within the session's `[startedAt, endedAt)` window for BAC computation, and it appears in the session's drink list ([user-experience.md → S9 Party Session Log](./user-experience.md#s9--party-session-log)).
- Otherwise the orphan has fully decayed and stays orphaned. It remains visible in history but does not contribute to the new session.

We do not need to track partial decay separately for this check — once absorbed, the drink's `consumedAt`/`BAC_initial`/`drinkConsumeMinutes` feed into the pooled Step 6 calculation like any other session drink, which handles a partially-absorbed or partially-decayed drink correctly.

This per-orphan `t_zero` check is itself a per-drink-independent-decay approximation — the same kind Step 6 deliberately moved away from for the canonical pool — applied only to decide absorb-vs-discard for orphans considered one at a time. With two or more overlapping orphans (e.g. logged close together, each below the discard threshold alone but still summing to residual BAC in the now-canonical pooled model), this check can discard an orphan whose alcohol a pooled read of the pre-session drinks would still count. Known, accepted approximation for Phase 1, not something Step 6's pooling fix addresses — revisit if orphan absorption proves to under-count in practice.

#### Implications

- **Absorbed orphans extend backwards in time.** A session can contain drinks whose `consumedAt` is earlier than `startedAt`. This is intentional: the session window is an organisational concept, while the BAC math reflects the actual residual alcohol in the user's bloodstream.
- **Auto-end timing.** The 12-hour auto-end clock is still measured from "the most recently logged alcoholic drink within the session". Absorbed orphans are by definition older than `startedAt`, so they will not extend the auto-end further than an in-session drink would. If the session has only absorbed orphans and no in-session drinks, the auto-end fires 12 hours after the most recent absorbed orphan — which may be earlier than `startedAt + 12h`. That is correct.
- **User transparency.** When orphan drinks are absorbed into a starting session, the start confirmation should tell the user (e.g. "Session started — included 2 earlier drinks that are still affecting your estimate"). The user must understand that the BAC they see accounts for drinks they declined to track at the time.
- **No opt-out.** Absorption is fully automatic: every orphan whose BAC has not yet decayed to 0 is absorbed into the new session. The user cannot uncheck individual drinks. The estimate is meant to reflect what is actually in the user's bloodstream per the model; letting the user hide drinks from the calculation would undermine the integrity of the estimate. The start-session confirmation tells the user clearly which drinks were absorbed.

## Required user inputs

The BAC estimate uses the user's profile, which is partly collected during onboarding ([user-experience.md → S5 Onboarding](./user-experience.md#s5--onboarding-first-launch-only)) and partly completed the first time the user tries to start a Party Session. Stored in [data-model.md → UserProfile](./data-model.md#userprofile).

| Field        | Required for Party Mode? | Source                                               | Used for                              |
| ------------ | ------------------------ | ---------------------------------------------------- | ------------------------------------- |
| `gender`     | Yes                      | Onboarding                                           | Sex-specific Widmark `r` and Watson coefficients |
| `weightKg`   | Yes                      | Onboarding (default 70)                              | Both Widmark and Watson               |
| `birthDate`  | **Yes**                  | Onboarding (optional) or first-session prompt        | 18+ gate; age input for Watson        |
| `heightCm`   | No (recommended)         | Onboarding (optional) or first-session prompt        | Watson model (improves accuracy)      |

**Gender — three options.** `male` / `female` / `unspecified`. Body composition differs significantly between male and female and is one of the biggest factors in BAC for a given dose, so the calculation needs *some* answer. The unspecified case is handled below.

**Birthday is required to use Party Mode.** If the user did not provide it during onboarding, the app prompts for it the first time they tap "Start party session". The same prompt offers `Height (optional, improves accuracy)` with a clear skip. The birthday cannot actually be validated — the app just trusts what's entered. If the resulting age is under 18 (or the locally configured age of majority), the app shows a friendly message and lets the user re-enter the date; there is no retry limit, and there is no permanent lockout — the gate is informational, not enforcement.

**Gender — unspecified handling.** When the user picks `unspecified`, both the Widmark and Watson paths use the **conservative (female) factor / coefficients** so the resulting BAC estimate is the higher of the two possibilities. A small footnote alongside the BAC value explains this ("Estimate uses a conservative model since gender isn't specified").

**Algorithm choice is data-driven.** When both birthday and height are present, the app uses the Watson TBW model. When height is missing, it falls back to Widmark. There is no user-facing setting to choose between them — the app picks the most accurate option the available data supports. See "BAC estimation algorithm" below.

The user can change any profile value at any time from settings; subsequent BAC estimates use the new values, but already-recorded sessions are not retroactively recomputed.

## Meals

Stored as [data-model.md → Meal](./data-model.md#meal) records, scoped to a single `PartySession`.

Food in the stomach slows alcohol absorption, lowering peak BAC and shifting it later in time. The app accounts for this in a deliberately lightweight way — meals are a small part of the experience, not leading.

### What we ask

A single, skippable prompt at session start: **"Did you eat recently? Small / Medium / Large / Skip"**. Skipping means "we don't know — assume worst case, no food modifier".

The user can also **add a meal at any time during the session** from the [Party tab](./user-experience.md#s7--party). There is **never** a per-drink food prompt.

### Meal sizes

The user picks a bucket; the descriptive cue is leading, weight and calories are supporting guidance:

| Size   | Examples                                              | Rough mass    | Rough kcal     | Peak modifier | Time constant τ |
| ------ | ----------------------------------------------------- | ------------- | -------------- | ------------- | --------------- |
| Small  | Snack, sandwich, light salad                          | ~150–300 g    | ~200–400 kcal  | 0.95          | 1.5 h           |
| Medium | Normal meal: plate of pasta, sandwich + soup          | ~400–700 g    | ~500–800 kcal  | 0.85          | 2.5 h           |
| Large  | Heavy meal: stew with rice, multiple courses, roast   | ~800 g+       | ~900+ kcal     | 0.75          | 3.5 h           |

The **peak modifier** is the value at `eatenAt`, when food's effect on absorption is strongest. The **time constant τ** is the gastric-emptying half-life-style parameter that controls how fast the modifier returns to 1.00 — see "How meals affect the BAC estimate" below for the formula.

Practically: at `Δt = τ` the modifier has recovered ~63% of the way back to 1.00; at `Δt = 3τ` it has recovered ~95%; at `Δt = 5τ` (~7.5 h / 12.5 h / 17.5 h) it is within 1% of 1.00 and the effect is negligible.

**Caveat we should be honest about in the UI copy:** what actually slows absorption is *gastric emptying time*, which depends on calories and fat/protein content more than raw weight. The buckets are a usable approximation, not a precise science. The descriptions above should appear in the picker so the user has anchors.

Bucket boundaries and time constants are confirmed; the τ values land within published gastric-emptying ranges for mixed meals (~60–180 min).

### Each meal stores

- A **size** (`small` / `medium` / `large`).
- An **`eatenAt`** timestamp — defaults to "now" at the moment of logging, adjustable by the user (e.g. "I ate an hour ago"). Most users will accept the default.

A session can contain zero, one, or several meals. A meal logged mid-session attaches to the current session.

### How meals affect the BAC estimate

For each alcoholic drink at time `t_drink`, look at every meal attached to the active session and compute that meal's current modifier using exponential decay:

```
Δt = t_drink − eatenAt          (in hours)

if Δt < 0:
    modifier_meal = 1.00          (meal hasn't been eaten yet at t_drink)
else:
    modifier_meal = 1.00 − (1.00 − peak) × exp(−Δt / τ)
```

`peak` and `τ` are the values for that meal's size (see the table above). The modifier starts at `peak` at `eatenAt` and decays exponentially back toward 1.00 as the food empties from the stomach. It never exceeds 1.00 and never drops below `peak`.

If multiple meals are attached to the session, take the **smallest** modifier across all of them — that meal is the one most slowing absorption right now. (Equivalently: the meal with the strongest still-active effect wins.)

```
modifier = min over all session meals of modifier_meal_i
```

Apply the modifier to that drink's `BAC_initial`:

```
BAC_initial' = BAC_initial × modifier
```

Then continue with the absorption-window and elimination model ([Step 4](#step-4--absorption-window) onward). Each drink can carry a different modifier depending on which meals are still effective when it is consumed.

#### Practical cutoff

`exp()` is cheap, so the implementation can simply evaluate every session meal at every drink-time. If a cutoff is wanted (e.g. to skip meals that are obviously irrelevant), `Δt > 5 × τ_largest` is a safe threshold — at that point every meal's modifier is within 1% of 1.00 and contributes negligibly.

### Honest caveat about the model

Multiplying `BAC_initial` lowers the peak *and* shortens time-to-zero, which understates the total area under the BAC curve (AUC). Physiologically, food primarily *slows* absorption rather than reducing total alcohol exposure. A more accurate model would use a real absorption curve, but that requires additional parameters (drink volume rate, meal composition) that are out of scope for phase 1. The simple multiplicative approach is a usable approximation; we should not claim more accuracy than it delivers.

The chosen multipliers (0.95 / 0.85 / 0.75) are conservative compared to published peak-BAC reductions (literature shows 30–50% reductions in some studies), specifically because the simple model already omits absorption dynamics — over-correcting would compound the error in the optimistic direction.

### Meals from previous sessions

For simplicity, only meals attached to the **active** session contribute to the modifier. A meal logged in a previous session that would technically still be in window does not carry over. This is a known small inaccuracy, accepted in exchange for a clean session-scoped model.

**Relationship to the absorption window (below).** The meal modifier and the absorption window are deliberately **independent** mechanisms in phase 1 — the meal modifier keeps scaling `BAC_initial` down exactly as described above, and the absorption window (a separate delay before that scaled value is fully in the blood) is layered on top. They are not unified into a single "food widens the absorption window" model, even though that would be the more physiologically correct fix for the AUC understatement flagged in "Honest caveat about the model" above — that unification is deliberately deferred; see [issue #133](https://github.com/controlol/drinks-mate/issues/133) for the reasoning and what a future pass would need to change.

## Drink consumption time

Two distinct delays sit between "drink logged" and "alcohol actually in the blood," and phase 1's BAC model accounts for both as a single combined **absorption window**, used in [Step 4](#step-4--absorption-window) of the algorithm below:

1. **How long the user takes to actually drink it** — downing a shot versus nursing a glass of wine over an hour. This is a real behavioural difference between users and occasions, and the only one the app asks about.
2. **How long it then takes to cross the stomach/gut wall into the bloodstream** — driven by gastric emptying, not by drinking speed. Nobody can accurately self-report their own gastric absorption rate, so phase 1 models it as one fixed constant rather than a second user-facing setting (see "Where the numbers come from" below).

### The two components

- **`drinkConsumeMinutes`** — user-configurable. Stored globally on [`UserPreferences`](./data-model.md#userpreferences) and mirrored onto [`PartySession`](./data-model.md#partysession) (session-scoped, live while active, frozen at `endedAt`). Default **20 minutes**; range 0–60, editable in 5-minute steps. Settings surface: [user-experience.md → S4 Settings](./user-experience.md#s4--settings), Party Mode section.
- **`ABSORPTION_DELAY_MINUTES`** — a fixed model constant, **30 minutes**, not exposed to the user anywhere.

```
T_minutes = drinkConsumeMinutes + ABSORPTION_DELAY_MINUTES
```

`T` is never zero — even at the fastest `drinkConsumeMinutes` setting (0), the fixed 30-minute physiological delay still applies. This is a deliberate floor: a truly-instant BAC spike is not physiologically real, no matter how fast the drink is consumed.

**Why the range stops at 60, not further.** [Step 6's emergent property](#step-6--current-bac-pooled-across-drinks-and-absorption-windows) means a drink whose absorption rate `r` drops to `β` or below never registers any BAC at all — it's metabolised as fast as it's absorbed. For a typical single drink and profile, that crossover lands around `drinkConsumeMinutes ≈ 40–45 min` (e.g. a 75 kg male's 250 ml 5% beer: `r <= β` once `T_hours >= 0.181 / 0.15 ≈ 1.2 h`, i.e. `drinkConsumeMinutes >= ~42 min`) — comfortably above the default of 20. A range that ran further (e.g. to 120) would spend most of its span in "a typical single drink shows 0.00 g/L the whole time" — real zero-order behaviour, but one that reads as a bug rather than a feature to most users. Capping at 60 keeps the slow-sipping realism (a nursed drink genuinely peaks lower and later) without living mostly past that cliff.

### Global setting, mirrored per session, locked at end

- `UserPreferences.drinkConsumeMinutes` is editable any time from Settings → Party Mode, whether or not a session is active.
- When a session **starts**, `PartySession.drinkConsumeMinutes` is copied from the current global value.
- While the session is **active** (`endedAt IS NULL`), changing the global setting — or the session's own inline control on the [Party tab](./user-experience.md#s7--party) (see "Party tab during a session" below) — updates `PartySession.drinkConsumeMinutes` directly, and every drink already logged in the session recomputes its BAC contribution against the new value immediately. Unlike session pricing, this needs **no retroactive sweep** of `DrinkEntry` rows (compare [→ Editing prices during a session](#editing-prices-during-a-session)): `drinkConsumeMinutes` is a modeling parameter read live at BAC-computation time, never snapshotted onto a drink.
- When the session **ends**, `PartySession.drinkConsumeMinutes` stops tracking the global setting and holds whatever value was in effect at `endedAt`, permanently — changing the global setting afterward has no effect on the ended session's own BAC history. Because the field mirrors the global value continuously right up to that instant, "locked in, and equal to the global setting at the moment the session ended" falls out automatically; no separate copy step is needed at end-time beyond simply no longer mirroring further changes.

### Where the numbers come from

Mitchell et al. (2014) had fasted subjects drink 0.5 g EtOH/kg **over 20 minutes** and measured peak BAC — timed from the *start* of drinking — at 36±10 min (vodka/tonic), 54±14 min (wine), and 62±23 min (beer). Subtracting the 20-minute drinking window leaves roughly 16–42 minutes of further absorption delay after swallowing, depending on beverage. `ABSORPTION_DELAY_MINUTES = 30` sits in the middle of that range as one flat constant — phase 1 does not vary it by beverage type, matching the app's existing appetite for simplification elsewhere (the meal modifier's flat size buckets, one `β` for all users). See "References" below.

## Pricing during a session

Stored as [data-model.md → PartySessionPrice](./data-model.md#partysessionprice) override rows, with the session's token configuration on [PartySession](./data-model.md#partysession).

Festivals, bars, and house parties usually have different prices than a user's normal-day reference (and often use a token system instead of money). Party Mode supports both without ever modifying the user's regular drink presets.

### Concept

Each `DrinkPreset` carries a single **regular price** (the menu price). On top of that, an active session can carry **per-session price overrides** — one per preset — that replace the regular price while the session is active and `useSessionPrices` is on. Overrides live with the session, not on the preset, so the user's day-to-day pricing is never disturbed and historical sessions retain the prices that were actually applied.

The user-facing presentation is the mental-model the user described: a table where each drink shows its **regular price** in one column and its **party price** in another, with the party-price column editable while a session is active.

### Money vs tokens

Each session-price override is **either** a money amount **or** a token amount, not both. So a single session can mix freely — beer in tokens, water in cash — but a single drink within a session has one currency-of-payment.

The session itself carries a token configuration:

- **Token name** — what to call them in the UI ("Token", "Munt", "Drink ticket"). Optional; defaults to "Token".
- **Token value** — what one token is worth, in money. Optional. When set, the app can show a money-equivalent total alongside the token total. When unset, token spending is simply not summed in money.

Both live on `PartySession` (see [data-model.md → PartySession](./data-model.md#partysession)) and can be configured at session start or any time during the session.

### Starting a session — pricing prompt

When the user starts a session, the start flow includes a brief pricing step:

1. **Copy prices from your last session?** If the user has at least one previous session with overrides, this option is offered. Choosing yes copies the most recently *ended* session's `PartySessionPrice` rows into the new session, including currency / tokens. Choosing no starts with no overrides — every drink defaults to its regular price.
2. **Token configuration** — name, value (optional). Pre-filled from the previous session if "copy from last session" was chosen.

The whole pricing step is itself skippable in one tap ("Skip — use regular prices") for users who don't care about pricing.

### Editing prices during a session

The Party tab (active-session view) exposes a "Manage prices" action that opens the per-session price table:

- One row per `DrinkPreset` (excluding hidden ones), showing: drink name + icon, regular price (read-only, for reference), party price (editable, this session only).
- Tapping a party-price cell opens an editor: pick **money** (amount + currency, defaults to the user's preferred currency) or **tokens** (count). Pick "no override" to fall back to the regular price for this drink.
- Edits are saved immediately and apply to subsequent log actions in this session, **and retroactively** to every drink already logged in this session from that preset — its `priceMinor`/`priceTokens`/`currency` snapshot is rewritten to match what a fresh log action would resolve to right now (falling back to the regular price when "no override" is picked, or when the "use session prices" toggle is off).
- **Exception:** an entry that was given its own one-off, this-entry-only price override (the log-time price field on the Party log-alcohol sheet, or a per-entry price edit from S6/S9) is skipped by the retroactive sweep. A deliberate per-entry edit always wins over the session-wide table — the two price-editing mechanisms never fight each other.

**Critical invariant:** edits made here only ever touch `PartySessionPrice` rows and, via the retroactive sweep above, non-overridden `DrinkEntry` rows on the active session. The `DrinkPreset.regularPrice*` fields are never modified by Party Mode actions.

### Toggle: use session prices

A toggle on the Party tab's active-session view lets the user switch session pricing on or off live:

- **On** (default if any overrides exist at session start): drinks logged in this session use the session override if one exists, falling back to the preset's regular price.
- **Off**: drinks log at their regular price even though overrides exist. Useful when the user temporarily steps out of the festival context (e.g. drove home, opens the fridge).

The toggle is session-scoped state; it does not persist across sessions.

### What gets snapshotted onto the drink

When a drink is logged during a session, the price snapshot on the resulting `DrinkEntry` reflects what was actually applied at that moment:

- If money was applied: `priceMinor` + `currency` are set; the token fields are null.
- If tokens were applied: `priceTokens` + `tokenValueMinor` + `tokenValueCurrency` are set (the token value snapshot lets historical aggregations show a money-equivalent even if the session's token configuration changes later); `priceMinor` and `currency` are null.

This mostly follows the [log immutability principle](./data-model.md#snapshot-semantics--log-immutability), with one deliberate exception: a party-price edit (see "Editing prices during a session" above) retroactively rewrites this snapshot on already-logged, non-overridden entries for the affected preset. A per-entry price edit (S6, S9, or the log-time one-off override) still behaves as an ordinary immutable snapshot from every other actor's perspective.

### Aggregations across mixed payment

Per-session totals are shown grouped, the same way the app handles mixed currencies:

- "Spent: €18.50" (sum of money-paid drinks, grouped by currency)
- "Tokens used: 7" (sum of token-paid drinks)
- "Token value: ≈ €10.50" (only shown if `tokenValueMinor` is set on the session)

No conversion is attempted across currencies. The user sees the breakdown they actually paid.

## Logging an alcoholic drink (during a session)

The log-drink drawer ([user-experience.md → S2 Log drink](./user-experience.md#s2--log-drink)) gains:

- **Alcoholic beverage types**: `beer`, `wine`, `spirit`, `cocktail`, `other_alcohol`. Each has a default ABV (alcohol by volume, %), which the user can override per entry.
  - `beer` — default 5.0% ABV.
  - `wine` — default 12.0% ABV.
  - `spirit` — default 40.0% ABV.
  - `cocktail` — no default; user must enter ABV.
  - `other_alcohol` — user enters ABV.
  - `[OPEN]` — confirm defaults; these are reasonable European starting points.
- **ABV override** — the user can override the ABV for any entry (e.g. a strong IPA at 8%).
- **Volume** — already part of the standard flow.

The Party tab's own log-alcohol sheet (used for the "Log alcohol" action on [S7](./user-experience.md#s7--party)) additionally carries **name** and **price** fields, per-entry — the one-off, this-entry-only customisation that [S2's Advanced editor](./user-experience.md#s2--log-drink) no longer offers for any drink type. A price entered here is a **one-off override for this entry only** — it never writes to the session-wide `PartySessionPrice` table, matching how a per-entry price edit works everywhere else (S6, S9): the regular preset price, the session-wide override, and a single entry's one-off override are three independent layers, each writable only from its own dedicated UI.

Non-alcoholic drinks are logged exactly as outside a session and contribute to hydration as usual. They do not lower the BAC estimate (see "Hydration does not lower BAC" below).

## BAC estimation algorithm

The estimate is computed from the alcoholic drink entries belonging to the active session, plus the user's profile.

### Step 1 — grams of pure alcohol per drink

For each alcoholic drink entry:

```
alcohol_grams = volume_ml × (abv_percent / 100) × 0.789
```

`0.789 g/mL` is the density of ethanol at room temperature.

### Step 2 — distribution volume

The choice of model is **data-driven**, not user-selectable. The app picks the most accurate option that the available profile data supports:

- **Watson TBW model** — used when both `heightCm` and `birthDate` are present (so age can be derived). Documented in the literature as ~15–20% more accurate than Widmark because it accounts for individual body composition rather than using a fixed `r` value.

  ```
  age_years    = floor((today − birthDate) / 365.25)
  TBW_male_L   = 2.447 − 0.09516 × age_years + 0.1074 × height_cm + 0.3362 × weight_kg
  TBW_female_L = −2.097 + 0.1069  × height_cm + 0.2466  × weight_kg
  ```

  Watson is validated for adults with BMI ≈ 17–67 (men) / 17–80 (women). When the user's computed BMI falls outside that range, the UI shows a small inline warning alongside the BAC value: *"BAC estimates may be less accurate for users outside typical body composition ranges."* The warning is informational only — the algorithm still computes and displays the estimate normally. Concretely:

  - Warn if `BMI < 17` (any gender).
  - Warn if `BMI > 67` and gender is `male`.
  - Warn if `BMI > 80` and gender is `female` or `unspecified` (unspecified follows the conservative path, see above).

  The warning only fires on the Watson path — when height is missing and BAC falls back to Widmark, no BMI can be computed and no warning is shown.

- **Widmark fallback** — used when height is missing (which is the only optional field for Party Mode; birthday is required, so age is always available). Uses the classic 1932 distribution-ratio approach:

  ```
  r = 0.68 (male), 0.55 (female), 0.55 (unspecified — conservative)
  ```

  When the unspecified-gender path is taken, the BAC display includes the explanatory footnote described above.

### Step 3 — initial BAC (g/L)

Per drink, with `meal_modifier` as described in the "Meals" section above (`1.00` if no meal applies, otherwise the exponentially-decaying value at `t_drink`):

- **Watson path** (height available):
  ```
  BAC_initial_g_per_L = (alcohol_grams × 0.806) / TBW_L × meal_modifier
  ```
  `0.806` is the water fraction of whole blood, which converts the TBW-distributed concentration to a blood concentration.

- **Widmark fallback** (height missing):
  ```
  BAC_initial_g_per_L = alcohol_grams / (weight_kg × r) × meal_modifier
  ```

### Step 4 — absorption window

Each drink's alcohol enters the bloodstream over a window, not instantly. See [Drink consumption time](#drink-consumption-time) above for where the two inputs come from.

```
T_hours = (drinkConsumeMinutes + ABSORPTION_DELAY_MINUTES) / 60      (ABSORPTION_DELAY_MINUTES = 30, fixed)
r = BAC_initial / T_hours                                            (g/L per hour — this drink's constant absorption rate)
```

`drinkConsumeMinutes` comes from the owning `PartySession`. `BAC_initial` is this drink's Step 3 value, already carrying its meal modifier. The drink is **absorbing** during `[consumedAt, consumedAt + T_hours)` and contributes nothing to the pool before `consumedAt`.

### Step 5 — elimination rate

The body eliminates alcohol at a roughly linear rate (zero-order kinetics) whenever there is alcohol in the blood — **including while a drink is still absorbing**, not only afterward. Use:

```
β = 0.15 g/L per hour   (default)
```

`β` typically ranges from 0.10 to 0.20 g/L/h across individuals. `0.15` is a common midpoint used in forensic and educational calculators, and lines up with the ~15 mg%/h average reported in the pharmacokinetics literature (1 g/L = 100 mg%).

### Step 6 — current BAC (pooled across drinks and absorption windows)

The blood alcohol pool has one net rate of change at any instant: the sum of the absorption rates `r` of every drink currently inside its window, minus `β` — floored at 0, since the pool cannot go negative.

```
net_rate(t) = (sum of r_i for every drink i with consumedAt_i <= t < consumedAt_i + T_hours_i) − β
```

To compute the pool at a query time `t_query`, walk the session's drinks in consumption order and build a sorted timeline of **rate-change events**: each drink contributes a `+r_i` event at `consumedAt_i` (starts absorbing) and a `−r_i` event at `consumedAt_i + T_hours_i` (finishes absorbing). Starting from `pool = 0` before the first drink, step through the events in chronological order up to `t_query`:

1. Advance the pool across the elapsed time to the next event (or to `t_query`, if that comes first) at the current net rate, flooring at 0: `pool = max(0, pool + net_rate × elapsed_hours)`.
2. Apply the event (add or subtract `r_i` to/from the running rate) and continue.

This directly generalises the single running-pool loop this step used before absorption windows existed — "decay the pool, then add the next drink's `BAC_initial`" is the special case where every `T_hours_i` is negligible — and it inherits the same over-elimination fix that loop was built to avoid: one shared `β` at every instant, never `N × β` for `N` simultaneously-active drinks (summing each drink's contribution independently over-eliminates for exactly that reason, and remains wrong for the same reason here).

**Emergent property, worth relying on elsewhere in this spec:** for a drink absorbed in isolation (no overlap with another drink's window) with `r_i > β`, the *total elapsed time from `consumedAt` until that drink's contribution returns to 0* is exactly `BAC_initial / β` — identical to the old instant-absorption formula, and independent of `T_hours`. Only the **shape** changes: a lower, later peak that catches up to the same straight decay line the instant the window closes (`BAC_initial − β × (t − consumedAt)`, unchanged), not the total time the alcohol is in the system. This is why the [orphan absorption rule](#absorbing-orphan-drinks-when-a-later-session-starts) below needs no formula change for the common case. The property only breaks down when `r_i <= β` — drunk so slowly that elimination keeps pace with absorption: the drink's contribution never rises off 0 and is fully metabolised as fast as it enters the blood. That is real, intended zero-order behaviour, not a bug; treat it as `t_zero = consumedAt` (no residual ever accumulates).

### Step 7 — formats for display

The app shows BAC in `g/L` as the primary value and `mmol/L` as a secondary value:

```
BAC_mmol_per_L = BAC_g_per_L × 21.7
```

`g/L` is the canonical internal unit; `mmol/L` is derived only at the display boundary.

### Worked example (sanity check)

A 75 kg, 180 cm, 30-year-old male starts a session (default `drinkConsumeMinutes = 20`) and drinks two 250 ml beers at 5% ABV at the same time — so both share `T_hours = (20 + 30) / 60 = 0.833 h` (50 min).

- Alcohol per beer: `250 × 0.05 × 0.789 = 9.86 g`
- Total alcohol: `19.73 g`
- TBW: `2.447 − 0.09516 × 30 + 0.1074 × 180 + 0.3362 × 75 = 43.93 L`
- BAC initial (Step 3, combined — both beers logged at the same instant): `(19.73 × 0.806) / 43.93 = 0.362 g/L (≈ 7.85 mmol/L)`
- Absorption rate (Step 4): `r = 0.362 / 0.833 = 0.434 g/L/h`
- Net rate while absorbing (Steps 5–6): `0.434 − 0.15 = 0.284 g/L/h`
- **Peak, at `consumedAt + 50 min`:** `0.284 × 0.833 = 0.237 g/L (≈ 5.14 mmol/L)` — lower than, and 50 minutes later than, the pre-absorption-window model's instant peak of `0.362 g/L` at `consumedAt`.
- After 2 hours (70 minutes past the peak, fully outside the absorption window): `0.237 − 0.15 × (2 − 0.833) = 0.062 g/L (≈ 1.34 mmol/L)` — **identical to what the old instant-absorption model gives at the same clock time** (`0.362 − 0.15 × 2 = 0.062`), which is exactly the emergent property from Step 6: once every drink's absorption window has closed, the two models sit on the same decay line.
- Time to zero: `consumedAt + 0.362 / 0.15 ≈ consumedAt + 2h25min` — also unchanged from the old model, since `r (0.434) > β (0.15)` for this drink (Step 6's emergent property applies). This total duration is independent of `drinkConsumeMinutes` entirely, as the invariant predicts.
- If no further alcohol is logged, the session auto-ends 12 hours after that last beer's `consumedAt`, unchanged.

### Worked example 2 — staggered drinks (pooling stress test)

Same profile and settings as above, but the two beers are logged **10 minutes apart** instead of together — this is the case that actually exercises Step 6's event-timeline pooling, since the two absorption windows overlap without being identical.

- Beer A at `consumedAt = 0 min`; Beer B at `consumedAt = 10 min`. Each alone: `BAC_initial = (9.86 × 0.806) / 43.93 = 0.181 g/L`, `T_hours = 0.833 h` (50 min), `r = 0.181 / 0.833 = 0.217 g/L/h`.
- Beer A absorbs over `[0, 50 min)`; Beer B absorbs over `[10 min, 60 min)` — a 40-minute overlap where both are simultaneously ramping.
- Event timeline and pool (`net_rate = active_r_sum − β`, floored at 0):

  | Segment (min) | Active | net_rate (g/L/h) | Pool at segment end (g/L) |
  | ------------- | ------ | ----------------- | -------------------------- |
  | 0–10   | A only    | `0.217 − 0.15 = 0.067` | `0.067 × (10/60) = 0.011` |
  | 10–50  | A + B     | `0.434 − 0.15 = 0.284` | `0.011 + 0.284 × (40/60) = 0.201` |
  | 50–60  | B only    | `0.217 − 0.15 = 0.067` | `0.201 + 0.067 × (10/60) = 0.212` |
  | 60+    | neither   | `−0.15` | decays from `0.212` |

- **Peak: `0.212 g/L` at `t = 60 min`** (when B's window closes) — lower than either the single-drink instant peak (`0.181`×2 if summed naively) or the simultaneous-logging Worked Example 1's peak (`0.237` at 50 min), because spreading the same two drinks further apart in time gives elimination more opportunity to act before the second drink's mass fully lands.
- Time to zero from `t = 0`: mass-balance shortcut (Step 6) still applies since the pool never touches the floor before its final decay — total time `= (0.181 + 0.181) / 0.15 = 2.413 h ≈ 145 min`, i.e. zero at `t ≈ 60 min + 85 min`. Matches a direct decay-from-peak calculation: `0.212 / 0.15 = 1.41 h ≈ 85 min` after the peak.
- **What this pins:** the pooled algorithm uses one shared `β` throughout the 30-minute overlap (`0.542 − 0.15`, not `0.271 − 0.15 − 0.15`) — the same over-elimination fix Step 6 carries forward, now also proven across overlapping absorption windows, not just overlapping post-absorption decay.

## BAC goal (cap)

- The user can set a personal cap, configured in settings, expressed in **g/L** (with the mmol/L equivalent shown). Default: **off** (no cap).
- The cap is a single persistent setting and applies whenever a session is active. It is not per-session.
- During an active session the [Party tab](./user-experience.md#s7--party) shows current estimated BAC versus the cap, with a clear visual indicator when the user is approaching or above the cap.
- The "approaching cap" notification fires when a logged drink's **projected peak** (see "Notifications during a session" below) reaches **80% or more** of the cap (inclusive boundary — see Parity Rulebook "Approaching-cap trigger"). Because this fires on a forward projection rather than the instant value, the notification copy must read prospectively ("on track to approach your cap," not "you have reached") — actual current BAC can be well below 80% at the moment it fires.
- The cap is a personal goal, not a legal threshold. The UI must not present it as a "safe to drive" line under any circumstances.

### Relation to legal limits

For reference only — these are **not** built into the cap behaviour:

- Netherlands: 0.5 g/L (≈10.85 mmol/L) for experienced drivers, 0.2 g/L (≈4.34 mmol/L) for novice drivers.
- Many other EU countries: 0.5 g/L.

Settings show these limits as reference values inside the Party Mode section, with a strong "informational only" framing — they help the user place their cap in context, not to indicate fitness to drive.

## Notifications during a session

When a session is active, the standard hydration reminders ([notifications.md](./notifications.md)) continue to behave as normal. Two additional notifications, both off by default, become eligible to fire:

- **Approaching cap.** Evaluated once, at the moment a drink is logged: project the pool forward through every currently-absorbing drink's remaining window — assuming no further drinks are logged — and find its peak. This is the same forward projection the [BAC line chart](#bac-line-chart)'s dashed segment already computes, reused here rather than built separately. If that projected peak is **80% or more** of the cap (inclusive), the app sends the notification immediately. This is a deliberate change from the pre-absorption-window rule ("pushes the estimated BAC to ≥80% *right now*"), which stops being meaningful once a drink's effect is spread over a window instead of landing instantly — projecting forward preserves the "warn as soon as you log something that matters" intent instead of silently going quiet. Logging a further drink re-projects from the new pool state and can fire again if the newly-projected peak newly clears the threshold.
- **Sober estimate.** When the estimated BAC returns to 0 g/L, the app sends a single notification ("Estimated BAC is back to 0 — remember this is an estimate."). The user can disable this independently. Scheduled against the session's projected zero-time, which — per [Step 6's emergent property](#step-6--current-bac-pooled-across-drinks-and-absorption-windows) — is unaffected by the absorption window as long as every drink's absorption rate exceeds β. In the rare case a drink is consumed so slowly that it never accumulates residual BAC (`r <= β`), there is no "return to 0" to notify about for that drink's contribution — it never left 0.

When the session ends (manually or automatically), neither of these notifications fires until a new session is active.

## Party tab during a session

When a session is active, the [Party tab](./user-experience.md#s7--party) displays an active-session view containing:

- A **summary card** at the top: current estimated BAC in **g/L** (large, clearly labelled "estimate") with the **mmol/L** equivalent shown smaller alongside, the user's cap (if set, same g/L primary / mmol/L secondary format with progress toward it), and time elapsed since the session started. If the session has a name (see "Starting a session" above), it is shown here too. **The entire card is tappable** and opens [user-experience.md → S9 Party Session Log](./user-experience.md#s9--party-session-log), the itemised, editable list of this session's drinks — the same destination the drinks-count line below opens.
- A **BAC line chart** plotting the estimated BAC over time (see "BAC line chart" below), in its own card directly below the summary card. The chart has its own tap-to-inspect-value interaction (see "Tap to inspect a value" below) and does **not** open S9 — its tap target is reserved for that, distinct from the summary card above it.
- A **quick-log widget for alcohol**, directly below the BAC line chart card: the same two-tap-to-log pattern as [S1's "Quick Log" grid](./user-experience.md#s1--today-home), scoped to alcoholic presets only. Shows the **top 2** alcoholic presets, always sorted by most-recently-used (automatic — no manual reordering), no scrolling. Tapping a tile logs that preset directly into the active session, same as the "Log alcohol" action.
- Number of alcoholic drinks logged this session and total grams of alcohol. This line is tappable and opens S9, same as the summary card above.
- A small **meal indicator** labelled "Add meal" — the label is constant, whether or not a meal has been logged yet. Once at least one meal has been logged this session, the count and relative time since the last one appears right-aligned on the same row (e.g. "2 meals · 45 min ago"). Tapping the indicator, anywhere on the row, opens the meal-size prompt to log a new meal. Editing or deleting an already-logged meal is done from [S9 Party Session Log](./user-experience.md#s9--party-session-log), the single authoritative place for meal edits and deletes, matching the drink-editing model.
- A **consume-time control**: a small row showing the session's current `drinkConsumeMinutes` (e.g. "Drink pace: 20 min"). Tapping it opens a stepper to adjust the value in 5-minute steps (0–60), same range as the global setting. Editing here updates `PartySession.drinkConsumeMinutes` directly and re-renders the BAC summary and chart immediately — see [Drink consumption time](./party-session.md#drink-consumption-time). Only shown while the session is active; an ended session's [S9](./user-experience.md#s9--party-session-log) header shows the frozen value as read-only text instead.
- A **session-prices control**: a small toggle showing the current `useSessionPrices` state and a "Manage prices" link that opens the per-session price table. When session prices are off but overrides exist, the toggle reads "Session prices: off — using regular prices".
- A **session totals** strip showing money spent (grouped by currency) and tokens used so far in this session. The token value money-equivalent is shown if `tokenValueMinor` is set.
- A full-width **"Log alcohol"** action, persistent at the bottom of the screen (sitting above the tab bar, outside the scrolling content) — same sticky treatment as S1's "Log drink" button. **End session** stays as an ordinary in-flow action above it, not sticky.

### BAC line chart

A line chart inside the active-session section visualising the estimated BAC over the session's lifetime plus its projected decay.

**Time axis (X)**
- Starts at the session's `startedAt`.
- Ends at the **projected return-to-zero time** — the moment the model says the BAC will be back to 0 g/L given the drinks logged so far. The end time is **rounded up to the next 30 minutes** so the axis sits on a tidy mark (e.g. predicted 02:47 → axis ends at 03:00; predicted 02:05 → axis ends at 02:30).
- Tick labels are rendered as **24-hour digital time in the device's local timezone** (e.g. `21:30`, `22:00`, `23:00`). Tick spacing is chosen automatically based on total span: every 30 min for spans under ~3 h, every hour for ~3–8 h, every 2 hours beyond that.

**Value axis (Y)**
- BAC in **g/L** as the primary scale.
- mmol/L shown as the secondary scale on the opposite side of the axis (or as a tooltip label, depending on layout density).
- The user's cap is drawn as a horizontal dashed line if set.

**The line itself**
- **Solid** segment: from `startedAt` to **now**. Plots the actual estimate based on drinks already logged.
- **Dashed** segment: from **now** to the rounded end time. This is the projection. The dashed segment also has a **subtle red tint** in the chart background behind it (a low-opacity red wash on the plot area to the right of "now"). The visual signal: solid + clear background = past/present, dashed + reddish background = predicted.
- A subtle vertical reference line at "now" marks the transition.
- **No vertical jumps.** Each logged drink shows as the start of a smooth linear rise (its absorption window, [Step 4](#step-4--absorption-window)) rather than an instant vertical step — this falls directly out of the pooled BAC algorithm and needs no special-casing in the chart: the plotted curve is already piecewise-linear across the whole session. The curve's *shape* depends only on the logged drinks, the session's `drinkConsumeMinutes`, and any meals — never on "now" — so "now" only moves the solid/dashed divider along an already-fully-determined line; it does not itself trigger a reshape (see "Re-rendering" below).

**Empty state**
- The chart area is reserved and rendered from the moment the session starts, even before any drink is logged — this avoids a layout jump when the first drink lands. Before the first alcoholic drink, it shows a **flat line at 0.00 g/L** across a default three-hour window (`startedAt` to `startedAt + 3h`), with no dashed projection segment (there is nothing to project yet) and no "now" marker. The user's cap, if set, still draws as a dashed horizontal reference line. The moment the first drink is logged, the chart switches to the normal solid/dashed rendering described above, re-scaled to the real projected end time.

**Tap to inspect a value**
- Tapping anywhere on the chart (solid or dashed segment) renders a vertical marker line at the tapped time and a small label showing the estimated BAC (g/L, with mmol/L alongside) at that point. Tapping elsewhere on the chart moves the marker; tapping outside the chart dismisses it. This is a chart-local interaction — it never navigates away from the Party tab, and is independent of the summary block's tap-to-open-S9 behaviour described below.

**Re-rendering**
- The chart re-renders whenever a drink is added, edited, or deleted in the session, when the meal modifier changes, or when "now" advances enough that the rounded end-time would change.

When no session is active, the Party tab shows a no-active-session state instead — a full-width **Start party session** button plus, on subsequent visits, a list of past sessions. The first time the user opens the tab they also see a brief explainer of what Party Mode is, including the "this is an estimate" disclaimer. See [user-experience.md → S7 Party](./user-experience.md#s7--party) for the canonical content list.

Party Mode is a secondary feature: it occupies its own tab so users can find it when they want it, while never appearing on the Today screen. Hydration is the headline of the app; Party Mode is available when needed.

## Hydration does not lower BAC

A common misconception: drinking water does not speed up alcohol elimination. The body metabolises ethanol at a near-constant rate regardless of hydration. The app must not imply otherwise:

- Logging a glass of water does **not** reduce the displayed BAC estimate.
- Notification copy during a session must avoid suggesting that drinking water "sobers you up". Hydration reminders during a session are still useful for general hydration, and the copy should reflect that honestly.

## Data we will not collect

Party sessions do not ask for, and the app does not store:

- Specific medications or health conditions.
- Whether the user has eaten.
- Pregnancy status.
- Anything else of a clinical nature.

The estimate is intentionally simple. If a user needs higher accuracy, they need a breathalyser, not an app.

## References

The algorithm above is based on:

- E.M.P. Widmark (1932), "Die theoretischen Grundlagen und die praktische Verwendbarkeit der gerichtlich-medizinischen Alkoholbestimmung."
- P.E. Watson, I.D. Watson, R.D. Batt (1981), "Total body water volumes for adult males and females estimated from simple anthropometric measurements." *Am J Clin Nutr* 33:27–39.
- A.W. Jones (2010 / 2020), reviews on alcohol pharmacokinetics — see Wikipedia's BAC article and the NIH PMC review linked below for accessible summaries.
- M.C. Mitchell Jr., E.C. Teigen, C.S. Ramchandani (2014), "Absorption and Peak Blood Alcohol Concentration After Drinking Beer, Wine, or Spirits." *Alcoholism: Clinical and Experimental Research* 38(5):1200–1204 — source of the [`ABSORPTION_DELAY_MINUTES` default](#where-the-numbers-come-from).
- NCBI StatPearls, "Physiology, Zero- and First-Order Kinetics" — background on why ethanol elimination is zero-order and absorption is first-order.

Authoritative public summaries:

- [Blood alcohol content — Wikipedia](https://en.wikipedia.org/wiki/Blood_alcohol_content)
- [Alcohol calculations and their uncertainty — NIH PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC4361698/)
- [Total body water is the preferred method to use in forensic blood-alcohol calculations — ScienceDirect / PubMed 33099270](https://pubmed.ncbi.nlm.nih.gov/33099270/)
- [Absorption rate constant — Wikipedia](https://en.wikipedia.org/wiki/Absorption_rate_constant)
- [Physiology, Zero- and First-Order Kinetics — NCBI Bookshelf NBK499866](https://www.ncbi.nlm.nih.gov/books/NBK499866/)
