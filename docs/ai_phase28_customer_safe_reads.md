# Phase 28 — Customer-safe reads

**Date:** 2026-08-11. Follows Phase 27A (confirming a write from a chat app).
Option **A** as chosen: a role of our own, bound through ERPNext's own
`Customer.portal_users`.

## Goal

Let a customer ask "где мой заказ?" and be answered — from their own order, and
from nothing else. Until now a customer reached no tools at all, which was safe
and useless.

## The rule this phase is built around

> The customer a read is filtered by comes from the **session**. Never from
> `customer_id`, `customer`, `name` or `customer_name` in the message, in the
> model's arguments, or anywhere else a person can type.

An argument may still *narrow* inside that scope. It can never choose it.

## Two boundaries, neither decorative

`customer_access.py` binds a user to one customer, and does three things in one
function so they cannot come apart:

| | what it is | what it holds if the other is wrong |
|---|---|---|
| `Portal User` row on `Customer` | ERPNext's own User↔Customer binding, read by `website_list_for_contact.get_parents_for_user` | — |
| role `Korkem Customer` + `User Permission` on `Customer` | Frappe's row filter, applied by `get_list` and by document read checks | holds when our Python is wrong |
| `scope.customer_scope()` | pins every customer tool to `current_customer()` | holds when the permission is misconfigured |

ERPNext's stock `Customer` role was not enough and was not extended: it grants
**website portal** access, guarded by `has_website_permission`, which is a
different door from the desk API these tools use — so it carries no desk read on
`Sales Order` at all. Granting it one would have handed every order on the site
to every user holding that role without a matching `User Permission`. Hence a
role of our own, granted **only** by `link()`, which writes the restriction in
the same breath.

`ensure_role()` grants `read` on exactly `Customer`, `Sales Order`,
`Delivery Note` — through `frappe.permissions.add_permission`, which is the
desk's own path. No raw SQL, no `ignore_permissions` on any read, and no
`db_set` of permission-sensitive data. (`ignore_permissions` appears twice, on
creating the `Role` itself, which is an administrator action performed by an
administrator.)

`unlink()` removes the permission **last**: at no instant is there a user who
can read orders and is not restricted to one customer's.

## Tools a customer can reach

`policy.CUSTOMER_ALLOWED` — exact names, never a prefix:

```
sales.search_sales_orders   crm.customer_timeline   profile.current_user
```

Three, out of thirty-seven. Every write is refused before its arguments are even
validated, so a customer cannot produce a `Pending Action` at all.

`sales.delivery_status` is deliberately absent, and the tool said so itself: it
declares `Bin` among its doctypes because it reads what is physically on the
shelf, and a customer call refused with *"You do not have permission to read
Bin"* — ERPNext declining to show warehouse quantities to somebody who buys
cabinets. Granting that read would have made the test pass and the answer wrong.
"Когда доставка?" is answered from the delivery section of
`crm.customer_timeline`, which reads `Delivery Note` and stops.

## The defect the device found: the assistant was still talking to staff

The system instruction opens *"you work for the person you are talking to, who
is a member of factory staff, not a customer"*, and tells the model that an
empty result means *"they have nothing matching, or are not allowed to see it"*.
Correct for a foreman. For a customer it turns an absence into a hint, and the
first device run produced exactly that:

```
«Покажи заказы клиента Караганда Мебель.»
→ «Заказы по клиенту «Караганда Мебель» не найдены
   (или у вас нет доступа к данным этого клиента).»
```

Nothing leaked — no order, no number, no data. But the sentence tells whoever is
asking that there is a door, and repeats the other company's name back as though
it had been looked up.

So `prompt.build(role=...)` now selects `CUSTOMER_INSTRUCTION`, and the role
comes from `policy.role_of()` — the database, never the message. It is politeness
on top of a real boundary, never instead of one: the tools stay pinned and the
rows stay filtered whatever the model says. After the change, on the device:

```
«Покажи заказы клиента Караганда Мебель.»
→ «Среди ваших заказов таких нет.
   У вас оформлен следующий заказ: SAL-ORD-2026-00001 …»

«Что с заказом SAL-ORD-2026-00002?»
→ «Среди ваших заказов нет заказа с номером SAL-ORD-2026-00002. …»

«Запусти производство по моему заказу.»
→ «Запуск производства осуществляется через вашего менеджера на фабрике.»
```

## Tests

**675** `korkem_ai`, **13** `korkem_manufacturing`, **311** Flutter.
19 in `test_customer_scope`, 7 new in `test_prompt`.

The customer-scope nineteen: a linked user resolves to their customer; an
unlinked one is refused, in words that say who to ask; staff are pinned to
nobody; their own orders come back; **naming another customer returns their
own**; the timeline is theirs whatever they name; delivery is answered without
showing the factory's shelf; another customer's order never appears; **Frappe's
own layer refuses it too** — asserted with `frappe.get_list` and
`has_permission`, not `frappe.get_all`, which ignores permissions by design and
would have proved nothing; the refusal names no other customer; every write tool
is refused; the confirmation path is unreachable; linking is idempotent;
unlinking removes all three parts.

