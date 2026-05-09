# Notifications

Reminders are a core part of the value proposition: the app exists in part to nudge users to drink throughout the day. This document describes how reminders should behave.

## Principles

1. **Spread, don't cram.** Reminders should encourage steady intake throughout the day. The point is *not* to flag a shortfall at 22:00 — it is to keep the user on pace.
2. **Respect the user's day.** Reminders only fire during user-configured active hours. Outside those hours, the app stays silent.
3. **Don't be annoying.** If the user has just logged a drink, the next reminder should be pushed back. A reminder right after a log is friction, not help.
4. **Adapt to actual intake.** Reminders adjust their recommended volume based on how the user is pacing today. Drinking more than expected reduces the next recommendation; drinking less increases it.
5. **Stop pestering inactive users.** If the user hasn't engaged with the app for a full week, no notifications fire — of any type — until they engage again.
6. **Local, not server.** Reminders are scheduled locally on the device. The app does not need a backend or push infrastructure for phase 1.

## Configuration

The user can configure, in settings:

- **Reminders enabled** — master on/off toggle. When off, no notifications of any type fire.
- **Active hours** — start and end time during which reminders may fire. Default: **08:00–22:00**.
- **Interval** — how often to remind. Default: **every 90 minutes**. The user can pick from a small set of values, e.g. 60 / 90 / 120 minutes.
- **Inactivity reminder** — independent on/off toggle. Default **ON**.
- **Weekly summary** — independent on/off toggle. Default **ON**.
- **Default drink** — beverage type and volume used by both the notification quick-log action and the reminder volume calculation. Default: **water, 200 ml**. See [data-model.md](data-model.md) UserPreferences.

The day boundary (when "today" rolls over) is also configurable, defaulting to **05:00**. It applies to goal tracking and reminder scheduling alike — see features F2.

## Behaviour

### When reminders fire

A reminder fires when **all** of the following are true:

1. Reminders are enabled and the OS-level notification permission is granted.
2. The user is **not inactive** — see "Inactive-user silence" below.
3. The current time is within the configured active hours.
4. The user has **not yet reached today's hydration goal**. Once intake ≥ goal for the current day, reminders stop until the next day-boundary rollover. (If the user later deletes or edits an entry such that intake drops back below goal, reminders resume on the normal schedule — current intake is what matters, not historical.)
5. At least `interval` has passed since the most recent drink log.

### Inactive-user silence

A universal rule that applies to **every notification type** in this document:

```
last_engagement = max(
    most_recent_DrinkEntry.consumedAt,         -- if any
    UserPreferences.installedAt                -- always present
)
days_inactive   = floor((now − last_engagement) / 1 day)

if days_inactive >= 7:
    suppress all notifications
```

- A brand-new user who has never logged a drink still gets 7 days of welcome reminders, measured from install time.
- An established user who stops logging gets 7 days of grace before notifications stop.
- The moment the user logs any drink (in-app, retroactively, or via the notification quick-log action), `last_engagement` resets and notifications resume on their normal schedule.
- The check runs at notification fire-time on the device, not in advance — so a user who silently passes the 7-day mark stops receiving the next scheduled notification, without the app needing to actively cancel anything.

`UserPreferences.installedAt` is the timestamp of when the local database was first created on this device — set once at install and never changed. See [data-model.md](data-model.md).

### Scheduling

- When reminders are enabled, the app schedules notifications at the configured interval within the active hours of each day.
- Logging a drink resets the reminder timer: the next reminder fires `interval` after the most recent log, not after the previously-scheduled reminder.
- Hitting the goal cancels remaining same-day reminders. The next day's first reminder is scheduled normally after the day-boundary rollover.

### Recommended volume per reminder

