# User Experience

This document describes the screens and primary flows of Drinks Mate. Visual design (colours, typography, exact layouts) is not finalised here — these are the structural requirements the visual design must support.

## Design principles

1. **Logging is the primary action.** The home screen exists to make logging fast. Everything else is secondary.
2. **One thumb, one hand.** Primary actions live in the lower half of the screen so the app is usable one-handed on a phone.
3. **Glanceable progress.** A user should understand their hydration status within a second of opening the app.
4. **Forgiving.** Every log can be edited or deleted. Mistakes are normal and easy to fix.

## Screens

### S1 — Today (home)

The default screen on app launch. Shows:

- A prominent visual indicator of progress toward today's goal (e.g. a filling shape or ring) with the numeric value and goal alongside.
- A list of today's logged drinks, newest first, each row showing beverage icon/type, volume, and time. Tapping a row opens edit/delete.
- A primary "Log drink" action (large, bottom of screen).
- A row of quick-log presets above or beside the primary action — tapping a preset logs that drink immediately at the current time, with a brief confirmation that can be undone.
- A **Party Session** control:
  - **No active session:** a small, understated entry point — a low-emphasis tile or link-style row placed below the primary hydration content. Party Mode is a secondary feature; the entry point should never compete with hydration progress, the log-drink action, or the today drinks list.
  - **Active session:** the entry point is replaced by a more prominent BAC section. Its full content list (current BAC, BAC line chart, cap progress, drinks count, total grams, time elapsed, meal indicator, session-prices control, session totals, End session action) is the canonical "Today view during a session" list in [party-session.md](party-session.md). Treat that list as authoritative; this S1 description does not duplicate it.

### S2 — Log drink

Reached from the primary action on the home screen. Presented as a **drawer that opens from the bottom of the screen and may expand to take up the entire screen**. The drawer has two phases: pick a drink, then edit and confirm.

#### Phase 1 — Pick a drink

- A **search field** at the top filters the preset list by name as the user types.
- A **scrollable list** of all visible drink presets (default + user-created, excluding hidden), each row showing its icon (in its configured colour) and its name. The list is grouped or ordered to surface the user's most-used presets near the top.
- A **"Create new preset"** action at the end of the list opens the create-preset flow (see F14).

Tapping a preset advances the drawer to phase 2.

#### Phase 2 — Edit and confirm

The selected preset is shown at the top (icon, name) so the user can confirm what they picked. The bottom of the drawer carries the editing controls and the action row:

- **Quick edits** — `volume` and `time` (defaults to now). Both inline, low-friction.
- **Action row** — at the very bottom of the drawer:
  - **Primary "Confirm" button**, large and full-width by default.
  - **A smaller "Advanced" button to the left of Confirm**, opening an additional editor for `name`, `ABV` (alcoholic drinks only), and `price`. Only fields the user is likely to want to tweak per-entry — the icon and colour are not editable here; those belong to the preset itself and are changed in "Manage drinks".

#### Advanced editor

Opening the Advanced editor reveals fields for `name`, `ABV`, and `price`. After making changes the user has three exit paths:

1. **Back** — discards the advanced edits and returns to phase 2 with the preset's original values.
2. **Confirm** — logs the drink with the entered values **for this entry only**. The underlying preset is unchanged. This is the most common path when the user just needs a one-off variation (e.g. "this particular beer is 7% instead of 5%").
3. **Save and confirm** — writes the advanced values back to the preset (overwriting it), **then** logs the drink. Use case: the user has been incorrectly over-stating their default beer's ABV and wants to fix the preset permanently. Per the [log immutability principle](data-model.md#snapshot-semantics--log-immutability), saving back to the preset does **not** modify any historical drink entries.
4. **Save as copy and confirm** — creates a **new preset** with the advanced values (the user is asked to confirm the new name), then logs the drink against the new preset. Use case: the user found a new drink they'll want to log again.

Options 3 and 4 are typically offered together as a split button or a small menu attached to the primary save action; "Confirm" remains the primary action on the row when nothing has been edited.

#### State transitions

- Tapping outside the drawer or swiping it down dismisses it without logging anything.
- After a successful confirm (any of the three confirm paths), the drawer closes and the today view shows the new entry with a brief "Logged" toast and undo affordance.

### S3 — History

Reached from a tab or menu. The screen has:

- A **range selector** at the top: Weekly / Monthly, with paging controls to step backwards and forwards through past periods.
- A stack of **bar charts** for the selected range. Hydration charts are always present; alcohol charts appear only when at least one Party Session overlaps the selected range. See [features.md](features.md) F4 for the full chart spec.
- A **day list** below the charts. Tapping a day on any chart, or selecting a row in the list, drills into the day detail (drink list with edit/delete, plus any Party Session summary on that day).

