# Open Questions

Decisions that still need to be made, organised by phase. Resolved decisions are recorded in [technical-architecture.md](technical-architecture.md) and the relevant feature documents — this file only lists what is still open.

## Phase 1 — Drink presets

- **Icon set.** Finalise the bundled SVG icons and the default colour palette. — see [features.md](features.md) F14.

## Phase 2 — To be designed when phase 2 begins

These are not blocking phase 1, but listing them now so they are not lost.

- **Auth method.** Email + password, magic link, social login, or a combination? — see features F8.
- **Friend discovery.** Username, email invite, share link, or a combination? — see features F10.
- **Sharing granularity.** What exactly do friends see — just goal-met today, the percentage, or individual entries? Defaults must err private. — see features F11.
- **Preference sync.** Which preferences sync across devices, and which stay per-device? Recommended starting point: goal and units sync; reminder schedule stays per-device. — see [data-model.md](data-model.md).
- **Party-session profile sync.** Should the user profile (sex, weight, height, age) sync across devices, or stay per-device? — see [data-model.md](data-model.md) UserProfile.
- **Active session across devices.** If a user is signed in on two devices and starts a session on one, should the session appear as active on the other? Recommended yes (sessions sync like other entities). — see [data-model.md](data-model.md) PartySession.
- **Conflict resolution edge cases.** Last-writer-wins on `updatedAt` is sufficient for the data shape we have, but phase 2 design needs to confirm behaviour around clock skew and offline edits on multiple devices. — see [technical-architecture.md](technical-architecture.md).
- **Backend stack and hosting.** Server framework, database, auth provider, hosting. — engineering decision in phase 2.
- **Privacy policy and consent copy.** Required before any data leaves the device. — see [data-model.md](data-model.md) Privacy.
