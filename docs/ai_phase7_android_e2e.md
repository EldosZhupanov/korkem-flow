# Phase 7 — Android end-to-end

**Date:** 2026-08-08 · Follows `ai_phase6_create_task.md`.

Status vocabulary: `LIVE VERIFIED` (executed against real hardware/services,
output quoted) · `TEST VERIFIED` · `NOT VERIFIED` · `BLOCKED` ·
`NOT SUPPORTED BY MODEL`.

---

## 1. Executive summary

**The chain is proven on a real Android device.** `LIVE VERIFIED`:

```
flutter test integration_test/assistant_e2e_test.dart -d emulator-5554
✓ Built build/app/outputs/flutter-apk/app-debug.apk
00:00 +0: the gateway reports the site the socket needs
00:07 +1: the real socket delivers a real answer
00:19 +2: a read tool runs and is reported as activity
00:38 +3: All tests passed!
```

Android app → HTTP → gateway → queue → Gemini → CRM tools → **socket.io** →
streamed answer, with Cyrillic asserted at the far end. Same suite, same
commit, also 3/3 on Linux desktop.

Getting there required finding a bug that had been misattributed for weeks, and
turned out not to be in the app at all.

## 2. Before

- Server-side: `LIVE VERIFIED` since Phase 6.
- Client-side: **never verified on any device.** `FrappeSocketChannel` had zero
  tests and there was no `integration_test/` directory.
- The known symptom — "the app signs in and the assistant never answers" — had
  been recorded across three prior phases as an unexplained device failure.

## 3. After

| | |
|---|---|
| Android E2E | **3/3 `LIVE VERIFIED`** |
| Linux desktop E2E | **3/3 `LIVE VERIFIED`** |
| Root cause of the device failure | **found and fixed** |
| Tool-result leak on the socket | **found and fixed**, mutation-checked |
| Backend tests | 260 → **264** |
| Flutter tests | **308** + 3 integration |

## 4. Architecture map (as built, from code)

| Hop | Where | Status |
|---|---|---|
| UI → controller | `chat_screen.dart` → `sendMessage` | `TEST VERIFIED` |
| controller → gateway | `RemoteAssistant.send` → `chat.send` (HTTP) | `LIVE VERIFIED` |
| gateway → queue | `chat.py` → `frappe.enqueue` | `LIVE VERIFIED` |
| queue → provider | `llm.resolve()` → `GeminiProvider` | `LIVE VERIFIED` |
| provider → tools | `agent/loop.py` → `registry.execute` | `LIVE VERIFIED` |
| write → pause | `chat._record_proposals` → `Pending Action` | `LIVE VERIFIED` (Ph 5/6) |
| gateway → client | `publish_realtime` → socket.io :9000, room `user:<user>` | `LIVE VERIFIED` |
| **client ← socket** | **`FrappeSocketChannel.events()`** | **`LIVE VERIFIED` on Android** |
| confirm | `chat.confirm` → `claim()` → `approve()` | `LIVE VERIFIED` (Ph 5/6) |

## 5. Android device

`emulator-5554`, AVD `korkem_test`, headless, `-memory 2048`.

Machine RAM rose from 7.4 → 9.7 GiB during this phase, which is what finally
made bench + emulator + Gradle coexist. At 7.4 GiB the emulator killed all four
bench containers twice, and the resulting "connection failed" looked exactly
like the socket bug — a trap worth naming.

## 6. Socket transport — the root cause

`AssistantFailure.offline`, fast, on Android only. `RemoteAssistant` discarded
the underlying error (`onError: (_)`), so a temporary patch was needed to see:

```
KORKEM_SOCKET_ERROR: {message: Unauthorized: TypeError: fetch failed}
```

That is Frappe's socket.io middleware failing the **loopback call it makes back
to the web server** to validate the session.
`frappe/realtime/utils.js:get_url` builds that URL from the **client's own
`Origin` header** when `webserver_host` is unset:

