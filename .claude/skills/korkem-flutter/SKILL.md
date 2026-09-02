---
name: korkem-flutter
description: KORKEM Flow's own Flutter conventions — design tokens, no code generation, Riverpod 3 gotchas, localisation, platform targets, and the verify gate. Load before writing or changing any Dart file in mobile/korkem_flow. Overrides generic Flutter advice, which will otherwise introduce freezed, build_runner and GraphQL that this project deliberately does not use.
---

# KORKEM Flow — Flutter conventions

`mobile/korkem_flow` is ~23 500 lines across 147 files with 370 tests. It has a
settled set of conventions, several of them chosen against the common default
for a documented reason. Generic Flutter guidance will contradict them.

---

## Things that are deliberately absent

**No code generation.** `freezed`, `json_serializable` and `riverpod_generator`
are not dependencies and must not be added. `riverpod_generator` 4.0.6 has an
unresolvable constraint (`analyzer ^13` against `riverpod_analyzer_utils` on
`^12`), and the DTO layer is small enough that an explicit `fromJson` is
clearer than a build step. There is **no `build_runner` stage** — do not add
one without re-checking those constraints and recording the result.

**No GraphQL.** ADR-0005 chose REST/RPC. The backend is Frappe; the transport
is `/api/method/...` and `/api/resource/...`.

**No Firebase.** KORKEM is local-first: the client owns their data and their
identity records live on their own Node. Firebase Auth, Firestore and Remote
Config all move ownership to Google and are out of scope by design.

**No second icon set and no literal colours.** See below.

## Feature layout

```
lib/features/<feature>/
├── data/          repositories — the only place that talks to the API
├── domain/        plain Dart models, explicit fromJson
├── application/   Riverpod controllers
└── presentation/  screens and widgets
```

Shared code lives in `lib/core/`. Features do not import each other.

## Design system

Everything visual comes from `lib/core/design/`: `tokens/` (colors, typography,
dimensions, motion, icons) and `widgets/`.

**No literal colour, spacing, radius or duration may appear in a widget file.**
That single rule is what keeps the system intact, and a test enforces it.

Status colours arrive through the `StatusColors` theme extension
(`context.statusColors`) — never by importing tokens and branching on
brightness. Icons come from `material_symbols_icons` through the semantic
`AppIcons` vocabulary.

Inter is bundled at `assets/fonts/` and verified to cover Kazakh; read
`THIRD_PARTY_LICENSES.md` before swapping it.

## Localisation

`gen-l10n` with `ru` / `kk` / `en` in `lib/l10n/`. Generated files land in
`lib/l10n/` and **are committed**. Every user-visible string goes through the
generated `AppLocalizations` — a Russian literal in a widget is a bug, because
the shop floor may be running Kazakh.

## Riverpod 3 — three traps that have already cost time

1. **Auto-retry hides errors.** A failed provider sits in
   `AsyncLoading(retrying)` and never settles into `AsyncError`. Tests must
   pass `retry: (_, _) => null`.
2. **`AsyncValue.valueOrNull` is gone.** The nullable getter is
   `AsyncValue.value`.
3. **`signIn` must never publish `AsyncValue.loading()`.** The router redirects
   a loading session to the splash, which disposes whatever screen is mounted;
   a login screen torn down mid-request loses the error it was about to show,
   so every failure looked like a spinner and then an empty form. Sign-in
   progress is **screen state**. A regression test asserts on the emitted
   state sequence — do not weaken it.

## Platform targets — what exists today

Only `android/` and `linux/` exist. There is **no `windows/`, `ios/` or
`macos/` folder**, so "KORKEM Flow Desktop.exe" is not currently a build
target. Adding Windows is `flutter create --platforms=windows .` plus a real
pass over plugins, fonts and file paths; iOS and macOS additionally need a Mac
and a paid Apple account.

There is also **no local database** — `sqlite`/`drift`/`isar`/`hive` and
`path_provider` are all absent. Offline is not "degraded" today, it is absent.
Any offline work starts by choosing that dependency deliberately.

## Running against a bench

`korkem.localhost` means nothing inside an Android emulator — it resolves to
the *guest's* loopback. The host is `10.0.2.2`, and the server is a runtime
field, so this is a launch flag rather than a source change:

```sh
flutter run -d emulator-5554 --dart-define=KORKEM_BASE_URL=http://10.0.2.2:8000
```

Cleartext HTTP is blocked at `targetSdk 36`. `android/app/src/debug/` permits
it **for loopback hosts only**, merged into debug builds and never a release
one — `docs/privacy_policy.md` promises users that Android blocks unencrypted
HTTP, and that must stay true of what ships.

