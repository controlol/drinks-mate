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

The app is not a calorie tracker, a wearable companion, or a medical device. It tracks beverages — water, coffee, tea, juice, milk, and, when the user opts in, alcoholic drinks during a discrete "party session". It is one Flutter app for both iOS and Android, offline-first, and works fully without an account in its first phase.

## Who it is for

The user is an adult who wants a low-friction way to monitor their hydration. They are not a patient managing a clinical condition, and they are not a quantified-self enthusiast looking for deep analysis. They want to know, in under a second of looking at their phone, whether they are drinking enough today, and they want logging a glass of water to be as close to a single tap as possible.

Two practical implications fall out of this:

- **Logging is the headline action.** The home screen exists to make logging fast. Charts, settings, and the rest are secondary.
- **The app stays out of the way.** No account requirement, no sign-in, no network dependency for the core loop. The user can install the app on a plane and start using it immediately.

## Product goals the design must serve

The product overview lists four goals; the visual design directly serves all of them.

1. **Fast logging.** Two taps from app launch to a logged drink, for the common case. The home screen must therefore expose a grid of one-tap "Quick Log" presets and a single prominent "Log drink" action — both within thumb reach on a phone held one-handed.
2. **Steady intake, not end-of-day cramming.** Reminders nudge the user every ~90 minutes during their active hours. The progress display on the home screen has to communicate "are you on pace right now?" — not just "did you hit your goal today?" — so a user opening the app mid-afternoon understands their state at a glance.
3. **An honest picture.** The app records what was drunk, not just how much. Drinks have types (water, coffee, tea, beer, etc.) and the user should be able to see the breakdown of their habits over time.
4. **Out of the way.** Onboarding is short. Every screen has a sensible default. Nothing nags. The visual tone should feel encouraging, not clinical or scolding — closer to a friendly companion than a fitness tracker.

The first release is considered successful if a new user can log their first drink within 60 seconds of opening the app for the first time, a typical day's logging takes under a minute of total interaction, and reminders are perceived as helpful rather than annoying.

## Design principles

Four principles apply to every screen.

1. **Logging is the primary action.** Treat it as such in layout, weight, and colour. Everything else competes for the leftover attention.
2. **One thumb, one hand.** Primary actions live in the lower half of the screen so the app is usable one-handed on a phone of any size. This governs the phone-width layout specifically; the tablet/desktop-width layout (S1, see below) relaxes it since one-handed reach is not the constraint on a device held with two hands or propped up.
3. **Glanceable progress.** The user must understand their hydration status within roughly a second of opening the app. Use a clear, large visual indicator (the horizontal progress bar with a pace marker, see Design Language) with the numeric value and goal alongside, plus a short status pill that says whether the user is on pace, behind, or ahead.
4. **Forgiving.** Every logged drink can be edited or deleted. Mistakes are normal and easy to fix. Toasts after a log should expose an undo affordance.

## Top-level navigation

The app uses a **bottom tab bar** with three tabs: **Today**, **Party**, **History**. Today is the default on launch and the home of the experience. Party is a dedicated tab for the opt-in alcohol-tracking feature and is empty until the user starts a session. History shows past intake and sessions.

A header sits at the top of every page with the page title on the left and a **settings gear icon** in the top-right corner — Settings is reached only from this gear, not from a tab. The tab bar is hidden when the Log drink drawer (S2) is open and when a full-screen route is pushed (e.g. Today Drinks Log, Settings).

## The screens

