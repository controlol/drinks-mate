# Release & distribution — operations guide

How a Drinks Mate build gets in front of users, and what still has to happen
before the *first* Play Store release can ship. Companion to
[`docs/agentic-workflow.md`](./agentic-workflow.md) (that one gates code
changes into `main`; this one gates a build from `main` out to users).

Two distinct paths, covered in this doc:
- **Firebase App Distribution** — no Play account, no store listing, no
  review; add a tester's email and they get a build within minutes. The
  right way to get a real build in front of people *today*, and to keep
  doing so throughout development.
- **Google Play Store** — the eventual production distribution channel.
  Has a real one-time setup cost (account, listing, policy questionnaires)
  and a per-release review; see [Technical gap](#technical-gap-for-the-first-play-release)
  for exactly what's still missing.

Nothing below requires choosing one over the other — they run off the same
signed APK/AAB and can operate in parallel indefinitely.

## Three build pipelines, three triggers

| Workflow | Trigger | Produces | For |
|---|---|---|---|
| [`build-apk.yml`](../.github/workflows/build-apk.yml) (existing) | Every relevant push to `main` (via CI completing) | Signed `.apk` (see [`RELEASE_SIGNING.md`](../RELEASE_SIGNING.md)) | Quick sideloading/sanity checks on `main`'s tip |
| [`distribute-firebase.yml`](../.github/workflows/distribute-firebase.yml) (added alongside this doc) | A `v*.*.*` tag, or manual dispatch | Firebase App Distribution release | Getting a real build to testers, no Play account, no waiting |
| [`release-play.yml`](../.github/workflows/release-play.yml) (added alongside this doc) | Publishing a GitHub Release | Signed `.aab` uploaded to the Play Console | An actual Play Store release |

All three build and sign independently (each decodes the same release
keystore from the same `ANDROID_*` secrets — see `RELEASE_SIGNING.md` —
rather than sharing artifacts across workflows), but on deliberately
different triggers. `build-apk.yml` firing on every `main` push is fine for
a disposable sideload artifact; `distribute-firebase.yml` and
`release-play.yml` are scoped to an explicit tag / a published GitHub
Release respectively so that shipping a build to testers or to Play is
always an intentional act, never a side effect of merging a PR.

```
        git tag v1.2.0 && git push --tags        gh release create v1.2.0 --tag v1.2.0
          (or: workflow_dispatch)                   [--prerelease]   (or the Console UI)
                    │                                          │
                    ▼                                          ▼
     distribute-firebase.yml                         release-play.yml
       decode release keystore                         decode release keystore
       flutter build apk --release                      flutter build appbundle --release
       upload to Firebase App                            upload to Play Console via the
       Distribution (group: testers)                      Play Developer API
                    │                              track = internal if the release is
                    ▼                              marked "pre-release", else production
          testers install via                                    │
          emailed/link invite                                    ▼
                                                     Google Play Console
                                             track review → (promote track) → users
```

## Firebase App Distribution: one-time setup

Do this once; after that, pushing a `v*.*.*` tag (or a manual dispatch of
`distribute-firebase.yml`) builds a fresh signed APK and ships it straight to
testers.

1. **Create a Firebase project** at [console.firebase.google.com](https://console.firebase.google.com/)
   (free tier is enough) and add an Android app to it with `packageName`
   `nl.controlol.drinksmate` — this doesn't need to be the same Firebase
   project you'd later use for anything else, and doesn't require or affect
   the Play Console `applicationId` decision at all.
2. **Grab the App ID** from Project settings → General → your Android app's
   "App ID" (format `1:1234567890:android:abcdef...`), and store it:
   ```bash
   gh secret set FIREBASE_APP_ID
   ```
3. **Create a service account** with the **Firebase App Distribution Admin**
   role: Google Cloud Console → IAM → Service Accounts → create → grant that
   role → Keys → Add key → JSON. Store its content directly:
   ```bash
   gh secret set FIREBASE_SERVICE_ACCOUNT_JSON < service-account.json
   ```
4. **Create a tester group** named `testers` in Firebase Console → App
   Distribution → Testers & Groups (or change the `groups:` input in
   `distribute-firebase.yml` to whatever name you use), and add tester
   emails to it. They'll get an email invite the first time a build lands;
   after accepting once, new builds just show up in the Firebase App Tester
   app.

That's the entire setup — no account review, no store listing, no waiting
period. Try it with `git tag v0.1.0 && git push origin v0.1.0`, or *Actions →
Build + upload APK to Firebase App Distribution → Run workflow* for an
ad-hoc build off any branch, once the secrets above are in place.

## How a Play release reaches users

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
  (add `whatsNewDirectory: flutter/distribution/whatsnew` to the
  `r0adkll/upload-google-play` step — pointing at the *directory*, with a
  `whatsnew-en-US` file inside it — if you want notes checked into the repo
  instead of typed into the Console each time).

## Play Store: one-time setup

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

### 4. Release keystore
`release-play.yml` signs the AAB with the same release keystore and
`ANDROID_KEYSTORE_BASE64`/`ANDROID_KEYSTORE_PASSWORD`/`ANDROID_KEY_ALIAS`/
`ANDROID_KEY_PASSWORD` secrets that `build-apk.yml` already uses — see
[`RELEASE_SIGNING.md`](../RELEASE_SIGNING.md) for how to generate it and
wire it into CI. One upload key, one place it's documented; nothing
Play-specific to set up here.

On first upload, Play requires enrolling in **Play App Signing**. The
Console defaults to **"Use Play-generated key"** — don't accept that
default here. It mints a brand-new signing key, which would leave the
Play-installed app signed differently from every `distribute-firebase.yml`
build, and Android refuses to install one as an "update" over the other:
testers who already have a Firebase build installed would have to uninstall
it before they could get the Play version.

Instead, choose **"Export and upload a key from a Java keystore"** and
upload the *same* keystore from `RELEASE_SIGNING.md`, so the Play app
signing key and the Firebase-distributed APKs share one certificate and
testers can update straight across:

1. Console → your app → *Setup* → *App integrity* → *App signing* → pick
   "Export and upload a key from a Java keystore". That page hands you two
   session-specific files: the **PEPK tool** (`pepk.jar`) and an
   **encryption public key** (`encryption_public_key.pem`) — both only
   available from inside this flow, not a stable download link.
2. Encrypt the existing keystore's private key for upload (alias is
   `upload`, per `RELEASE_SIGNING.md`; same password serves as both the
   store and key password):
   ```bash
   java -jar pepk.jar \
     --keystore=upload-keystore.jks \
     --alias=upload \
     --output=output.zip \
     --include-cert \
     --rsa-aes-encryption \
     --encryption-key-path=encryption_public_key.pem
   ```
3. Upload the resulting `output.zip` on that same Console page.

This is a one-time, first-enrollment-only choice — Google only lets you
change the app signing key afterward through an exceptional, manually
reviewed "key upgrade" request (e.g. a compromised key), not as a routine
do-over. If the upload key in `RELEASE_SIGNING.md` is ever lost or
compromised, that same request process applies; the Play-side app signing
key stays recoverable independent of it either way.

### 5. Upload the first release manually
**The Play Developer API cannot create the first release for a package name
it has never seen** — `release-play.yml` will fail on a brand-new app no
matter how correctly it's configured. Build one AAB locally and upload it by
hand through the Console once, using the same `versionCode` formula
`release-play.yml` uses (`major*10000 + minor*100 + patch`) so the manual
upload and every subsequent tagged release live on the same numbering
scheme — e.g. for the `v0.1.0` tag that formula gives `100`:
```bash
cd flutter
flutter build appbundle --release --build-name=0.1.0 --build-number=100
# Play Console → your app → Testing → Internal testing → Create release →
# upload build/app/outputs/bundle/release/app-release.aab
```
Because every tagged release after this one has a strictly higher
`major*10000 + minor*100 + patch` value than `100`, `versionCode` is always
strictly increasing from here on — no collision with this manual upload.

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

**Sharing a build with testers, no Play release needed:** once
[Firebase setup](#firebase-app-distribution-one-time-setup) is done,
```bash
git tag v1.2.0 && git push origin v1.2.0
```
builds a signed APK and ships it to the Firebase `testers` group within a
few minutes. No Play track, no review — this is the everyday path while
iterating. (Or dispatch `distribute-firebase.yml` manually for an ad-hoc
build off any branch, tag or no tag.)

**Cutting an actual Play Store release:**

1. Land the changes on `main` through the normal PR flow
   ([`docs/agentic-workflow.md`](./agentic-workflow.md)) and tag it as above
   if you also want it on Firebase.
2. Publish a GitHub Release for that tag — this, not the tag push itself, is
   what triggers `release-play.yml`. **Create/push the tag first (step 1),
   then create the release against the existing tag**, rather than letting
   `gh release create` mint the tag itself: if `gh release create` both
   creates the tag and publishes the release in one call, it fires
   `distribute-firebase.yml` (tag push) and `release-play.yml` (release
   published) at the same moment, producing a redundant (harmless, but
   pointless) Firebase build.
   ```bash
   gh release create v1.2.0 --title v1.2.0 --generate-notes --prerelease
   ```
   `release-play.yml` builds `app-release.aab` with `versionName=1.2.0` and a
   `versionCode` derived from the tag itself (`major*10000 + minor*100 +
   patch`, e.g. `10200` for `v1.2.0` — strictly increasing with the version
   and independent of CI run counters), and uploads it to Play. **The track
   is derived from the release itself**: mark it `--prerelease` for the
   `internal` track, or omit the flag for a full release to go straight to
   `production`. There's no manual `track` input — creating the right *kind*
   of GitHub Release is the whole interface. **Don't publish an `-rc` tag
   (e.g. `v1.2.0-rc1`) as a GitHub Release and later `v1.2.0` itself** — the
   `-rc` suffix is stripped before computing `versionCode`, so both would
   compute the same value and Play requires `versionCode` to be unique
   across every release.
3. For an internal-track release: check it in Play Console, sanity-check on
   a real device via the track's opt-in link, then promote it to
   closed → open → production in the Console as it clears each bar (a
   Console action, no rebuild needed).
4. Production releases go live as a **staged rollout at 10%** by default
   (`release-play.yml` sets `status: inProgress`, `userFraction: 0.1`); ramp
   it up to 100% manually in the Console once you're confident in the build.
   Internal-track releases ship at 100% immediately (`status: completed`) —
   there's no meaningful "stage" for a track that's already limited to 100
   testers. Production releases also go through Play's standard review
   before going live at all.

## Technical gap for the first Play release

Play Store publishing is **not required** to get real builds in front of
people — Firebase App Distribution (above) does that today, with only the
four setup steps in that section and no Play account at all. The gap below
is specifically what's still missing for a *Play Store* release; nothing
here blocks using Firebase App Distribution in the meantime.

Two different kinds of gap. The first kind is closed by code already on
`main`, or by the workflow added alongside this doc; the rest need a human
with Play Console / Google Cloud / Firebase access and can't be scripted
from inside this repo.

**Closed in code:**
- `flutter/android/app/build.gradle.kts` used to sign every release build
  with the **debug keystore** — fixed in #74 (`RELEASE_SIGNING.md`), which
  also wired a real signing key into `build-apk.yml`. `release-play.yml`
  reuses that same key/secrets rather than a second Play-specific one.
- There was no App Bundle build target or Play upload step anywhere in CI —
  `build-apk.yml` only produces a `.apk`, which Play doesn't accept for
  new-app publishing. `release-play.yml` adds the AAB build + Play
  Developer API upload.
- There was no versioning convention beyond hand-editing `version:` in
  `pubspec.yaml` (frozen at `0.1.0+1`). Both new workflows now derive
  `versionName` from a git tag/GitHub Release; `release-play.yml` derives
  `versionCode` from the tag's semver (`major*10000 + minor*100 + patch`,
  strictly increasing and independent of CI run counters), while
  `distribute-firebase.yml` uses the CI run number since Firebase has no
  Play-style strictly-increasing-versionCode requirement to satisfy.
- There was no way to get a build to testers without either sideloading an
  APK by hand or going through Play at all. `distribute-firebase.yml` closes
  that gap independently of the Play Store work, and is scoped to a tag/
  manual dispatch rather than firing on every `main` push.

**Still open — blocks the first Play release, not fixable in code:**
- **No Play Developer account exists yet** (personal vs. organization is an
  unmade, consequential decision — see step 1).
- **No app listing / package name registered in Play Console** — until one
  exists, `release-play.yml` has nothing to upload to (see step 5: the very
  first upload for a new app must be manual regardless of pipeline quality).
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
- **No Play Developer API service account** — `PLAY_SERVICE_ACCOUNT_JSON`
  doesn't exist yet; requires linking a Google Cloud project in Console API
  access.
- **The closed-testing gate itself is a lead-time risk, not just a
  checkbox** — for a personal account, 12 active testers for 14 consecutive
  days must elapse before Play will even consider a production application,
  independent of how ready the app or pipeline is.

For Firebase App Distribution, the equivalent still-open list is much
shorter: a Firebase project, the `FIREBASE_APP_ID`/
`FIREBASE_SERVICE_ACCOUNT_JSON` secrets, and a tester group — all covered in
[Firebase App Distribution: one-time setup](#firebase-app-distribution-one-time-setup)
above, with no account review or waiting period.
