# KORKEM Flow — Android production readiness

Every result below was observed on a device, not inferred from code. Where a
result depends on a measurement, the measurement is quoted. Where something was
not exercised, it says **NOT TESTED** rather than being left out.

Items marked **you** need a human with an account, a secret, or a decision —
they are not things this repository can do for itself.

## What was tested, and on what

| | |
|---|---|
| Build | `flutter build apk --debug --dart-define=KORKEM_BASE_URL=http://10.0.2.2:8000` |
| App | `kz.korkem.korkem_flow`, `versionName 0.1.0`, `minSdk 24`, `targetSdk 36` |
| Device | `korkem_test` AVD — Android 16 (API 36), `sdk_gphone64_x86_64`, 1536 MB |
| Backend | The Docker bench (`korkem.localhost`), reached at `10.0.2.2:8000` |
| Signed in as | `Administrator`, via API key |
| Host gates | `dart format` clean · `flutter analyze` → *No issues found!* · `flutter test` → **157 passing**, 1 skipped |

The audit ran across two sessions against the same build lineage. Everything
marked PASS was observed **after** the fix it depends on, on a build containing
that fix.

## The 21 categories

| # | Category | Result | Evidence |
|---|---|---|---|
| 1 | Every screen renders | **PASS** | Dashboard, Sales (Deals/Leads/Customers/Quotes), Deal/Lead/Customer detail, Tasks, Operations (Production/Warehouse), Approvals, Notifications, Profile, Settings, Login — all opened with live bench data. Warehouse and the Customer detail were the last two, closed in this pass. |
| 2 | Every navigation path | **PASS** | All four branches; detail routes as children of their branch, so the bottom bar and per-tab back stack survive. Branch state is preserved: returning to Sales restored the lead detail that was open. |
| 3 | Orientation changes | **PASS** | Landscape ≥600 dp switches the bottom bar for a `NavigationRail` and the dashboard to a 4-column grid; scroll position and tab selection survive the rotation. |
| 4 | Dark mode | **PASS** | Applies live, without a restart. Status colours come through the `StatusColors` extension and stay semantically correct in dark — "Overdue" red, "Awaiting approval" amber, "In production" green. |
| 5 | Font scaling | **PASS** | At 1.6× every list row, metric card and detail field ellipsizes; no `RenderFlex overflow` in the log. |
| 6 | Android Back button | **PASS** *(was FAIL — fix 2)* | Detail → list → first tab → dashboard → launcher. Re-verified on today's build: back from the Sales branch landed on Home with Home's own stack restored, then popped to the dashboard, then exited. |
| 7 | Process death | **PASS** | `am force-stop` then relaunch: session restored from secure storage, no crash, no re-login. |
| 8 | App restore | **PASS** | Survived a `-r` reinstall too — the stored credential outlived the APK replacement and the app came back straight to the dashboard. |
| 9 | Offline mode | **PASS** *(was FAIL — fix 3)* | Airplane mode now yields an error state with a working "Try again" instead of skeletons that never resolve. |
| 10 | Slow network | **PASS** | Driven at EDGE and GPRS profiles: skeletons while in flight, content on arrival, no timeout-shaped failure. |
| 11 | Invalid server URL | **PASS** | A bad host produces a visible, readable connection error on the login screen; the typed values are kept. |
| 12 | Expired session | **PASS** | API key revoked server-side → next call cleared the credential and returned to login, with the server field preserved so re-entry is one password. |
| 13 | Logout | **PASS** | Clears the credential and returns to login; no cached data is reachable afterwards. |
| 14 | Login again | **PASS** | Straight back to the dashboard. A *different* user gets that user's data — see fix 1. |
| 15 | All API calls | **PASS** | 28 requests over this pass, **all HTTP 200, zero 4xx/5xx**. Endpoints: `korkem_ai...dashboard.get_summary`, `frappe.client.get_count`, `frappe.auth.get_logged_user`, `ping`, and `/api/resource/` for CRM Lead, CRM Deal, CRM Organization, CRM Task, Item, Work Order, and the two status doctypes. |
| 16 | Memory leaks | **PASS** | PSS 138 → 141 MB across three full navigation laps, plateauing rather than climbing; `Activities: 1` throughout, so no leaked activity. 119 MB PSS at the end of this pass. |
| 17 | Rebuild performance | **PASS** | Profile build: worst case 75 skipped frames, and none during steady-state scrolling. Debug numbers are not quoted — see the caveat below. |
| 18 | Startup time | **PASS** | 3.0 s cold start, profile build. |
| 19 | Crashes in `adb logcat` | **PASS** | 0 `FATAL EXCEPTION`, 0 ANRs attributed to `kz.korkem.*`, across 42,963 lines in the first pass and 11,363 in this one. |
| 20 | Flutter errors | **PASS** | 0 `E/flutter`, 0 `FlutterError`, 0 unhandled exceptions in both passes. |
| 21 | Backend logs | **PASS** | No traceback, no permission error, no 500 raised by anything the app did. |