```js
let url = socket.request.headers.origin;            // http://10.0.2.2:9000
if (conf.developer_mode) { …swap in webserver_port… }   // http://10.0.2.2:8000
```

`10.0.2.2` is the host *as seen from the emulator* and means nothing inside the
Docker container → `fetch failed` → `Unauthorized`. From Linux desktop the
Origin is `korkem.localhost`, which the container **can** resolve — which is
precisely why desktop passed and Android did not, and why the bug looked like an
app defect for so long.

The app cannot work around it: the same middleware separately requires the
`Origin` hostname to equal the `Host` it dialled.

**Fix** — `infra/frappe_bench/scripts/bootstrap.sh`:

```sh
bench set-config -g webserver_host 127.0.0.1
```

Ruled out first, each by evidence: cleartext policy (`10.0.2.2` whitelisted, and
HTTP worked throughout), port reachability (`nc` from inside the emulator —
8000 **and** 9000 both open), and `extraHeaders` on a websocket-only transport
(`socket_io_client-3.1.6` passes them through).

## 7–10. Gemini, structured tools, read tool, write tool

Unchanged from Phases 5–6 and re-exercised here through the device:

| | |
|---|---|
| Gemini chat + streaming | `LIVE VERIFIED` on Android |
| Structured tool call | `LIVE VERIFIED` (`crm.search_deals` via the device) |
| Read tool → CRM → answer | `LIVE VERIFIED` on Android |
| Write tool (`create_lead`/`create_task`) | `LIVE VERIFIED` server-side (Ph 5/6); **not re-run through the device this phase** |

## 11–14. Pending Action, confirmation, audit, replay

Unchanged and untouched. All `LIVE VERIFIED` in Phases 5–6; the atomic `claim()`
remains mutation-checked. **Not re-exercised from Android** — the device suite
covers read paths only, so confirmation-on-device is `NOT VERIFIED`.

## 15. Security

A second defect, found by watching the wire rather than by reading code:
`agent/loop.py` published `{"type": "tool", **result}` — spreading the **entire**
tool outcome, `payload` included, onto every realtime event. One
`crm.search_deals` put fifty complete deal rows on the socket, to a client that
reads two fields.

Same-user room, so not a cross-user breach, but it contradicted the rule
`registry._log` exists to enforce and put an unbounded result set on every tool
call. Fixed via `_activity()`; observed payload **14,897 → 1,754 bytes**.
Mutation-checked — three tests fail when the spread is restored, one asserting
on the serialised event because a key-by-key check would pass while the whole
result travelled.

## 16. API key handling

Unchanged: encrypted server-side, write-only, masked, never returned. The
device suite passes `--dart-define` credentials for the *Frappe* login only; no
provider key exists on the device. Secret scan clean across tree and history.

## 17. Streaming

`LIVE VERIFIED` on Android. Event order `started → tool → delta … → done`
observed on the wire. The Cyrillic assertion in the E2E test is deliberate — a
UTF-8 bug in the SSE reader once mangled every non-ASCII reply, and this is the
layer that would hide a repeat.

## 18. Error handling

`RemoteAssistant.onError` now logs the transport error instead of discarding it.
The user still sees only "offline" (a transport error is not actionable for
them), but the next occurrence is readable from a log rather than requiring a
patch to that exact line — which is what this phase had to do.

## 19–20. Provider abstraction and settings

Unchanged from Phase 6. Flutter names no provider; the gateway resolves
credentials. `settings_api` + AI Settings screen as built in Phase 4.

## 21. Test matrix

| | Backend | Socket | Android |
|---|---|---|---|
| Gemini chat | `LIVE` | `LIVE` | **`LIVE`** |
| Gemini read tool | `LIVE` | `LIVE` | **`LIVE`** |
| Gemini write tool | `LIVE` | `LIVE` | `NOT VERIFIED` |
| Confirmation | `LIVE` | `LIVE` | `NOT VERIFIED` |
| Replay protection | `LIVE` + mutation | n/a | n/a |
| Streaming | `LIVE` | `LIVE` | **`LIVE`** |
| Error handling | `TEST` | `LIVE` (the bug itself) | **`LIVE`** |
| Auth | `LIVE` | **`LIVE`** | **`LIVE`** |
| **Reconnect** | n/a | `NOT VERIFIED` | `NOT VERIFIED` |
| Ollama tool calling | — | — | `NOT SUPPORTED BY MODEL` |
| OpenAI / Anthropic / OpenRouter | `TEST` (adapter) | `NOT VERIFIED` | `NOT VERIFIED` |

