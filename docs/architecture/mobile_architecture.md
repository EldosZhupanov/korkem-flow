# KORKEM Flow Mobile — Technical Architecture

> Companion documents: [`backend_api_audit.md`](./backend_api_audit.md) (verified backend facts),
> [`design_system.md`](./design_system.md), [`mobile_app_structure.md`](./mobile_app_structure.md),
> [`api_mapping.md`](./api_mapping.md), [`flutter_project_plan.md`](./flutter_project_plan.md).
>
> **Backend is read-only for this project.** No endpoint in this document is invented — every one is
> traced to the audit. Where a screen needs something that does not exist, it is listed as a gap, not
> designed around.

## 1. Guiding constraints

Four facts from the audit shape everything below:

1. **Header auth, never cookies.** Cookie sessions trigger CSRF rejection on every write
   (`400 CSRFTokenError`, reproduced live). OAuth2 + PKCE is the only production-grade option.
2. **The custom API surface is three methods.** The app is overwhelmingly a *generic Frappe REST
   client*, not a client of a bespoke mobile BFF. The data layer must therefore be excellent at the
   generic case: typed access to arbitrary doctypes with fields/filters/pagination.
3. **Manufacturing has no custom doctypes.** Production screens talk to native ERPNext `Work Order`,
   `BOM`, `Item`, `Stock Entry`.
4. **`CRM Task.name` is an integer** (`Autoincrement`). Ids are not uniformly `String`.

## 2. Stack — and why each choice

Versions are the current pub.dev latest, checked 2026-07-27.

| Concern | Choice | Version | Why this, not the alternative |
|---|---|---|---|
| Framework | Flutter stable | 3.44.8 | Installed and verified. Dart 3.12.2. |
| State + DI | `flutter_riverpod` + `riverpod_generator` | 3.4.1 / 4.0.6 | One tool for both. Compile-time safe, testable without `BuildContext`, trivial provider overrides in tests. Replaces a separate DI container (get_it) — a second DI system would duplicate the object graph. |
| Routing | `go_router` | 17.3.0 | Declarative, typed routes, deep links, and `redirect` — which is where auth and **role** gating belongs (§8). |
| HTTP | `dio` | 5.11.0 | Interceptor pipeline is the requirement: silent token refresh, retry, offline short-circuit, logging. `http` has no interceptors. |
| Models | `freezed` + `json_serializable` | 3.2.5 / 6.14.0 | Immutable models, value equality, and **sealed unions** — the natural encoding for `AsyncValue`-style domain results and error taxonomies (§11). |
| Local DB | `drift` | 2.34.2 | **Not Hive.** ERP lists are filtered, sorted, joined and paginated. Drift is typed SQL over SQLite with reactive queries; Hive is a key-value store that would force in-memory filtering of unbounded lists. |
| Secrets | `flutter_secure_storage` | 10.3.1 | Keychain / EncryptedSharedPreferences. Refresh tokens never touch Drive or SharedPreferences. |
| Theming | `flex_color_scheme` | 8.4.0 | Generates a complete, consistent M3 `ColorScheme` from seed colours, including the surface-tint ramp that hand-rolled schemes get wrong. |
| Fonts | `google_fonts` | 8.2.0 | Bundled at build time (not fetched at runtime — see §16). |
| Connectivity | `connectivity_plus` | 7.3.1 | Drives the offline banner and the write queue's drain trigger. |
| Images | `cached_network_image` | 3.4.1 | Frappe file URLs are stable and auth-gated; disk caching avoids re-download. |
| Logging | `talker_flutter` | 5.1.19 | **Not bare `logger`.** Ships a Dio interceptor and an in-app log viewer — decisive for diagnosing a shop-floor device you cannot attach a debugger to. |
| i18n | `intl` + `flutter_localizations` | 0.20.3 | ARB + `gen-l10n`, the official path. |
| Lints | `very_good_analysis` | 10.3.0 | Strictest maintained public ruleset. |
| Diagnostics | `package_info_plus`, `device_info_plus` | latest | Version and device context attached to every crash report. |
| Animation | `lottie` | latest | See §14 — Rive deliberately excluded. |

