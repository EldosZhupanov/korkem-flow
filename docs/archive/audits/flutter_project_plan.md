> **АРХИВ. Это не описание системы сегодня.**
> Документ сохранён ради причин, стоящих за решениями. Актуальное состояние — в `NOW.md`, `ROADMAP.md`, `PLAN.md`.
> Не строить по этому файлу.

---

# KORKEM Flow Mobile — Development Plan

> Phases are ordered by dependency and by **risk retired per phase**. Each ends in something
> demonstrable on a real device. No phase is "just plumbing" with nothing to show.
>
> Estimates assume one experienced Flutter engineer. They are ranges, not commitments.

## Phase 0 — Unblock (before any Flutter work)

**Not a development phase.** These are decisions only you can make.

| # | Item | Type | Blocks |
|---|---|---|---|
| 1 | Create `OAuth Client`, redirect `korkemflow://auth-callback` (**G1**) | Backend config | Phase 2 onward |
| 2 | Confirm app identity: bundle id, display name, brand assets | Product | Phase 1 |
| 3 | Confirm target platforms (Android-only v1, or iOS too) | Product | CI, Phase 1 |
| 4 | Provide staging backend URL, or confirm dev-only | Infra | Phase 1 |
| 5 | Decide on G3–G6 custom endpoints | Backend code | Phases 4, 6, 10 |

**iOS constraint:** this machine is WSL2 Linux. Android builds and the full test suite run here; iOS
requires macOS CI or a Mac. If iOS is in scope, that must be arranged before Phase 1 closes.

---

## Phase 1 — Bootstrap

**Goal:** a running, themed, linted, CI-verified app shell.

**Files:** `pubspec.yaml` · `analysis_options.yaml` · `main.dart` · `bootstrap.dart` · `app.dart` ·
`core/theme/*` (tokens + light/dark builders) · `core/logging/*` · `core/l10n/*` · `l10n/*.arb` ·
flavor configs · `.github/workflows/ci.yaml`

**Tests:** theme resolves in both modes · golden tests for typography and colour tokens · CI runs
analyze + test + build on every PR.

**Acceptance:**
- App launches on Android showing a themed placeholder in light **and** dark.
- `dart analyze --fatal-infos` and `dart format --set-exit-if-changed` pass.
- Three flavors install side by side.
- No literal colour/spacing/radius value in any widget (lint-enforced).

**Risks:** design-token drift if Phase 2 starts before tokens are locked — *mitigate by treating
`core/theme` as frozen after this phase, changed only via review.*

---

## Phase 2 — Authentication ⚠️ depends on G1

**Goal:** real OAuth2 + PKCE login against the live backend.

**Files:** `core/auth/{oauth_service, pkce, token_store, session_controller, auth_repository}.dart` ·
`core/api/{frappe_client, frappe_query, exceptions}.dart` ·
`core/api/interceptors/{auth, retry, offline, talker}.dart` · `features/auth/**`

**Tests:** PKCE challenge correctness (S256 vectors) · token store round-trip · **single-flight
refresh under concurrent 401s** · expiry → refresh → retry · refresh failure → session cleared ·
redaction: no token ever reaches a log sink.

**Acceptance:**
- Login via **system browser** (not WebView) against `korkem.localhost`.
- Access token in memory; refresh token in Keychain/Keystore.
- Ten concurrent 401s trigger **exactly one** refresh.
- Killing and reopening the app restores the session.
- Sign out revokes server-side and wipes local state.

**Risks:**
- *Single-flight refresh is the classic production bug* — concurrent refreshes invalidate each other
  and log everyone out. Explicitly tested above.
- Deep-link scheme collisions — verify on a device with both flavors installed.
- **Hard blocker:** without G1 this phase cannot start.

---

## Phase 3 — Navigation and permissions

**Goal:** role-aware shell; each persona lands somewhere correct.