The app has seven screens. Their structural requirements are summarised here; for the canonical content list per screen see [user-experience.md → Screens](./user-experience.md#screens).

### S1 — Today (home)

The default screen on launch and the home of the experience. Hydration only — Party Mode does **not** appear here. Top to bottom:

- A **progress card** at the top of the page. The card contains the big intake numeric on the left (e.g. `1.4 L`), the daily goal as a smaller secondary value alongside (e.g. `/ 2.1 L`), a short **status pill** in the top-right of the card reading `On pace` / `Behind` / `Ahead`, and a **horizontal progress bar** below that fills the full card width. The bar carries a **vertical tick line** marking the linear-pace position — where intake "should be" by now in the user's active hours. The bar fill colour shifts between brand (on/ahead) and behind-pace colour. Tapping the entire card opens the Today Drinks Log (S6) as a full-screen push.
- Two **stat cards side-by-side** under the progress card: a 7-day daily average and a "days on goal" count in the last 7 days (`n/7` format).
- A **"Quick Log" section** — a header row carries the "Quick Log" title plus a **sort-mode dropdown** (Manual / Recently used (default) / Most used) on the right. Below it, a vertically-scrolling grid of the **top 8** presets by the selected sort mode — tap one to log that drink immediately at the current time. Two tiles per row at phone width; wider screens show more columns.
- **On tablet/desktop-width screens** (≥ 840dp), the entire "Quick Log" section (heading, dropdown, grid) relocates to sit **beside** the progress card and stat cards instead of below them, forming an evenly-split (50/50) two-column page; see [user-experience.md → Responsive layout](./user-experience.md#responsive-layout) for the full breakpoint/column table.
- A **full-width "Log drink" button** persistent at the bottom of the screen (same horizontal padding as the rest of the screen, sitting above the tab bar). This opens the S2 Log drink drawer and is the path for any drink not already in the "Quick Log" grid, including new presets. (S2's own picker screen keeps the label "Log a drink" for its header — a separate, deliberately unrenamed surface; see [user-experience.md → S1](./user-experience.md#s1--today-home).)

Today's drink list is **not** rendered inline here. It lives on S6 (Today Drinks Log), reached by tapping the progress card.

### S2 — Log drink

Reached from the full-width "Log drink" button at the bottom of the Today screen. Presented as a drawer that opens from the bottom of the screen and can expand to take up the whole screen. The tab bar is covered while the drawer is open. The drawer has two phases:

1. **Pick a drink** — its own header (title + sort-mode dropdown, sharing the same setting as the Today grid's) and a search field at the top, then a "Create new preset" entry, then a scrollable list of all visible drink presets (icon + name) ordered by the selected sort mode.
2. **Edit and confirm** — the selected preset is shown at the top so the user can confirm what they picked. Inline quick edits for volume and time sit in the middle. An action row at the bottom carries a large full-width "Confirm" button with a smaller "Advanced" button to its left.

The Advanced editor reveals editable fields for name, ABV, and price. Crucially, the designer should plan for three save paths beyond plain confirm: "Confirm" (one-off variation), "Save and confirm" (overwrite the underlying preset), and "Save as copy and confirm" (create a new preset). These typically appear as a split button or a small menu attached to the primary save action.

Dismissal — swiping the drawer down or tapping outside it — discards the log. A successful confirm closes the drawer and shows a brief "Logged" toast with undo.

### S3 — History

Reached from the **History** tab in the bottom navigation. The screen has a Weekly / Monthly range selector with paging at the top, a stack of bar charts in the middle, and a day list below the charts. Hydration charts are always present (intake per day with the goal as a reference line, and number of drinks per day). When a Party Session overlaps the selected range, additional alcohol charts appear (alcoholic drinks per day, peak estimated BAC per day) and the days touched by a session are visually banded.

Charts are read-only. Tapping a day on any chart, or a row in the day list, drills into a day detail with the full drink list and any Party Session summary. Editing always happens via that drill-down or via the Today Drinks Log (S6), not on the charts themselves.

### S4 — Settings

Reached by tapping the **settings gear** in the top-right corner of any top-level screen header. Presented as a full-screen push, with the tab bar hidden while Settings is open.

Grouped in this exact order: Hydration, Reminders, Drinks, Profile, Party Mode, Display & format, About. The Drinks section contains the "Manage drinks" surface — a list of every drink preset with reorder, edit, hide, delete, and create-new actions. Party Mode settings are present even before the user has ever started a session, but the section should not steal weight from the hydration-focused sections above it.

### S5 — Onboarding (first launch only)

Five steps in one continuous flow: Welcome (one-line value proposition), Username, Personal info (gender, weight, optional height, optional birthday), Daily hydration goal (pre-filled at `30 ml × weight_kg` rounded to the nearest 100 ml), Notification permission. Every step has a sensible default so a user who taps through the whole thing ends up with a working profile. The flow should feel like a brief introduction, not a form — under 30 seconds end to end is the bar.

The Welcome step carries a full hero illustration. Steps 2–5 are plain forms with a small progress-dot indicator at the top of the screen.

### S6 — Today Drinks Log

Reached by tapping the progress card on the Today screen. Full-screen push; tab bar hidden. Shows a slim summary header (today's intake and goal, for orientation) and the reverse-chronological list of today's logged drinks. Each row carries the drink's icon (tinted), name, volume, and time. Tapping a row opens an edit/delete affordance. The empty state — when nothing has been logged yet today — uses an illustration with a friendly one-line prompt and a button that opens the S2 Log drink drawer.

### S7 — Party

Reached from the **Party** tab in the bottom navigation. The screen has three states.

**First-run (the very first visit, no session has ever existed):** a brief explainer of what Party Mode is, the "this is an estimate" disclaimer, and a full-width "Start party session" button. The explainer is shown once; afterward an info affordance in the header lets the user revisit it.

**Subsequent visits, no active session:** a full-width "Start party session" button at the top, followed by a list of past sessions. Each row shows session date, peak BAC, alcoholic drink count, and how it ended (manual or auto).

**Active session:** the active-session view — current estimated BAC in g/L with mmol/L alongside, a BAC line chart, cap progress, drinks-this-session count, total grams of alcohol, time elapsed, a meal indicator, session-prices control, session totals, and an End session action. Canonical content list lives in [party-session.md → Party tab during a session](./party-session.md#party-tab-during-a-session).

## Key flows

Six flows shape the experience. Detailed step lists and Mermaid diagrams are in [user-experience.md → Key flows](./user-experience.md#key-flows).

- **First-time use** — install, onboard, land on the Today screen with progress at 0, log the first drink. Under 60 seconds total.
- **Quick log (most common)** — open the app, tap a preset tile in the "Quick Log" grid on Today, see progress update. Two taps total.
- **Detailed log** — tap the full-width "Log drink" button at the bottom of Today, pick a preset in the drawer, optionally tweak volume / time, optionally open the Advanced editor, confirm.
- **Correcting a mistake** — tap the progress card on Today to open the Today Drinks Log (S6), tap an entry, edit or delete, return to Today and watch progress recompute.
- **Responding to a reminder** — tap the notification body to open the app on Today, or tap the inline "Log {default drink}" action to log without opening the app at all.
- **Starting and running a Party Session** — switch to the Party tab, tap "Start party session", answer the optional birthday/height/meal/pricing prompts, then land on the active-session view with the BAC chart.

The quick-log flow is by far the most common. The visual design should optimise for it relentlessly: making a glass of water log in two taps is more important than any other interaction in the app.

## Party Session — a secondary, opt-in surface

Party Session is a phase 1 feature but explicitly secondary. Most users on most days will never use it. The design reflects that by giving it its own tab rather than crowding the Today screen.

- The Party tab is always present in the bottom navigation but is empty (a brief explainer plus a Start CTA, or a Start CTA plus past sessions after the first visit) until the user starts a session. Today is untouched by Party Mode.
- When a session is active, the Party tab carries the full active-session view: current BAC in g/L with mmol/L alongside, the BAC line chart, cap progress, drinks count, total grams of alcohol, time elapsed, a meal indicator, session-prices control, session totals, and an End session action. Canonical content list lives in [party-session.md → Party tab during a session](./party-session.md#party-tab-during-a-session).

A non-negotiable constraint: the BAC value must always be labelled as an estimate. The UI must never frame it as a fitness-to-drive indicator. A persistent disclaimer must be visible while a session is active. The user's chosen "cap" is a personal goal, not a safety threshold, and must not be visually treated as a legal or safety line.

The BAC line chart deserves special design attention. It shows a solid line for the actual BAC estimate up to "now" and a dashed line for the projected decay beyond "now". The projected portion has a subtle warm-red wash in the background (low opacity, ~8–10%), and there is a vertical reference line at "now". The X-axis is 24-hour digital time in the local timezone, rounded up to a tidy half-hour mark. The Y-axis shows BAC in g/L primarily and mmol/L secondarily, with the user's cap drawn as a horizontal dashed line if set. The chart renders from the moment the session starts (not just once a drink is logged), to avoid a layout jump — before the first drink it shows a flat 0.00 g/L line across a fixed 3-hour window instead of the solid/dashed/projected rendering described above. See [party-session.md → BAC line chart](./party-session.md#bac-line-chart) for the full empty-state and tap-to-inspect spec.

The Party tab uses an **emerald / mint** accent (see Design Language → Colour) to distinguish it from the azure-led hydration screens. The accent must feel evening / lively without tipping into nightclub aesthetics — the brief explicitly rules out neon-on-black and "dark / edgy / nightlife" looks.

## Drink presets

Presets are the unit of interaction. Every drink the user logs goes through a preset — either a default one shipped with the app, a user-created one, or a one-off variant edited via the Advanced editor. Each preset combines a name, beverage type, volume, ABV (for alcoholic drinks), optional price, an icon, and an icon colour.

The app ships with a set of filled SVG icons with subtle inner detail that can be tinted at render time: `glass`, `bottle`, `can`, `mug`, `small_cup`, `wine_glass`, `beer_glass`, `plastic_cup`, `cocktail`, `shot_glass`, plus a small set of generics. Each icon has a two-shade structure (silhouette + inner detail), both rendered from the single `iconColor` value via an HSL lightness offset at render time. Default colours per beverage type pre-fill the colour picker but the user can pick anything from a small brand-friendly palette or an "any colour" picker — the per-beverage default palette is the designer's call.

Finalising the icon artwork itself is part of the design work. The list of icon slots is fixed; the artistic execution is open.

## Reminders

Reminders are part of the value proposition, not an afterthought. The default cadence is every 90 minutes during 08:00–22:00 active hours, only when the user is below today's goal and at least one interval has passed since the last log. Each reminder recommends a specific volume in 0.5-glass increments based on how far behind pace the user is, with a minimum of half a glass and a maximum of two glasses. Copy is friendly and motivating, never robotic, and varies across a set of phrasings so the user does not see the same string every 90 minutes.

Each notification carries an inline "Log {default drink}" action button that logs the user's configured default drink (typically a glass of water) without opening the app. Tapping the body of the notification opens the app on Today.

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

The reminder copy already sets the emotional register: friendly, encouraging, motivating, honest — never nagging or clinical. The app is a companion that helps the user build a small daily habit, not a coach that scolds them for failing. Hydration is the headline; Party Mode is available when needed but never the centre of gravity.

Within that register, the chosen visual direction is **bold, energetic, playful**. Closest reference: habit-tracker apps in the Streaks family — bright accents, tactile cards, satisfying feedback on every interaction. Explicitly **not** clinical / medical, not corporate / banking, not childish / cartoonish, and **not** dark / edgy / nightlife. The visual energy carriers are colour saturation, large display type, and expressive illustration — not motion (motion stays calm, see below).

## Design Language

The following defines the visual system. It is opinionated where decisions have been made and explicit about what is still the designer's call.

### Personality & references

- **Adjectives:** bold, energetic, playful.
- **Closest reference:** Streaks-style habit trackers — bright accents, tactile cards, satisfying tap feedback.
- **Anti-references:** clinical / medical apps (avoid spreadsheet density and sterile blues), corporate / banking (avoid stiff layouts), childish / cartoonish (no mascots, no sticker overload), dark / edgy / nightlife (no neon-on-black, no cocktail-bar aesthetic — even in Party Mode).
- **Where the energy lives:** colour saturation, oversized display type for headline numerics, and expressive illustration. Motion stays calm; the energy is visual, not kinetic.

### Colour

Three named accents plus a semantic palette. Both light mode and dark mode ship at v1, following the system setting.

- **Azure / sky** — primary brand colour. Mid-blue, friendly, energetic but not corporate-navy. Owns hydration identity: progress bar fill (on-pace state), today screen accent, all default hydration UI accents.
- **Honey / amber** — warm action accent (yellow-leaning warm). Used for the primary CTAs ("Log drink", "Start party session"), goal-met celebration, and other points of action. Plays freely alongside azure across the hydration screens.
- **Emerald / mint green** — Party Mode accent. Vibrant, saturated, evening-capable without nightclub overtones. Used exclusively on the Party tab and in Party-specific UI. Replaces an earlier exploration of plum / purple, which was rejected as too nightlife-coded.

Cohesion rule: **azure and honey mix freely across hydration UI. Emerald / mint is quarantined to Party Mode and never appears on Today, History, or Settings.**

Semantic palette is conventional: green = goal-met, amber = behind-pace, red = warning / destructive. Note the friction: the brand honey is also amber-leaning, so the behind-pace amber must visibly differ from the brand colour (e.g. pushed more orange or paired with a non-colour secondary indicator like an icon or label change). Every state that depends on colour must also carry a non-colour signal (icon, label, or pattern) for accessibility.

Per-beverage default icon tints (water blue, coffee brown, tea green, etc.) are **the designer's call**. The data model carries a `colour` per preset and the user can override anything, so designer-chosen defaults are starting points only.

### Typography

- **Family:** DM Sans across both iOS and Android. Single open-source family — no platform divergence, no layout drift between iOS and Android. Not flashy; industry-standard, broad weight range, friendly geometric character that supports the bold-playful brand.
- **Display weight + tabular figures for the headline numerics:** the big intake value on the Today progress card (`1.4 L`) and the BAC value on the Party tab use the heaviest available weight, tabular (fixed-width) digits so the values don't jitter when changing, and a very large size.
- The rest of the type scale (body, secondary, captions, settings rows) uses standard weights and proportional figures. The designer owns the full type scale; the constraints are: support dynamic type at all system sizes, keep body legible at minimum size, and reserve the display-weight numerals for genuine headline moments.

### Iconography

- **Drink icons** (the bundled set used across the app): filled silhouettes with **subtle inner detail** rendered as a second shade of the same hue (derived at render time from the single `iconColor` field via HSL ±15% lightness or similar). The icons read clearly at 24–32 px. The bundled slots are listed in [features.md → F14](./features.md#f14--drink-presets-and-customisation); the artwork itself is the designer's to draw.
- **UI icons** (tab bar, settings rows, edit, delete, etc.): a custom set, approximately 25 icons, drawn in the same visual family as the drink icons (matched weight, palette, geometry rules). Platform-default icons are **not** used — the goal is a single cohesive visual system across both platforms. Inventory roughly: tab bar (today, party, history), settings gear, edit, delete, undo, plus, close, chevron, search, info, drag-handle, calendar, eye / eye-off, share, dot-menu, refresh, sort, filter, check, warning, plus a few category icons for meals / currency / tokens. Designer audits the screens and confirms the final list before drawing.

### Illustration

- **Style:** flat with subtle gradient. Vector-pure, scalable, dimensional but not photorealistic. Cohesive with the icon family.
- **No characters or mascots.** Illustrations are **object-led**, optionally using **hands or limbs only** as the human element — a hand pours a glass, a hand holds a mug. No full figures, no recurring mascot character. This honours the anti-childish / anti-mascot constraint while keeping warmth.
- **Where illustration appears:**
  - The onboarding welcome step (a hero illustration on step 1 only; steps 2–5 are plain forms with a progress-dot indicator at the top).
  - Empty states: empty Today Drinks Log, first-run Party tab, possibly History empty.
  - The full-screen goal-met celebration (see below).
- **Coherence:** a single visual family across drink icons, UI icons, and illustrations — shared stroke weight, palette rules, and geometric construction. The designer delivers a small style guide alongside the assets so future contributors can stay in style.

### Shape, surface, spacing

- **Corner radius:** generous rounding. Large radii on cards and surfaces (suggested ~16–24 px), pill-shaped buttons.
- **Elevation:** soft shadows on cards, never heavy or sharp. Tactile rather than floating.
- **Spacing scale:** the designer owns the spacing scale; the brief constraint is "comfortable density" — readable at a glance, not crammed.

### Layout primitives

These primitives recur across the app and have specific requirements:

- **Progress card (Today):** full page width within standard padding. Contains, in order: a header row with the large intake numeric on the left, the goal as a smaller secondary value alongside, and a status pill (`On pace` / `Behind` / `Ahead`) anchored to the **top-right** of the card. Below the header row, a **horizontal progress bar** filling the entire card width (within the card's own padding). The bar carries a **vertical tick line** marking the linear-pace position. The entire card is a tappable surface that opens S6 Today Drinks Log on press.
- **Stat card pair (Today):** two cards side-by-side under the progress card, equal width. Each shows a label and a single bold numeric — 7-day average, days-on-goal-in-last-7.
- **"Quick Log" section (Today):** header row (title + sort-mode dropdown) above a vertically-scrolling grid of the top 8 preset tiles by the selected sort mode. Each tile shows the preset's icon (tinted) and name; taps log immediately. Two tiles per row at phone width, more on wider screens. On tablet/desktop-width screens the whole section sits beside the progress card and stat cards rather than below them.
- **Full-width primary button:** persistent at the bottom of pages that need a primary action (Today's "Log drink", Party's "Start party session"). Full page width within standard horizontal padding. Sits above the bottom tab bar. Uses the honey accent.
- **Status pill:** short label only (`On pace` / `Behind` / `Ahead`). No quantified copy in the pill itself. Magnitude is implied by the bar fill versus the tick marker.
- **Pace marker:** thin vertical tick line on the progress bar. Must remain visible against both the on-pace fill colour and the behind-pace fill colour, so the tick uses a non-fill-colour treatment.
- **Top-screen header:** page title left, settings gear right. Present on Today, Party, History.
- **Bottom tab bar:** three tabs — Today, Party, History. A single brand-styled bottom nav rendered by Flutter; it may adopt each platform's idiom (Cupertino tab bar on iOS, Material bottom nav on Android) or use one Material nav on both — a brand/UX call, identical in behaviour either way. Hidden when S2 drawer is open and when full-screen routes are pushed.

### Motion & feedback

- **Motion personality:** smooth ease-in-out, **no bounce, no overshoot**. Standard iOS/Material curves. The bold/playful brand is carried by colour, type, and illustration — not motion. Motion stays calm so the app does not feel busy or twitchy. A reduce-motion fallback is required for every animated element.
- **Log feedback:** every drink log triggers a **light haptic** (iOS `impactLight` / Android tick), the progress bar **animates** to its new fill level, and a **"Logged" toast** appears at the bottom of the screen (above the tab bar) for **4 seconds** with an inline Undo affordance. No sound.
- **Goal-met celebration:** the first time the user crosses their daily goal each day, a **full-screen celebration** appears. Content: animated confetti drawn from the app's palette (azure + honey, with mint accents acceptable — not Party-exclusive in this moment), a filled-glass illustration in the centre, and a large "Goal reached" numeric / message. A **medium haptic** fires alongside (iOS `impactMedium` / Android heavy click). The celebration **auto-dismisses after 10 seconds**, or immediately if the user **taps anywhere** before then. Once dismissed, it does **not** re-fire the same day — even if the user drops below goal (via delete) and re-crosses upward. Reduce-motion fallback: a static "Goal reached" card with the same content but no particles / no animation.
- **Other haptics:** none. Haptic is reserved for the log impact and the goal-met celebration so it stays meaningful.

### Notifications

System-default appearance on both platforms, with the branded app icon shown in the system tray. Drinks Mate's notifications are real OS notifications (posted via the platform notification APIs), so they render with each system's native styling. No image attachments, no large icon overrides — just clean system notifications carrying the spec'd copy and the "Log {default drink}" quick-log action button. The brand is conveyed by the app icon alone, not by per-notification rich content.

### Accessibility integration

The accessibility constraints from the user-experience document apply unchanged:

- All interactive elements need accessible labels.
- Dynamic type must scale at every system size without layout breakage.
- Colour is never the sole indicator of state — the status pill carries a text label, the bar fill is paired with that label, the chart bars below the daily goal use a non-colour secondary signal as well as the colour difference.
- VoiceOver (iOS) and TalkBack (Android) must work end-to-end.

In addition: reduce-motion users get the static-card fallback on the goal-met celebration; high-contrast users get strengthened contrast on the bar fill, tick marker, and status pill in particular (these are the load-bearing glanceable elements).

## Open design questions

The following points are not yet decided and remain the designer's to propose or refine in the first design pass:

- Exact azure, honey, and mint hex values (light + dark mode pairs) and their contrast targets against background surfaces. WCAG AA at minimum; AAA preferred on body text.
- How the behind-pace amber visually separates from the honey CTA without introducing a fourth accent.
- Per-beverage default icon tints (water / coffee / tea / juice / milk / beer / wine / spirit / cocktail / shot / non-alcoholic beer) — designer proposes the full palette.
- Specific stroke weight, corner radius, and construction rules for the single-visual-family ruleset that covers drink icons, UI icons, and illustrations.
- Exact spacing scale and type scale.
- Confirm UI icon inventory (currently estimated ~25, designer to audit screens and finalise the list).
- Confetti particle palette balance (azure-honey-mint mix) and density for the goal-met celebration.
- Dark-mode behaviour for the Party tab's emerald accent — depth shift, mint surface tint, or accent only.
- Reduce-motion equivalents for the log-feedback bar animation (instant fill versus brief crossfade).