### Deliberate exclusions

You listed these; here is why each is left out. Omitting them is a decision, not an oversight.

- **`flutter_hooks`** — Riverpod 3's `Notifier`/`AsyncNotifier` plus generated providers already cover
  local state and lifecycle. Adding hooks introduces a *second* idiom for the same problem; on a team,
  that reliably produces two incompatible house styles in the same codebase. Excluded for consistency,
  not capability.
- **`hive`** — superseded by Drift for the reasons above. Using both would split the cache across two
  engines with two invalidation stories.
- **`rive`** — overlaps Lottie. Rive earns its place only when animation must be *interactive*
  (state-machine driven by user input). Nothing in the designed screens requires that. Revisit if an
  interactive onboarding is added.
- **Very Good CLI** — useful **once**, to bootstrap flavors, `l10n` wiring and CI templates. It is a
  scaffolding tool, not a dependency; it must not appear in `pubspec.yaml`.

## 3. Architectural shape

**Feature-first, with a shared core.** Layers exist *inside* a feature, not above it — so a feature is
deletable in one `rm -rf` and reviewable in one directory.

```
Presentation  (widgets, screens)          — no I/O, no business rules
    ↓ ref.watch
Controllers   (Riverpod Notifiers)        — orchestration, UI state
    ↓
Repositories  (feature-owned)             — domain contracts, caching policy
    ↓
Data sources  (remote: FrappeClient  |  local: Drift DAO)
```

Strict rules:

- Widgets never import `dio`, `drift`, or a DTO.
- Repositories return **domain models**, never DTOs.
- Controllers never construct a repository — they resolve it via a provider.
- The domain layer imports nothing from Flutter.

Clean Architecture is applied *where it pays*: a repository boundary and a DTO↔domain boundary. There
are no `UseCase` classes — for a CRUD-shaped ERP client they would be one-line pass-throughs, which is
ceremony, not architecture. A use-case is introduced only when logic spans two repositories.

## 4. Folder structure

```
lib/
├── main.dart                       # thin: runs bootstrap()
├── bootstrap.dart                  # DI overrides, error zone, logging init
├── app.dart                        # MaterialApp.router + theme + l10n
│
├── core/
│   ├── api/
│   │   ├── frappe_client.dart      # Dio wrapper: resource/method/doc_method
│   │   ├── frappe_query.dart       # typed fields/filters/order_by/pagination
│   │   ├── interceptors/
│   │   │   ├── auth_interceptor.dart      # Bearer + single-flight refresh
│   │   │   ├── retry_interceptor.dart
│   │   │   ├── offline_interceptor.dart
│   │   │   └── talker_interceptor.dart
│   │   └── exceptions.dart          # FrappeException taxonomy
│   ├── auth/                        # OAuth2+PKCE, token store, session controller
│   ├── db/                          # Drift database, DAOs, migrations
│   ├── sync/                        # outbox queue, conflict policy
│   ├── permissions/                 # role model + capability resolution
│   ├── error/                       # AppFailure, error mapper, reporter
│   ├── logging/
│   ├── router/                      # GoRouter, guards, route names
│   ├── theme/                       # see design_system.md
│   ├── l10n/
│   └── widgets/                     # shared primitives ONLY (see §5)
│
├── features/
│   ├── auth/            {presentation, application, data, domain}
│   ├── dashboard/
│   ├── crm/             # leads, deals, organizations
│   ├── production/      # work orders, BOM
│   ├── tasks/           # CRM Task — shop-floor + sales tasks
│   ├── warehouse/       # items, stock, warehouses
│   ├── approvals/       # Pending Action — the AI approval gate
│   ├── conversations/   # Agent Conversation + messages
│   ├── notifications/
│   └── settings/
│
└── l10n/                # .arb files
```

Each feature directory:

```
features/production/
├── data/
│   ├── dto/work_order_dto.dart          # @freezed + @JsonSerializable
│   ├── work_order_remote_source.dart
│   ├── work_order_local_source.dart
│   └── work_order_repository_impl.dart
├── domain/
│   ├── work_order.dart                  # domain model
│   └── work_order_repository.dart       # abstract contract
├── application/
│   └── work_order_controller.dart       # AsyncNotifier
└── presentation/
    ├── work_order_list_screen.dart
    ├── work_order_detail_screen.dart
    └── widgets/
```

**`core/widgets/` admission rule:** a widget moves there only when used by **three or more** features.
Below that it stays feature-local. Without this rule `core/widgets` becomes a dumping ground.

## 5. Data layer

### The generic client is the product

Because the backend exposes almost no custom endpoints (audit §3), `FrappeClient` is the most
important class in the codebase. It offers exactly four operations:

| Method | Maps to |
|---|---|
| `getList<T>(doctype, query)` | `GET /api/resource/{doctype}` |
| `getDoc<T>(doctype, name)` | `GET /api/resource/{doctype}/{name}` |
| `callMethod<T>(path, params)` | `GET/POST /api/method/{path}` |
| `runDocMethod<T>(dt, dn, method)` | `POST /api/method/run_doc_method` |

`FrappeQuery` is a typed builder producing Frappe's exact wire format — `fields` as a JSON array
string, `filters` as a JSON array of `[fieldname, operator, value]`, plus `limit_page_length`,
`limit_start`, `order_by`. Hand-built query strings are forbidden; they are how field-name typos reach
production.

### DTO ↔ domain separation

DTOs mirror the wire format exactly, including Frappe's quirks (`0`/`1` for booleans, `"docstatus"` as
int, `name` as `dynamic` because **`CRM Task.name` is an int while others are strings**). Domain models
are clean Dart. The mapper is the only place that knows about the quirks.

Concretely, the `docstatus` int becomes a domain enum:

| `docstatus` | Domain |
|---|---|
| `0` | `DocStatus.draft` |
| `1` | `DocStatus.submitted` |
| `2` | `DocStatus.cancelled` |

This matters: a Work Order is only real when `docstatus == 1`, and the UI must never let a user act on
a draft as though it were live.

### Repository contract

```
Future<Result<T>>            // never throws; failures are values
Stream<T>                    // Drift-backed, emits on local change
```

Repositories own the caching policy, not the controllers.

## 6. Offline strategy

Two directions, deliberately asymmetric — reads and writes have different risk profiles.

### Reads — stale-while-revalidate

1. Emit cached rows from Drift immediately (screen renders with data, no spinner).
2. Fire the network request.
3. On success, upsert into Drift; the reactive query pushes the update to the UI.
4. On failure, keep showing cache **with a visible staleness indicator** (§ design system).

Cache freshness is per-entity, stored as `fetched_at`. Lists are cached per *query signature* so a
filtered list does not poison the unfiltered cache.

### Writes — explicit outbox, never silent

Writes go to an `outbox` table first, then drain when connectivity returns.

**Only these operations are queueable offline:**

| Operation | Rationale |
|---|---|
| `complete_task` | The shop floor genuinely loses signal; this is the core offline use case. |
| Note/comment creation | Append-only, conflict-free. |

**Explicitly NOT queueable:** `Pending Action.approve`/`reject`, Work Order submission, stock
movements. These have financial or material consequences and re-validate server-side at execution
time (`approve()` re-checks the target still exists). Queuing them would let a user approve something
that has since changed. Offline, these actions are **disabled with an explanation**, not queued.

This is a product decision as much as a technical one, and it is the safe default.

### Conflict policy

Last-write-wins is unacceptable for an ERP. On `409`/version mismatch the outbox entry moves to
`conflict` state and surfaces in a **Sync Issues** screen for human resolution. Silent data loss is
never acceptable.

## 7. Authentication

