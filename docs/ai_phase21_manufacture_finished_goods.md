# Phase 21 — Manufacture / Finished Goods

**Date:** 2026-08-10. Follows Phase 20 (Delivery / Customer Fulfilment).

## Goal

Close production into stock. Until now a completed operation recorded that work
*happened* and put nothing on a shelf, so the goods Phase 20 shipped had to be
seeded as opening stock.

## Before

`produced_qty` was set on the seeded work orders with `db_set` and no stock
entry was ever posted, so the factory claimed eleven finished units and the
Finished Goods warehouse held none. Phase 20 papered over it with a Material
Receipt — honest as an opening balance, but it meant delivery could never be
demonstrated on goods this factory actually produced.

## What changed

One WRITE tool. A **Manufacture** stock entry now drains work-in-progress,
receives the finished units, and moves `produced_qty` — so the number and the
ledger are the same fact.

## ERPNext native flow used

`manufacturing/doctype/work_order/mapper.py:make_stock_entry(work_order,
"Manufacture", qty)` — the same function the WIP transfer already used. It sets
`purpose`, `fg_completed_qty`, drains `wip_warehouse` per the bill of materials,
receives into `fg_warehouse`, and carries the routing's operating cost. Its
submit updates `produced_qty` and the work order status. Nothing is
reimplemented.

**ERPNext permits a Manufacture entry whatever the job cards say.** No block was
invented on top of that; the tool reports the current operation and how many are
outstanding so a person can judge.

## Tools

`manufacturing.complete_production` — WRITE, confirmation required. Registry:
**34 tools**.

No read tool was added: «сколько можно сейчас выпустить» is
`remaining_qty` per work order, which `manufacturing.production_control` already
returns.

## Confirmation

The existing chain, unchanged: proposal → Pending Action → ConfirmationCard →
tap → server re-reads the work order → `make_stock_entry` → insert → submit →
audit. Nothing moves before the tap.

## Partial production

`LIVE VERIFIED` on the bench: release 2 of 5 → `produced_qty` 0 → 2, Finished
Goods 5 → 7, WIP 10 → 6, work order still `In Process`. Then release the rest →
`produced_qty` 5, WIP 0, status `Completed`.

## Idempotency

Asking for 400 against 3 remaining released **3**, reported
`adjusted: true, requested_qty: 400`. A further attempt on a finished job
returns `already_complete` and creates no second entry — that would put units on
a shelf that were never built.

## Company security

`ensure_company` on both the sales order and the work order; no `company`
argument on the tool. Another company's work order is refused as "not found".

**A new guard, added because the device run found the need for it:** if the
model names both a sales order and a work order and they disagree, the tool
refuses. Two customers order the same product here, so "выпусти Тумбу
Караганда" is genuinely ambiguous, and releasing against the wrong job would
consume another order's material.

## LIVE VERIFIED

`manufacture_e2e_test.dart`, `emulator-5554`, as `korkem.planner@example.com`:
`01:00 +1: All tests passed!`

```
Производство по заказу Павлодар Уют закончено, выпусти готовую продукцию.
   → card → Confirm → produced 5, status Completed, shelf +5
Можно отгрузить этот заказ?   → 5
Отгрузи.                      → card → Confirm → shelf back to where it started
```

The shelf reading before and after is the whole assertion: production must put
stock there and delivery must take it away.

## ERPNext VERIFIED

```
Work Order MFG-WO-2026-00007  qty 5  produced_qty 5  status Completed  KORKEM
MAT-STE-2026-00011  Material Transfer for Manufacture  Stores → WIP  10 + 10
MAT-STE-2026-00012  Manufacture   docstatus 1  owner korkem.planner@example.com
    Ручка       10  from Work In Progress - KRK
    ЛДСП 18мм   10  from Work In Progress - KRK
    Тумба Караганда 5  into Finished Goods - KRK
WIP after            ЛДСП 0 · Ручка 0
Delivery Note MAT-DN-2026-00001  Павлодар Уют  docstatus 1  owner planner
Sales Order SAL-ORD-2026-00003  status To Bill  per_delivered 100
audit  Approved · korkem.planner@example.com · Google Gemini · 01:48:10
```

## Stock Ledger

Stock Ledger Entries exist for both entries against this work order. WIP went
10 → 0 and Finished Goods rose by exactly the released quantity, then fell by
exactly the delivered quantity.

## Delivery regression

The Phase 20 delivery tests are unchanged and still pass on opening stock. A new
test — and the device run — prove the same delivery path works on goods that
were genuinely manufactured: `TestManufacturedStockCanBeDelivered` releases,
then ships, and asserts the shelf returns to where it started.

## Tests

**471** `korkem_ai` (+12), 13 `korkem_manufacturing`, 311 Flutter, 18
integration. `analyze` and `format` clean.

The twelve: a completed operation alone puts nothing on the shelf; releasing
moves material out of WIP and goods onto the shelf; `produced_qty` matches the
ledger; the entry is a real Manufacture document; the rest can be released
later; asking for more than is left releases what is left; releasing a finished
job creates no second entry; non-positive refused; it is a write needing
confirmation; unknown work order; another company's job refused; manufactured
stock can be delivered.

## Defects found and fixed

1. **Every Manufacture failed with "Account is required" — after the stock
   ledger had already posted.** The routing's hourly rates from Phase 18 make
   the entry carry a real operating cost (31 266 KZT), and ERPNext needs an
   account for it. `KORKEM` had none, and the `Workstation Operating Component`
   created in Phase 18 had no account either. Both are now set from the
   company's own `Expenses Included In Valuation` account. Ordinary ERPNext
   setup for a manufacturer on perpetual inventory, not a workaround.
   *(`Company.expenses_included_in_valuation` does not exist in ERPNext 17 —
   the field is `default_operating_cost_account`, plus a per-component account.)*
2. **Ambiguous product naming released against the wrong job.** Two orders make
   Тумба Караганда; the model named the product and picked the other order.
   ERPNext refused correctly ("20 units needed in WIP"), and a guard now
   catches the disagreement explicitly.

## Not verified

- **Gemini tool routing per question**, as in Phase 20 — the device prompts
  answered correctly but no per-question tool trace was recorded.
- **Releasing more than WIP holds.** ERPNext refuses it (observed during the
  audit), but there is no test pinning that message.
- **Job-card state as a gate.** ERPNext does not enforce it and neither does
  this tool; whether it *should* is a product decision, not a defect.
- Scrap, process loss, quality inspection on the finished item.

## Remaining limitations

- **The two narrative work orders still carry a `db_set` `produced_qty`** (6 of
  10 and 5 of 20) with no ledger behind them, and Phase 20's opening stock is
  still in place. Rewriting those would consume board the shortage story depends
  on. The real Manufacture path is proven on the third order, which goes
  through transfer → operations → manufacture → delivery entirely for real.
- Row-level User Permissions remain unverified, unchanged since Phase 12.

## Gates & commits

Backend 471 + 13, Flutter 311, integration 18. `analyze`, `format`, secret scan
clean; four vendored repos pristine. Commits listed in the final report.
