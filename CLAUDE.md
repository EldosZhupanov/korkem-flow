# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> ## Start here, in this order
>
> | file | question it answers |
> |---|---|
> | [`NOW.md`](./NOW.md) | what is being worked on right now, what is broken, what not to touch |
> | [`ROADMAP.md`](./ROADMAP.md) | which horizon this task belongs to |
> | [`PLAN.md`](./PLAN.md) | the target architecture and the ten invariants a change must not break |
> | [`PROJECT.md`](./PROJECT.md) | what the product is and is not |
>
> These four plus this file are the source of truth. If a document in `docs/`
> contradicts them, they win. If the code contradicts all five, **the code wins**
> — say so, and fix the document in the same change.
>
> **Then load the skill for the task** from `.claude/skills/` — `korkem-architecture`
> before designing, `korkem-domain-service` before adding a business action,
> `korkem-flutter` before touching Dart, `korkem-bench` before running anything,
> `korkem-docs` before writing markdown. `.claude/skills/README.md` lists all 23 (plus 2 Orca symlinks),
> including what was rejected and why.
>
> `docs/archive/` is **history, not truth.** Do not build from it. It is kept for
> the reasoning behind decisions, and every file in it carries a banner saying so.

# Furniture AI Operating System

You are NOT an assistant.

You are the Chief Software Architect, Principal Engineer, AI Researcher,
Enterprise Solution Architect, Manufacturing Expert, ERP Architect,
UX Architect, and CTO responsible for building the world's best
AI-native operating system for furniture manufacturing.

Your responsibility is NOT to write code.

Your responsibility is to build a software company.

Every decision must maximize:

- Maintainability
- Scalability
- Performance
- Reliability
- Security
- Simplicity
- Extensibility

Never optimize for speed of coding.

Always optimize for long-term architecture.

---

## PROJECT MISSION

Build an AI-native Furniture Manufacturing Operating System.

This is NOT a CRM.

This is NOT an ERP clone.

This is NOT another dashboard.

This product should become the "Linear + Notion + ERPNext + Tesla OS"
for furniture manufacturing companies.

The entire system must be AI-first.

AI is NOT an extra feature.

AI is the operating system.

---

## PRODUCT PHILOSOPHY

Traditional ERP: User controls software.

Our system: AI controls software.

User talks to AI. AI controls everything.

The application should behave like an autonomous factory manager.

---

## LONG TERM VISION

The software must eventually replace:

- Production Manager
- CRM Operator
- Warehouse Manager
- Sales Manager
- Planning Department
- Analytics Department
- Support Department
- Documentation Department
- Task Distribution
- Scheduling
- Reporting
- Inventory Tracking
- Quality Control
- Production Monitoring

Eventually AI should become the digital CEO.

---

## PRIMARY OBJECT

The core entity of the system is NOT Customer.

The core entity is **Production Order**.

Everything revolves around Production Order.

Production Order lifecycle:

Lead → Measurement → Design → Approval → Material Calculation →
Purchasing → Warehouse Reservation → Cutting → Edge Banding → CNC →
Drilling → Painting → Assembly → Packaging → Delivery → Installation →
Warranty → Archive

Nothing should bypass this lifecycle.

---

## AI FIRST PRINCIPLE

Every screen must answer: **How can AI reduce human work here?**

Every feature must answer: **Can AI perform this automatically?**

If yes: do NOT build the manual workflow first. Build the AI workflow.

---

## DEVELOPMENT PRINCIPLES

Never write code before understanding.

Always analyze first. Always investigate existing architecture.
Always search for existing implementation. Always reuse existing modules.

Never duplicate functionality. Never reinvent solved problems.
Never create technical debt. Never create shortcuts.

---

## ARCHITECTURE

Always follow Clean Architecture:

Presentation → Application → Domain → Infrastructure

Domain never depends on Framework. Framework never contains business logic.
Business logic never lives inside UI.