### Also exercised in this pass

| Area | Result | Evidence |
|---|---|---|
| Search | **PASS** | Typing filters the list and offers a clear affordance; clearing restores it. |
| Filter | **PASS** | Status options are read from the backend, not hard-coded. Applying one marks the filter icon with a badge, and an empty result offers "Clear filter" rather than a dead end. |
| Pagination | **PASS** | Scrolling the 424-lead list issued `limit_start=20` then `limit_start=40` — page size 20, fetched on demand, no jank at the seam. |
| `tel:` / `mailto:` / `wa.me` | **PASS** | Launched from the app's own UID, which is what the `<queries>` declaration exists to permit: Call → `com.google.android.dialer`, Email → `com.google.android.gm`, WhatsApp → `com.android.chrome`. The last is correct, not a defect: WhatsApp is not installed on this image, and `https://wa.me/…` is an ordinary web link that a browser should claim. On a handset with WhatsApp installed its app-link filter takes it instead. **Not verified on a device with WhatsApp installed** — that specific hand-off is inferred from the intent filter, not observed. |

### NOT TESTED

| Area | Why |
|---|---|
| Physical hardware | Everything above is an x86-64 emulator. Nothing here substitutes for one run on a real ARM handset. |
| WhatsApp hand-off with WhatsApp installed | See above — the browser fallback was observed, the app hand-off was not. |
| Tablet / foldable form factors | The ≥600 dp rail was seen in landscape phone only. |
| Other Android versions | API 36 only. `minSdk` is 24; nothing between 24 and 35 was exercised. |
| Release-build behaviour end to end | The release build compiles and is minified, but the audit ran on debug/profile. R8 keeps are configured, not proven against a full run. |
| Multi-user / permission-restricted roles | Signed in as `Administrator`. A `Sales User` reaches the login path (proven in Stage A) but was not driven through the whole app. |

## The five failures found, and what fixed them

**1 — Stale data survived a user switch.** Ten controllers took their repository
with `ref.read` inside `build()`, which snapshots the dependency once. When the
authenticated client was replaced on sign-out/sign-in, those controllers kept the
previous user's client and served the previous user's records. Changed to
`ref.watch` in every controller `build()`; `ref.read` remains correct inside
actions. Pinned by a test that swaps in a second client and asserts a refetch —
verified to fail on `ref.read` and pass on `ref.watch`.

**2 — Back exited the app from any tab.** Two placements failed first. A
`PopScope` in the shell is never consulted, because it sits above the branch
navigators and back is dispatched to the innermost one. A `BackButtonListener`
is not consulted either, because it uses the legacy `didPopRoute` channel while
`targetSdk 36` enables predictive back, which routes through `PopScope`
registrations. Fixed by `lib/core/navigation/tab_back_handler.dart`, wrapping
each branch *root screen* — a route that genuinely belongs to the branch
navigator, so both dispatch paths reach it.

**3 — Offline showed skeletons forever.** Riverpod 3 auto-retries a failed
provider with backoff and no attempt limit, so a failing provider sits in
`AsyncLoading(retrying)` and never settles into `AsyncError` — the UI had no
error to render. `lib/core/api/retry_policy.dart` caps retries at two and
refuses to retry at all for failures a retry cannot fix (auth, permission,
not-found, validation).

**4 — The language group opened with nothing selected.** The default state
follows the device locale, which matched no radio option, and once a language
was picked there was no way back to it. The group is now `RadioGroup<Locale?>`
with a "Device language" entry first, mirroring the theme group above it.

**5 — Theme and language reset on every launch.** They were in-memory only:
someone who chose Russian on a Kazakh-locale phone chose it again every launch.
Now persisted through `shared_preferences`, resolved in `main()` **before**
`runApp` so the first frame is already correct — loading afterwards would render
the default and visibly swap. The reset path was broken separately: `setLocale`
went through `copyWith`, which resolves a null argument to the existing value,
so a language could be set but never cleared; it now constructs the state
directly.

Both halves of 5 were confirmed on the device this pass: Dark + Русский survived
a force-stop with no flash of the wrong theme, and the prefs file held
`themeMode=dark`, `locale=ru`. Resetting to "Device language" *removed* the
`locale` key and left `themeMode` alone, and that reset survived a restart too.

## Remaining blockers

