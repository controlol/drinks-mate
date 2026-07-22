# Firebase Fit-Assessment for the Phase 2 Backend

> **Status note.** This is an **evaluation, not a decision record.** Phase 2 backend/hosting/auth is explicitly deferred ([technical-architecture.md → What this document does not decide](../../design/technical-architecture.md#what-this-document-does-not-decide); [open-questions.md → Backend stack and hosting](../../design/open-questions.md#phase-2--to-be-designed-when-phase-2-begins)) and nothing about a backend is committed yet. This doc asks one question — **does Firebase satisfy each Phase 2 requirement, and where does it strain?** — for Firebase alone. It is deliberately **not comparative**: per the house norm ("a recommendation with no rejected alternatives is a red flag" — [README.md](../README.md)), a real decision record still needs a Firebase-vs-Supabase-vs-custom comparison before anything is `Accepted`. Treat every verdict below as an input to that future record, not a substitute for it.

## Summary

Firebase fits the *shape* of Phase 2 well on paper — its Auth method coverage and free tier line up with a single-user, append-mostly, small-team app. Firebase also offers **two different storage products** worth weighing against each other: **Firestore** (document store) and **Data Connect / SQL Connect** (a fully-managed Postgres database, GA since April 2025 and expanded with offline/realtime support in April 2026) — see §1. The one place either genuinely strains is **structural**: Phase 1's offline-first contract makes the **local Drift database the permanent source of truth** ("sync reconciles, it does not replace" — [technical-architecture.md → Offline-first](../../design/technical-architecture.md#offline-first)), while both Firebase storage products ship their own offline persistence designed to let their *own* local cache serve that role. Adopting Firebase safely means treating whichever product is chosen as a **sync transport behind the existing repository seam**, not as a replacement store — everything below assumes that integration shape.

### At a glance

| # | Dimension | Verdict | Headline caveat |
|---|-----------|---------|------------------|
| 1 | Data storage (Firestore vs. Data Connect / SQL Connect) | ⚠️ fits with caveats | Firestore needs FK denormalisation; Data Connect fits the relational shape but is a newer product with a standing Cloud SQL cost |
| 2 | Forward-constraints (`updatedAt`/`deletedAt`/money/units) | ✅ fits | `UserPreferences` has no `deletedAt` to tombstone |
| 3 | Sync semantics & conflict resolution | ⚠️ fits with caveats | Firestore's own LWW is server-timestamp-based, not identical to ours |
| 4 | Auth | ✅ fits | Apple Sign-In becomes mandatory on iOS once any social login ships |
| 5 | Friends / social | ⚠️ fits with caveats | No native unique-constraint for usernames |
| 6 | `core` purity constraint | ✅ fits (with a boundary to enforce) | FlutterFire SDKs must stay out of `core` entirely |
| 7 | Cost & operations | ✅ fits | Costs are indicative only; re-price before committing |
| 8 | Privacy & the no-telemetry line | ⚠️ fits with caveats | Analytics/Crashlytics/Performance modules must stay unbundled |

---

## 1 — Data storage: Firestore vs. Data Connect / SQL Connect (managed Postgres) vs. Realtime Database

Firebase now offers **two structurally different storage products**, and the real fork for this app is between them, not between Firestore and Realtime Database.

**Realtime Database is dispatched quickly.** Its flat-JSON-tree model is a worse match than either of the other two for date-range/day-boundary history queries; not considered further.

### Option A — Firestore (document store)

Relational FKs (`PartySession` ← `Meal`/`PartySessionPrice`/`DrinkEntry`) must be denormalised into top-level collections with string-reference fields, or reshaped into subcollections — either way, a real modelling decision, not a mechanical port.

**Mapping the seven Phase 1 entities.** `DrinkEntry`, `DrinkPreset`, `UserPreferences` (singleton), `UserProfile`, `PartySession`, `PartySessionPrice`, and `Meal` ([data-model.md](../../design/data-model.md)) are relational: `PartySession` is referenced by `Meal.partySessionId`, `PartySessionPrice.partySessionId`, and `DrinkEntry.partySessionId`. Firestore has no joins, so the shape becomes either:
- **Top-level collections per entity** (`drinkEntries`, `meals`, `partySessionPrices`, keyed by the same UUID `id`s) with the FK stored as a plain string field and resolved client-side — closest to the current relational shape, simplest to sync incrementally.
- **Subcollections under `partySessions/{id}/meals`, `.../prices`** — more idiomatic Firestore, but complicates syncing `DrinkEntry` (which outlives a session and is queried independently of session in History) and adds a second access pattern.

Top-level collections mirroring the existing tables is the lower-risk shape — it keeps the mapping mechanical and leaves query patterns (date-range history, day-boundary bucketing) as ordinary indexed Firestore queries on `consumedAt`.

**The immutable-snapshot rule helps here.** `DrinkEntry` carries no FK to `DrinkPreset` — preset values are snapshotted at log time ([data-model.md → Snapshot semantics](../../design/data-model.md#snapshot-semantics--log-immutability)). That was originally justified as avoiding "a sync ordering dependency in phase 2," and it pays off directly in a document-store world: a `DrinkEntry` document is fully self-contained and never needs a join or a second read to render.

UUID `id`s (already the primary key on every entity, "becomes the cross-device key in phase 2" — [data-model.md](../../design/data-model.md)) map cleanly onto Firestore document IDs — no re-keying needed.

### Option B — Firebase Data Connect / SQL Connect (managed Postgres)

Firebase's second storage product is a **fully-managed PostgreSQL database on Cloud SQL**, launched as Data Connect (GA April 2025) and expanded/rebranded **Firebase SQL Connect** at Cloud Next 2026 — schema/queries defined via GraphQL *or* native SQL, with offline cache and realtime sync added in the April 2026 update, plus a Flutter SDK.

Because it is **real relational Postgres**, this resolves the exact tension Option A creates: `PartySession`/`Meal`/`PartySessionPrice`/`DrinkEntry` foreign keys, joins, and constraints port over as an almost mechanical translation of the existing Drift schema, rather than requiring a denormalisation judgment call. The History date-range/day-boundary aggregation queries — currently hand-written SQL against Drift — are the kind of query this product is built for, more directly than Firestore's indexed-document queries.

Trade-offs against Option A:
- **Cost shape differs.** Firestore is pay-per-operation with no baseline cost. Data Connect bills operations similarly (free up to 250K ops/month, ~$4/1M after) but the underlying **Cloud SQL instance is a standing cost** — free for a 3-month trial, then from roughly $9.37/month regardless of usage. For a small Phase 2 user base this is a real fixed floor Firestore doesn't have.
- **Newer, still-settling product.** Two rebrands (Data Connect → SQL Connect) inside about two years is a signal to weigh, not dismiss — less production track record than Firestore, which has been stable for a decade.
- **Different integration shape.** GraphQL/SQL schema-and-codegen workflow instead of Firestore's direct client SDK — a different day-to-day development model, worth spiking before committing either way.
- **Likely the same offline source-of-truth question as Firestore.** SQL Connect's offline cache is new (added April 2026); until it's inspected directly, assume it raises the same "whose local cache is the source of truth" question as Firestore §Summary — it should not be assumed to sidestep that risk just because the backing store is relational.
- **Arguably less vendor lock-in.** Because the data actually lives in Postgres, migrating off Cloud SQL to any other managed-Postgres host later is a more conventional migration than migrating off Firestore's proprietary document model — though the app would still depend on GCP for the instance itself while on this path.

**Net read:** if data-model fit is weighted heavily, Data Connect/SQL Connect is arguably the *structurally* better match for this schema than Firestore — but it's young enough, and different enough operationally (standing cost, GraphQL/SQL workflow), that it needs its own spike before being preferred. This is exactly the kind of fork the eventual comparative decision record needs to resolve, not something to default on now.

## 2 — Do the Phase 1 forward-constraints map onto either storage option?

This is the strongest part of the story — the Phase 1 schema was deliberately built for this, and it holds for both options:

- **`updatedAt`** → directly usable as the last-writer-wins field (see §3 for the nuance, and the Option A/B difference there).
- **`deletedAt` soft-delete** → propagates deletions without separate tombstone tracking, exactly as designed ([data-model.md](../../design/data-model.md)): a tombstone field on a Firestore document under Option A, or a nullable column under Option B — the latter is, if anything, a more direct match since it's the same shape Drift already uses. One gap either way: **`UserPreferences` has no `deletedAt`** — it's a never-deleted singleton, so it needs no tombstone path, but any generic sync-reconciliation code must special-case it.
- **Money as integer minor units** and **all values stored metric** ([phase-1-constraints.md → C1](../phase-1-constraints.md)) travel as plain numbers either way — no currency or unit conversion edge cases at the sync boundary, which is exactly why those rules were pinned in Phase 1.

Verdict: **✅ fits.** Nothing here requires storage-product-specific rework; the Phase 1 schema already anticipated this handoff.

## 3 — Sync semantics & conflict resolution

The design specifies **last-writer-wins reconciliation on `updatedAt`**, judged "sufficient for this app's data shape (single-user, append-mostly)" ([technical-architecture.md → Sync model](../../design/technical-architecture.md#sync-model-phase-2-design-constraints)), and [open-questions.md](../../design/open-questions.md) explicitly flags **clock skew and offline edits on multiple devices** as unresolved.

Firestore has its own conflict behavior: offline writes queue locally and replay on reconnect, with the *last client write to reach the server* winning **per document**, optionally using `FieldValue.serverTimestamp()` for a server-assigned time rather than trusting the client clock. Two things to reconcile before this can be relied on:

- Firestore's native LWW operates at **server-write-arrival order**, not necessarily at our own `updatedAt` field — if reconciliation logic keys off our `updatedAt` (client-set) while Firestore's own resolution keys off arrival order, the two can disagree under clock skew. Using `serverTimestamp()` for `updatedAt` at write time would close most of this gap, but that's a design decision Phase 2 still owes, not a Firestore default.
- The house architecture keeps math and reconciliation logic in pure Dart in `core` ("Phase 2 adds new algorithms (sync reconciliation) as more pure functions" — [flutter-stack.md → D7](flutter-stack.md#d7--shared-computation-pure-dart-core-package)). Reconciliation should stay **our** pure-Dart LWW comparison over documents read from Firestore, not delegated to Firestore's automatic per-document resolution — otherwise the clock-skew question in open-questions.md never actually gets answered, just papered over by whichever write happened to arrive last.

This is Option A's picture specifically. **Under Option B (Data Connect/SQL Connect)**, Postgres offers real transactions and row-level locking, which changes the reconciliation story: conflicting concurrent writes can be detected and resolved inside a SQL transaction rather than relying on last-write-arrival semantics — a potentially cleaner fit for an `updatedAt`-keyed LWW comparison, though this still needs the same treatment: reconciliation logic belongs in `core` as pure functions, not delegated to whatever Data Connect does by default.

Verdict: **⚠️ fits with caveats** — Firestore is a workable transport, but the clock-skew/LWW-semantics open question in the design docs must be resolved by our own reconciliation code, not assumed away by Firestore's defaults.

## 4 — Auth

[features.md → F8](../../design/features.md#f8--account-creation-and-sign-in-phase-2) requires: account creation **always optional**, a user who never signs up gets the unchanged Phase 1 experience, and sign-out **stops sync but preserves local data**. The auth method itself is `[OPEN]` — "email + password, magic link, social login, or a combination?" ([open-questions.md](../../design/open-questions.md)).

Firebase Auth covers every candidate on that list out of the box: email/password, email-link (magic link), and social providers (Google, Apple, and others via FlutterFire's `firebase_auth`). None of it requires the app to *always* be signed in — Firebase Auth's anonymous/no-session state composes naturally with "optional account" and "sign out preserves local data," since local data lives in Drift regardless of auth state.

One concrete platform requirement to flag now rather than at implementation time: **if any social sign-in ships, Apple requires Sign in with Apple be offered alongside it on iOS** (App Store review policy) — this isn't a Firebase constraint, but it becomes a live one the moment "social login" is chosen from the open list.

Verdict: **✅ fits** — strong match to F8's requirements and to every option still open in the design.

## 5 — Friends / social (Phase-2 entities)

The Phase-2-only entities `Account`, `Friendship`, `ShareSetting` — explicitly barred from any Phase 1 migration ([data-model.md](../../design/data-model.md#phase-2-only-entities-defined-here-for-forward-compatibility-not-built-in-phase-1); [phase-1-constraints.md → C1](../phase-1-constraints.md)) — map onto Firebase constructs reasonably directly:

- **`Account`** → a Firebase Auth user record (§4).
- **`Friendship`** (pending/accepted) and **`ShareSetting`** (per-friend visibility) → collections/tables, access-controlled to enforce "sharing is between accepted friends only" and "no sharing by default until the user opts in" ([features.md → F11](../../design/features.md#f11--progress-sharing-with-friends-phase-2), [→ Explicit non-features](../../design/features.md#explicit-non-features)) — via Firestore Security Rules under Option A, or ordinary row-level access control under Option B.

**Username uniqueness is the one real gap — and it's Firestore-specific.** `username` is "reserved as the basis for friend discovery in phase 2" and Phase 2 is expected to add **server-side uniqueness enforcement** ([data-model.md → Username character rules](../../design/data-model.md#username-character-rules)). Under **Option A (Firestore)**, there's **no native unique-constraint mechanism** — enforcing it requires either a dedicated `usernames/{username}` collection written inside the same transaction as account creation (racy without care) or a Cloud Function performing the check server-side; genuine extra machinery. Under **Option B (Data Connect/SQL Connect)**, this is an ordinary Postgres `UNIQUE` column constraint — no extra machinery needed. This is one concrete point in Option B's favour if friends/social ships early in Phase 2.

Friend discovery method itself is still `[OPEN]` ([open-questions.md](../../design/open-questions.md)) — username-based discovery is one option Firebase supports reasonably (once uniqueness is solved); email-invite or share-link discovery would lean on Firebase Dynamic-Links-successor tooling or a custom Cloud Function instead.

Verdict: **⚠️ fits with caveats** — the collections and access-control model fit; username uniqueness needs deliberate extra design.

## 6 — The `core` purity constraint

Non-negotiable #1 ([CLAUDE.md](../../CLAUDE.md)) requires `flutter/packages/core` to stay pure Dart — no Flutter, Drift, or native-plugin imports. The FlutterFire plugins are **native-backed Flutter plugins**, not pure Dart, whichever storage option is chosen — `cloud_firestore` for Option A, the Data Connect Flutter SDK for Option B, plus `firebase_core`/`firebase_auth` either way — none of them can be imported into `core` under any circumstance.

This is not a blocker, but it is a boundary that must be actively enforced: all Firebase I/O belongs in the **app/repository layer** (the same seam already identified as "exactly where Phase 2 sync slots in without touching the UI" — [flutter-stack.md → D2](flutter-stack.md#d2--architecture--state-management-riverpod--repository-pattern)), while the **LWW comparison, tombstone logic, and any other reconciliation math** stay pure functions in `core`, fed plain Dart values read out of the backend by the repository.

Verdict: **✅ fits**, contingent on this boundary being respected from the first line of sync code.

## 7 — Cost & operations

Indicative figures only (July 2026 pricing; **re-verify before any commitment**, both because pricing changes and because Phase 2's actual usage shape isn't designed yet):

**If Firestore (Option A):**
- **Spark (free) tier:** ~50,000 reads/day, ~20,000 writes/day, ~20,000 deletes/day, 1 GiB stored; Firebase Auth free for the first ~50,000 monthly active users (basic email/password and social sign-in; phone-auth SMS is billed separately).
- **Blaze (pay-as-you-go):** roughly $0.06/100K reads, $0.18/100K writes, $0.02/100K deletes beyond Spark limits, plus storage/egress. **No baseline/instance cost** — a zero-traffic project costs nothing.

**If Data Connect / SQL Connect (Option B):**
- **Operations:** free up to 250K queries+mutations/month, then ~$4/1M; network egress free up to 10 GiB/month.
- **Cloud SQL instance:** free for a 3-month trial, then a **standing cost from roughly $9.37/month regardless of usage** — this is the material difference from Firestore's model.

Given the data shape this app produces — single-user, append-mostly, on the order of a handful of writes per active user per day (drink logs, occasional preference/profile edits) — a small user base on Firestore sits comfortably inside or just past the free tier at effectively no baseline cost. Data Connect/SQL Connect carries a small fixed monthly floor from the Cloud SQL instance regardless of traffic. Neither is a meaningful differentiator at Phase 2's likely scale on its own; the fixed floor matters more for a hobby-scale rollout than a funded one.

Verdict: **✅ fits** at the scale implied by the current design either way; revisit once Phase 2 usage patterns (especially social/sharing read volume) are actually specified, and factor the Option A vs. B cost-shape difference into that call.

## 8 — Privacy & the no-telemetry line

[data-model.md → Privacy](../../design/data-model.md#privacy) requires that **data leaves the device only after the user creates an account, which is always optional** — Firebase's optional-auth model is directly compatible with this (§4).

The sharper line to watch: this ban isn't Phase-1-scoped and doesn't lapse when Phase 2 begins. [features.md → F7](../../design/features.md#f7--local-first-storage) states it directly: **"No analytics or telemetry in phases 1 or 2... This is a fixed product decision and not revisited until a later phase."** Firebase ships as a suite — Analytics, Crashlytics, Performance Monitoring, Cloud Messaging are all part of the same product family and easy to reach for once `firebase_core` is already a dependency. Adopting Firebase for storage/auth/sync **must not** be allowed to quietly pull in `firebase_analytics` / `firebase_crashlytics` / `firebase_performance` — those packages need to stay off the dependency manifest in Phase 2 as well, the same way they're already called out as excluded in Phase 1 ([flutter-stack.md → Dependency manifest](flutter-stack.md#dependency-manifest)). Per F7, this isn't Phase 2's call to revisit at all.

Worth naming as an honest con, not a blocker: choosing either Firebase storage option is choosing **Google/GCP** as the data processor for anything that syncs — the degree of vendor-specific lock-in differs by option, see §1/Risk 6.

Verdict: **⚠️ fits with caveats** — compatible with the privacy model, but requires discipline to keep the non-storage parts of the Firebase suite out of the build.

---

## Risks & open questions

1. **[HIGH] Offline-first source-of-truth tension.** The headline risk (see Summary). Any implementation must keep Drift as the on-device source of truth and treat the chosen Firebase storage product purely as sync transport behind the repository — never let its own offline cache (Firestore's, or Data Connect/SQL Connect's newer one) become the thing the UI reads from directly.
2. **[MED] Two overlapping local caches.** Both Firestore and (per its April 2026 offline update) Data Connect/SQL Connect maintain their own local persistence layer; naïve integration means two on-device stores (Drift + the Firebase product's cache) tracking overlapping data. The integration design needs to say explicitly whether that local persistence is even enabled, or whether the app talks to the backend in a way that avoids double-caching.
3. **[MED, Firestore-specific] NoSQL modelling of an inherently relational schema.** History's date-range/day-boundary aggregation queries were designed against relational SQL (Drift); the equivalent Firestore query/index design for the same aggregates needs to be worked out, not assumed to transfer directly. **This risk is largely avoided by choosing Option B (Data Connect/SQL Connect)** instead, at the cost of that product's own newness and standing Cloud SQL instance cost (§1, §7).
4. **[MED] Clock-skew / multi-device conflict edge cases.** Still `[OPEN]` in the design ([open-questions.md](../../design/open-questions.md)) and not resolved by adopting either Firebase storage product — see §3.
5. **[LOW-MED] Username-uniqueness enforcement.** Needs a dedicated collection-plus-transaction or Cloud Function under Firestore; under Data Connect/SQL Connect it's an ordinary Postgres `UNIQUE` constraint — one place Option B is simpler (§5).
6. **[LOW-MED, Firestore-specific] Vendor lock-in.** Firestore's document model and security-rules DSL are Google-specific and would need real rework to migrate off. Data Connect/SQL Connect is comparatively more portable, since the data is real Postgres — though the app would still depend on Cloud SQL/GCP while on that path. Factor into any eventual comparative decision.
7. **[LOW, Option-B-specific] Product maturity.** Data Connect/SQL Connect has rebranded twice in about two years (Data Connect → SQL Connect) and gained offline/realtime support only in April 2026 — less production track record than Firestore. Worth a spike, not a disqualifier.
8. **[Not a risk — a reminder] This is not yet a decision.** Even within Firebase, §1 leaves Firestore vs. Data Connect/SQL Connect unresolved. A comparative record (that internal fork, plus Firebase vs. Supabase vs. a fully custom backend) is still owed before Phase 2's backend is `Accepted` anywhere.