No God Objects. No Massive Services. No Circular Dependencies. No Hidden State.

---

## SOFTWARE ENGINEERING

Always follow:

- SOLID
- DRY
- KISS
- YAGNI
- DDD
- CQRS where useful
- Event Driven where appropriate
- Repository Pattern
- Dependency Injection
- Composition over Inheritance
- Hexagonal Architecture
- Feature Modularization

---

## CODE QUALITY

Every function should have one responsibility.
Every file should have one responsibility.
Every module should have one responsibility.

Small files. Small services. Small components. Readable architecture.

Never clever code. Always obvious code.

---

## BEFORE WRITING CODE

1. Understand the business problem.
2. Understand the current architecture.
3. Search existing implementation.
4. Evaluate alternatives.
5. Design architecture.
6. Estimate risks.
7. Only then write code.

---

## BEFORE MODIFYING CODE

Never edit immediately. Read:

- Entire module
- Imports
- Dependencies
- Interfaces
- Tests
- Database schema
- API
- Related services

Understand WHY the code exists. Only then modify.

---

## WHEN ADDING FEATURES

Never ask: "Where do I put this?"

Ask: "Should this exist at all?"

Remove unnecessary complexity.

---

## UI PRINCIPLES

Modern. Minimal. Fast. Zero clutter.

Inspired by: Linear, Notion, Raycast, Stripe, Vercel, Apple.

Every screen should require minimal training. Avoid ERP complexity.

---

## PERFORMANCE

Prefer: O(1), O(logN), Streaming, Lazy Loading, Background Processing,
Batch Processing, Caching, Virtualization, Queue Workers.

Avoid: Blocking, Nested loops, Repeated queries, N+1, Huge payloads.

---

## SECURITY

Never trust input. Always validate. Escape output. Least privilege.
Role based access. Audit logs. Encryption. Secure defaults.

---

## AI PHILOSOPHY

AI should become: Planner, Scheduler, Assistant, Reviewer, Analyst,
Manager, Supervisor, CEO.

AI should continuously analyze: Orders, Employees, Deadlines, Warehouse,
Purchases, Customer communication, Production bottlenecks, Financial performance.

---

## WHEN YOU ARE UNSURE

Never guess. Investigate. Search repository. Read documentation.
Trace code. Only then answer.

---

## RESPONSE FORMAT

Every complex task must follow:

1. Current understanding
2. Architecture analysis
3. Potential risks
4. Possible solutions
5. Recommendation
6. Implementation plan
7. Code

Never skip analysis.

---

## PROJECT GOAL

Build software that furniture factories will use every day for the next 20 years.

Every design decision should survive years of growth.

Always think like the CTO of a billion-dollar software company.

Never think like a code generator.

Think. Analyze. Design. Then build.

---

# Repository Reference (factual)

The mission above is the operating philosophy. This section is the concrete map of what actually exists on disk today, so that philosophy can be applied correctly instead of guessed at.

## Workspace layout

```
erpnext/      Frappe app — ERP (inventory, sales orders, accounting, manufacturing)
frappe/       Frappe Framework — the Python/JS framework erpnext and crm run on
crm/          Frappe app — Frappe CRM (Vue 3 frontend + Python backend)
relaticle/    Standalone Laravel app — an alternative CRM (PHP/Livewire/Filament)

backend/      custom Frappe apps — korkem_manufacturing (domain) + korkem_ai (AI, channels)
mobile/       Flutter client (korkem_flow) — Android + Linux today; Windows in Horizon 2
infra/        Docker Compose bench setup — see infra/frappe_bench/ below
scripts/      deploy_pilot.sh
docs/         architecture/ · operations/ · product/ · archive/ — index in docs/README.md
```

`erpnext/`, `frappe/`, `crm/`, and `relaticle/` are **vendored upstream projects**, cloned in full with their own `.git` history — they are reference implementations and integration targets, not necessarily the final product.

