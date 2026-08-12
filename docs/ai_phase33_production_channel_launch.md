# Phase 33 — Production channel launch

**Date:** 2026-08-12. Follows Phase 32 (channel operations).

## What this phase is, and what it is not

Phase 33's goal was a **real** end-to-end message: a person typing into Telegram
or WhatsApp, reaching this system over the public internet, and getting an
answer that came from ERPNext.

That did not happen, and the reason is not code. It is stated plainly in
[Real provider status](#real-provider-status) below, with exactly what is
missing.

What this phase did instead is everything either side of that gap: it found and
fixed four defects that would have surfaced on the first day of real traffic,
built the public HTTPS front door the webhooks need, and wrote down the launch
procedure so that the missing pieces are the only work left.

**Nothing here is described as verified unless it was measured.**

## The four defects, all found by preparing to launch

**1. The status page could say a channel was fine while every message to it was
being refused.** `_state` matched a stored verdict against four codes, and the
classifier had since grown two more — `forbidden` (the bot is blocked) and
`rate_limited`. Both fell through to **READY**. That is the exact green light
that means nothing, which this design is arranged against everywhere else. All
six verdicts are now in one list, and a test iterates that list rather than
repeating it.

**2. A malformed webhook body answered 500.** `frappe.parse_json` on a body that
is not JSON raises, Frappe turns that into a 500, and **a 500 is what a provider
retries** — so one bad update would have become an endless redelivery loop.
Both webhooks now acknowledge what they cannot parse: it will not parse next
time either.

**3. Neither webhook had a size limit.** A public URL will be sent a megabyte
eventually. WhatsApp's case is worse than Telegram's, because computing an HMAC
over the body is work an unauthenticated caller would otherwise be choosing for
us — so the size check now runs *before* the signature check.

**4. The correlation chain could not distinguish two messages.** `turn_id` on a
proposal was the *conversation's* name, so every proposal in a thread shared one
id. There is now a real per-turn id, minted where the turn begins and carried to
the audit rows, the proposal and the notification delivery.

## Deployment: what a real webhook needs

Telegram will not call an HTTP URL and will not call a private host. This bench
is `http://korkem.localhost:8000` inside Docker, with the application port
published straight to the host and no proxy — fine for an emulator, impossible
for a bot.

`infra/frappe_bench/docker-compose.public.yml` adds the front door:

```
internet → :443 Caddy (TLS, auto-issued) → bench:8000 → gateway → agent → ERPNext
```

```sh
KORKEM_PUBLIC_HOST=korkem.example.com \
KORKEM_ACME_EMAIL=ops@example.com \
docker compose -f docker-compose.yml -f docker-compose.public.yml up -d
```

Three decisions in it worth stating:

- **A separate file**, so a bench that is not published is not one edit away
  from being published.
- **Caddy**, because it obtains and renews the certificate itself; the only
  operator input is a hostname that resolves to the machine.
- **Only the two webhook paths are proxied.** A public front door for a bot is
  not a reason to publish the desk, the API or the file manager — everything
  else answers 404, which tells a scanner nothing. The application port moves to
  `127.0.0.1` so the proxy is the only way in.

Verified: `docker compose config` resolves the overlay, the proxy publishes
80/443 and the bench port is bound to loopback. **Not verified: a real
certificate**, which needs a real hostname.

## Real provider status

**Telegram: NOT VERIFIED. WhatsApp: NOT VERIFIED.**

Missing, precisely:

### REAL CREDENTIALS REQUIRED

1. **Telegram bot token** from BotFather, and a **webhook secret** of your
   choosing (any random string; it is stored encrypted and never displayed).
2. **WhatsApp Cloud API access token**, **phone number ID**, **app secret** and
   **webhook verify token** from a Meta Business account with a registered
   number.

### PUBLIC INFRA REQUIRED

1. **A DNS name** with an `A`/`AAAA` record pointing at the machine running the
   bench.
2. **Ports 80 and 443 reachable from the internet** on that machine — 80 is
   needed for the ACME challenge, 443 for the webhooks themselves.
3. Nothing else. No purchased service, no tunnel, no external account beyond the
   two provider consoles above.

Given those, the operator flow is complete and tested against mocks:
**token → Test connection → Register webhook → Send test message → status.**

What is already proved without them: both provider APIs are **reachable** from
this container and both **reject** this bench's placeholder credentials in their
own words, correctly classified (`invalid_credentials`, not retryable). That is
a real round-trip over the real internet; it is not an end-to-end message, and
this document does not call it one.

## Test procedure for the day credentials exist

1. Point DNS at the machine; bring up the public overlay.
2. Settings → Channels → Telegram: paste the token and a webhook secret, Save.
3. **Test connection** → expect `connected` and the bot's username.
4. **Configure webhook** → expect `connected`, `pending_update_count: 0`, no
   `last_error`. A wrong hostname surfaces here, in Telegram's own words.
5. **Send test message** to your own linked identity → a real message, recorded
   in the delivery centre as `channel.test`, touching no ERPNext document.
6. Link your Telegram id to a `User` in Identity management.
7. Message the bot: «Что на производстве?» — expect an answer built from tools.
8. As a linked customer: «Где мой заказ?» — expect only their own.
9. «Создай заказ на 5 шкафов Астана к 25 сентября» → inline buttons → Confirm →
   a real Sales Order, and the number back in the chat.
10. Verify in ERPNext directly, not from the reply.
11. WhatsApp: paste credentials, then paste the callback URL and verify token
    into Meta's dashboard (their webhook is registered on their side; there is
    no API for it). Repeat 5–10.

