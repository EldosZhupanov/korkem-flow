> **АРХИВ. Это не описание системы сегодня.**
> Документ сохранён ради причин, стоящих за решениями. Актуальное состояние — в `NOW.md`, `ROADMAP.md`, `PLAN.md`.
> Не строить по этому файлу.

---

# Phase 29 — The business loop

**Date:** 2026-08-12. Follows Phase 28 (customer-safe reads).

## What this phase is

Everything before it made the assistant able to *answer*. This one makes it able
to run the loop a furniture factory actually turns:

```
customer  →  order            sales.create_sales_order
manager   →  sees it          sales.search_sales_orders · dispatch.list_instructions
manager   →  hands it over    dispatch.assign_work        → Telegram / WhatsApp
employee  →  accepts          the same buttons, or dispatch.respond_to_instruction
employee  →  works            manufacturing.*  (unchanged)
customer  →  asks             sales.delivery_forecast · crm.customer_timeline
```

**One brain throughout.** No channel owns any business logic: a Telegram adapter
still speaks only Telegram, the gateway still turns a payload into a turn, and
every write still stops at a `Pending Action`. The three new capabilities are
tools like all the others.

Registry: **37 → 42 tools**.

| Tool | | |
|---|---|---|
| `sales.search_items` | new, READ | what the factory makes, and what it costs the customer |
| `sales.create_sales_order` | new, WRITE | place an order — the only write a customer may propose |
| `sales.delivery_forecast` | new, READ | when it can be ready, against when it was asked for |
| `dispatch.assign_work` | new, WRITE | give a person a job, on their own channel |
| `dispatch.list_instructions` | new, READ | who accepted, who has not answered |
| `dispatch.respond_to_instruction` | new, WRITE | accept or refuse, from the app |

## The defect this phase found first

**A proposal was never written down on a channel.** Approval was implemented,
tested and documented in Phase 27A; *proposal* was not. `gateway._await_confirmation`
looked its rows up by the provider's own call id and skipped every one it could
not find — which was all of them, because nothing on that path had ever written
one. A foreman on Telegram was shown a sentence describing a write and then had
nothing to confirm.

The fix is one recorder, `agent/proposals.py`, used by the app and the gateway
alike. That is the same reasoning that keeps one agent loop behind three
channels: two implementations of the same step drift, and this pair had already
drifted into one working and one not existing.

## Customer order intake

**Nothing about who they are comes from what they say.** `customer`, `company`,
warehouse, price list and rate are all resolved server-side; a customer writing
«я клиент Караганда Мебель» changes nothing, because the only customer the tool
will write is `scope.customer_scope()`.

**The catalogue is what the factory makes** — items with a default BOM, which is
ERPNext's own statement that it builds the thing. Nobody had to write a list, and
a customer cannot order a sheet of chipboard.

**A missing detail is asked for, never invented.** No quantity, no date, an
unknown product, two products that both match, a date in the past, an item with
no price: six different refusals, each naming what is wrong, and none of them
writes a document.

**The price is ERPNext's.** `set_missing_values` resolves it from the price list
the customer buys on (`accounts/party.get_default_price_list`). An item with no
price produces no order at all — a Sales Order carrying a number somebody
invented is worse than no Sales Order.

### Two deliberate exceptions, both measured

Neither was chosen for convenience, and both are the narrowest form of what they
had to be.

**The order is written by the system.** `Sales Order.set_missing_values` reaches
`erpnext/accounts/party.py:get_party_account`, whose `account_perm_check` asks
`frappe.has_permission("Account", …)` — which does not consult
`ignore_permissions`. Measured: a customer building the document raises *"User
don't have permissions to select/read this account."* Granting a customer read on
the chart of accounts to place an order would be absurd, and granting them
`create` on Sales Order would let them post one straight to the desk API at a
price of their choosing. So every decision is made in their own session and only
the writing is elevated, with `owner` stamped back to the customer's user.
ERPNext does the same where it must — `www/book_appointment/verify/index.py`
switches to Administrator to write a visitor's appointment and switches back.