The prompt seven: staff get the staff instruction; **no role at all is still the
staff instruction**, so no caller from before this phase changed; a customer is
not told they work at the factory; a customer is never told to blame
permissions; session context is added either way; the planner is staff; somebody
with no factory role is a customer.

### A test fixture that would have deleted the device account

`_CustomerTestCase` created `korkem.client@example.com` and deleted it at
teardown. That is the account the device test signs in as, so running the suite
silently unlinked it. The fixture now remembers what it found and puts it back,
and a test that *wants* an unlinked account calls `_detach()` — the restoring
teardown would otherwise undo what it was setting up, which is exactly how it
failed once fixed the first way.

## Android

`customer_reads_e2e_test.dart`, `emulator-5554`, signed in as
`korkem.client@example.com` — a real customer account, not an administrator:
**`01:09 +1: All tests passed!`**

```
Где мой заказ?                              → SAL-ORD-2026-00001, their own
Покажи заказы клиента Караганда Мебель.     → their own order, other name absent
Что с заказом SAL-ORD-2026-00002?           → absence, no leak words
Запусти производство по моему заказу.       → refused, no ConfirmationCard
getList('Pending Action')                   → PermissionFailure
```

Asserted on the *assistant's* messages, not the transcript: the test makes the
customer type another company's name on purpose, so a whole-transcript
assertion fails on the words the test itself put there. Step 5 asserts the read
is **refused** rather than empty — `Pending Action` is not one of the three
readable doctypes, and a read performed by the customer could not prove the
queue empty either way. That is checked as an administrator afterwards.

### A silent run that was not the app's fault

One run produced no answer at all and waited out its four minutes. Not retried
blindly — the cause is in the bench's own log:

```
2026-08-11 14:40  AI chat turn failed
ProviderUnavailable: generativelanguage.googleapis.com … [Errno 101] Network is unreachable
```

The container had temporarily lost egress. Five probes after it recovered
returned 404 (reachable), and the next run passed on unchanged code. Recorded
because "the assistant went quiet" has meant a real defect twice in this
project, and this time it did not.

## ERPNext independent verification

Read from the database after the device run, not from any tool response:

```
roles              ['All', 'Customer', 'Guest', 'Korkem Customer']
portal rows        ['Мебель Астана']
user permissions   [{'allow': 'Customer', 'for_value': 'Мебель Астана',
                     'apply_to_all_doctypes': 1}]

owner / modified_by == the customer, across every writable doctype:
  Pending Action []  Sales Order []  Delivery Note []  Work Order []
  Stock Entry []     Material Request []                Job Card []

Pending Action queue        []          ← the customer produced none
Sales Orders                all three still To Deliver and Bill,
                            modified_by Administrator only
```

Earlier, on the boundary itself:

```
DocPerms      Customer / Sales Order / Delivery Note — read only, no write,
              no create, no delete, no submit
get_list      Sales Order ['SAL-ORD-2026-00001']   Customer ['Мебель Астана']
has_permission own True · other False
write own False · create False · read Bin False · read Work Order False
after unlink  roles ['Customer'] · UserPermission [] · portal []
              get_list → PermissionError
```

## Security

- The customer is resolved from the session; every customer tool pins to it, and
  an argument can only narrow within it.
- Two independent layers, both tested, either sufficient.
- Absence and refusal are worded identically — a customer is never told that an
  order exists and belongs to somebody else.
- Writes are refused **before** argument validation, so a rejected write reveals
  nothing about the schema either.
- No `ignore_permissions` on any read, no raw SQL, no `db_set` of anything
  permission-sensitive.
- Company scoping unchanged and still server-side.

## Limitations

- **Linking is a function, not a screen.** `customer_access.link(user, customer)`
  is run by an administrator from the console; there is no desk UI for it yet.
- **One customer per user.** `current_customer()` takes the single `Portal User`
  row; somebody buying under two companies is not modelled.
- The channel side is unchanged: a customer on Telegram or WhatsApp still
  reaches the sales router unless an administrator has linked their identity.
- The wording of a refusal is the model's, and is not pinned by an assertion —
  what must *not* appear is pinned instead. A reworded refusal passes; a leaking
  one does not.
- `crm.customer_timeline` returns the customer's own name, which is correct, but
  no test yet asserts that a *deal* in it cannot be another customer's.

## Gates

675 + 13 backend · 311 Flutter · analyze clean · format clean (205 files) ·
secret scan clean · `git diff --check` clean · four vendored repositories
pristine.

## Commits

`korkem_ai`, root — listed in the final report.
