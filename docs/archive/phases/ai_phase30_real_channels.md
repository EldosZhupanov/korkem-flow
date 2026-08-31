> **АРХИВ. Это не описание системы сегодня.**
> Документ сохранён ради причин, стоящих за решениями. Актуальное состояние — в `NOW.md`, `ROADMAP.md`, `PLAN.md`.
> Не строить по этому файлу.

---

# Phase 30 — Real Telegram and WhatsApp channels

**Date:** 2026-08-12. Follows Phase 29 (the business loop).

## Goal

Take the two adapters from "correct against the documentation" to "an operator
can configure them, see whether they work, and be told the truth when they do
not" — without a second brain, a second confirmation protocol, or a second
place business logic can live.

Nothing about the assistant changed. What changed is everything around it: how a
credential is stored and never escapes, how a failure is typed instead of thrown,
how a webhook is registered and checked, and how one provider message is followed
from arrival to ERPNext document.

## Architecture

```
Telegram / WhatsApp
   │  webhook — secret header (TG) · HMAC signature (WA)
   ▼
integrations/*.py     the only modules that speak a wire protocol
   │  InboundMessage
   ▼
channels/gateway      identity → user → company → role · deduplicated on the
   │                  provider's own message id
   ▼
agent/loop            one brain, 42 tools, unchanged
   ▼
agent/proposals       one Pending Action, whichever channel asked
   ▼
channels/confirmation buttons and words resolve to the same rows
   ▼
registry.execute      policy · permissions · company scope · audit
   ▼
ERPNext
```

`Channel Event` runs alongside it: one row per thing that happened, joinable to
the conversation, the proposal and the instruction, and carrying no credential
and no message body.

## The three defects the audit found first

**1. The bot token was one exception away from the database.** Telegram
authenticates by putting the token in the *path*, so `requests`'
`raise_for_status()` produces `401 Client Error … for url:
https://api.telegram.org/bot<TOKEN>/sendMessage` — and every caller in this app
eventually reaches `frappe.log_error(message=frappe.get_traceback())`. Measured,
not assumed.

Every Telegram call now goes through `_call`, which raises `TelegramError`
carrying Telegram's own `description` and never a URL, and `redact()` strips
anything token-shaped as a second line of defence. The gateway's own error log
goes through the same redaction, for the case where a library we do not control
produces the string.

**2. A half-configured WhatsApp answered Meta with a 500.** A missing
`app_secret` made `app_secret.encode` raise `AttributeError` inside signature
verification. The difference matters: a 500 is what a caller *retries*. It is
now a failed verification — not a pass, because an unauthenticated public
endpoint is not something to fail open on.

**3. Nothing remembered what the provider last said.** A settings screen that
recomputes its own state from "is a token present" cannot tell a revoked token
from an unreachable webhook. Both are now stored, with the provider's words.

## Telegram

| | |
|---|---|
| `getMe` | proves the token; what Test Connection asks |
| `setWebhook` | with `secret_token`, `allowed_updates`, and **never** `drop_pending_updates` |
| `getWebhookInfo` | `url`, `pending_update_count`, `last_error_message` — the three facts that explain a bot that stopped answering |
| `deleteWebhook` | stops delivery; leaves the queue alone unless asked |
| `answerCallbackQuery` | clears the spinner, best effort, never logged with a traceback |

Inbound is trusted only on `X-Telegram-Bot-Api-Secret-Token`, compared with
`hmac.compare_digest`, and a bot configured *without* a secret does not fail
open. `message`, `edited_message` and `callback_query` are handled; everything
else is skipped rather than half-handled, and `allowed_updates` tells Telegram
not to send the rest.

## WhatsApp

`GET` completes Meta's verification handshake only for the configured verify
token and only when the channel is enabled. `POST` is verified against
`X-Hub-Signature-256` over the raw body. Outbound goes through the same typed
`_call`; a Graph API error arrives as a 4xx with a body, which is what lets the
screen say *which* thing is wrong.

