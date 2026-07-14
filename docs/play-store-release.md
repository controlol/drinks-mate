# Play Store release — operations guide

How a Drinks Mate build becomes a release on the Google Play Store, and what
still has to happen before the *first* one can ship. Companion to
[`docs/agentic-workflow.md`](./agentic-workflow.md) (that one gates code
changes into `main`; this one gates a build from `main` out to users).

## Two build pipelines, two jobs

| Workflow | Produces | For |
|---|---|---|
| [`build-apk.yml`](../.github/workflows/build-apk.yml) (existing) | Debug-signed `.apk` | Direct install on a test device, sideloading, sharing a build with someone off Play entirely |
| [`release-play.yml`](../.github/workflows/release-play.yml) (added alongside this doc) | Signed `.aab` (Android App Bundle) | Upload to the Play Console |

These are deliberately separate. Play has required the App Bundle format for
new app publishing since 2021 — a plain `.apk` cannot be uploaded as a
production Play release — while the existing APK workflow still earns its
keep for quick installs that don't go through Play at all. Don't collapse one
into the other.

```
git tag v1.2.0 && git push --tags       workflow_dispatch (track=internal|alpha|beta|production)
        │                                         │
        └───────────────────┬─────────────────────┘
                            ▼
        .github/workflows/release-play.yml
          decode release keystore from secrets
          flutter build appbundle --release
            --build-name=<tag>  --build-number=<run_number>
          upload app-release.aab as a workflow artifact
          upload to Play Console via the Play Developer API
            (r0adkll/upload-google-play → chosen track)
                            │
                            ▼
                  Google Play Console
        track review → (promote track) → users
```

## How a release reaches users

Play releases move through **tracks**, each with a different audience and a
different bar to promote out of it:

1. **Internal testing** — up to 100 testers you add by email/Google Group, no
   review wait, live within minutes. This is where every build should land
   first, including the one that ends up in production five minutes later.
2. **Closed testing** — an invite-only or link-based group of testers. **New
   personal Play developer accounts (created after 13 Nov 2023) cannot skip
   this**: Google requires at least 12 opted-in testers actively using the
   app for 14 consecutive days before the account is even eligible to apply
   for production access. The 14-day clock starts once 12 testers have opted
   in and the release is approved — not from upload — and dropping below 12
   active testers can reset it. Organization accounts are exempt from this
   gate, but take longer to verify up front (see below).
3. **Open testing** — anyone with the opt-in link, listed as a beta on the
   Play Store page. Optional; useful for a public beta before production.
4. **Production** — the live Play Store listing. Requires passing Play's
   standard app review each time a new release is submitted (separate from
   the one-time closed-testing gate above).

**Sharing a build with users**, concretely:
- Internal/closed testing: the Play Console → *Testing* → track page has an
  **opt-in URL** — send it to testers; they accept, then install/update
  through the Play Store app like any other app.
- Open testing / production: the normal Play Store listing URL.
- Promoting a build from one track to the next (e.g. internal → production)
  is a Console action (or a Play Developer API call) — it re-uses the
  already-uploaded `.aab`, no rebuild needed. Production rollout can be
  staged as a percentage and ramped up manually or on a schedule.
- Release notes: Play Console has a per-track "what's new" field per release
  (add `whatsnewDir` to the `r0adkll/upload-google-play` step, pointing at
  `flutter/distribution/whatsnew/whatsnew-en-US`, if you want notes checked
  into the repo instead of typed into the Console each time).

## One-time setup

These are mostly Play Console / Google Cloud actions, not code. Do them once,
in roughly this order — several have multi-day lead times, so start early.

