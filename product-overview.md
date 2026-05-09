# Product Overview

## Vision

Many people drink too little throughout the day, and when they do drink, they often consume large amounts in short bursts rather than spreading intake evenly. Drinks Mate helps users build a healthier drinking habit by making it effortless to track what they drink, when they drink it, and whether they are on pace to meet their daily hydration goal.

## Problem statement

- People underestimate how little they drink across a day.
- Drinking a lot in a single sitting is less effective than steady intake throughout the day.
- Existing trackers tend to focus only on water and ignore other beverages, or require too many taps to log a drink.

## Goals

1. **Make logging fast.** Logging a drink should take no more than two taps from the home screen for common cases.
2. **Encourage steady intake.** The app should nudge users to drink at regular intervals rather than only flagging end-of-day shortfalls.
3. **Give an honest picture.** The app should track *what* was drunk, not just *how much*, so users understand their habits (e.g. coffee vs. water).
4. **Stay out of the way.** The app should be usable without an account and without a network connection for the core tracking loop. This holds in every phase, including after cloud features are introduced.

## Target users

Adults who want a low-friction way to monitor their hydration. The app is **not** a medical device and does not give medical advice.

## Product shape

- **Native apps** for iOS and Android — see [technical-architecture.md](technical-architecture.md).
- **Offline-first** — the core tracking loop (logging, today view, history, reminders) works fully without network.
- **Phased rollout.** Phase 1 is a complete local-only product. Phase 2 adds opt-in accounts, cloud sync, and social features (friends, progress sharing). Users who never create an account continue to get the full phase 1 experience unchanged.

## Non-goals

- Calorie or macronutrient tracking.
- Detailed analysis of caffeine, alcohol, or sugar intake. `[OPEN]` — we may surface basic categorisation but will not give health-specific advice.
- Integration with wearables or third-party health platforms in either phase 1 or phase 2. May be reconsidered later.
- Replacing the local database with a cloud-only model. The local database remains the on-device source of truth even after phase 2 ships.

## Success criteria

The first release (phase 1) is successful if:

- A user can install the app and log their first drink within 60 seconds of opening it for the first time.
- A typical day of logging (6–10 drinks) takes under one minute of cumulative interaction.
- Reminder notifications are perceived as helpful, not annoying. Measured by retention of the reminder feature (users who keep it enabled after one week).
- The app works fully offline on a device that has never been online.

Phase 2 success criteria are defined when phase 2 design begins.