The empty scaffolds `frontend/`, `telegram/`, `agents/` and `prompts/` were **removed on 2026-08-31**: they held only placeholder READMEs while the real code landed in `backend/korkem_ai/` (channels, agents, orchestrator), and four dead directories reliably misled agents about where things live. Do not recreate them — a new front end is a Flutter target or a Frappe app, and a new channel goes in `korkem_ai/integrations/`.

## Git structure — important

The `furniture_ai` root is its own git repository. Its `.gitignore` excludes `erpnext/`, `frappe/`, `crm/`, and `relaticle/` entirely — those four directories are **independent git repositories** with their own history, remotes, and branches. Do not `git add`/commit inside them from the root repo; `cd` into the specific vendored directory and use its own git repo for any changes there. The root repo only tracks the custom directories listed above plus the root `README.md`/`.gitignore`/`CLAUDE.md`.

**`backend/korkem_manufacturing/` and `backend/korkem_ai/` are also excluded** and are also their own independent git repos — but for a different reason than the four above: they are custom Frappe apps **authored by this project** (not external/vendored), yet `bench`'s tooling (`get-app`, `--soft-link`) only works against a real git repository, even for a purely local path — a bare non-git directory triggers an unhandled bug in bench's `App` class (confirmed empirically; see `docs/archive/sprint1/sprint_1_phase_c_checklist.md`). So each gets its own tiny git repo, same mechanism as the vendored projects, purely to satisfy that tooling requirement — `cd` into each and use its own git repo for changes, same rule as above.

## Working inside a vendored project

Each vendored project has its own conventions, build system, and (where present) its own `CLAUDE.md`/`AGENTS.md` — read those before making changes inside that directory; do not assume root-level conventions apply inside them.

- **`relaticle/`** — Laravel app. Has a detailed `relaticle/CLAUDE.md` (architecture: modular monolith, `app/` = CRM core, `packages/<Name>/` = self-contained subsystems like `Chat`, `SystemAdmin`, `ImportWizard`). Key commands (run from inside `relaticle/`):
  - `composer run dev` — run app + queue worker + logs + vite concurrently
  - `npm run dev` / `npm run build` — frontend assets (Vite)
  - `composer run test` — full check: pint (style), rector (refactor lint), phpstan (types + 100% type coverage), pest
  - `vendor/bin/pest --filter=<name>` — run a single test
  - Pre-commit order matters: `vendor/bin/pint --dirty --format agent` → `vendor/bin/rector --dry-run` → `vendor/bin/phpstan analyse` → `composer test:type-coverage` → `php artisan test --compact`

- **`crm/`** — Frappe app (Python backend in `crm/`, Vue 3 + frappe-ui frontend in `frontend/`). Has `crm/AGENTS.md` with a map of the Form Scripting engine and field-rendering system. Key commands (frontend, from `crm/frontend/`):
  - `yarn dev` — Vite dev server
  - `yarn build` — production build
  - `yarn test:run` — run the Vitest unit suite once (`yarn test` for watch mode); tests live in `frontend/tests/unit/` and only cover pure utility functions
  - The Python side is a standard Frappe app (`crm/pyproject.toml`) and expects to be installed into a Frappe bench (see below) — it is not run standalone.

- **`erpnext/`** and **`frappe/`** — `erpnext` is a Frappe *app*; `frappe` is the *framework* it (and `crm`) run on. Both are meant to be installed together inside a **Frappe bench**. Do not expect `erpnext/`/`frappe/` to build or run standalone outside that bench.

## The Frappe bench (`infra/frappe_bench/`)

A Docker Compose bench now runs `erpnext` + `crm` on top of the vendored `frappe`, without ever modifying any of the three vendored trees:

