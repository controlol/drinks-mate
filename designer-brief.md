# Designer Brief

This document is a narrative overview of Drinks Mate for the designer who will produce the visual design. It distils the existing design documentation into one place: what the app is for, who it is for, what screens it has, how users move through them, and the constraints any visual treatment must respect.

It is not a full specification. The detailed functional specs live in the other documents in this folder. Where this brief summarises, the linked source documents are authoritative.

- Vision and target user: [product-overview.md](./product-overview.md)
- Functional scope: [features.md](./features.md)
- Screen-by-screen structure: [user-experience.md](./user-experience.md)
- Reminders and notification behaviour: [notifications.md](./notifications.md)
- Party Session feature: [party-session.md](./party-session.md)
- Stored data: [data-model.md](./data-model.md)
- Platform and rollout: [technical-architecture.md](./technical-architecture.md)

## What the app is

Drinks Mate is a mobile app for iOS and Android that helps people build a healthier daily drinking habit. The core proposition is simple: it should be effortless to record what you drink throughout the day, see at a glance whether you are on pace toward your daily hydration goal, and get gentle reminders that keep your intake steady rather than crammed into the evening.

The app is not a calorie tracker, a wearable companion, or a medical device. It tracks beverages — water, coffee, tea, juice, milk, and, when the user opts in, alcoholic drinks during a discrete "party session". It runs natively per platform, offline-first, and works fully without an account in its first phase.

## Who it is for

The user is an adult who wants a low-friction way to monitor their hydration. They are not a patient managing a clinical condition, and they are not a quantified-self enthusiast looking for deep analysis. They want to know, in under a second of looking at their phone, whether they are drinking enough today, and they want logging a glass of water to be as close to a single tap as possible.

Two practical implications fall out of this:

- **Logging is the headline action.** The home screen exists to make logging fast. Charts, settings, and the rest are secondary.
- **The app stays out of the way.** No account requirement, no sign-in, no network dependency for the core loop. The user can install the app on a plane and start using it immediately.

## Product goals the design must serve

The product overview lists four goals; the visual design directly serves all of them.

1. **Fast logging.** Two taps from app launch to a logged drink, for the common case. The home screen must therefore expose a row of one-tap "quick-log" presets and a single prominent "Log drink" action — both within thumb reach on a phone held one-handed.
2. **Steady intake, not end-of-day cramming.** Reminders nudge the user every ~90 minutes during their active hours. The progress display on the home screen has to communicate "are you on pace right now?" — not just "did you hit your goal today?" — so a user opening the app mid-afternoon understands their state at a glance.
3. **An honest picture.** The app records what was drunk, not just how much. Drinks have types (water, coffee, tea, beer, etc.) and the user should be able to see the breakdown of their habits over time.
4. **Out of the way.** Onboarding is short. Every screen has a sensible default. Nothing nags. The visual tone should feel encouraging, not clinical or scolding — closer to a friendly companion than a fitness tracker.

The first release is considered successful if a new user can log their first drink within 60 seconds of opening the app for the first time, a typical day's logging takes under a minute of total interaction, and reminders are perceived as helpful rather than annoying.

## Design principles

Four principles apply to every screen.

1. **Logging is the primary action.** Treat it as such in layout, weight, and colour. Everything else competes for the leftover attention.
2. **One thumb, one hand.** Primary actions live in the lower half of the screen so the app is usable one-handed on a phone of any size.
3. **Glanceable progress.** The user must understand their hydration status within roughly a second of opening the app. Use a clear, large visual indicator (a filling shape, a ring, or similar) with the numeric value and goal alongside.
4. **Forgiving.** Every logged drink can be edited or deleted. Mistakes are normal and easy to fix. Toasts after a log should expose an undo affordance.

## The screens