## 22–25. Verified / not verified

**`LIVE VERIFIED`** — Android 3/3; Linux desktop 3/3; socket auth, namespace and
delivery; streaming with Cyrillic; read tool through the device; the leak fix on
the wire; `webserver_host` as the root cause and its fix.

**`TEST VERIFIED`** — 264 backend + 308 Flutter; the leak regression
(mutation-checked); everything from Phases 5–6.

**`NOT VERIFIED`** — write/confirmation **from a device**; reconnect (see below);
OpenAI/Anthropic/OpenRouter live; `ToolSpec.timeout` enforcement (still declared
and unimplemented); manual UI inspection at 1.6× scale, dark mode and kk/en on
the device — the suite is programmatic, nobody has *looked* at the app.

**`BLOCKED`** — nothing.

## 26–27. Bugs found and fixed

| # | Bug | Fixed |
|---|---|---|
| 1 | `webserver_host` unset → socket rejects every non-resolvable client host | ✔ `bootstrap.sh` |
| 2 | Tool results broadcast in full on every realtime event | ✔ `loop.py:_activity` |
| 3 | Socket errors discarded (`onError: (_)`), making #1 undiagnosable | ✔ logged |

## 28. Remaining risks

- **Reconnect is a real gap.** Probed by restarting the bench between two turns:
  turn 1 succeeded, turn 2 returned `AssistantFailed`. But the probe restarted
  the *whole* bench, so the HTTP endpoint was down too — and the code was
  `unknown`, not `offline`, which points at the HTTP call rather than the
  socket. **The failure is real; the attribution is not isolated.** There is no
  `onDisconnect`, no retry and no `WidgetsBindingObserver` anywhere in the app,
  so the gap is genuine regardless; it simply has not been cleanly measured.
- `FrappeSocketChannel` still has no unit tests. The E2E suite covers it
  end-to-end; option building and error mapping are not covered in isolation.
- `ToolSpec.timeout` declared, not enforced.
- No rate limit or token budget.
- The E2E suite needs a live bench and real Gemini credit; it is not a CI gate.

## 29. Next priorities

1. **Isolate and fix reconnect** — restart *only* socketio, confirm whether the
   next turn recovers, then fix what that shows.
2. Confirmation flow from a device (the write path's last unproven hop).
3. `FrappeSocketChannel` unit tests.
4. Enforce `ToolSpec.timeout`.
5. Manual UI pass on the device: 1.6× text, dark mode, kk/en, keyboard.

## 30. Reproducing

```sh
# order matters — the emulator has killed the bench twice by starting first
mobile/korkem_flow/android/gradlew --stop
docker compose -f infra/frappe_bench/docker-compose.yml up -d   # wait for /api/method/ping
emulator -avd korkem_test -no-audio -no-boot-anim -no-window -memory 2048

cd mobile/korkem_flow
PW=$(grep -E '^ADMIN_PASSWORD=' ../../infra/frappe_bench/.env | cut -d= -f2-)
flutter test integration_test/assistant_e2e_test.dart -d emulator-5554 \
  --dart-define=KORKEM_BASE_URL=http://10.0.2.2:8000 \
  --dart-define=KORKEM_E2E_USER=Administrator \
  --dart-define=KORKEM_E2E_PASSWORD="$PW"
```

Linux desktop is the same command with `-d linux` and
`KORKEM_BASE_URL=http://korkem.localhost:8000`.

Ollama, if used, still needs the temporary relay documented in
`ai_p0_p1_fixes.md`; it is not required for any of the above.