**The catalogue is published, not permitted.** `valuation_rate` and
`last_purchase_rate` sit at permlevel 0 on `Item`, so the permission that shows
somebody a cabinet also shows them what it costs the factory. The catalogue is
therefore a fixed projection — four descriptive fields and the selling price —
and `sales.search_items` declares no doctype, which is the honest statement that
it does not read `Item` with the caller's permission.

The same reasoning shapes `sales.delivery_forecast`: `Work Order` has no customer
field, so a `User Permission` cannot narrow it, and read on it would show the
whole factory's production. The estimate is computed over jobs belonging to an
order the caller could already list through `frappe.get_list`, and a customer is
never handed a work order number.

## "Когда будет готов" is three facts, not one

`requested_date` is the date on the order. `estimated_ready_date` is what the
remaining planned operation minutes imply against the workstations' own working
hours. `meets_requested_date` is whether the second fits inside the first. They
are reported separately and the basis is spelled out in words, because telling a
customer their date is fine *because they asked for it* is the one answer this
must never give.

Measured on the seeded bench (order names as they were numbered then):

```
SAL-ORD-…-00002  requested 2026-08-08  estimated 2026-08-15  meets False
                 30.3 h of work left, an 8 h day
SAL-ORD-…-00001  requested 2026-08-25  estimated 2026-08-13  meets True
SAL-ORD-…-00003  requested 2026-09-01  estimated None
                 "производство по заказу ещё не запущено"
```

## Dispatch

`Work Instruction` records the *asking*: who was told, on which channel, whether
they answered and what they said. It points at the Sales Order and the Work
Order and describes neither — `produced_qty` stays ERPNext's, and nothing here
counts anything.

Seven states, each caused by something that happened: `Draft` → `Sent` →
`Acknowledged` → `In Progress` → `Completed`, with `Rejected` and `Cancelled` as
the two ways out. No workflow engine, no timers.

**Who may dispatch is ERPNext's answer.** The doctype grants `create` to
`Manufacturing Manager`; a `Manufacturing User` holds `write` and not `create`,
so the seeded planner is refused by the permission model rather than by a second
role list here. That also gave `ToolSpec.permission`: a write that *updates* an
existing row needs `write`, not `create`, and an employee answering their own job
holds exactly one of those.

**An employee sees their own work.** ERPNext cannot express "only rows addressed
to you" here, because the field that would say so is `employee_user` and not
`owner`, so the tool draws that line — using `has_permission(create)` as the test
for "are you the one giving orders" rather than inventing a role list.

## One protocol, two kinds of thing

A `Pending Action` asks *"shall I run this write?"*. A `Work Instruction` asks
*"will you do this work?"*. They are answered with the same two buttons, because
to the person holding the phone they are the same gesture — and a second button
protocol would be a second way for a press to be misread.

So `confirmation.handle` resolves a name against both, in that order; a bare
«принял» prefers the instruction, because a foreman accepting a job has not
agreed to anything else; and both are claimed with a single conditional `UPDATE`,
so a double-tap and a re-delivered webhook change nothing the second time.

A second press of a button that already worked now says *"это задание уже
принято"* rather than *"нечего подтверждать"* — the latter reads as though the
first press was lost, which is the one thing a person must not be told after it
worked.

## A customer on a channel now reaches the assistant

Until Phase 28 they could not: filtering which tools exist does nothing about
which rows they read, so the only safe answer was the sales router. Now every
customer-reachable tool pins its reads to the session's own customer, so the same
brain answers them — with six tools instead of forty-two.

`Channel Identity.role` finally *does* something: the pin is set as a flag for
the length of the turn and `policy.role_of` honours it, so the registry, the
customer scope and the system instruction all see the narrowed role. It can still
only narrow. The flag is cleared in a `finally`, because a queue worker reuses
its process and a pin left behind would be applied to the next person's turn.

