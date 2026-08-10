# Phase 23 — Scrap / Process Loss / Quality Inspection

**Date:** 2026-08-10. Follows Phase 22 (Production Ledger Integrity).

## What was built

A stage can now be booked as it actually happens: some pieces good, some
spoiled, some not attempted yet. The spoiled ones never become finished goods,
and the last stage will not close without a quality verdict.

```
Раскрой закончен: сделали 4, одну в брак
  → job card: 4 good, 1 process loss, closed
  → later stages capped at 4, the missing unit carried forward
ОТК закончен            → refused: no quality result
ОТК принял              → Quality Inspection, Accepted, submitted
ОТК закончен            → closes
Производство закончено  → 5 started, 1 lost, 4 on the shelf
```

## Tools

| Tool | Change |
|---|---|
| `manufacturing.complete_operation` | **extended** — `scrap_qty`; a stage stays open until every piece is accounted for; quality gate checked before writing |
| `manufacturing.record_inspection` | **new**, WRITE, confirmation — the ОТК verdict |
| `manufacturing.complete_production` | scrap-aware: outstanding excludes spoiled units, carries the verdict onto the entry |
| `manufacturing.shop_floor` | reports `good_qty` / `scrap_qty` / `pending_qty` and inspection state |
| `manufacturing.production_control` | operations carry `scrap_qty` |

Registry: **35 tools**. Nothing was duplicated — the shop-floor tools were
extended.

## ERPNext mechanisms used

Everything below is ERPNext's, not a parallel model:

- **`Job Card.complete_job_card(qty, pending_qty, process_loss_qty, end_time, auto_submit)`** — the whitelisted method the desk button calls. It enforces
  `total_completed_qty + process_loss_qty + pending_qty == for_quantity`.
- **`Job Card.set_process_loss`** — derives the loss; we supply the split.
- **`Work Order Operation.process_loss_qty` / `pending_qty`** — written by the
  card's own `update_work_order`.
- **`Stock Entry.set_process_loss_qty`** — takes the **maximum** loss across the
  operations, not the sum. A unit lost at the saw is the same unit missing at
  every bench after it, so declaring it downstream does not lose it twice.
- **`Job Card.validate_inspection`** — gated on `BOM.inspection_required` **and**
  `Work Order Operation.quality_inspection_required`. Only ОТК is marked, so
  there is no quality gate in front of every cut.
- **`QualityInspectionService.validate_inspection`** — the finished-item row of a
  Manufacture entry.
- **`Quality Inspection`** with `reference_type` Job Card / Stock Entry.

## Scrap, precisely

`total_completed_qty` is **good** output; ERPNext already excludes loss from it.
So `scrap_qty` is the card's `process_loss_qty` and `pending_qty` is what the
arithmetic leaves. Booking four good and one spoiled on a card for five closes
it; booking two of five leaves it open.

**Carry-forward.** ERPNext refuses an operation that completes more than a
previous one did. So the fifth unit of a later stage is not "pending" — it does
not exist. It is carried forward as that stage's loss, which is exactly what the
`MAX` roll-up collapses back to one.

## Quality, and the coupling that shapes it

`BOM.inspection_required` is one switch that gates **two** things: the ОТК job
card, and the finished-item row of every Manufacture entry. You cannot have the
operation gate without the finished-goods gate.

Both are kept. That is how a shop with quality control is configured, and it is
what makes "a failed inspection cannot become finished goods" ERPNext's rule
rather than ours.

A Quality Inspection belongs to **one** document — ERPNext re-points it at
whatever transaction links it — so the ОТК inspection cannot be reused across
releases. `complete_production` therefore reads the ОТК *verdict* and writes it
onto each entry. Nothing is decided there: a rejection is written as a
rejection, and ERPNext refuses the entry.

The planner gained ERPNext's stock **`Quality Manager`** role, which is what
creating and submitting an inspection requires. The viewer deliberately did not.

## Changes to earlier phases — flagged, not silent

1. **A partial stage no longer closes.** Phase 17's `complete_operation(qty=3)`
   on a card for five submitted the card and abandoned the rest. Phase 23
   requires the remainder to be bookable later, so the stage stays open until
   every piece is accounted for. Two Phase 17 tests encoded the old contract and
   were rewritten; a new test pins that a *closed* stage still books nothing.
2. **Releasing now depends on the routing.** Phase 21 recorded that "ERPNext
   permits a Manufacture entry whatever the job cards say" and invented no block.
   Marking the product for inspection makes ERPNext itself impose one: the ОТК
   card cannot carry a verdict until the stages before it are done, and there is
   no release without a verdict. This is configuration, not a rule of ours, but
   it is a real change and the release fixtures now run the floor.

## Defects found and fixed

1. **Releasing the good quantity put fewer goods on the shelf.**
   `fg_completed_qty` is the batch *started*; ERPNext deducts the operations'
   loss from it. Asking for four when five were started with one spoiled put
   **three** on the shelf. Found on the device, not in a test — the one number
   nobody would think to check. The recorded loss is now added back before the
   entry is built.
2. **A refused completion left the card half-written.** ERPNext throws the
   quality error on *submit*, by which point `complete_job_card` has already
   saved the quantities and closed the time log. The gate is now checked before
   the write — the same lesson as Phase 12's orphaned draft.