**OAuth2 Authorization Code + PKCE (S256)**, using Frappe's provider (audit §1).

```
1. App generates code_verifier + S256 challenge
2. Opens system browser (ASWebAuthenticationSession / Custom Tabs) → authorize endpoint
3. Redirect to korkemflow://auth-callback?code=…
4. POST get_token  { code, code_verifier, client_id }  → access + refresh token
5. access_token → memory;  refresh_token → flutter_secure_storage
6. openid_profile → user identity;  roles → capability set (§8)
```

Non-negotiables:

- **System browser, never an in-app WebView.** A WebView lets the app observe credentials, which
  breaks the trust model and violates RFC 8252 (OAuth for Native Apps).
- **Refresh is single-flight.** Concurrent 401s must await one refresh, not fire N. This is the most
  common source of refresh-token invalidation in production apps.
- Access token in memory only. Refresh token in secure storage. Neither is ever logged (§11).
- On refresh failure → clear session, route to login, preserve the attempted deep link.

> **Blocked on G1**: no `OAuth Client` record exists yet. Until you approve creating one with redirect
> URI `korkemflow://auth-callback`, login cannot be implemented. There is no workaround that does not
> modify the backend.

## 8. Permissions and roles

Roles come from the session profile and map to the **real** backend roles verified in audit §5 —
`Shop Floor User`, `Manufacturing User`, `Stock User`, `Sales User`, `Customer`, `System Manager`.
Never invent role names.

The app resolves roles into a **capability set** once, at session start:

```
Capability.viewProduction, Capability.completeTask,
Capability.approveAiAction, Capability.viewStock, …
```

UI gates on capabilities, not role strings — so a permission change is one mapping edit, not a
codebase-wide grep.

**The client gate is UX, not security.** The server is the authority; ERPNext enforces permissions on
every request. Client gating exists to avoid showing a user actions that will fail. Both layers are
required: server-only means ugly errors, client-only means a trivially bypassed app.

> **Unverified (audit §8):** all probing ran as `Administrator`, which bypasses permission checks.
> Per-role visibility must be tested with real role-holding users before the gating in
> `mobile_app_structure.md` is trusted.

## 9. Navigation

`go_router` with a `StatefulShellRoute` for bottom-nav tabs, so each tab keeps its own navigation
stack and scroll position across switches.

Guards live in one `redirect`:

1. Unauthenticated + protected route → `/login`, remembering the target.
2. Authenticated + `/login` → role home.
3. Lacking capability → `/not-authorized` (never a blank screen).

Deep links (`korkemflow://work-order/{name}`) resolve after auth, so a notification tap survives a
cold start on a logged-out app.

## 10. State management

| Kind | Tool |
|---|---|
| Server state | `AsyncNotifier` + repository, exposed as `AsyncValue` |
| Local UI state | `Notifier` |
| Derived | computed providers (no manual caching) |
| One-shot events | explicit callbacks, never state flags |

`AsyncValue` is the single source of loading/error/data — this is what makes the loading, empty and
error states in `mobile_app_structure.md` uniform rather than per-screen improvisation.

Providers use `autoDispose` by default; only session and connectivity are kept alive.

## 11. Error handling and logging

### Taxonomy

Frappe returns errors as HTTP status plus a `_server_messages` JSON blob. The mapper normalises:

| Wire | Domain failure | UI |
|---|---|---|
| 401 | `AuthFailure` | silent refresh, then re-login |
| 403 | `PermissionFailure` | "You don't have access" |
| 404 | `NotFoundFailure` | empty state |
| 409 | `ConflictFailure` | sync-issue flow (§6) |
| 417 + `_server_messages` | `ValidationFailure(message)` | inline field/form error — this carries the *human* message ERPNext intends |
| timeout / socket | `NetworkFailure` | offline banner + retry |
| 5xx | `ServerFailure` | "Something went wrong" + report |

Parsing `_server_messages` properly is what separates a professional Frappe client from one that shows
raw JSON to a factory worker.

### Logging