## Settings, and what a screen may not say

`channels_api.py` plus a Flutter screen: bot token, webhook secret, access token,
phone number id, verify token, enabled, the webhook URL to paste into the
provider, and a connection test.

- **No endpoint returns a credential.** The screen is told `configured: true` and
  never what with. An app that has once held a bot token has published it to
  every device it runs on.
- **An empty field is not a value.** Sending one would clear a working credential
  every time somebody toggled a checkbox — which is how a settings screen takes a
  factory's bots offline.
- **"Ready" is not "Connected".** Ready means nothing is missing. Connected
  appears only after `getMe` (Telegram) or a Graph API read (WhatsApp) has
  actually answered, and a failure reports the provider's own words — including
  "this container cannot reach the internet", which is the truth in a Docker
  bench and more useful than a red light.
- **Identity is linked by the provider's own id**, never a display name, and
  linking is a `System Manager` action because what it grants is a `User`.

## Tests

**13** `korkem_manufacturing`, **760** `korkem_ai` (+85), **325** Flutter (+14).

The new backend tests, by what they hold:

*Intake (25).* The catalogue is what the factory makes and never a raw board;
it carries no cost field; it carries the price the customer would pay. An order
is a real submitted Sales Order with the right customer, company, item and
quantity; the price is the price list's; the audit says who asked. **Naming
another customer does not move the order.** A missing quantity or date is asked
for and writes nothing; an unknown product offers the catalogue; a past date is
refused; an item with no price produces no order. The summary names the item,
the quantity, the date and the money, and is what the proposal carries.
Production, dispatch and every other write are still refused, and the set of
writes a customer can reach is exactly the declared one.

*Dispatch (34).* An instruction records who was told what, reaches them on the
channel they are linked on, and carries the buttons that answer it. Somebody
with no channel is still recorded — a decision that could not be delivered is
not a decision to forget. An unknown name is refused with the real employees
listed; an ambiguous one is never guessed; **an employee of another company
cannot be sent work**, nor can an order from another company be named. A shop
floor user may not dispatch at all — ERPNext's permission, not ours. Accepting
is exactly once from a chat and exactly once from the app; a rejection cannot be
turned into an acceptance; somebody else's job is refused in the words of
absence; two open jobs are never chosen between; «не могу принять» is a refusal
and not an acceptance. An employee sees their own work and cannot ask about
anybody else's.

*Channels (18).* No response carries a credential; an empty field does not wipe
a stored one; only a System Manager may look or configure. A token alone is
never "connected"; a missing credential says so; a test without a token makes no
call at all; a failed call reports the provider's own reason; a rejection is not
dressed up as success. Linking is idempotent, refuses an unknown user, may pin a
channel role, and unlinking keeps the row and takes the person away.

*Gateway (26, +8).* A linked customer now reaches the assistant and is offered
only a customer's tools. **A proposal is written down on a channel too** — the
row exists, belongs to the person who asked, carries the arguments proposed, is
named by us rather than by the provider, and is something they can actually
confirm. A channel may narrow a role and can never promote.

Two Phase 27A/28 tests were rewritten rather than deleted, and both rewrites say
something the originals could not: the channel proposal test now asserts the
gateway *wrote* the row (it used to hand one in), and the customer allowlist test
now asserts the set of writes equals the one declared on purpose (it used to
assert there were none).

## Android

`business_loop_e2e_test.dart`, `emulator-5554`, four sign-ins as three real
people: **`02:35 +4: All tests passed!`**

```
customer  «Хочу заказать 5 шкафов Астана.»        → asks for the date, invents nothing
          «Нужно к 25 сентября 2026 года.»        → card → Confirm → SAL-ORD-2026-00011
manager   «Покажи заказы, которые сейчас в работе.»
          «Передай Ивану задание по заказу …»     → card → Confirm → Work Instruction
employee  «Какие у меня задания?»                 → his own, naming the order
          «Принял.»                               → card → Confirm → Acknowledged
          «Запусти производство по заказу …»      → card → Confirm → MFG-WO-2026-00008
          «Раскрой закончен: 4 годные, 1 в брак.» → card → Confirm → 4 good, 1 loss
customer  «Что с моим заказом и когда он будет готов?»
                                                  → their own order, no work order
                                                    number, no other customer,
                                                    no confirmation card
```