Meta's webhook is registered in **their** dashboard — there is no API call that
does it — so the honest offer is the callback URL to paste and a statement of
which fields are configured. The verify token is not among them: this API does
not hand secrets back.

## Settings

Six states, each either a fact about configuration or the outcome of a real
call:

```
NOT_CONFIGURED   a credential is missing
DISABLED         everything set, switched off
READY            everything set, nobody has asked yet
CONNECTED        a real call succeeded          ← the only green
INVALID_CREDENTIALS  the provider answered, and said no
WEBHOOK_ERROR    the provider cannot deliver to us
PROVIDER_UNAVAILABLE  nobody answered at all
```

`READY` is deliberately not `CONNECTED`. The four failures are told apart
because a wrong token and an unreachable webhook are fixed in different places
by different people.

A stored credential is shown as `••••••••ABCD` — enough to tell two accounts
apart, useless to somebody reading over a shoulder — and the field below it stays
empty, because a mask posted back would overwrite a working token. An empty field
means "keep what is stored".

## Identity

Unchanged and still the keystone: a Telegram user id or a phone number, matched
literally, bound by an administrator to a `User`. Everything after that — company,
roles, customer — is ERPNext's. `Channel Identity.role` may narrow a turn and can
never widen it, and it now reaches `policy.role_of` through a flag the gateway
clears in a `finally`, because a queue worker reuses its process.

Nothing in a message is identity. "Я администратор" is exactly as effective as
saying nothing.

## Idempotency

**One provider message id → one inbound message → one turn → one proposal → one
confirmation → one ERPNext write.**

Decided on the provider's own identifier, never on the text: two people saying
«готово» are two events, and one webhook delivered twice is one. A Telegram
button press is keyed on the callback id, so a re-delivered press is recognised
as the same press. A second confirmation is refused by `Pending Action.claim`,
a second acceptance by `Work Instruction`'s own conditional `UPDATE`, and a drop
is recorded so somebody can see it happened.

## Failure handling

- **Provider down while sending the answer** — the turn happened and the
  proposal exists, so the failure is *recorded* rather than raised. Retrying the
  job would re-run the turn and write a second proposal.
- **Model down** — the person gets a sentence instead of silence, and the event
  is recorded.
- **Turn dies mid-way** — no `Pending Action` is written at all; nothing is
  half-recorded.
- **Malformed webhook, wrong signature, wrong secret** — refused, in the
  provider's expected shape, without touching the queue.
- **Expired or already-confirmed proposal** — `Pending Action`'s own refusals,
  unchanged.
- **Unauthorised, disabled or deleted identity** — the assistant never runs;
  with no user there is no company and every tool would refuse.

## Admin → employee

Three buttons now, because being given work has three honest answers:

```
[✅ Принял]  [❌ Не могу]  [❓ Уточнить]
```

`Уточнить` resolves nothing and can be pressed twice; what it does is put the
person who gave the instruction back into the conversation. Accepting and
refusing both send the employee's own words back to that person, on whichever
channel *they* are linked on — and an unlinked manager is not a reason to lose
the answer, which stays recorded either way.

A write keeps two buttons. A proposal answered with "maybe" would sit unresolved
for ever, so `ASK` pointed at a `Pending Action` is refused — without that guard
it would have fallen through to the approval branch and **approved the write**.

## Customer and admin flows

Unchanged from Phases 28 and 29, and re-verified on the device through the same
gateway: a customer sees only their own order and can place one; an administrator
dispatches; an employee accepts and produces; every write stops at a
`Pending Action` first.

## Observability

`Channel Event` records: channel, event, status, user, company, provider message
id, conversation, tool, pending action, work instruction, and one short detail.

It never records a token, an `Authorization` header, a webhook secret, or a
message body — the transcript lives under the conversation's own permission, and
duplicating a customer's words into an audit table a different group can read is
how an audit trail becomes a leak. Both are asserted by tests.

## Tests