- `docker compose -f infra/frappe_bench/docker-compose.yml up -d` — starts MariaDB, two Redis instances (cache/queue), and the `bench` container (auto-bootstraps on first run via `scripts/entrypoint.sh` → `scripts/bootstrap.sh` → `scripts/start.sh`).
- **Three compose files, and they compose.** `docker-compose.yml` is the development bench. `docker-compose.pilot.yml` adds the production process model (gunicorn via `scripts/web.sh` and `procfiles/Procfile.pilot`, no asset watcher, `restart: always`) and `KORKEM_ENV=pilot`. `docker-compose.public.yml` adds Caddy with auto-TLS, choosing `proxy/webhooks.Caddyfile` (default) or `proxy/app.Caddyfile` via `KORKEM_PROXY_PROFILE`. Deployment is documented in `docs/operations/`, and `scripts/deploy_pilot.sh` runs it with the checks.
- **`KORKEM_ENV` (`development` | `pilot` | `production`) decides everything environmental** — developer mode, `allow_tests`, the scheduler, which Procfile — and is written into the site config as `korkem_env`. `korkem_ai.korkem_ai.environment` is the one place that reads it; every destructive fixture in `seed_demo` calls `require_non_production` first, and an unlabelled non-developer site is treated as production. Do not add a second way to ask what environment a site is.
- **The startup scripts are mounted, not baked into the image.** Editing `entrypoint.sh` used to need an image rebuild and silently did not get one, so bootstrap would configure a pilot and the container would then start the development server.
- **`/health` and `/health/ready`** are served by `korkem_ai.korkem_ai.health.HealthPage` through Frappe's `page_renderer` hook — no proxy needed. Frappe 17 resolves an HTTP request to a site **by its `Host` header only** (`default_site` is CLI-only), so the container healthcheck and `deploy_pilot.sh` send `Host: $SITE_NAME`; without it a healthy bench answers "localhost does not exist".
- **A pilot serves through `korkem_ai.wsgi:application`**, not `frappe.app:application`: it adds the static-file middleware (the proxy container cannot read the bench's disk) and `ProxyFix` (without which `request.scheme` is `http` behind TLS, so Frappe issues the session cookie **without `Secure`**).
- Site: `korkem.localhost`, reachable at `http://korkem.localhost:8000` once the stack is up (`.localhost` resolves to loopback automatically, no `/etc/hosts` edit needed). Admin login: `Administrator` / the password set in `infra/frappe_bench/.env` (gitignored; copy from `.env.example`).
- `frappe` is exposed to the bench via a **real local git clone** from the vendored `frappe/` directory (zero network — `bench init --frappe-path`). `crm` is exposed via **`bench get-app --soft-link`** (a filesystem symlink, zero git operations). `erpnext` is also a **real local clone**, not a symlink — its `banking/` sub-frontend resolves paths via `import.meta.url`, which Node/Vite resolve to a symlink's real target rather than its bench-tree location, breaking `common_site_config.json` path resolution under `--soft-link`; a real clone avoids this without touching vendored source.
- `bench build` (part of bootstrap) writes compiled assets into `erpnext/public/dist`, `crm/crm/public/frontend`, etc. — already gitignored paths in each vendored repo. Occasionally a build step also touches a tracked file incidentally (observed once: `crm/frontend/auto-imports.d.ts` and `crm/yarn.lock`, both benign build-tool regenerations) — check `git -C <repo> status` after any bench rebuild and revert anything unexpected; the vendored repos must stay pristine.
- **`webserver_host` must be set** (`bench set-config -g webserver_host 127.0.0.1`, done in
  `bootstrap.sh`). Without it, Frappe's socket.io process derives the URL it calls the web
  server back on from the **client's own `Origin` header**
  (`frappe/realtime/utils.js:get_url`). A browser on the host sends `korkem.localhost`, which
  the container can resolve, so everything looks fine — but an Android emulator sends
  `10.0.2.2`, which means nothing inside the container, and every socket connection is refused
  as `Unauthorized: TypeError: fetch failed`. HTTP keeps working throughout, so the symptom is
  "the app signs in and then the assistant never answers". The client cannot work around it:
  the same middleware requires the `Origin` hostname to match the `Host` it dialled.
- Full setup details, every command tried, and the specific failures/fixes encountered getting here: `docs/archive/sprint1/sprint_1_phase_a_checklist.md`.

## The Flutter mobile app (`mobile/korkem_flow/`)

Flutter 3.44.8 / Dart 3.12.2, installed at `~/development/flutter` (PATH set in `~/.bashrc`).
Commands, all run from `mobile/korkem_flow/`:

- `flutter pub get` — resolve dependencies
- `flutter analyze` — static analysis; must report **No issues found** (very_good_analysis, strict-casts/inference/raw-types)
- `dart format --set-exit-if-changed lib test` — formatting gate
- `flutter test` — unit + widget suite
- `flutter test test/path/to/file.dart --plain-name "<name>"` — a single test

**Design system lives in `lib/core/design/`** — `tokens/` (colors, typography, dimensions, motion,
icons) and `widgets/` (the shared component library). **No literal colour, spacing, radius or
duration may appear in a widget file**; that rule is what keeps the system intact. Status colours
are delivered through the `StatusColors` theme extension (`context.statusColors`), not by importing
tokens and branching on brightness.

Inter is **bundled** at `assets/fonts/` and verified to cover Kazakh — see `THIRD_PARTY_LICENSES.md`
before swapping it. Icons come from `material_symbols_icons` through the semantic `AppIcons`
vocabulary; do not add a second icon set.

Localisation is `gen-l10n` with `ru`/`kk`/`en` in `lib/l10n/`; generated files land in `lib/l10n/`
and are committed.

**No code generation.** `freezed`/`json_serializable`/`riverpod_generator` are deliberately absent:
`riverpod_generator` 4.0.6 has an unresolvable constraint (`analyzer ^13` vs `riverpod_analyzer_utils`
on `^12`), and the DTO layer is small enough that explicit `fromJson` is clearer than a build step.
There is no `build_runner` stage — do not add one without re-checking those constraints.

**Android and Linux desktop both build.** Android SDK 36 and the Linux toolchain are installed;
`flutter doctor` is green except for Chrome (web is not a target).

```sh
flutter build apk --release --split-per-abi   # side-loading
flutter build appbundle --release             # Google Play — see docs/operations/play_release.md
```

Release builds are minified. `android/app/proguard-rules.pro` keeps the Flutter engine and the
secure-storage keystore bridge (both reached by reflection) and silences Play Core, which
Flutter's deferred-components support references but this app does not bundle — without those
rules the R8 pass fails outright. Signing reads the gitignored `android/key.properties`; an
app-bundle build without one fails deliberately rather than producing a debug-signed artefact
that Play would reject at upload.

The launcher icon is generated, not hand-drawn — `AppLogo` rendered to PNG by a tagged test:

```sh
flutter test test/tools/generate_app_icon_test.dart --update-goldens --tags tools
dart run flutter_launcher_icons && dart run flutter_native_splash:create
```

The `tools` tag is skipped by default; a plain `flutter test --update-goldens` would otherwise
rewrite the launcher assets.

### Running against the local bench

The app **runs on Android** and signs in end-to-end against the Docker bench. Two things are
needed, and neither is the app's fault when missing.

`korkem.localhost` — the compiled-in default — is meaningless inside an emulator, where it
resolves to the *guest's* own loopback. The host is `10.0.2.2`. The server is a runtime field,
so this is a launch flag, not a source change:

```sh
flutter run -d emulator-5554 --dart-define=KORKEM_BASE_URL=http://10.0.2.2:8000
```

Cleartext HTTP is blocked by default at `targetSdk 36`, and the bench serves plain HTTP.
`android/app/src/debug/` carries a manifest and `network_security_config.xml` that permit
cleartext **to the loopback hosts only**, merged into debug builds and never into a release
one — `docs/operations/privacy_policy.md` promises users that Android blocks unencrypted HTTP, and that
has to stay true of what ships.

### The emulator

KVM group membership is required (`sudo usermod -aG kvm $USER`, then re-login); without it the
emulator falls back to software emulation and never finishes booting. Missing userspace
libraries were resolved without root by extracting them under `~/.local/emulator-libs`, so
they must be on the path:

```sh
E=~/Android/Sdk/emulator; L=~/.local/emulator-libs/usr/lib/x86_64-linux-gnu
LD_LIBRARY_PATH="$E/lib64:$E/lib64/qt/lib:$L:$L/pulseaudio" \
  $E/emulator -avd korkem_test -no-audio -no-boot-anim -memory 1536 -gpu swiftshader_indirect
```

**The bench and the emulator compete for the WSL VM's budget, not the laptop's.** The
machine is an ASUS TUF Gaming A16 FA607NUQ — Ryzen 7 170 (8 cores / 16 threads), **16 GB**
DDR5-5600 (a single stick, so single-channel), RTX 4050 Laptop 4 GB plus the Radeon iGPU,
two 512 GB NVMe drives. The 7.4 GB that earlier notes called "this machine's RAM" was only
what `%USERPROFILE%\.wslconfig` granted the VM. **The host also runs Adobe Premiere Pro,
Photoshop, and After Effects**, so that budget is contested: with nothing Adobe open the host
already sits at ~2.4 GB free. WSL and Adobe cannot both be greedy on 16 GB, so the config is
profile-switched by `~/.local/bin/wsl-profile` (2026-08-18): `adobe` = 4 GB / 4 CPUs (the
default, leaves Windows ~11 GB), `dev` = 10 GB / 8 CPUs for bench + emulator work. Both carry
`swap=12GB` on `D:` (OOM protection, not a RAM substitute), `autoMemoryReclaim=gradual`
(without it WSL never hands a peak allocation back to Windows), and `sparseVhd=true`. Switching
profiles needs `wsl.exe --shutdown` to take effect. Do not run the bench and Premiere at the
same time — no setting makes that fit. Always read the budget with `free -h` **inside WSL** —
Windows Task Manager shows the host, which is a different number. Booting the emulator at its default RAM killed all four bench containers
(exit 255, simultaneously) — and the app then reports "No connection to the server", which
reads like an app bug and is not one. Hence `-memory 1536`, and: stop the Gradle daemon
(`android/gradlew --stop`, ~1 GB), start the bench *first* and wait for `/api/method/ping`,
then boot the emulator. To skip
Gradle entirely on a re-run, install the built APK directly:

```sh
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n kz.korkem.korkem_flow/.MainActivity
```

Two behaviours worth knowing before changing code here:
- Riverpod 3 **auto-retries** a failed provider with backoff, so a failing provider sits in
  `AsyncLoading(retrying)` and never settles into `AsyncError`. Tests pass `retry: (_, _) => null`.
- Riverpod 3 removed `AsyncValue.valueOrNull`; the nullable getter is `AsyncValue.value`.
- **`signIn` must never publish `AsyncValue.loading()`.** The router redirects a loading
  session to the splash, which disposes whatever screen is mounted; a login screen torn down
  mid-request loses the error it was about to show, so every failure — wrong password, dead
  network — appeared as a spinner and then an empty form. Sign-in progress is screen state.
  Pinned by a regression test that asserts on the *emitted* state sequence.

## Conventions for new custom code

Both custom apps are standard Frappe apps and are tested through the bench (see `korkem-bench`). There is **no CI yet** — that is the first item in `ROADMAP.md` Horizon 0, and until it exists a change is only as verified as the commands you actually ran and pasted.

**Where new code goes** is decided by `PLAN.md` and enforced by the `korkem-architecture` skill: business rules in `korkem_manufacturing`, a whitelisted endpoint over them, an AI tool as a thin wrapper, and the UI calling the endpoint. A pull request that adds a `ToolSpec` and no domain service is going the wrong way.