### Rollback

Every step is reversible from the same screen: **Remove webhook** stops delivery
without dropping what is queued at the provider; **Disconnect** switches the
channel off and keeps the credentials; taking the public overlay down returns
the bench to loopback. No business data is involved in any of it.

## Failure modes, and what each looks like

| what happened | what the operator sees | retryable |
|---|---|---|
| wrong or revoked token | `invalid_credentials`, the provider's words | no |
| bot blocked by that chat | `forbidden` | no |
| throttled | `rate_limited` | yes |
| provider having a bad day | `provider_unavailable` | yes |
| certificate or hostname wrong | `webhook_error`, with Telegram's own complaint | yes |
| body not JSON, or too large | acknowledged and dropped, no retry loop | — |
| forged or missing secret / signature | 401, nothing queued | — |
| same update delivered twice | one turn, one proposal, one write | — |

## Observability

One message can now be followed end to end:

```
provider_message_id → Channel Event(received/identified)
   → turn_id ─┬→ Channel Event(proposed) → Pending Action → tool → ERPNext doc
              └→ Notification Delivery → Channel Event(sent|failed)
```

`turn_id` is on `Channel Event`, `Pending Action` and `Notification Delivery`. A
notification raised by a scheduled job carries none, deliberately: the chain
starts at the business event instead, and inventing a turn would make it lie
about where it began.

## Security

Unchanged boundaries, re-tested: identity from the provider's own id and never
from a message; company and customer scope server-side; every write confirmed;
no secret in a response, a log, an audit row, an exception or a widget.

New in this phase: the size check runs before the signature check, so an
unauthenticated caller cannot make us hash arbitrary data; and a forged secret
is refused before the body is read at all.

## Tests

**13** `korkem_manufacturing`, **947** `korkem_ai` (+25), **346** Flutter (+2).

*Launch readiness (25, new).* Each of the four defects above has a regression,
and three of them are written so the test cannot drift from the code: the
verdict test **iterates `VERDICTS`** rather than repeating the list, so a
seventh code added later is covered the day it is added.

- *A status page that cannot flatter* — every verdict a provider can leave
  reaches the screen; a blocked bot and a rate limit each read as themselves and
  not as READY; every state has words and a retryable verdict; a missing
  credential still outranks a stale `connected`; both classifiers agree about
  what is worth retrying.
- *A public endpoint survives what is sent to it* — unparseable JSON is
  acknowledged rather than 500'd on both providers; an oversized body is dropped,
  and on WhatsApp **before** the signature is computed; a forged secret is
  refused; an update type we do not answer is skipped; a body edited in flight
  fails its signature; a payload that is not an object is ignored.