**Files:** `core/router/{app_router, routes, guards}.dart` ·
`core/permissions/{role, capability, capability_resolver}.dart` · role shell scaffolds ·
`features/settings/**` · Not-Authorized screen

**Tests:** guard matrix — every (role × route) combination · deep link while logged out preserves
target · capability resolution for all seven personas · tab state survives switching.

**Acceptance:**
- Each of the seven roles sees the tab set from `mobile_app_structure.md` §2.
- Unauthorized route → Not-Authorized screen, never blank.
- Deep link on cold start resolves after login.
- Each tab keeps its own stack and scroll position.

**Risks:** role→capability mapping is **unverified against real permissions** (audit §8) — *mitigate by
testing with real role-holding users this phase, not at the end.*

---

## Phase 4 — Worker: My Tasks (first vertical slice)

**Goal:** the highest-value screen, end to end, offline-capable.

Deliberately before dashboards: it exercises the full stack (auth → REST → Drift → outbox → custom
endpoint) on the smallest surface, and is the screen with the most daily users.

**Files:** `core/db/**` (Drift, DAOs, migrations) · `core/sync/{outbox, drain_service}.dart` ·
`features/tasks/**` · shared list/empty/error/skeleton widgets

**Tests:** DTO↔domain incl. **integer `name`** · stale-while-revalidate · outbox enqueue → drain →
clear · drain failure → retry with backoff · conflict → Sync Issues · widget tests for all five
states · integration: login → list → complete → verify server-side.

**Acceptance:**
- Task list renders from cache instantly, then refreshes.
- Complete works online **and** offline, draining on reconnect.
- `complete_task` sends `task` as an **integer**.
- Airplane-mode → complete → reconnect → server reflects it.
- Zero layout shift between skeleton and loaded state.

**Risks:**
- *Sending `task` as a String fails at Frappe's runtime type check* — pinned by a contract test.
- Outbox double-submission on drain — idempotency guard per entry.
- Drift migrations are hard to reverse — migration tests from v1 onward.

---

## Phase 5 — CRM

**Goal:** deals, leads, organizations, conversations.

**Files:** `features/crm/**` · `features/conversations/**` · shared filter/search sheets

**Tests:** pagination (`limit_start`) incl. last-page boundary · filter/sort round-trip ·
**contact-write path for `mobile_no`** · conversation ordering.

**Acceptance:**
- Infinite scroll with no duplicates or gaps.
- Phone edits go through the `contacts` child table and **persist** (direct `mobile_no` writes are
  discarded — audit §4).
- Conversations render chat-shaped with correct sender attribution.

**Risks:** *the derived `mobile_no` trap silently discards writes* — a test asserts the value survives
a round-trip. Outbound WhatsApp is out of scope (no endpoint).

---

## Phase 6 — Production and Warehouse

**Goal:** work orders, BOM, materials, items, stock (read).

**Files:** `features/production/**` · `features/warehouse/**`

**Tests:** `docstatus` → `DocStatus` mapping · draft Work Orders expose **no** live actions · BOM
explosion rendering · stock aggregation by warehouse.

**Acceptance:**
- Work Order detail shows overview, materials, tasks, timeline.
- Draft vs submitted is visually unambiguous and gates actions.
- Stock balances match ERPNext for a spot-checked item.

**Risks:** *treating a draft as live is a real-world error with material cost* — enforced in the
mapper, not the widget, and covered by tests.

---

## Phase 7 — Approvals (AI gate)

**Goal:** the product-defining screen.

**Files:** `features/approvals/**`

**Tests:** `display_data` **string→JSON** parsing incl. malformed input · approve/reject via
`run_doc_method` · expired proposal is non-actionable · offline disables both actions · optimistic
removal rolls back on failure.

