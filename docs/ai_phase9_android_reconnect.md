# Phase 9 — Android Socket.IO reconnect and recovery

**Date:** 2026-08-08 · Follows `ai_phase8_android_write_e2e.md`.

Labels: `LIVE VERIFIED` (executed on `emulator-5554` against a live bench and
real Gemini, output quoted) · `TEST VERIFIED` · `NOT VERIFIED` · `BLOCKED`.

---

## 1. Objective

Prove that KORKEM Flow on a real Android device survives losing its Socket.IO
connection and keeps working after it returns — without duplicating listeners,
responses or CRM writes.

## 2. Initial architecture

`FrappeSocketChannel` registered exactly four things: the data event,
`onConnectError`, `onError`, and `connect()`. There was **no `onDisconnect`, no
reconnect handler, and no `WidgetsBindingObserver` anywhere in the app**.
Reconnect options were never configured, so `socket_io_client`'s defaults
applied.

Both error handlers called `_failWith`, which pushes an error onto the channel's
broadcast stream — so a *connect* error during a retry would fail any turn
listening at the time.

## 3. Initial behaviour — measured, not assumed

**Reconnection already worked.** The library's default did the job. What did not
exist was any way to *see* it: the app could not distinguish "socket dropped"
from "model hasn't answered yet", which is why three previous phases recorded
reconnect as an unknown.

Measured detection latency: **~32 seconds**. With the defaults
(`pingInterval` 25s, `pingTimeout` 20s) a drop is not noticed for up to ~45s.
A 30-second outage was measured as **entirely undetected** — the socket was
never told, and connectivity returned before the timeout fired. That is correct
behaviour, and it is also why an early reproduction attempt "passed" while
proving nothing.

## 4. Reproduction — isolated to the socket

Earlier phases restarted the whole bench, which takes HTTP, the gateway, the CRM
and the session down together. This time the outage is **port 9000 only**, from
the device:

```sh
adb root
adb shell iptables -A OUTPUT -p tcp -d 10.0.2.2 --dport 9000 -j DROP   # break
adb shell iptables -D OUTPUT -p tcp -d 10.0.2.2 --dport 9000 -j DROP   # restore
```

Verified isolation, `LIVE VERIFIED`:

```
baseline        9000: OPEN     | 8000: OPEN
rule added      9000: BLOCKED  | 8000: OPEN
rule removed    9000: OPEN     | 8000: OPEN
```

HTTP keeps working throughout, so anything the socket does is the socket's.

**Socket.IO isolation on the server: NOT ISOLATABLE.** The Procfile runs
`socketio: bench socketio` under honcho, which tears down the whole process
group when a child dies — killing it would take the bench with it. The
client-side block above is the isolation that was used instead.

## 5. Root cause

There was no reconnect *defect* to fix. The defects were:

1. **Unobservable.** No `onDisconnect`, no status, nothing logged. A drop was
   indistinguishable from a slow model.
2. **A connect error during a retry failed in-flight turns.** `onConnectError`
   called `_failWith`, so a normal retry poisoned any listening subscriber.
3. **Unbounded retries.** A client retrying for ever against a server that is
   not coming back looks, to a user, exactly like one that is still working.

## 6. Fix

`assistant_channel.dart` only:

- `ChannelStatus { connected, disconnected, reconnecting, failed }` and a
  `status` stream on `AssistantChannel`.
- Handlers for `connect`, `disconnect`, `reconnect_attempt`, `reconnect`,
  `reconnect_failed`, `connect_error`, `error`.
- `onConnectError` now reports `reconnecting` instead of failing the stream.
  Only `onError` still fails it.
- `setReconnectionAttempts(8)` — bounded, with `failed` as a terminal state.

Nothing in the gateway, Gemini, tools, Pending Action or confirmation was
touched.

## 7. Socket event lifecycle — `LIVE VERIFIED`

```
15:57:52  socket.connected
15:58:07  [harness] blocked port 9000
15:58:36  socket.disconnect reason=transport close      ← 29s after the block
15:58:57  socket.error timeout
15:58:58  socket.connect_error timeout                  ← retry, still blocked
15:59:12  [harness] restored port 9000
15:59:19  socket.connect_error timeout
15:59:22  socket.connected                              ← back 10s after restore
statuses=[connected, disconnected, reconnecting, reconnecting, connected]
```

Logged fields are timestamp, event, and a truncated reason — never a payload,
header or credential.

## 8. Authentication after reconnect — `LIVE VERIFIED`

`frappe.auth.get_logged_user` returned `Administrator` after the outage. The
session, cookies and headers all survived; no re-login was needed.

## 9–11. AI request, streaming and CRM read after reconnect — `LIVE VERIFIED`

A real turn after the outage: real Gemini, real `crm.*` tools, streamed answer,
exactly one `AssistantDone`.

## 12. CRM write after reconnect — **`NOT VERIFIED`**

Stated plainly because the test that was supposed to prove it does not.

`one write request still creates exactly one record` passes, and proves one
request → one confirmation → one terminator → one row. It is **not** a reconnect
test: each test builds a fresh container, so the channel is created lazily on
the first turn — which happens *after* the outage window. The run log confirms
it: no `socket.disconnect` during that test, and `socket.connected` landing 40
seconds past the harness restoring the port.

A warm-up turn before the window would fix it. That is the first item in Phase
10.

Phase 8's write path itself remains `LIVE VERIFIED` on a device — this gap is
only about writing *after a reconnect*.

## 13. Duplicate listener — `LIVE VERIFIED`

