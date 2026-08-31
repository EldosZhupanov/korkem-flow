> **АРХИВ. Это не описание системы сегодня.**
> Документ сохранён ради причин, стоящих за решениями. Актуальное состояние — в `NOW.md`, `ROADMAP.md`, `PLAN.md`.
> Не строить по этому файлу.

---

# Sprint 1 / Phase D — Execution Log
## WhatsApp integration (inbound webhook + outbound sender)

## Schema fix surfaced by this work

`Agent Conversation.user` was modeled as a required Link to `User` in Phase C, implicitly assuming an internal/staff conversation (e.g. a future web chat widget). A WhatsApp sender is an external customer with no Frappe User account. Fixed: `user` is now optional, a new `contact_phone` field was added, `validate()` requires at least one of the two, and `AgentConversation.get_or_create_for_contact(phone, channel)` was added to find-or-create the active conversation for an external sender.

## What was built (`backend/korkem_ai/korkem_ai/`)

- **`WhatsApp Settings`** (Single doctype) — `enabled`, `api_version`, `phone_number_id`, `business_account_id`, `access_token`/`app_secret`/`webhook_verify_token` (Password fieldtype). Mirrors `crm_twilio_settings.json`'s exact shape (per ADR-0011).
- **`integrations/whatsapp.py`**:
  - `verify_webhook_signature` — real HMAC-SHA256 verification of Meta's `X-Hub-Signature-256` header.
  - `parse_inbound_messages` — extracts text messages from Meta's nested webhook JSON, skipping non-text messages and status-update payloads.
  - `send_message` — real `requests.post` call to the Cloud API's `/messages` endpoint.
  - `queue_send_message` — async dispatch via `frappe.enqueue` (ADR-0009).
  - `check_verification_request` — pure decision logic for Meta's GET handshake, deliberately extracted from the request-context-bound wrapper so it's directly unit-testable.
  - `webhook` — single `@frappe.whitelist(allow_guest=True)` endpoint handling both the GET handshake and POST message events.

## Real bug found via live HTTP testing (not just unit tests)

Unit tests (mocked) all passed, but a **live curl against the actual running endpoint** showed the verification handshake returning `{"message": "abc123challenge"}` instead of the raw `abc123challenge` text Meta's API requires. Root cause (confirmed by reading `frappe/handler.py`): a whitelisted method's return value is JSON-wrapped into `frappe.response["message"]` by default — *unless* it returns a genuine `werkzeug.Response` object, which Frappe passes through completely unmodified. Fixed by having `_handle_verification`/`_handle_inbound` return real `Response` objects (`text/plain`, explicit status code) instead of plain strings. Re-verified live after the fix — correct raw body, correct status codes for both success and rejection paths.

This is exactly why the sprint plan's "run tests" step means more than unit tests alone for anything touching the HTTP layer — the mocked tests were fully passing this whole time and would never have caught this.

## Live end-to-end verification performed (no unit-test mocking)

1. `GET .../webhook?hub.mode=subscribe&hub.verify_token=<correct>&hub.challenge=X` → `200`, body `X` exactly.
2. Same with a wrong token → `403`, body `Forbidden`.
3. `POST .../webhook` with a real inbound-message payload and a correctly-computed HMAC-SHA256 signature → `200 OK`, and confirmed via direct DB query that a real `Agent Conversation` + `Agent Conversation Message` were created with the correct phone number and message content.
4. Test data cleaned up afterward; `WhatsApp Settings.enabled` reset to 0 (no real credentials exist in this environment — see the module's docstring).

**Explicitly not verified**: live send/receive against the real WhatsApp Business network. That requires a real Meta Business Account, phone number, and access token, none of which exist in this environment. The integration code is real and correct against Meta's documented API; only the third-party network round-trip is unverified.

## Test results

`bench --site korkem.localhost run-tests --app korkem_ai`: **33/33 passing** (up from 12 — added HMAC verification, payload parsing, verification-handshake logic, mocked send, and inbound-dispatch tests).

## Status: Phase D COMPLETE
