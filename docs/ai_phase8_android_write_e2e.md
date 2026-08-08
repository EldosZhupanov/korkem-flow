# Phase 8 — the write path, confirmed on a device

**Date:** 2026-08-08 · Follows `ai_phase7_android_e2e.md`.

Status vocabulary: `LIVE VERIFIED` (executed on `emulator-5554` against a live
bench and real Gemini, output quoted) · `TEST VERIFIED` · `NOT VERIFIED` ·
`BLOCKED`.

---

## 1. Executive summary

**The write path is proven on a real Android device, through the real user
interface.** `LIVE VERIFIED`:

```
flutter test integration_test/write_flow_e2e_test.dart -d emulator-5554
00:36 +1: All tests passed!
```

The test types into the real login form, types into the real composer, waits for
a real Gemini turn over a real socket, sees the real `ConfirmationCard` appear,
and taps the real Confirm button. Independent verification from the database
afterwards:

```json
{"name":"2e2ti4cmtc","tool":"crm.create_task","status":"Approved",
 "provider":"Google Gemini","model":"gemini-flash-latest",
 "owner":"Administrator","resolved_by":"Administrator",
 "executed_at":"2026-08-08 14:47:35.770162","error":null}

action_data: {"title": "Әдемі E2E 1786180629926"}
result_data: {"data":{"task_id":637,"title":"Әдемі …","status":"Backlog"}}
```

Exactly one record. A replayed confirmation was refused and created none.

Getting there found **one real product bug** that every previous phase had
missed, because it only appears when a real await sits between two frames.

## 2. What Phase 7 had not proven

Phase 7's suite called `RemoteAssistant.send()` directly. It never pumped a
widget. So `ConfirmationCard` — the single widget standing between a language
model and a database write — had **never been rendered on a device**, and no
write had ever been triggered from one. Server-side tests and scripted widget
tests both passed throughout.

## 3. The bug

```
Bad state: Using "ref" when a widget is about to or has been unmounted is unsafe.
#2  approvePendingAction (threads_controller.dart:481)
```

`approvePendingAction(ref)` is called from `ConfirmationCard`'s Confirm button.
Its **first action** is `pendingConfirmationProvider.clear()` — and the card is
rendered only while that provider is non-null, so clearing it unmounts the very
widget that supplied the `ref`. Everything after the first `await` was then a
use-after-unmount: `busy.finish()`, `activity.idle()`, the final `save`.

It never fired before because Phase 6's widget test used a scripted repository
whose stream completed synchronously — no await, no unmount in between. On a
device, with a real socket and a real model, there are seconds between the tap
and the `finally`.

**Fix:** every provider handle the turn needs is read *before* anything is
awaited. Notifiers belong to the container, not the widget, so holding them is
safe for the life of the turn. `ActiveThread.current` was added so the final
save does not have to reach back through a `WidgetRef` at all.

The same shape existed in three more places and was fixed with it:
`sendMessage`'s `finally` and its two post-await reads, and
`rejectPendingAction`, which also reads the repository after `clear()`.

## 4. A test defect worth recording

The first run failed with `Insufficient Permission for CRM Task`, which reads
like a product or auth problem. It was neither: `TextFormField` builds a
`TextField`, so the test's "wait for the composer" condition
(`find.byType(TextField).isNotEmpty`) was already satisfied **by the login
screen**. The test proceeded unauthenticated and queried the API as Guest.

The signal that sign-in finished is the login *form* disappearing. Noted here
because the misleading error cost a cycle and would cost the next person one.

Also recorded: `frappe.client.get_count` is **not whitelisted** for RPC. Its
failure message ("Login to access…") also reads like auth rather than routing.
The test counts through `/api/resource`, which is the path the app itself uses.

## 5. Step-by-step result