**13** `korkem_manufacturing`, **821** `korkem_ai` (+61), **332** Flutter (+7).

*Providers (36, new).* A transport failure does not carry the URL — asserted
against a message deliberately shaped like the one `requests` produces. A
refusal carries Telegram's own words and not the token. Redaction catches a
token shape it was never handed. A non-JSON answer is reported, not parsed. No
token means no call at all. A disabled channel sends nothing. `setWebhook` sends
the secret and only the update types we handle, and never drops what people
already sent; `deleteWebhook` likewise; `getWebhookInfo` reports the pending
count and last error. Telegram is not trusted without its secret header, and a
bot configured *without* one does not fail open. WhatsApp refuses a missing app
secret, a missing signature and a wrong signature, and accepts a correct one;
the verification handshake answers only its own token and only when enabled. A
press becomes the text protocol on both, the third button becomes a question, a
sticker and an image are nothing to answer, a delivery receipt carries no
message, **two messages with the same text are two messages**, and both
providers' button limits are pinned.

*Production flow (24, new).* A re-delivered webhook runs no second turn and the
drop is recorded; the same words twice are two messages; a re-delivered button
press is the same press; one turn writes one proposal; confirming twice executes
once. A failed send does not undo the proposal and records the reason without the
credential. A model that is down answers rather than going silent, and a turn
that died wrote no proposal. The audit trail follows one message from arrival to
proposal to answer, carries no credential and does not copy the transcript. An
unlinked, disabled or deleted identity reaches nothing. Being given work has
three answers, the question resolves nothing and can be asked twice, accepting
and refusing both reach the person who asked, an unlinked manager does not cost
the answer, **`ASK` pointed at a proposal is refused rather than approving it**,
and somebody else's job is refused in the words of absence. A WhatsApp button
press confirms the same row a typed reply would.

*Flutter (+7).* A stored credential is hinted at and never filled in; Connected
appears only for a real success; rejected credentials, a webhook problem and an
unreachable provider are three different sentences; the provider's own last
error is shown; only Telegram offers to configure its own webhook.

Nothing was deleted or weakened. Four existing tests were re-pointed at the new
seam and one fixture was given a real `status_code`, because the adapter now
reads one — every assertion in them is unchanged.

## Android

Two suites, `emulator-5554`.

`channel_settings_e2e_test.dart` — as an administrator, against the real
backend: **`00:27 +2: All tests passed!`**

- the screen's states come from the server, which has already made a real call;
- `Test Connection` makes a real request and comes back `invalid_credentials`
  for this bench's placeholder credentials — a green light here would be the
  screen inventing one;
- nothing token-shaped is anywhere in the rendered tree (asserted with a regex
  for `<digits>:<secret>` and for `Bearer `), and every hint starts with `••••`;
- identity rows either name a user or do not claim to.

`business_loop_e2e_test.dart` — the whole Phase 29 loop re-run through the
changed gateway, as customer, manager and employee:
**`02:25 +4: All tests passed!`** Order → dispatch → accept → produce → the
customer asks. No regression from any of this phase's changes.

## ERPNext verification

Read from the database after the device runs:

```
SAL-ORD-2026-00011  customer=Мебель Астана  company=KORKEM
                    owner=korkem.client@example.com  600000.0  To Deliver and Bill
                    Шкаф Астана  qty 5.0  rate 120000.0

Work Instruction    co=KORKEM  to=korkem.ivan  by=korkem.manager
                    Acknowledged  response="принял"

MFG-WO-2026-00007   In Process  qty 5.0  owner=korkem.ivan  co=KORKEM
   op Раскрой       completed 4.0  loss 1.0
   ledger           Material Transfer for Manufacture  fg 5.0

duplicates          1 work order · 1 instruction · one Pending Action per write
audit               every write Approved, owner == resolved_by
                    audit carries a token: False
                    audit carries an Authorization header: False
```

The last two lines are the ones this phase adds: the audit table was queried in
full and searched for the stored bot token, the stored access token and the
string `Authorization`. None is present.