**Acceptance:**
- Cards render the agent's human-readable summary and change list — never raw JSON.
- Approve/Reject succeed against the live backend.
- Offline, both are **disabled with an explanation**, never queued (architecture §6).
- Server-side rejection (expired//missing target) surfaces the real message.

**Risks:** *queuing an approval offline would let a user approve a stale proposal* — prevented by
design and asserted by test.

---

## Phase 8 — Dashboard and Customer

**Goal:** manager overview; minimal customer view.

**Files:** `features/dashboard/**` · customer order screens

**Tests:** parallel count composition · partial failure degrades gracefully (one metric fails, others
render) · **Customer role sees no cost or internal data**.

**Acceptance:**
- Dashboard loads within 2s on cache, refreshes in background.
- One failed metric does not blank the screen.
- Customer view verified against a **real Customer user** — not Administrator.

**Risks:** *Customer over-exposure is a data incident, not a bug* (audit §8) — this phase does not
close until tested with a real Customer account. **G3** absence makes this the chattiest screen.

---

## Phase 9 — Notifications ⚠️ depends on G2

**Goal:** in-app notifications; push if the relay is enabled.

**Files:** `features/notifications/**` · FCM registration · deep-link handlers

**Tests:** token registration · deep link from cold start / background / foreground · mark-read sync.

**Acceptance:**
- Notification list with unread state; tap deep-links correctly.
- With G2 resolved: push arrives and routes correctly from a killed app.
- Without G2: refresh-on-foreground works and the limitation is visible in Settings.

**Risks:** relay is an external Frappe service — *build in-app notifications first so the phase
delivers value even if G2 is never resolved.*

---

## Phase 10 — Hardening and release

**Goal:** production-ready.

**Files:** cert pinning · `FLAG_SECURE` screens · crash reporting · Sync Issues screen · full golden
suite · store assets

**Tests:** full golden suite light+dark · text scaling to 1.6× on every screen · TalkBack/VoiceOver
pass on primary flows · offline→online E2E · **penetration check that tokens never appear in logs or
backups**.

**Acceptance:**
- WCAG AA verified on every screen (measured, not assumed).
- Cold start < 2s on a mid-range Android device.
- Crash-free rate > 99.5% in internal testing.
- Signed builds produced entirely by CI.
- No `TODO`, no placeholder, no dead code.

**Risks:** accessibility and offline defects found here are expensive — *mitigate by testing both from
Phase 4 onward rather than deferring to this phase.*

---

## Sequencing rationale

Phase 4 (Worker) precedes Phase 8 (Dashboard) deliberately: it retires the most technical risk
(offline writes, custom endpoint, Drift, type traps) on the smallest UI, and puts the app in the hands
of the largest user group earliest. Dashboards are the most visible phase but the least risky — and,
without **G3**, the least efficient.

## Cross-phase definition of done

A phase is complete only when **all** hold:

1. All five UI states implemented (`mobile_app_structure.md` §5).
2. Light and dark both golden-tested.
3. Offline behaviour matches the declared strategy for every call.
4. Accessibility: targets ≥48dp, labels present, 1.6× scaling clean.
5. No literal design values in widgets.
6. CI green: analyze, format, test, build.
7. Errors surface the human `_server_messages` text, never raw JSON.
8. No `TODO`, no placeholder, no commented-out code.

## Consolidated risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| G1 not resolved | — | **Blocks everything** | Escalated as Phase 0 |
| Role permissions differ from assumption | High | High | Test with real role users in Phase 3 |
| Customer role over-exposure | Medium | **Severe** (data incident) | Gate Phase 8 on a real Customer account |
| Refresh-token race | Medium | High | Single-flight, tested Phase 2 |
| `task` id typed as String | Medium | High | Contract test, Phase 4 |
| `mobile_no` silent write loss | High | Medium | Round-trip test, Phase 5 |
| Draft treated as submitted | Medium | High | Mapper-level enforcement, Phase 6 |
| Approval queued offline | Low | **Severe** | Designed out; asserted Phase 7 |
| iOS build unavailable on WSL2 | High | Medium | Decide in Phase 0 |
| Drift migration error | Medium | High | Migration tests from v1 |