Each reminder recommends a specific amount to drink, expressed in **glasses** (where one glass = the user's configured default-drink volume) and rounded to **0.5-glass increments**. The amount is computed from the user's pace deficit at reminder time:

```
day_start         = today's day-boundary (e.g. today at 05:00)
active_start      = day_start applied to the configured active-hours start (e.g. today at 08:00)
active_end        = day_start applied to the configured active-hours end   (e.g. today at 22:00)
active_window_min = active_end − active_start

# Where the user "should" be by now, on a linear pace through the active window:
elapsed_active_min  = max(0, min(active_window_min, t_now − active_start))
expected_intake_ml  = goal_ml × (elapsed_active_min / active_window_min)

deficit_ml          = expected_intake_ml − actual_intake_today_ml
glasses_raw         = deficit_ml / default_drink_volume_ml
glasses_rounded     = round(glasses_raw × 2) / 2     # nearest 0.5

glasses_recommended = clamp(glasses_rounded, 0.5, 2.0)
```

- **Minimum** is `0.5` glass. Even if the user is on or ahead of pace, the reminder still recommends half a glass — the point of the reminder is to maintain the habit, not just to recover lost ground.
- **Maximum** is `2` glasses. Even if the user is far behind, we don't recommend chugging more than two glasses at once.
- **Adjustment in action.** Suppose the previous reminder said "1.5 glasses" and the user logged 2 glasses afterward. The user is now 0.5 glass ahead of where the linear pace expected them, so the next reminder recommends one glass less than it would have — typically just 1 glass. This falls out of the formula naturally because `actual_intake_today_ml` includes the user's recent over-shoot.

### Notification copy

Copy is friendly and motivating, never robotic. The tone is encouraging — "you've got this, here's a small nudge" — not nagging. The app picks one line at random from the relevant set so users see variety, not the same string every 90 minutes.

#### Glass formatting

The variable `{n}` in copy expands to a natural-language form, not a raw decimal:

| Recommended volume | Rendered as     |
| ------------------ | --------------- |
| 0.5                | `half a glass`  |
| 1                  | `a glass`       |
| 1.5                | `1.5 glasses`   |
| 2                  | `2 glasses`     |

The noun follows the **beverage type** of the user's default drink, not the preset's display name (so "of water" / "of tea" / "of coffee" — never "of glass of water"). For non-water beverages we drop the water-drop emoji.

#### On-pace reminder set

Used when the previous reminder was acted on (the user logged a drink after it) or when no previous reminder exists today.

- "Time for {n} of water 💧"
- "Quick hydration check — how about {n}?"
- "Staying steady. {n} of water now."
- "{n} of water keeps you on pace."
- "You're doing well — keep it up with {n}."
- "A little break for {n} of water 💧"

#### Off-pace reminder set ("missed a timer")

Used when the previous reminder fired and the user did **not** log a drink before this one. Same cadence as the on-pace reminder — there is no extra notification; the copy just shifts to acknowledge the gap. Tone stays kind, not chiding.

- "Looks like the last one slipped by — {n} of water now? 💧"
- "Catching up: {n} of water gets you back on pace."
- "It's been a while. {n} of water 💧"
- "No worries — let's pick it back up with {n} of water."

#### Inactivity reminder

A once-per-day re-engagement nudge for users who have logged nothing today **and** logged at least one drink in the last 7 days. See "Notification types" below.

- "Hey, did you forget to log? Tap to add what you've had today."
- "We haven't seen anything from you yet today — log a drink?"
- "Quick check-in: how's hydration looking today?"

#### Weekly summary

Once per week, summarising the previous week's goal achievement. See "Notification types" below.

- "Last week you hit your goal **{x}/7** days. Nice work, here's to another good week 💧"
- "Last week's hydration: **{x}/7** days at goal. Tap to see the chart."

`{x}` is the integer number of days the user reached the goal. The copy adapts at the extremes:

- `0/7` — "A slow week — every day is a fresh start. Tap to see your chart."
- `7/7` — "Perfect week: **7/7** days at goal 💧 nice."

#### Lock-screen visibility

Standard hydration, missed-timer, inactivity, and weekly-summary notifications contain nothing sensitive and are always safe to render on the lock screen.

BAC-related content from Party Mode is gated by a user setting — **"Show BAC on lock screen"**, default **ON** (`UserPreferences.bacOnLockScreenEnabled`). With the default in place, BAC values are rendered in full inside Party Mode notification bodies and visible on the lock-screen preview. When the user turns the setting off, Party Mode notifications either omit the BAC value from the visible body or render with the platform's "hidden content" preview style, depending on what each platform supports.

The setting label and copy in the UI is neutral and does not justify the option ("Show your estimated BAC on the lock screen"); we surface the choice without recommending either side.

### Notification quick-log action

Notifications expose a single in-line action button: **"Log {default_drink}"** (e.g. "Log water · 200 ml"). Tapping the action logs the user's configured default drink at the current time **without opening the app**.

- iOS: implemented via notification categories with an action.
- Android: implemented via notification actions on the notification channel.
- Tapping the body of the notification (not the action) opens the app on the today view, ready to log a different drink.
- Logging via the action resets the reminder interval the same way an in-app log does.

The default drink (beverage type + volume) is configurable in the user's profile/settings (see [data-model.md](data-model.md) UserPreferences).

### Permissions

- The app must request notification permission before scheduling any reminders.
- If the user declines, the app remains fully functional with reminders simply unavailable. The settings screen reflects that the OS-level permission is missing and offers a way to open system settings.

## Notification types

Phase 1 has four notification types in the hydration flow, each independently toggleable in settings.

### 1. Hydration reminder (default ON)

Covered above. Fires at the configured interval during active hours when the user is below goal and at least `interval` has passed since the last log. Copy is drawn from the on-pace or off-pace set depending on whether the previous reminder was acted on.

### 2. Inactivity reminder (default ON)

A single once-per-day nudge for users who appear to have forgotten the app exists.

**When it fires:**

- The user has logged **zero drinks today** (since the last day boundary), AND
- The user has not yet seen an inactivity reminder today, AND
- The current time is **noon (12:00 local)**, snapped to the configured active-hours start if noon is outside active hours, AND
- The user passes the inactive-user silence check (covered above — applies to all notification types).

**Interaction with the regular reminder:** if both would fire in the same window, only the inactivity reminder fires. The regular reminder schedule resumes afterward.

**Copy:** see "Inactivity reminder" set above.

### 3. Weekly summary (default ON)

A once-per-week recap of how the user did against their goal.

**When it fires:**

- **Sunday at 20:00 local time**, snapped into the user's active hours if 20:00 falls outside (e.g. fires at the active-hours end if active hours close before 20:00), AND
- The user has not yet seen a weekly summary for this week, AND
- The user passes the inactive-user silence check.

The week is the **ISO week** (Monday–Sunday). The summary covers the seven days ending on the day of firing.

**Content:** the integer number of days the user reached their daily goal, formatted via the weekly-summary copy set above. Tapping the notification opens the History view scoped to the past week (see F4).

The fire time (Sunday 20:00 local) is a fixed phase 1 default and not user-configurable.

### 4. Party Mode notifications (default OFF)

Two opt-in notifications introduced by Party Mode (approaching cap, sober estimate). See [party-session.md](party-session.md). These are independent of the hydration types above and do not fire outside active sessions.

## Anti-spam principles

To honour the "no unnecessary messages" rule:

- A drink logged anywhere (in-app, via notification quick-log, retroactive entry) **resets** the reminder timer and **suppresses** the inactivity reminder for the day.
- Reaching the goal **cancels** all remaining same-day hydration and inactivity reminders, including any that were already scheduled. They resume after the day boundary.
- The inactivity reminder fires **at most once per day**.
- The weekly summary fires **at most once per week**.
- After **7 days of inactivity** (no drink logs since install or since the last log), all notification types are suppressed until the user logs again. See "Inactive-user silence" above.
- During an active Party Session, hydration reminders continue to behave normally — being in a session does not silence them. (Drinking water during a session is still healthy; the app should not stop encouraging it.)
- If the user dismisses a notification without acting, the app does not retry the same notification — it waits for the next scheduled trigger.

## Platform notes

- **iOS:** Use `UNUserNotificationCenter` with local triggers and notification categories for the quick-log action. Be mindful of the 64-pending-notification limit per app — schedule a rolling window rather than every reminder for the next month. Recompute the recommended volume at delivery time when possible (e.g. via a notification service extension), since intake may have changed since scheduling.
- **Android:** Use `AlarmManager` (or `WorkManager` where appropriate) for exact-ish timing, plus the notification channels API and notification actions. The user should be able to control the channel from system settings. Recompute the recommended volume in the broadcast receiver at delivery time, for the same reason.
- The exact API choices are an engineering decision — these are pointers, not a prescription.