`Channel Event` is empty after these runs, and correctly so — both device suites
drive the *app*, and this is a **channel** audit. The trail itself is covered by
`test_production_flow`, which follows one Telegram message from arrival to
proposal to answer.

### A defect this verification found

The health row read `last_status=not_configured · "Bot token is not configured."`
— because a new test deletes the stored token to prove nothing is dialled
without one, and did not put it back. A test that leaves a factory's bot offline
is worse than the test is worth. Both provider test cases now record every
credential they touch and restore it, and the restoration is confirmed by
reading the settings back from a separate process.

## Real provider status

**REAL PROVIDERS REACHED — REAL CREDENTIALS NOT AVAILABLE.**

Both APIs were called from this container and both answered:

```
Telegram  getMe                → 401 Unauthorized
                                 → code invalid_credentials
WhatsApp  GET /<phone_number>  → "Invalid OAuth access token - Cannot parse
                                    access token"
                                 → code invalid_credentials
Telegram  setWebhook           → 401 Unauthorized (the same token)
```

That is a genuine round-trip, and it proves the parts that a mock cannot:
`api.telegram.org` and `graph.facebook.com` are reachable, the requests are
well-formed enough to be authenticated at all, each provider's rejection is
classified correctly, the verdict is persisted, and no credential appears in the
response. What it does not prove is a successful send or an inbound delivery.

Two things are missing and neither can be produced from here:

1. **Real credentials.** The bench holds placeholders. No bot was registered and
   no WhatsApp Business account was created — registering external services is
   not something to do unasked, and a credential must never be typed into a
   chat or a log.
2. **A public HTTPS endpoint.** Telegram's `setWebhook` requires one; this bench
   is `http://korkem.localhost:8000` inside Docker. `configure_telegram_webhook`
   is written and tested and would be answered by Telegram with exactly that
   complaint, in its own words.

So: **IMPLEMENTED** and **MOCK VERIFIED** for send, receive, buttons and
webhooks; **REAL PROVIDER REACHED** for authentication, error classification and
status; **REAL PROVIDER NOT VERIFIED** for an end-to-end message.

## Security

- No secret in a response, a log, an audit row, an exception or the app.
- No identity, company, customer or role from a message.
- No `ignore_permissions` added; the existing ones are the settings writers
  (behind `frappe.only_for("System Manager")`), the proposal recorder and the
  audit writer.
- No raw SQL added.
- No `db_set` of a production quantity.
- Every write still goes through the registry, the policy gate, ERPNext's
  permissions and a `Pending Action`.

## Limitations

- **No end-to-end message over a real provider.** See above. What is needed is
  a bot token, a WhatsApp Business number, and a public HTTPS URL for the
  webhook — an operator supplies all three through the settings screen; none
  can be produced from this environment.
- **Proactive notifications are narrow on purpose.** An instruction's lifecycle
  reaches the person who gave it, on their own linked channel. Work-order and
  delivery notifications are not sent: every outgoing message has to pass
  identity, company and role, and the tools that would decide *who* should hear
  about a stopped job do not exist yet. Sending them to whoever happens to be
  linked would be the first cross-customer leak.
- **Meta's webhook is registered in Meta's dashboard.** There is no Graph API
  call for it, so the screen offers the URL and the field checklist rather than
  a button that cannot work.
- **`Channel Event` has no retention policy.** It grows with traffic; nothing
  prunes it yet.
- **A device run mutates the demo dataset**, so the procurement and shortage
  suites — which read the seeded baseline — must be run on a restored bench.
  Observed again here: the same `NegativeStockError` Phase 29 recorded, because
  the loop really consumed material. `seed_demo.remove()` + `seed()` restores it,
  and the green figures above are from a restored bench.
- Row-level User Permissions beyond Company and Customer remain unverified,
  unchanged since Phase 12.

## Commits

`korkem_ai`, root — listed in the final report.