The app has five screens. Their structural requirements are summarised here; for the canonical content list per screen see [user-experience.md → Screens](./user-experience.md#screens).

### S1 — Today (home)

The default screen on launch. It carries the daily progress display, today's drink list, the quick-log row, the primary "Log drink" action, and a small Party Mode entry point. Progress is the visual headline. The drink list is reverse-chronological and each row is tappable for edit or delete. Quick-log presets sit above or beside the primary action so a one-tap log is always reachable.

When the user has an active Party Session, the small Party Mode entry point is replaced by a richer section that becomes prominent — current estimated BAC, a line chart of BAC over time, drinks count, total alcohol grams, a meal indicator, session pricing controls, session totals, and an "End session" action. When no session is active, the entry point should be understated and never compete visually with hydration.

### S2 — Log drink

Reached from the primary action on the home screen. Presented as a drawer that opens from the bottom of the screen and can expand to take up the whole screen. The drawer has two phases:

1. **Pick a drink** — a search field at the top, then a scrollable list of all visible drink presets (icon + name), with the user's most-used presets near the top, and a "Create new preset" action at the end.
2. **Edit and confirm** — the selected preset is shown at the top so the user can confirm what they picked. Inline quick edits for volume and time sit in the middle. An action row at the bottom carries a large full-width "Confirm" button with a smaller "Advanced" button to its left.

The Advanced editor reveals editable fields for name, ABV, and price. Crucially, the designer should plan for three save paths beyond plain confirm: "Confirm" (one-off variation), "Save and confirm" (overwrite the underlying preset), and "Save as copy and confirm" (create a new preset). These typically appear as a split button or a small menu attached to the primary save action.

Dismissal — swiping the drawer down or tapping outside it — discards the log. A successful confirm closes the drawer and shows a brief "Logged" toast with undo.

### S3 — History

Reached from a tab or menu. The screen has a Weekly / Monthly range selector with paging at the top, a stack of bar charts in the middle, and a day list below the charts. Hydration charts are always present (intake per day with the goal as a reference line, and number of drinks per day). When a Party Session overlaps the selected range, additional alcohol charts appear (alcoholic drinks per day, peak estimated BAC per day) and the days touched by a session are visually banded.

Charts are read-only. Tapping a day on any chart, or a row in the day list, drills into a day detail with the full drink list and any Party Session summary. Editing always happens via that drill-down or the today view, not on the charts themselves.

### S4 — Settings

Grouped in this exact order: Hydration, Reminders, Drinks, Profile, Party Mode, Display & format, About. The Drinks section contains the "Manage drinks" surface — a list of every drink preset with reorder, edit, hide, delete, and create-new actions. Party Mode settings are present even before the user has ever started a session, but the section should not steal weight from the hydration-focused sections above it.

### S5 — Onboarding (first launch only)

Five steps in one continuous flow: Welcome (one-line value proposition), Username, Personal info (gender, weight, optional height, optional birthday), Daily hydration goal (pre-filled at `30 ml × weight_kg` rounded to the nearest 100 ml), Notification permission. Every step has a sensible default so a user who taps through the whole thing ends up with a working profile. The flow should feel like a brief introduction, not a form — under 30 seconds end to end is the bar.

## Key flows

Six flows shape the experience. Detailed step lists and Mermaid diagrams are in [user-experience.md → Key flows](./user-experience.md#key-flows).

- **First-time use** — install, onboard, land on an empty today view, log the first drink. Under 60 seconds total.
- **Quick log (most common)** — open the app, tap a preset on the today view, see progress update. Two taps total.
- **Detailed log** — open the log-drink drawer, pick a preset, optionally tweak volume / time, optionally open the Advanced editor, confirm.
- **Correcting a mistake** — tap an entry in today's list, edit or delete, watch progress recompute.
- **Responding to a reminder** — tap the notification body to open the app on the today view, or tap the inline "Log {default drink}" action to log without opening the app at all.
- **Starting and running a Party Session** — explicit opt-in from the today view, optional birthday / height prompt the first time, optional meal prompt, optional pricing setup, then a session-active home screen with the BAC section and chart.

The quick-log flow is by far the most common. The visual design should optimise for it relentlessly: making a glass of water log in two taps is more important than any other interaction in the app.

## Party Session — a secondary, opt-in surface

Party Session is a phase 1 feature but explicitly secondary. Most users on most days will never use it. The design should reflect that:

- The entry point on the today view (when no session is active) is understated — a low-emphasis tile or link-style row placed below the primary hydration content. It must never compete with hydration progress, the log-drink action, or the today drinks list.
- When a session is active, the entry point is replaced by a richer section that does become prominent. That section's full content list is canonical in [party-session.md → Today view during a session](./party-session.md#today-view-during-a-session) — current BAC in g/L with mmol/L alongside, the BAC line chart, cap progress, drinks count, total grams of alcohol, time elapsed, a meal indicator, session-prices control, session totals, and an End session action.

A non-negotiable constraint: the BAC value must always be labelled as an estimate. The UI must never frame it as a fitness-to-drive indicator. A persistent disclaimer must be visible while a session is active. The user's chosen "cap" is a personal goal, not a safety threshold, and must not be visually treated as a legal or safety line.

The BAC line chart deserves special design attention. It shows a solid line for the actual BAC estimate up to "now" and a dashed line for the projected decay beyond "now". The projected portion has a subtle red tint in the background, and there is a vertical reference line at "now". The X-axis is 24-hour digital time in the local timezone, rounded up to a tidy half-hour mark. The Y-axis shows BAC in g/L primarily and mmol/L secondarily, with the user's cap drawn as a horizontal dashed line if set. The chart only appears once the first alcoholic drink in the session has been logged.

## Drink presets

Presets are the unit of interaction. Every drink the user logs goes through a preset — either a default one shipped with the app, a user-created one, or a one-off variant edited via the Advanced editor. Each preset combines a name, beverage type, volume, ABV (for alcoholic drinks), optional price, an icon, and an icon colour.

The app ships with a set of monochrome SVG icons that can be tinted at render time: `glass`, `bottle`, `can`, `mug`, `small_cup`, `wine_glass`, `beer_glass`, `plastic_cup`, `cocktail`, `shot_glass`, plus a small set of generics. Default colours per beverage type pre-fill the colour picker (water → blue, coffee → brown, tea → green, etc.) but the user can pick anything from a small brand-friendly palette or an "any colour" picker.

Finalising the icon artwork itself is part of the design work. The list of icon slots is fixed; the artistic execution is open.

## Reminders

Reminders are part of the value proposition, not an afterthought. The default cadence is every 90 minutes during 08:00–22:00 active hours, only when the user is below today's goal and at least one interval has passed since the last log. Each reminder recommends a specific volume in 0.5-glass increments based on how far behind pace the user is, with a minimum of half a glass and a maximum of two glasses. Copy is friendly and motivating, never robotic, and varies across a set of phrasings so the user does not see the same string every 90 minutes.

Each notification carries an inline "Log {default drink}" action button that logs the user's configured default drink (typically a glass of water) without opening the app. Tapping the body of the notification opens the app on the today view.

Anti-spam rules are baked in. A drink logged anywhere resets the reminder timer. Hitting the goal cancels remaining same-day reminders. Seven days of inactivity (no logs since install or the last log) suppresses all notifications until the user logs again. The visual design of notifications themselves should match the platform conventions; the copy is specified.

## Accessibility

Non-negotiable across every screen:

- All interactive elements must have accessible labels.
- The app must support the system's dynamic text sizes.
- Colour must not be the sole indicator of state. Goal-met, for example, needs an icon or text label as well as a colour change. Bars below the daily goal on the history charts need a non-colour visual distinction in addition to the colour difference.
- The app must work with VoiceOver on iOS and TalkBack on Android.

## What the app is not

Worth keeping in mind because it shapes what should not be in the design:

- It is not a calorie, sugar, or caffeine tracker.
- It is not a medical device and does not give medical advice.
- It does not integrate with wearables or third-party health platforms.
- It has no analytics, telemetry, or crash reporting in phase 1 or phase 2.
- It has no public social feed; phase 2 social features (when designed) are limited to accepted friends only.
- The first release (phase 1) has no account, no sign-in, and no cloud sync. Visual scaffolding should not hint at unfinished phase 2 work.

## Visual tone

The product overview and user-experience documents do not prescribe a visual style — colours, typography, illustration approach, and exact layouts are open. The design principles above (logging-first, one-handed, glanceable, forgiving) and the reminder copy ("encouraging, not nagging") set the emotional register: friendly, calm, motivating, honest. The app is a companion that helps the user build a small daily habit, not a coach that scolds them for failing.

Hydration is the headline. Party Mode is available when needed but never the centre of gravity. Every visual decision should be checked against that hierarchy.