3. **Synthetic time logs overlapped on a shared workstation.** Three operations
   share the paint-and-assembly bench; a one-hour window invented for each ran
   straight through its neighbours and ERPNext refused the card. A closed card
   now starts where the last job on that bench ended.
4. **`_resolve_card` took the newest work order** when only a sales order was
   named — the silent first-match Phase 22 removed from `complete_production`,
   still present on the shop-floor path. It now refuses and lists candidates.
5. **`_ShopFloorTestCase._clean` deleted every job card on the site**, leaving
   the demo factory with no shop floor after a suite run. Scoped to its own jobs
   — the same shape as the stock-entry sweep Phase 22 found.
6. **`remove()` deleted operations and workstations before the work orders that
   reference them**, so cancelling failed with "Could not find Operation:
   Раскрой". The shop floor now goes last.
7. **`remove()` deleted job cards before the manufacturing entries costed from
   them**, which ERPNext refuses. Reordered.
8. **Quality Inspections accumulated** across re-seeds — fourteen for two work
   orders. `remove()` now clears them, and so does the test fixture.

## Tests

**518** `korkem_ai` (+28), **13** `korkem_manufacturing`, **311** Flutter, **17**
integration. `analyze` clean, `format` clean (201 files), secret scan clean,
`git diff --check` clean, four vendored repositories pristine.

Covering the brief's list: normal completion; partial completion; scrap; partial
then scrap; carry-forward to the next stage; negative scrap refused;
over-request trimmed; quality not required on an uninspected stage; the
inspected stage refuses without a verdict; a refused stage is left untouched; a
passed inspection is a real submitted document; the stage closes once it has
passed; **a failed inspection keeps the goods off the shelf**; a verdict twice
changes nothing; an unreadable verdict refused; confirmation and no `company`
argument; another company's job refused; spoiled units never become finished
goods; `produced_qty` still equals the Manufacture ledger under scrap; the stock
ledger receives four not five; the entry carries ERPNext's computed loss;
releasing again creates nothing; two work orders are never chosen silently for
an operation or an inspection.

Regression: procurement, receiving, company scope, production control, WIP
top-up, job cards, shop floor, capacity, priority, CRM timeline, delivery and
manufacture all pass unchanged. A full suite run leaves the bench identical to
the seed — 5 stock entries, 7 job cards per work order, correct bins.

## Android E2E

`scrap_quality_e2e_test.dart`, `emulator-5554`, `korkem.planner@example.com`
(non-admin): **`02:16 +1: All tests passed!`**

```
Запусти производство по заказу Павлодар Уют.      → card → Confirm
Раскрой закончен: сделали 4, одну штуку в брак.   → card → Confirm
Сколько годных и сколько брака на раскрое?        → 4
Кромление … Сборка закончены                      → card → Confirm ×5
ОТК принял, контроль качества пройден.            → card → Confirm
ОТК закончен.                                     → card → Confirm
Производство закончено, выпусти готовую продукцию.→ card → Confirm
```

## Independent ERPNext verification

Read from the database afterwards, not from the transcript:

```
Work Order Operation — every stage: completed 4.0, process loss 1.0, Completed
Job Card ОТК  PO-JOB00021  4 good · 1 loss · submitted
              quality_inspection MAT-QA-2026-00049
MAT-QA-2026-00049  Job Card    PO-JOB00021          Accepted  owner planner
MAT-QA-2026-00050  Stock Entry MAT-STE-2026-00012   Accepted  owner planner
MAT-STE-2026-00012  Manufacture  fg_completed_qty 5.0  process_loss_qty 1.0
Stock Ledger, Тумба Караганда:  +5 (seed) → 5 ·  +4 → 9
audit  complete_operation · record_inspection · complete_production — all
       Approved, all korkem.planner@example.com
```

Five started, one spoiled, **four** received. The spoiled unit is in the ledger
as loss and nowhere on the shelf.

## NOT VERIFIED

- **Gemini tool routing per question** — the ten device prompts each produced the
  right call, which exercises routing implicitly, but no per-question trace was
  recorded. Unchanged since Phase 20.
- **A failed inspection on the device.** Backend-tested
  (`test_a_failed_inspection_keeps_the_goods_off_the_shelf`); the device run
  passes ОТК.
- **`Stock Settings` set to "Warn"** rather than "Stop" for a rejected
  inspection — the tool reports which it is, but only the default was exercised.
- **BOM scrap items** (by-products with value) and `scrap_warehouse`. Different
  from process loss and not used here.
- **Delivery after scrap on the device** — the shelf figure is asserted, but the
  shipment itself is covered by Phase 22's runs.

## Remaining limitations

- **Carry-forward loss is booked automatically** when a later stage is closed
  without an explicit quantity. It is derived from ERPNext's own cap and
  collapses under `MAX`, and it is reported separately as
  `carried_forward_loss` — but a shop that wants those units left pending
  instead has no way to say so.
- **Rework and corrective job cards** are untouched; a spoiled unit is lost, not
  repaired.
- Row-level User Permissions remain unverified, unchanged since Phase 12.

## Commits

`korkem_manufacturing`, `korkem_ai`, root — listed in the final report.
