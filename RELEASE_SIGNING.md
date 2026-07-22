# Android release signing

Why release APKs need a stable signing key, how CI gets access to it, and how
to generate a new one if it's ever lost.

## Why this matters

Android refuses to install an APK as an "update" over an existing install
unless it's signed with the exact same key. The Flutter template's default
release `signingConfig` falls back to the debug key, and CI runners generate
a fresh, random debug keystore on every run — so every `build-apk.yml`
artifact used to be signed with a different key, and no CI build could ever
be installed as an update over the previous one.

The fix: a real release keystore, generated once, whose key material is
injected into the build rather than regenerated per run.

## How the builder accesses the keys

Two stages: **GitHub secrets → files/env vars on the runner → Gradle reads
them at build time.**

1. **CI decodes the keystore to a file**
   (`.github/workflows/build-apk.yml`, "Decode release keystore" step).
   GitHub secrets only store text, so the keystore is kept as base64 in the
   `ANDROID_KEYSTORE_BASE64` secret. This step decodes it to a binary `.jks`
   in `$RUNNER_TEMP` (wiped when the job ends) and records the path in
   `$GITHUB_ENV` as `ANDROID_KEYSTORE_PATH`.

2. **The build step passes the rest through as plain env vars**
   (`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`)
   — these are just strings, no file needed.

3. **Gradle reads those env vars**
   (`flutter/android/app/build.gradle.kts`). A `signingProp` helper checks
   `android/key.properties` first (for local builds — gitignored, see
   `flutter/android/key.properties.example`), then falls back to
   `System.getenv(...)` (for CI). The same config serves both cases:
   locally you point `key.properties` at a keystore file on disk; in CI, the
   workflow's env vars fill the same role. If neither is present, the build
   falls back to the debug key so `flutter run --release` still works on a
   contributor machine with no signing material configured.

Nothing is ever committed or logged: GitHub redacts secret values in Action
logs, and the decoded `.jks` only exists in the ephemeral `$RUNNER_TEMP`.

## Generating a signing key

Standard `keytool`, bundled with any JDK:

```bash
keytool -genkeypair -v \
  -keystore upload-keystore.jks \
  -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storetype PKCS12 \
  -dname "CN=Drinks Mate, OU=Engineering, O=Drinks Mate, L=, ST=, C=NL"
```

- `-keystore` — output file. Keep this forever; it's never rotated, since
  Android ties app updates to it permanently.
- `-alias` — name for this key inside the store (a keystore can hold
  several); matches the `ANDROID_KEY_ALIAS` secret.
- `-keyalg RSA -keysize 2048` — Google's current minimum for Play Store
  uploads.
- `-validity 10000` — days (~27 years); needs to outlive the app, since an
  expired signing cert also breaks updates.
- `-storetype PKCS12` — modern standard format (the original proprietary
  `.jks` format is deprecated).
- `-dname` — the certificate's identity fields; cosmetic only, doesn't
  affect functionality.

It prompts interactively for the store password and key password (or pass
`-storepass`/`-keypass` non-interactively for scripting). Then push it to
GitHub:

```bash
base64 -w0 upload-keystore.jks | gh secret set ANDROID_KEYSTORE_BASE64
gh secret set ANDROID_KEYSTORE_PASSWORD
gh secret set ANDROID_KEY_ALIAS
gh secret set ANDROID_KEY_PASSWORD
```

## This is a one-way door

Losing the keystore means no future build can ever be installed as an
"update" over an app instance signed with it — every existing install would
need to be uninstalled and reinstalled as a new package identity. Keep a
durable backup of the keystore file and its passwords outside of any
CI-ephemeral or container-local storage (e.g. a password manager or
encrypted offline storage), not just as the base64-encoded GitHub secret,
which isn't retrievable once set.