Charts are read-only. Editing always happens via the day drill-down or the today view.

### S4 — Settings

The settings screen is grouped into the following sections, in this order. This list is the canonical settings spec — F6 in [features.md](features.md) mirrors it.

1. **Hydration**
   - Daily goal (numeric input, ml). Suggested during onboarding from `30 ml × weight_kg` rounded to nearest 100 ml.
   - Day boundary (local time, default 05:00).
2. **Reminders** (see [notifications.md](notifications.md))
   - Master on/off.
   - Active hours (default 08:00–22:00).
   - Interval (default 90 min).
   - Inactivity reminder toggle (default ON).
   - Weekly summary toggle (default ON).
   - Default drink — reference to a non-alcoholic `DrinkPreset` (default: "Glass of water").
3. **Drinks**
   - Manage drinks — list of drink presets with reorder, edit, hide, delete, and create-new actions. See [features.md](features.md) F14.
4. **Profile**
   - Gender (male / female / unspecified).
   - Weight (kg).
   - Height (cm, optional).
   - Birthday (optional but required to use Party Mode).
5. **Party Mode**
   - Personal cap (g/L, optional).
   - "Approaching cap" notification toggle (default OFF).
   - "Sober estimate" notification toggle (default OFF).
   - "Show BAC on lock screen" toggle (default ON).
   - Reference legal limits (informational only — NL 0.5 g/L experienced / 0.2 g/L novice; many EU 0.5 g/L).
6. **Display & format**
   - Units (metric / imperial display).
   - Currency (EUR / USD / GBP).
7. **About / version**.

### S5 — Onboarding (first launch only)

Onboarding creates a profile that the rest of the app builds on. Steps are presented in this order:

1. **Welcome** — one-line value proposition.
2. **Username** — a short freeform name. Used locally as a friendly label and reserved as the basis for friend discovery in phase 2. `[OPEN]` — allowed length / allowed characters.
3. **Personal info**:
   - **Gender** — three options: *Male*, *Female*, *Prefer not to say*. Defaults to *Prefer not to say* (= `unspecified`) if the user does not change it. The copy explains this is asked for hydration and BAC pharmacokinetic calculations.
   - **Weight** — kilograms. **Required**, defaults to `70 kg`. The user can adjust before continuing.
   - **Height** — centimetres. **Optional**. Improves BAC accuracy in Party Mode (Watson model). Skippable.
   - **Birthday** — date. **Optional in onboarding**, but **required to use Party Mode** (for both the 18+ gate and the Watson age input). Skippable here; the user is asked again the first time they try to start a session.
4. **Daily hydration goal** — pre-filled with the personalised suggestion `30 ml × weight_kg`, rounded to the nearest 100 ml. The user can accept the suggestion or override it. The suggestion is always computed from weight (which is required), so there is no "no weight" fallback case in normal flow.
5. **Notification permission** — request with an honest explanation (reminders to drink). The user can decline and still use the app.

Onboarding is one continuous flow with no skip-everything escape, but each step has a sensible default so a user who taps "next" through the whole thing ends up with a working profile: gender `unspecified`, weight 70 kg, no height, no birthday, daily goal **2100 ml** (= 30 × 70 kg, rounded). The user can revise any of these in settings.

## Key flows

### Flow 1 — First-time use

1. User opens the app for the first time.
2. Onboarding (S5) runs — under 30 seconds end to end.
3. User lands on the today view (S1) with their goal set and an empty drink list.
4. User logs their first drink via a quick-log preset or the log-drink screen.

The 60-second goal from the success criteria applies here.

### Flow 2 — Quick log (most common)

1. User opens the app.
2. Taps a quick-log preset on the today view (e.g. "200 ml water").
3. The drink is logged at the current time. Progress updates immediately. A brief toast or similar confirms the action with an undo affordance.

Two taps total (open the app, tap the preset).

### Flow 3 — Detailed log

1. User opens the app and taps "Log drink".
2. User selects beverage type, volume, and optionally adjusts the time.
3. User confirms; the drink is added to today's list and progress updates.

### Flow 4 — Correcting a mistake

1. User taps an entry in today's drink list.
2. User edits volume, type, or time, or deletes the entry.
3. Progress updates accordingly.

### Flow 5 — Responding to a reminder

1. User receives a reminder notification.
2. Tapping the notification opens the app on the today view, ready to log.
3. `[OPEN]` — should the notification itself include a quick-log action so the user can log without opening the app? Recommended for a later iteration.

## Accessibility

- All interactive elements must have accessible labels.
- The app must support the system's dynamic text sizes.
- Colour must not be the sole indicator of state (e.g. goal-met should also have an icon or text label, not only a colour change).
- The app should work with VoiceOver (iOS) and TalkBack (Android).
