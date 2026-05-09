# Open Questions

Decisions that still need to be made, organised by phase. Resolved decisions are recorded in [technical-architecture.md](./technical-architecture.md) and the relevant feature documents — this file only lists what is still open.

## Phase 1 — Drink presets

- **Icon set.** Finalise the bundled SVG icons and the default colour palette. — see [features.md → F14 Drink presets and customisation](./features.md#f14--drink-presets-and-customisation).

## Phase 2 — To be designed when phase 2 begins

These are not blocking phase 1, but listing them now so they are not lost.

- **Auth method.** Email + password, magic link, social login, or a combination? — see [features.md → F8 Account creation and sign-in](./features.md#f8--account-creation-and-sign-in-phase-2).
- **Friend discovery.** Username, email invite, share link, or a combination? — see [features.md → F10 Friends](./features.md#f10--friends-phase-2).
- **Sharing granularity.** What exactly do friends see — just goal-met today, the percentage, or individual entries? Defaults must err private. — see [features.md → F11 Progress sharing with friends](./features.md#f11--progress-sharing-with-friends-phase-2).
- **Preference sync.** Which preferences sync across devices, and which stay per-device? Recommended starting point: goal and units sync; reminder schedule stays per-device. — see [data-model.md → UserPreferences](./data-model.md#userpreferences).
- **Party-session profile sync.** Should the user profile (sex, weight, height, age) sync across devices, or stay per-device? — see [data-model.md → UserProfile](./data-model.md#userprofile).
- **Active session across devices.** If a user is signed in on two devices and starts a session on one, should the session appear as active on the other? Recommended yes (sessions sync like other entities). — see [data-model.md → PartySession](./data-model.md#partysession).
- **Conflict resolution edge cases.** Last-writer-wins on `updatedAt` is sufficient for the data shape we have, but phase 2 design needs to confirm behaviour around clock skew and offline edits on multiple devices. — see [technical-architecture.md → Sync model](./technical-architecture.md#sync-model-phase-2-design-constraints).
- **Backend stack and hosting.** Server framework, database, auth provider, hosting. — engineering decision in phase 2.
- **Privacy policy and consent copy.** Required before any data leaves the device. — see [data-model.md → Privacy](./data-model.md#privacy).