| Step | Android | Gateway | Gemini | CRM | Result |
|---|---|---|---|---|---|
| 1 App launches | ✅ | — | — | — | `LIVE VERIFIED` |
| 2 Login through the real form | ✅ | ✅ | — | — | `LIVE VERIFIED` |
| 3 AI Workspace opens | ✅ | — | — | — | `LIVE VERIFIED` |
| 4 Socket connects | ✅ | ✅ | — | — | `LIVE VERIFIED` |
| 5 Real prompt sent | ✅ | ✅ | ✅ | — | `LIVE VERIFIED` |
| 6 Structured `crm.create_task` | — | ✅ | ✅ | — | `LIVE VERIFIED` |
| 7 Pending Action created | — | ✅ | — | — | `LIVE VERIFIED` |
| 8 `needs_confirmation` received | ✅ | ✅ | — | — | `LIVE VERIFIED` |
| 9 **ConfirmationCard appears** | ✅ | — | — | — | `LIVE VERIFIED` |
| 10 Confirm tapped | ✅ | — | — | — | `LIVE VERIFIED` |
| 11 Stored tool + arguments run | — | ✅ | — | ✅ | `LIVE VERIFIED` |
| 12 **Exactly one record** | — | ✅ | — | ✅ | `LIVE VERIFIED` |
| 13 Result back on the device | ✅ | ✅ | ✅ | — | `LIVE VERIFIED` |
| 14 Replay creates nothing | — | ✅ | — | ✅ | `LIVE VERIFIED` |
| 15 Cyrillic / Kazakh | ✅ | ✅ | ✅ | ✅ | `LIVE VERIFIED` |
| 16 Error path | — | — | — | — | `NOT VERIFIED` |

Step 12 is asserted three times: zero before the tap, one after, one after the
replay — read from the database, not from the screen.

Step 15: the marker `Әдемі E2E …` is Kazakh (`Ә`) and made the whole round trip
— prompt → Gemini → tool arguments → `action_data` → `CRM Task.title` → answer.

Step 16 is honest: no error-path case was exercised **from the device** this
phase. Error codes are covered server-side and in widget tests.

## 6. Constraints observed

Nothing was mocked: no mock Gemini, no substituted socket, no confirmation
simulated in Dart. The only substitution is the credential *cache*
(`flutter_secure_storage` needs a keyring), which is not on the path under test
and was already documented in Phase 7.

RAM was checked before and after each heavy run and the Gradle daemon stopped
between builds. No OOM occurred; the bench survived every run. Peak use left
~1.2 GiB free.

## 7. Tests

| Suite | Count |
|---|---|
| `korkem_ai` | **264** |
| `korkem_manufacturing` | **13** |
| Flutter unit/widget | **308** |
| Integration (Phase 7) | 3 |
| Integration (this phase) | **1** |

`flutter analyze` clean · `dart format` clean (186 files).

## 8. Verified / not verified

**`LIVE VERIFIED`** — steps 1–15 above; the audit row with provider, model,
resolver and timestamps; exactly-one-record; replay refusal.

**`TEST VERIFIED`** — 585 automated tests, including the Phase 5/6 confirmation
and replay suites and their mutation checks.

**`NOT VERIFIED`** — the error path from a device; reconnect (unchanged from
Phase 7 and still not isolated); `crm.create_lead` specifically from a device
(`crm.create_task` was the one exercised — the mechanism is shared);
`ToolSpec.timeout` enforcement; a manual human look at the app on the phone.

**`BLOCKED`** — nothing.

## 9. Remaining risks

- Reconnect remains the largest unproven behaviour: no `onDisconnect`, no retry,
  no `WidgetsBindingObserver`.
- `FrappeSocketChannel` still has no unit tests.
- The integration suite needs a live bench and real Gemini credit; it cannot be
  a CI gate as it stands.
- `ToolSpec.timeout` declared, unenforced.

## 10. Reproducing

```sh
mobile/korkem_flow/android/gradlew --stop
docker compose -f infra/frappe_bench/docker-compose.yml up -d   # wait for ping
emulator -avd korkem_test -no-audio -no-boot-anim -no-window -memory 2048

cd mobile/korkem_flow
PW=$(grep -E '^ADMIN_PASSWORD=' ../../infra/frappe_bench/.env | cut -d= -f2-)
flutter test integration_test/write_flow_e2e_test.dart -d emulator-5554 \
  --dart-define=KORKEM_BASE_URL=http://10.0.2.2:8000 \
  --dart-define=KORKEM_E2E_USER=Administrator \
  --dart-define=KORKEM_E2E_PASSWORD="$PW"
```

The test creates one `CRM Task` with a unique marker and deletes it on the way
out.
