# Phase 26 — Stopping and resuming a job

**Date:** 2026-08-11. Follows Phase 25 (Parallel Production & Rework).

## Goal

Let a job be halted and put back to work. A shop needs this more often than it
would like: a customer postpones, a board turns out to be the wrong colour, a
machine goes down.

## What existed

Thirty-six tools, and every one of them moved a job **forwards**. There was no
way to stop one. A cancelled or postponed order therefore kept:

- asking for material in `inventory.factory_shortage`,
- holding `reserved_qty_for_production` that another order could have used,
- taking a slot in `manufacturing.production_priority`,

for as long as the work order existed. The only alternative was the desk.

## What changed

One tool, `manufacturing.stop_production`, doing both directions — the same
shape as ERPNext's own `stop_unstop(work_order, status)`, which is one method
for Stop and Resume rather than two.

Stopping frees the material the job was holding. **Nothing is un-made:**
`produced_qty`, `material_transferred_for_manufacturing` and every stock entry
are untouched. Stopping stops a job going further; it does not reverse it.

The existing guard in `complete_production` (`if job.status in ("Stopped",
"Closed", "Cancelled")`) already refuses to produce against a stopped job, so
the two halves meet without a new rule.

## Tools

| Tool | | |
|---|---|---|
| `manufacturing.stop_production` | **new**, WRITE, confirmation | halt a job or put it back to work |

Registry: **37 tools**. `action` takes the words a foreman uses — «останови»,
«приостанови», «возобнови», «продолжай», «верни в работу» — and resuming is
matched before stopping, because of the two ways to misread an instruction only
one interrupts a running floor.

Also **removed a duplicate resolver**: the work-order-from-sales-order lookup
with its ambiguity refusal now lives in `_the_only_job`, shared by
`complete_production` and `stop_production` rather than written twice.

## ERPNext mechanism used

- **`work_order.stop_unstop(work_order, status)`** — the whitelisted method the
  desk's Stop button calls. It checks `write` permission itself, calls
  `update_status` and `update_planned_qty`.
- **`update_planned_qty`** is what releases the reservation. Measured: 30 → 0 on
  both materials when stopped, 0 → 30 when resumed.
- `Bin.reserved_qty_for_production`, read either side of the call rather than
  predicted.

Nothing about status or reservation is computed here.

## Tests

**131/131** production module (+16), **565** `korkem_ai`, **13**
`korkem_manufacturing`, **311** Flutter, **20** integration. Green on the first
run.

The sixteen: a running job can be stopped; stopping releases the material it was
holding; resuming takes it back; stopping unmakes nothing; stopping twice moves
nothing twice; resuming a running job says so; a stopped job cannot be produced;
a stopped job leaves the priority queue; the shortage stays truthful after a stop
(invariant J, no negative or double-counted figure); confirmation required and no
`company` argument; an unreadable intent refused; an unknown work order; another
company's job refused; a job belonging to another order refused; naming only the
order works when it has one job; **two jobs on one order are never chosen
silently** — and the job is still running afterwards, so the refusal wrote
nothing.

Teardown verified: after the full suite the bench is byte-identical to the seed —
WIP empty, stores unchanged, both work orders `In Process`.

## Android

`stop_production_e2e_test.dart`, `emulator-5554`, `korkem.planner@example.com`
(non-admin): **`01:13 +1: All tests passed!`**, first run.

Four routed calls, four different phrasings, to show the routing is not one
memorised sentence:

```
Останови производство по заказу Караганда Мебель — клиент перенёс сроки.
   → card → Confirm → Stopped · reserved 60 → 0
Возобнови производство по этому заказу.
   → card → Confirm → In Process · reserved 0 → 60
Приостанови этот заказ, станок сломался.
   → card → Confirm → Stopped · reserved → 0
Верни его в работу.
   → card → Confirm → In Process · reserved → 60
```

Every one selected `manufacturing.stop_production` and was accepted by the
schema — the failure class Phase 25 found (a natural argument a closed schema
rejects) did not recur.

## ERPNext verification

Read from the database after the device run, not from the tool response:

```
Work Order MFG-WO-2026-00006  qty 20.0 · produced_qty 5.0 · process_loss 0.0
                              status In Process
   Manufacture ledger 5.0 — matches produced_qty
Bin reserved_qty_for_production  ЛДСП 18мм 30.0 · Ручка 30.0
Bin actual_qty (Stores)          unchanged: ДСП 12.8 · Кромка 132 · Петля 28
                                 ЛДСП 190 · Ручка 290
WIP                              empty
Stock Entries against the job    2 — unchanged by four stop/resume calls
audit  stop_production ×4 · Approved · korkem.planner@example.com
```

Four halts and restarts moved **no stock at all** and left `produced_qty` on the
ledger's number. That is the correct result: a stop is a change of intent, not a
transaction.

## Defects found and fixed

None new. The one thing worth recording is a near miss: matching «останови»
before «возобнови» would have read «не останавливай» as a stop. Resuming is
checked first for the same reason Phase 24 checks failure before success.

## Security

- Company scoping via `ensure_company`; another company's job is "not found".
- No `company` argument on the tool.
- Permission is ERPNext's own — `stop_unstop` raises `PermissionError` without
  `write`, and `job.check_permission("write")` runs first for a clearer message.
- Ambiguity refused, never resolved by first match; the refusal is asserted to
  leave the job running.
- No stock mutation, no `db_set` of any production field.

## Limitations

- **`Closed` is not offered.** ERPNext refuses to stop or reopen a closed work
  order, and closing one is a different decision from pausing it.
- A stopped job still appears in `production_control` and
  `crm.customer_timeline` with its status. That is correct — it exists and
  somebody should see it — but neither view calls attention to *why* it stopped;
  `reason` is recorded in the audit trail only.
- Stopping does not return material already in work-in-progress to the store.
  Nothing is stranded on the current data, so this is not yet a real gap.

## Gates

analyze clean · format clean (204 files) · secret scan clean ·
`git diff --check` clean · four vendored repositories pristine · no
`db_set` of `produced_qty` or `status` anywhere · teardown clean.

## Commits

`korkem_ai`, root — listed in the final report.

## Next logical slice

**Returning unused work-in-progress material to the store.** A job stopped or
closed short leaves the material transferred for the units it will now never
build sitting in WIP, where it is invisible to the shortage report and unusable
by any other order. ERPNext's `Material Transfer` is the mechanism. It does not
bite on today's data — every seeded job consumes exactly what it transferred —
but it is the first thing a real shop would hit after stopping a job mid-batch.