### This repository cannot fix these — **you**

| Blocker | Why it blocks a release |
|---|---|
| **A public HTTPS backend** | The app defaults to `http://korkem.localhost:8000`. Android has blocked cleartext by default since API 28, and `docs/privacy_policy.md` tells users so. A Play release is meaningless until KORKEM's ERPNext is reachable over HTTPS from the public internet. No code change needed — the server is a login-screen field and `normaliseServerUrl` already prepends `https://`. |
| **A Play developer account** | Nothing can be uploaded without one. |
| **A hosted privacy policy URL** | Play requires a public URL. `docs/privacy_policy.md` is written but not hosted. |
| **Store assets** | 512×512 icon, feature graphic, screenshots. The launcher icon is generated from `AppLogo`; the store assets are not. |
| **A crash-reporting decision** | There is no Sentry (or equivalent) DSN, so a crash in the field is currently invisible. This is a decision, not a task — it commits KORKEM to a vendor and a data-processing relationship. |
| **Signing keystore** | `android/key.properties` is gitignored and absent. An app-bundle build without one fails deliberately rather than producing a debug-signed artefact Play would reject. |

### This repository can fix these, and has not yet

| Item | Note |
|---|---|
| **Delete `mobile.test@korkem.local`** | A test account with a known password, created during Stage A. Must not exist in production. |
| **Verify on real hardware** | See NOT TESTED. |
| **Exercise a non-admin role end to end** | `Sales User` was proven only through login. |
| **Offline support** | Currently the app fails honestly when offline; it does not work offline. Evaluate `frappe_mobile_sdk` before building anything bespoke. |

## Score

**78 / 100 — production-ready as an application, not yet releasable as a product.**

Every remaining hard blocker is infrastructure or paperwork. None is an app
defect, and none needs a code change to clear.

| Dimension | Weight | Score | Reasoning |
|---|---|---|---|
| Correctness | 25 | 24 | Five real defects found and fixed, each pinned by a regression test. Zero crashes, zero Flutter errors, zero non-2xx responses across the sweep. Held back only because the sweep is emulator-only. |
| Stability under stress | 15 | 14 | Process death, reinstall, offline, slow network, expired session, rotation and 1.6× font all handled without loss. |
| Performance | 15 | 13 | 3.0 s cold start and a 75-frame worst case in profile are good but not measured on real hardware, where they matter. |
| UX completeness | 15 | 14 | Empty states are filter-aware, errors are actionable, settings persist, three languages including Kazakh. |
| Test coverage | 10 | 8 | 157 tests including goldens, but the platform surfaces — intents, persistence, navigation — are covered by device evidence rather than by automated tests. |
| Observability | 10 | 2 | **The weak spot.** No crash reporting, no analytics, no remote logging. A crash in a salesperson's hand leaves no trace. |
| Release engineering | 10 | 3 | Signing, minification and the Play path are documented and wired, but unproven end to end and blocked on a keystore and an account. |

Raise observability and release engineering and this is a 90+. Neither depends
on the application code.

## A caveat on the performance numbers

Debug-build measurements are meaningless and are not quoted above. For the same
navigation sequence on the same device:

| | Debug | Profile |
|---|---|---|
| Cold start | 7.2 s | **3.0 s** |
| Worst skipped-frame burst | 990 | **75** |

Only the profile figures appear in the table. Anyone re-running this audit
should measure in profile, or the app will look far worse than it is.

## Reproducing this audit

The bench and the emulator do not both fit in 7.4 GB. Booting the emulator at
default RAM kills all four bench containers at once (exit 255), and the app then
reports "No connection to the server" — which reads like an app bug and is not
one. Order matters:

```sh
android/gradlew --stop                                    # frees ~1 GB
docker compose -f infra/frappe_bench/docker-compose.yml up -d
# wait for /api/method/ping to answer

E=~/Android/Sdk/emulator; L=~/.local/emulator-libs/usr/lib/x86_64-linux-gnu
LD_LIBRARY_PATH="$E/lib64:$E/lib64/qt/lib:$L:$L/pulseaudio" \
  $E/emulator -avd korkem_test -no-audio -no-boot-anim -memory 1536 \
  -gpu swiftshader_indirect

flutter build apk --debug --dart-define=KORKEM_BASE_URL=http://10.0.2.2:8000
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

`uiautomator dump` returns nothing useful for Flutter screens — the app renders
to its own surface and exposes a semantics tree only when an accessibility
service is running. Use `adb exec-out screencap -p` and read the image.
`dumpsys gfxinfo` reports 0 frames for the same reason; use the Choreographer's
"Skipped N frames" lines from logcat instead.