- *One message followed end to end* — the proposal carries the **turn** and not
  the conversation; two messages in one conversation are two turns; the audit
  rows of a turn share its id; a notification raised during a turn carries it,
  and one raised by a scheduled job carries none.
- *The operator's test message* — recorded where every other outbound message
  is, visible in the delivery centre, **runs no model and writes no business
  document**, records a failure as a failed delivery, and says in its own words
  that it is a test.

*Flutter (+2).* A blocked bot does not read as ready; a rate limit is its own
state and a warning rather than an error.

### A defect these tests found in themselves

The first device run after them failed: the settings screen reported
**connected** for a bench holding placeholder credentials. The cause was the new
tests — `send_test_message` persists a health verdict, and the fixture restored
`enabled` but not `last_status`. A test that leaves `connected` behind produces
exactly the lie these tests exist to catch, by the back door. The fixture now
records and restores the verdict; re-checked afterwards, the bench reports
`invalid_credentials` with Telegram's own words.

## Android

`business_loop_e2e_test.dart` — **`02:17 +4: All tests passed!`**
`channel_settings_e2e_test.dart` — **`00:24 +2: All tests passed!`**

The settings suite is the one that matters for this phase: it asserts the screen
does **not** say connected on a bench whose credentials are placeholders, and
that nothing token-shaped appears in the rendered tree.

## ERPNext verification

Read from the database after the device run:

```
SAL-ORD-2026-00011  customer=Мебель Астана  company=KORKEM
                    owner=korkem.client@example.com  600000.0
instructions on it: 1 · work orders on it: 1        ← nothing duplicated

MFG-WO-2026-00007   In Process  qty 5.0  owner=korkem.ivan
   op Раскрой       completed 4.0  loss 1.0

stock  Stores 81.8 (reserved for production 16.8) · WIP 21.0
       consistent with one job of five having drawn its material

correlation  turn 833a8a8980f3 → 1 proposal
             manufacturing.complete_operation · Approved · owner korkem.ivan

deliveries   10 · distinct keys 10 · all Suppressed
customer messages carrying somebody else's business: none
health       telegram invalid_credentials ("Not Found")
             whatsapp invalid_credentials ("Invalid OAuth access token")
carries a token: False · carries Authorization: False
```

Two of those lines need reading precisely rather than generously.

**`Channel Event` rows for that turn: 0.** Correct: this run came through the
*app*, and `Channel Event` is a **channel** audit. The turn id is on the
proposal, which is the part of the chain the app path shares.

**All ten deliveries `Suppressed`.** Also correct: restoring the demo dataset
removes the channel identities, so at that moment nobody had a chat address.
`Suppressed` is the honest record of "there was nobody to send to" and is
exactly what it should say.

### Something the verification found about itself

The first verification came back empty. The launch-readiness module's teardown
deletes `Notification Delivery` and `Channel Event` **globally**, and it had run
after the device suite — so the evidence was cleaned up by a later test. The
loop was re-run to produce a live trail. The teardown is left as it is (every
channel test case cleans that way, and a scoped teardown would leak rows between
tests); what changes is the order: **verify before running more tests.**

## Limitations

- **No real provider end-to-end.** The blocker is credentials and a public
  hostname; see [Real provider status](#real-provider-status). Everything either
  side of the wire is implemented and tested.
- **The public overlay is unexercised.** `docker compose config` resolves it and
  the port bindings are as intended, but no certificate has been issued and no
  request has traversed it — that needs a DNS name.
- **`Channel Event` has no retention policy**, unchanged since Phase 31.
- **The delivery centre has no paging**, unchanged since Phase 32.
- **A device run mutates the demo dataset**, and this phase found the sharper
  version of that: four runs in a row exhausted the edge banding, and the fourth
  correctly refused to start production. Restore the dataset between runs.
- **Test teardown is global for channel rows**, so a verification must be taken
  before running further tests.
- Row-level User Permissions beyond Company and Customer remain unverified,
  unchanged since Phase 12.

## Commits

`korkem_ai`, root — listed in the final report.