### 1. Play Developer account
Register at [play.google.com/console](https://play.google.com/console/) —
US$25 one-time fee, identity verification. **Personal accounts trigger the
12-tester/14-day closed-testing gate before production (see above);
organization accounts are exempt but require a D-U-N-S number and can take
several business days to verify.** Decide which account type up front —
switching later is disruptive.

### 2. Create the app listing
In the Console: *Create app* → name, default language, app/game, free/paid,
and the declarations Play asks for at creation time. This mints the
`packageName` slot the pipeline uploads into.

### 3. Complete the Console's mandatory gates
None of these block *building*, but Play won't let a release out to any
track — not even internal testing — until they're filled in:
- **Store listing**: short/full description, 512×512 app icon, 1024×500
  feature graphic, phone screenshots. (Separate from the in-app launcher
  icons in `flutter/android/app/src/main/res/mipmap-*`.)
- **Privacy policy URL**, publicly hosted. Play requires this for every app,
  regardless of whether data ever leaves the device — the design docs
  currently frame the privacy policy as a *Phase 2* deliverable (`design/open-questions.md`,
  `design/technical-architecture.md` §Privacy) because that's when data
  starts leaving the device. That framing doesn't hold for Play submission:
  a Phase 1, fully local-only app still needs a hosted privacy policy page
  before the first release. This needs to be written and hosted before step 5.
- **Data safety form** — what data the app collects/shares, even "none."
- **Content rating questionnaire (IARC)**.
- **Target audience & content**, ads declaration, government-app declaration.
- **Alcohol content review**: the Party Session / BAC feature is likely to
  trigger Play's alcohol-related content policy and age-gating requirements
  on top of the standard content rating — check the current policy for
  apps that estimate or discuss BAC before submitting, since this can affect
  age rating and country availability.

### 4. Generate the release (upload) keystore
```bash
keytool -genkey -v -keystore release.keystore -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias drinks-mate-upload
```
Keep this file and its passwords **outside the repo** — `flutter/android/`
already gitignores `key.properties` and `*.keystore`/`*.jks`. This is your
**upload key**: on first upload, enroll in **Play App Signing** (the Console
default for new apps) so Google holds the actual **app signing key** and
re-signs what you upload; if the upload key is ever lost or compromised you
can request a Console-mediated reset, unlike the app signing key.

Feed it to CI as three repo secrets, base64-encoding the keystore file:
```bash
base64 -w0 release.keystore | gh secret set PLAY_KEYSTORE_BASE64
gh secret set PLAY_KEYSTORE_PASSWORD
gh secret set PLAY_KEY_ALIAS       # drinks-mate-upload, from the command above
gh secret set PLAY_KEY_PASSWORD
```
For local signed builds, copy `flutter/android/key.properties.example` to
`flutter/android/key.properties` (gitignored) and fill in the same values.

### 5. Upload the first release manually
**The Play Developer API cannot create the first release for a package name
it has never seen** — `release-play.yml` will fail on a brand-new app no
matter how correctly it's configured. Build one AAB locally and upload it by
hand through the Console once:
```bash
cd flutter
flutter build appbundle --release
# Play Console → your app → Testing → Internal testing → Create release →
# upload build/app/outputs/bundle/release/app-release.aab
```
After that upload, the package name exists in Play's system and every
subsequent release can go through the API — i.e. through `release-play.yml`.

### 6. Create a Play Developer API service account
Play Console → *Setup* → *API access* → link (or create) a Google Cloud
project → create a service account there → grant it access back in Play
Console with at least **Release manager** permission for this app → download
its JSON key. Store the JSON directly as a secret:
```bash
gh secret set PLAY_SERVICE_ACCOUNT_JSON < service-account.json
```

## Day-to-day: cutting a release

1. Land the changes on `main` through the normal PR flow
   ([`docs/agentic-workflow.md`](./agentic-workflow.md)).
2. Decide the version (semver) and tag it:
   ```bash
   git tag v1.2.0 && git push origin v1.2.0
   ```
   This triggers `release-play.yml`, which builds `app-release.aab` with
   `versionName=1.2.0` and a `versionCode` derived from the GitHub Actions
   run number (guaranteed to strictly increase, which is Play's only
   requirement for `versionCode`), and uploads it to the `internal` track by
   default.
   
   To target a different track (or re-run without tagging), use *Actions →
   Release to Play Store → Run workflow* and pick `track`.
3. Check the internal testing release in Play Console; sanity-check on a
   real device via the track's opt-in link.
4. Promote: in Play Console, promote the same release to closed → open →
   production as it clears each bar (or re-run the workflow with a different
   `track` input — either uploads/promotes, no separate rebuild required for
   promotion via the Console). Production releases go through Play's review
   before going live; stage the rollout percentage if you want a ramp
   instead of 100% at once.

## Technical gap for the first release

Two different kinds of gap. The first is now closed by the changes alongside
this doc; the rest need a human with Play Console / Google Cloud access and
can't be scripted from inside this repo.

**Closed by this change:**
- `flutter/android/app/build.gradle.kts` signed every release build with the
  **debug keystore** (explicit `TODO`s in the file) — there was no path to a
  Play-acceptable signed build at all. It now reads an optional
  `key.properties`/keystore and falls back to debug signing only when that's
  absent, so it's a no-op until step 4 above is done.
- There was no App Bundle build target or Play upload step anywhere in CI —
  `build-apk.yml` only ever produced a debug-signed `.apk`, which Play
  doesn't accept for new-app publishing. `release-play.yml` adds the AAB
  build + Play Developer API upload.
- There was no versioning convention beyond hand-editing `version:` in
  `pubspec.yaml` (frozen at `0.1.0+1`). The release workflow now derives
  `versionName`/`versionCode` from a git tag and the CI run number instead.

**Still open — blocks the first release, not fixable in code:**
- **No Play Developer account exists yet** (personal vs. organization is an
  unmade, consequential decision — see step 1).
- **No app listing / package name registered in Play Console** — until one
  exists, `release-play.yml` has nothing to upload to (see step 5: the very
  first upload for a new app must be manual regardless of pipeline quality).
- **No release keystore has been generated** — `key.properties`/the
  `PLAY_KEYSTORE_*` secrets don't exist. Whoever generates it becomes the
  long-term holder of the upload key.
- **No privacy policy exists** — required by Play for every app regardless
  of whether Drinks Mate is local-only; the design docs currently treat it as
  Phase 2 scope, which doesn't satisfy the Play submission requirement.
- **Store listing assets don't exist** — description copy, 512×512 icon,
  1024×500 feature graphic, screenshots. (Distinct from the in-app launcher
  icons, which do exist but haven't been confirmed as final, non-placeholder
  art.)
- **Content rating / data safety / target audience questionnaires** haven't
  been filled in, and the alcohol/BAC feature likely needs a specific look
  at Play's alcohol-content policy before submitting.
- **`applicationId "com.controlol.drinks_mate"` needs an explicit
  confirm-it's-final** — it's immutable after the first publish, and the
  `build.gradle.kts` TODO calling it out was otherwise silent on the
  consequence.
- **No Play Developer API service account** — `PLAY_SERVICE_ACCOUNT_JSON`
  doesn't exist yet; requires linking a Google Cloud project in Console API
  access.
- **The closed-testing gate itself is a lead-time risk, not just a
  checkbox** — for a personal account, 12 active testers for 14 consecutive
  days must elapse before Play will even consider a production application,
  independent of how ready the app or pipeline is.