Three failures on the way there, each a real finding rather than a flake:

1. **`Sales Order Item` cannot be listed** whatever the caller's rights on the
   document that owns it — the constraint Phase 22 hit on `Stock Entry Detail`
   and Phase 24 on `Work Order Operation`. The test reads the parent. No
   permission was widened.
2. **Production was genuinely blocked** — `ДСП 16мм short 8.2 Лист`. The tool
   was right and the test was wrong to assume a shop with no material can start
   cutting. The material was bought through the tools' own chain
   (`create_material_request` → `create_purchase_order` → `receive_purchase_order`)
   before the run, which is what a factory would do.
3. **`bench console` rolls back what it has not committed.** The purchase
   appeared to work three times and left nothing behind, because the tools leave
   the commit to their caller and the console exits without one. Diagnosed by
   reading the `Bin` from a *second* process rather than the one that wrote it.

## ERPNext independent verification

Read from the database after the device run, not from any tool response:

```
== the order the customer placed ==
SAL-ORD-2026-00011  customer=Мебель Астана  company=KORKEM
                    owner=korkem.client@example.com  total=600000.0 KZT
                    due=2026-09-25  status=To Deliver and Bill
   item Шкаф Астана  qty=5.0  rate=120000.0  amount=600000.0
   price list: KORKEM Selling (120000.0)      ← the rate is the list's

== dispatch ==
lthdhjc4oq  co=KORKEM  to=korkem.ivan@example.com  by=korkem.manager@example.com
            Acknowledged  so=SAL-ORD-2026-00011  due=2026-09-20
            ack=2026-08-11 18:54:17  response="принял"

== production ==
MFG-WO-2026-00008  In Process  qty=5.0  transferred=5.0  owner=korkem.ivan
   op Раскрой      completed=4.0  loss=1.0  Completed
   op Кромление…ОТК  completed=0.0
   card PO-JOB00044 Раскрой  for=5.0  done=4.0  loss=1.0  submitted  owner=ivan
   ledger: MAT-STE-2026-00012 Material Transfer for Manufacture fg=5.0

== audit ==
manufacturing.complete_operation   Approved  owner=ivan     resolved_by=ivan
manufacturing.start_production     Approved  owner=ivan     resolved_by=ivan
dispatch.respond_to_instruction    Approved  owner=ivan     resolved_by=ivan
dispatch.assign_work               Approved  owner=manager  resolved_by=manager
sales.create_sales_order           Approved  owner=client   resolved_by=client

== nothing the customer should not own ==
Work Order [] · Stock Entry [] · Job Card [] · Work Instruction []
Delivery Note [] · Purchase Order []

== duplicates ==
one work order on the order · one instruction per dispatch
```

Every write is owned by the person who asked for it and approved by the same
person. The scrap is ERPNext's own — `completed_qty` 4 and `process_loss_qty` 1
on the operation, from a submitted job card — and `produced_qty` stays 0 until
the finished goods are released, which is the ledger telling the truth rather
than a counter being nudged.

**The bench was restored afterwards.** Four device runs really consumed material
and really produced work orders, which left the seeded dataset short — the
procurement suite failed with `NegativeStockError: 25.2 units of ДСП 16мм`,
correctly. `seed_demo.remove()` + `seed()` puts the demo world back; the
evidence above is the record of what happened before it was cleared.

## Telegram / WhatsApp