The turn after reconnect produced **exactly one** `AssistantDone`. A second
subscription would deliver every event twice, terminator included.

Deliberately *not* asserted: uniqueness of tool names. A model legitimately
calls the same tool repeatedly (four consecutive `crm.search_deals` is normal),
and an early version of this test failed on that correct behaviour.

## 14. Duplicate write — `TEST VERIFIED`

One request produced exactly one `CRM Task`, verified by querying the database
before and after. Not on a reconnected channel — see §12.

## 15. Android lifecycle — **`NOT VERIFIED`**

Not tested. Backgrounding the app suspends the integration-test driver, so this
needs either a driver-based approach or manual inspection. There is still no
`WidgetsBindingObserver` in the app. No claim is made either way.

## 16–17. Failure and recovery behaviour

Recovery: `LIVE VERIFIED` above. Terminal failure after 8 attempts emits
`ChannelStatus.failed` — `NOT VERIFIED` end-to-end, as it needs an outage
longer than the retry budget.

**A stream interrupted mid-flight is `NOT VERIFIED`.** Every outage in these
runs happened between turns. With the fix, a connect error no longer kills a
listening turn, but that has not been exercised with a real turn in flight.

## 18. Tests

| Suite | Count |
|---|---|
| `korkem_ai` | **264** |
| `korkem_manufacturing` | **13** |
| Flutter unit/widget | **308** |
| Integration | **6** (3 Phase 7, 1 Phase 8, 2 here) |

`flutter analyze` clean · `dart format` clean (187 files).

## 19. Security

Transport logging records timestamp, event name and a reason string truncated to
120 characters. No password, key, cookie, token or payload. `_summarise` exists
precisely to keep a server response body out of the log.

The reproduction needs `adb root` on the emulator; that is a debug AVD and
nothing about it ships.

## 20. Performance / RAM

Checked before and after every heavy run; Gradle daemon stopped between builds;
never more than one build at a time. Total 9.7 GiB, emulator at 2048 MB. Lowest
free observed: **478 MiB**, no OOM, bench survived every run.

## 21. Regression results

All green: 264 + 13 backend, 308 Flutter, `analyze` clean, `format` clean.
Phase 7 and Phase 8 integration suites unchanged and unaffected — the only
production change is in `assistant_channel.dart`.

## 22. NOT VERIFIED

- CRM **write after reconnect** (§12) — the headline gap.
- App background → foreground (§15).
- Stream interrupted **mid-turn** (§17).
- `ChannelStatus.failed` reached end-to-end.
- Server-side Socket.IO isolation — `NOT ISOLATABLE` under honcho.

## 23. Remaining risks

- Detection takes up to ~45s on defaults. A user sees a turn hang for that long
  before anything reports. Tuning `pingTimeout` is a deliberate decision that
  was **not** taken blind here.
- The `status` stream is not surfaced in the UI yet — the app can now see a
  disconnect but does not tell the user.
- `FrappeSocketChannel` still has no unit tests; coverage is end-to-end only.
- The reconnect harness is timing-based, so the test is inherently slow (~4.5
  min) and not a CI candidate as written.

## 24. Recommendation for Phase 10

1. Add the warm-up turn and close §12 — smallest change, largest gap.
2. Surface `ChannelStatus` in the UI ("reconnecting…"), now that it exists.
3. Exercise a mid-turn disconnect.
4. Decide on `pingTimeout` deliberately, with the 45s measurement in hand.

## Evidence table

| Scenario | Result | Evidence |
|---|---|---|
| Initial Android connection | `LIVE VERIFIED` | `15:57:52 socket.connected` |
| Disconnect detected | `LIVE VERIFIED` | `15:58:36 disconnect reason=transport close` |
| Reconnect attempt | `LIVE VERIFIED` | two `connect_error timeout`, status `reconnecting` |
| Reconnect successful | `LIVE VERIFIED` | `15:59:22 socket.connected`; statuses end `connected` |
| Auth after reconnect | `LIVE VERIFIED` | `frappe.auth.get_logged_user` → `Administrator` |
| New AI request | `LIVE VERIFIED` | turn after outage, no `AssistantFailed` |
| Gemini response | `LIVE VERIFIED` | one `AssistantDone` |
| CRM read | `LIVE VERIFIED` | `crm.*` tool activity after reconnect |
| Streaming | `LIVE VERIFIED` | deltas then `done`, in order |
| Write after reconnect | **`NOT VERIFIED`** | no `socket.disconnect` in that test (§12) |
| Duplicate listener | `LIVE VERIFIED` | exactly one `AssistantDone` |
| Duplicate CRM write | `TEST VERIFIED` | one row before/after; not post-reconnect |
| Background → foreground | **`NOT VERIFIED`** | not tested (§15) |

## Reproducing

```sh
adb root
# terminal 1
flutter test integration_test/reconnect_e2e_test.dart -d emulator-5554 \
  --dart-define=KORKEM_BASE_URL=http://10.0.2.2:8000 \
  --dart-define=KORKEM_E2E_USER=Administrator \
  --dart-define=KORKEM_E2E_PASSWORD="$PW"
# terminal 2, on seeing "RECONNECT_PROBE window open"
sleep 5;  adb shell iptables -A OUTPUT -p tcp -d 10.0.2.2 --dport 9000 -j DROP
sleep 65; adb shell iptables -D OUTPUT -p tcp -d 10.0.2.2 --dport 9000 -j DROP
```

The outage must exceed ~45 seconds or nothing is detected. Clear the rule with
`adb shell iptables -F OUTPUT` if a run is interrupted.