## The one suite that talks to a real server

`integration_test/` holds 23 tests that drive the **production app against a
running bench** — real HTTP, real socket.io, real login form. Everything in
`test/` fakes the network, which is what makes it fast and also what makes it
blind to `FrappeSocketChannel`, the layer that has caused every device-level
failure in this project.

They had **never been run** until 2026-09-02. Run them like this:

```sh
cd mobile/korkem_flow
flutter test integration_test/<file>.dart -d linux \
  --dart-define=KORKEM_BASE_URL=http://korkem.localhost:8000 \
  --dart-define=KORKEM_E2E_USER=Administrator \
  --dart-define=KORKEM_E2E_PASSWORD=<password>
```

`-d linux` because the Linux desktop target builds here and needs no emulator.

### The variable names are not the same in every file

Cost a whole run to learn. Most files read `KORKEM_E2E_USER` /
`KORKEM_E2E_PASSWORD`, but not all:

| file | reads |
|---|---|
| most (43 references) | `KORKEM_E2E_USER`, `KORKEM_E2E_PASSWORD` |
| `channel_settings_e2e_test.dart` | `KORKEM_E2E_ADMIN`, `KORKEM_E2E_ADMIN_PASSWORD` |
| `business_loop_e2e_test.dart` | also `KORKEM_E2E_MANAGER`, `KORKEM_E2E_EMPLOYEE` |

A missing define is an **empty string**, not an error, so the app signs in with
blank credentials and the test dies as `timed out waiting for sign-in to
complete`. That reads like a broken login screen and is not one. `grep -o
'KORKEM_E2E_[A-Z_]*' <file>` before blaming the app.

### Most of them need a live model, and cannot pass without one

`business_loop_e2e_test.dart` and its neighbours drive the assistant, so they
need a configured AI provider on the bench. Without a key the transcript comes
back as `ChatRole.assistant:` with nothing after it, and the test fails on a
missing confirmation card. That is a missing configuration, not a defect —
but it means **these tests are not a gate until a key exists.**

`channel_settings_e2e_test.dart` needs no model. It was the first green
end-to-end run in this project: 2 tests, real login form, real bench.

## The verify gate — run all four, paste the output

```sh
cd mobile/korkem_flow
flutter pub get
flutter analyze                                  # must say: No issues found
dart format --set-exit-if-changed lib test
flutter test
```

**Read all four results, not the last one.** Chained into one command the
suite's "All tests passed!" lands at the bottom and `analyze`'s verdict scrolls
off the top; a backgrounded run shows you the tail. That is how a commit came
to claim "analyze — No issues found" while the same output's first line said
`1 issue found`, and CI caught what the commit message asserted. Run the four
separately, or read the whole output — never the tail alone.

`very_good_analysis` with strict-casts, strict-inference and strict-raw-types
is on. A single test: `flutter test <file> --plain-name "<name>"`.

**A failing golden is a question, not a chore.** It says the view changed; the
first thing to establish is whether it changed *correctly*. Never reach for
`--update-goldens` to make it quiet — open the two images and look.

Measured, 2026-09-01: an agent updated `warehouse_light.png` to silence a
failure. The new baseline was the screen it had just written, rendered in its
**error state** — "Что-то пошло не так. That could not be saved." The test
would have passed for as long as the screen stayed broken. A failing test is a
message; a blessed wrong baseline is silence.

The same failure was also telling the truth about something else: the golden
tapped a stock card expecting it to expand in place, and the agent had replaced
that expansion with navigation, deleting a feature whose reason was written
right above it. The golden was the only thing that noticed.

**Never run a bare `flutter test --update-goldens`** — it would rewrite the
launcher assets, which are generated by a `tools`-tagged golden test that is
skipped by default.

## Release builds

Minified. `android/app/proguard-rules.pro` keeps the Flutter engine and the
secure-storage keystore bridge (both reached by reflection) and silences Play
Core; without those rules R8 fails outright. Signing reads the gitignored
`android/key.properties`, and an app-bundle build without one fails
deliberately rather than producing a debug-signed artefact.

## Memory, when a bench is also running

The emulator and the Docker bench compete for the WSL VM's budget, not the
laptop's. Start the bench first and wait for `/api/method/ping`, stop the
Gradle daemon (`android/gradlew --stop`, ~1 GB), then boot the emulator with
`-memory 1536`. Booting it at default RAM has killed all four bench containers
at once, and the app then reports "No connection to the server" — which reads
like an app bug and is not one.