`talker_flutter`, with a **redaction layer** applied before any sink: `Authorization` headers,
`api_secret`, tokens and passwords are stripped. Debug builds log verbosely to console and the in-app
viewer; release builds keep a rolling in-memory buffer attached to crash reports only.

No PII in logs. No request bodies containing customer contact data.

## 12. Testing

| Layer | Tool | What is actually asserted |
|---|---|---|
| Domain/mappers | `test` | DTO↔domain round-trip, including the int-vs-string `name` and `docstatus` mapping |
| Repositories | `mocktail` | cache-hit/miss, offline fallback, outbox enqueue and drain |
| Controllers | `ProviderContainer` overrides | state transitions incl. failure paths |
| Widgets | `flutter_test` | loading/empty/error/data for every list screen |
| Golden | `alchemist` | design-system components, light + dark |
| E2E | `integration_test` | login → task list → complete task |

Contract tests pin the **exact Frappe wire shapes** captured in the audit, so an upstream change breaks
a fast test rather than a production screen.

Coverage is a diagnostic, not a target. The mapper and permission layers are the ones that must be
near-total — they fail silently, which is the worst failure mode.

## 13. Caching

| Data | Store | Invalidation |
|---|---|---|
| Session/tokens | secure storage | logout, refresh failure |
| Lists | Drift, per query signature | TTL + pull-to-refresh |
| Documents | Drift | on write, on realtime event |
| Images | `cached_network_image` | LRU, disk |
| Masters (statuses, warehouses) | Drift | long TTL, refresh on app start |

## 14. Motion

`AnimatedSwitcher`/`Hero`/implicit animations for the ordinary cases; Lottie only for empty states and
success confirmations. Durations and curves are defined once in the design system, never inline.

All motion respects `MediaQuery.disableAnimations` (§ accessibility). An animation that cannot be
turned off is an accessibility defect.

## 15. Responsive layout

Phone-first. Breakpoints: `< 600` compact, `600–1024` medium (tablet: list-detail), `> 1024` expanded.
Navigation adapts `NavigationBar` → `NavigationRail`. Layout is driven by available width, never by
`Platform.isX`.

## 16. Security

- OAuth2 + PKCE; no password ever stored or handled by the app.
- Refresh token in Keychain/Keystore; access token memory-only.
- **Certificate pinning** on the Dio adapter for production hosts.
- `flutter_secure_storage` with `encryptedSharedPreferences: true` on Android.
- Screenshot suppression (`FLAG_SECURE`) on screens showing costs/margins.
- Fonts **bundled at build time** — `google_fonts` runtime fetching is disabled, since it is a network
  dependency on a third-party host at render time.
- No secrets in the repo; config injected via `--dart-define-from-file`.
- Jailbreak/root detection is *not* included — it is trivially bypassed and gives false assurance.

## 17. CI/CD

GitHub Actions:

| Stage | Gate |
|---|---|
| `analyze` | `dart analyze --fatal-infos` + `dart format --set-exit-if-changed` |
| `test` | unit + widget + golden, coverage uploaded |
| `build` | Android AAB, iOS IPA (`--dart-define-from-file`) |
| `distribute` | Firebase App Distribution → TestFlight/Play internal |

Flavors `dev` / `staging` / `prod` with separate bundle ids, so all three install side by side on one
device. Version from a single source; build number from the CI run number. Release builds are signed
via CI secrets, never from a developer machine.

## 18. Open decisions requiring your input

1. **G1 — OAuth Client** must be created before auth can be built. Blocking.
2. **G2 — push relay** disabled; without it, notifications degrade to poll-on-foreground.
3. **G3–G6** — dashboard aggregation, "my tasks", Work Order composite, and search would each be one
   custom endpoint. Without them these screens are chatty (multiple round-trips). I have designed
   around their absence; adding them is a backend change needing your approval.
4. **iOS build capability** — this machine is WSL2 Linux. Android and tests run here; iOS requires
   macOS CI or a Mac.
