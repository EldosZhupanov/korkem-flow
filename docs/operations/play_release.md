# Releasing KORKEM Flow to Google Play

Every claim here was checked against the project or against Google's own
documentation in July 2026. Items marked **you** need a human with an account,
a secret, or a decision — they are not things this repository can do for itself.

## Where the build stands

| | |
|---|---|
| Application id | `kz.korkem.korkem_flow` |
| Version | `0.1.0+1` → `versionCode 2001`, `versionName 0.1.0` |
| `targetSdk` / `compileSdk` | 36 |
| `minSdk` | Flutter default (24) |
| Release APK, arm64, minified | 20.2 MB |
| Signing | Falls back to the **debug** key until `android/key.properties` exists |
| Permissions | `INTERNET` only |

`targetSdk 36` is already what Play will demand: **from 31 August 2026 new apps
and updates must target API 36**. Nothing to do, but nothing to let slip either.

## Blocking prerequisite: a public HTTPS backend

The app defaults to `http://korkem.localhost:8000`. That is a development host,
and Android has blocked cleartext HTTP by default since API 28. A Play release
is meaningless until KORKEM's ERPNext is reachable over **HTTPS** from the
public internet.

No code change is needed: the server is a field on the login screen, and
`normaliseServerUrl` already prepends `https://` to a schemeless host. Build
with the real default once it exists:

```sh
flutter build appbundle --release \
  --dart-define=KORKEM_BASE_URL=https://erp.korkem.kz \
  --dart-define=KORKEM_FLAVOR=prod
```

## 1. Signing — **you**

Play App Signing means Google holds the *app* signing key and you hold an
*upload* key. Losing the upload key is recoverable through Play Console
support; losing a self-managed app signing key is not. Generate it once:

```sh
keytool -genkey -v -keystore ~/korkem-upload.jks \
        -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then copy `android/key.properties.example` to `android/key.properties` and fill
it in. Both the file and `*.jks` are gitignored.

Back the keystore up somewhere that is not this machine. A release build without
it silently falls back to the debug key for APKs, and **fails outright** for
app bundles — that guard exists so the mistake surfaces at build time rather
than after an upload is rejected.

## 2. The artefact

Play requires an **Android App Bundle**, not an APK, for new apps:

```sh
flutter build appbundle --release
```

Split APKs remain useful for side-loading during testing:

```sh
flutter build apk --release --split-per-abi
```

Before uploading, prove the *signed release bundle* actually runs — a debug
build passing is not evidence:

```sh
bundletool build-apks --bundle=build/app/outputs/bundle/release/app-release.aab \
                      --output=/tmp/korkem.apks --connected-device
bundletool install-apks --apks=/tmp/korkem.apks
```

## 3. Versioning

`versionCode` must strictly increase on every upload; Play rejects a repeat.
Flutter derives it from the `+N` suffix in `pubspec.yaml`, so bump that:

```
version: 0.1.0+1   →   0.1.1+2   →   0.2.0+3
```

`versionName` is what users see and may repeat; `versionCode` may not.

## 4. Store listing — **you**

| Asset | Requirement | Status |
|---|---|---|
| App icon | 512×512 PNG | `assets/icon/app_icon.png` is 1024×1024; downscale |
| Feature graphic | 1024×500 | **missing** |
| Screenshots | 2–8, phone | can be captured from the emulator once it runs |
| Short description | ≤ 80 chars | **missing** |
| Full description | ≤ 4000 chars | **missing** |

The icon is generated from the design tokens by
`test/tools/generate_app_icon_test.dart`. If KORKEM has a real logo, replace
`assets/icon/*.png` and re-run `dart run flutter_launcher_icons`.

## 5. Privacy policy and data safety — **you host, drafted here**

Play requires a privacy policy at a public URL *and* a Data Safety declaration,
and rejects listings where the two disagree. A draft consistent with what the
app actually does is in [`privacy_policy.md`](./privacy_policy.md), with the
matching Data Safety answers.

## 6. Account — **you**

A Google Play developer account costs $25 once and now requires government-ID
verification, which takes days. Start it early; it is the longest lead time in
this list.

## Submission checklist

- [ ] Public HTTPS ERPNext deployment
- [ ] Verified Play developer account
- [ ] Upload keystore generated and backed up; `key.properties` in place
- [ ] `flutter build appbundle --release` with production `--dart-define`s
- [ ] Signed bundle installed and smoke-tested via `bundletool`
- [ ] Privacy policy hosted at a public URL
- [ ] Data Safety form submitted and consistent with it
- [ ] Content rating questionnaire
- [ ] Store listing assets
- [ ] Internal testing track before production

## Not done yet

- **Crash reporting.** Nothing reports a crash from a user's phone today. Sentry
  is the recommendation over Firebase Crashlytics: no Firebase project needed,
  self-hostable if the data must stay in-country, and a simpler Data Safety
  story. It needs a DSN, so it is a decision, not a default.
- **Device verification.** The app has never run on Android. See the emulator
  note in `CLAUDE.md`.