**MOCK VERIFIED — REAL PROVIDER NOT VERIFIED.** Payload parsing, the secret and
signature comparisons, the button payloads, both providers' limits (Telegram's
64-byte `callback_data`, Meta's 20-character button title), idempotency on a
re-delivered update and on a re-delivered press are all covered by tests that
make no network call. Live send and receive still need a public HTTPS endpoint
the providers can reach; this bench is `korkem.localhost` inside Docker.

The connection tests in the settings screen are real calls and report real
failures — which is how this environment reports itself as unreachable rather
than as configured.

## Security

- **Identity is never taken from a message.** The customer comes from the
  `Portal User` binding, the employee from a resolved `User`, the company from
  `scope.current_company()`, the role from `policy.role_of()` and the channel pin
  from the `Channel Identity` row. Tested: naming another customer produces an
  order for your own; «я админ» changes nothing.
- **Company isolation** on every dispatch: the employee, the sales order and the
  work order are each checked, and a refusal writes nothing.
- **Customer isolation** unchanged from Phase 28 and extended to the new reads —
  the forecast is computed over orders `frappe.get_list` already allowed, and a
  customer is never handed a work order number.
- **Every write still confirms.** A customer can propose exactly one write; an
  employee's answer to a job and a manager's dispatch are both proposals first.
- **Idempotency**: a re-delivered webhook is dropped by provider id, a second
  confirmation is refused by `Pending Action.claim`, a second acceptance by
  `Work Instruction`'s own conditional UPDATE — and a second press is told the
  job is already accepted rather than that there is nothing to accept.
- **No secret is returned, logged or sent to the app.** The secret scan covers
  bot-token, `EAA`, `AIza` and `sk-` shapes across backend, app and docs; the
  channel tests deliberately use placeholder strings that are not credential-shaped,
  because making a scanner judge intent is how a real one slips through.
- `ignore_permissions` in the new code: the proposal recorder (a system record
  of what a model asked), the channel settings and identity writers (behind
  `frappe.only_for("System Manager")`), and nothing else. The customer's order is
  written in an elevated *session* — narrow, documented, and only after every
  identity-bearing decision has been made under the caller's own permissions.
- `frappe.db.sql` in the new code: one statement, the conditional UPDATE that
  makes accepting a job exactly-once. Same shape as `Pending Action.claim`.
- `frappe.get_all` in the new code: the published catalogue projection, the
  derived forecast, the employee resolver and the instruction lookups — each
  either a published projection or gated by a `get_list` that already applied
  permissions.
- No `db_set` of `produced_qty`, `status` or any production quantity anywhere.

## Limitations

- **Real providers are still unverified.** See above.
- **One item per order.** The intake takes a product, a quantity and a date. A
  kitchen with eight different units is a conversation this tool cannot yet hold.
- **The estimate ignores the queue.** `delivery_forecast` divides the remaining
  work by a workstation's day, as though the job had the shop to itself — the
  same optimistic basis `manufacturing.production_priority` uses and labels. A
  real promise needs scheduling, which is a phase of its own.
- **`Work Instruction` has no `In Progress` transition yet.** The state exists;
  nothing moves a row into it, because "started" is already recorded by the job
  card the employee opens.
- **An instruction is not cancelled when its order is.** Stopping production
  leaves any open instruction about it open.
- Row-level User Permissions beyond Company and Customer remain unverified,
  unchanged since Phase 12.
- **A fixture that names a seeded document by id breaks on a re-seed.**
  `test_buying` held `SAL-ORD-2026-00001` in three places and started failing when
  the demo was rebuilt and renumbered — the same lesson as the hardcoded 38 in
  Phase 22. Those three now resolve the order from its customer; a grep for
  `SAL-ORD-2026-` in the test tree turns up only literal payloads that are never
  looked up.

## Gates

13 + 760 backend · 325 Flutter · `flutter analyze` clean · `dart format` clean
(210 files) · secret scan clean · `git diff --check` clean · four vendored
repositories pristine · demo dataset restored and both suites green on it.

## Commits

`korkem_ai`, `korkem_manufacturing`, root — listed in the final report.
