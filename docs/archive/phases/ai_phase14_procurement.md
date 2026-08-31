> **АРХИВ. Это не описание системы сегодня.**
> Документ сохранён ради причин, стоящих за решениями. Актуальное состояние — в `NOW.md`, `ROADMAP.md`, `PLAN.md`.
> Не строить по этому файлу.

---

# Phase 14 — Procurement

**Date:** 2026-08-09 · Slice 3. Follows `ai_phase13_factory_materials.md`.

## Goal

The chain stopped at «заявка создана». Nobody could ask what was actually
ordered, from whom, for how much, or when it lands — and nobody could tell the
difference between material that had been *bought* and material that was *on the
shelf*. Slice 3 carries it to a real Purchase Order and to knowing where every
shortage has got to.

## User journeys

Asked live as `korkem.planner@example.com`:

| Question | Tool | Answer |
|---|---|---|
| «Что сейчас заказано у поставщиков?» | `search_purchase_orders` | none yet, and the open request that has no order |
| «Какие заявки на закупку ещё не закрыты?» | `search_material_requests` | MAT-MR-2026-00001, Pending, 4 листа not ordered |
| «Что из необходимого ещё не заказано?» | `search_material_requests` | same, with the required-by date |
| «Какие закупки блокируют производство?» | `procurement_status` | ДСП 16мм — 4, blocks SAL-ORD-2026-00001, stage named |
| «Создай заказ поставщику по этой заявке.» | `create_purchase_order` | card → PUR-ORD-2026-00001 |
| «Что уже заказано и когда придёт?» | `search_purchase_orders` | 4 листа, Мебельная база Астана, 22.08 |

## Tools

Four, all `procurement.*`, in `tools/buying.py`:

- **`search_material_requests`** — READ. Requests with `ordered_qty`,
  `received_qty`, `pending_qty` per line and the purchase orders raised against
  them. `only_unordered` answers «что ещё не заказано».
- **`search_purchase_orders`** — READ. Orders with supplier, `received_qty`,
  `pending_qty`, expected date, overdue and days late. `arriving_within_days`
  answers «что придёт на этой неделе»; `overdue_only` answers «просроченные».
- **`procurement_status`** — READ, the aggregator. Adds the shortage → request
  → order trace.
- **`create_purchase_order`** — WRITE, confirmation required.

## ERPNext relationships

Read off the running bench (ERPNext 17.0.0-dev), not from documentation:

```
Material Request (docstatus 1, type Purchase)
  └─ Material Request Item .ordered_qty / .received_qty / .stock_qty
        ▲
        │ Purchase Order Item .material_request + .material_request_item
        │
Purchase Order (.supplier, .schedule_date, .per_received, .status)
  └─ Purchase Order Item .qty / .received_qty / .rate
        ▲
        │ Purchase Receipt
        ▼
Bin .actual_qty ↑   .ordered_qty ↓
```

`material_request_item` is the row-level link, and it is what makes fulfilment
track per line rather than per document.

**The order is built by ERPNext's own mapper**,
`stock/doctype/material_request/mapper.py:make_purchase_order`. It validates the
request is submitted and of type Purchase, skips lines already fully ordered,
carries both links, and resolves rates. Nothing about that is reimplemented.

## Calculation rules

**Ordered is not received, and neither is available.** Four quantities, never
collapsed: *required*, *available* (`actual_qty`), *ordered* (on a submitted PO,
not here), *received* (arrived, now part of available). Measured on the device
run: placing the order moved `ordered_qty` 0 → 4 and left `actual_qty` at 38.
Production stayed blocked, correctly.

That distinction produced a **real defect in this slice's own aggregator**,
found by running it rather than by reading it. `procurement_status` first built
`blocking_production` from `factory_shortage`, which answers *"do we need to buy
more"* — and raising a request takes that to zero. So the moment somebody asked
to buy the board, the system reported **nothing was blocking production** while
the floor still could not cut. `factory_shortage` now reports
`physical_shortage_qty` and `on_order_qty` alongside `shortage_qty`, and the
aggregator reads the physical one.

**Statuses are ERPNext's.** `Material Request.status` (Pending / Partially
Ordered / Ordered / Partially Received / Received) and `Purchase Order.status`
are passed through. Only derived facts — pending quantity, days overdue — are
computed here, from ERPNext's own running totals.

**Overdue** means goods are late, not paperwork: the promised date has passed
*and* something is still outstanding. Days late are counted server-side.

**Dates** come from the request; a date in the past is moved to today, because
ERPNext refuses an order due before it was written and back-dating a purchase
does not un-late it.

## Security

**Nothing is invented.** The supplier comes from `Item Default.default_supplier`
or `Item Supplier`; with none set, the tool returns `supplier_unknown` and names
the items rather than picking one of the bench's ten suppliers — a purchase
order is a letter to a real business. The price comes from the supplier's own
price list through `get_party_details` + `set_missing_values`; with none, it
returns `price_unknown` rather than sending an order at zero.

**The model supplies no quantity at all.** `create_purchase_order` takes a
request name and nothing else — quantities come from the request's outstanding
lines. There is no number for a model to get wrong.

Permissions are unchanged in kind: `get_list` throughout, create *and* submit
checked before insert, closed schema. The planner gained **`Purchase User`** —
a stock ERPNext role, and a deliberate widening recorded in the seed: placing
the order is the other half of noticing the shortage. The viewer did not, and
`Sales User` grants no Material Request permission at all, so that user sees no
procurement whatsoever — asserted rather than worked around.

## Confirmation

Unchanged generic chain: proposal → Pending Action → ConfirmationCard →
explicit tap → server re-reads the request → insert → submit → audit.

Re-read at execution, not trusted from the proposal: if the request has since
been fully ordered the tool returns `not_needed` and writes nothing; if it was
cancelled it refuses.

## Android verification

`LIVE VERIFIED` — `purchase_order_e2e_test.dart`, `emulator-5554`, signed in as
the planner: `00:40 +1: All tests passed!`

Verified independently in ERPNext:

```json
{"name": "PUR-ORD-2026-00001", "supplier": "Мебельная база Астана",
 "status": "To Receive and Bill", "docstatus": 1,
 "owner": "korkem.planner@example.com", "grand_total": 39200.0,
 "currency": "KZT", "schedule_date": "2026-08-22"}
  item: ДСП 16мм · qty 4.0 · rate 9800.0 · amount 39200.0
        material_request: MAT-MR-2026-00001
        material_request_item: 3gujujit6s
audit: Approved · korkem.planner@example.com · Google Gemini · 01:53:24
```

0 orders before the tap, 1 after, replay refused, and the test cancels and
deletes what it created.

## What was actually verified

`LIVE VERIFIED` — the six questions and their routing; the order placed from the
device with supplier and price resolved from ERPNext; `ordered_qty` rising while
`actual_qty` did not; the shortage → request → order trace at all three stages.

`TEST VERIFIED` — **357** `korkem_ai` (+27), 13 `korkem_manufacturing`, 311
Flutter, 11 integration. New tests cover: open requests and pending quantities;
the request drops out once fully ordered; both link directions including the
row-level one; ordered puts nothing on the shelf; production still blocked after
ordering; received *does* reach the shelf; partial receipt leaves the remainder
outstanding; overdue and the arrival horizon computed server-side; the three
trace stages; supplier and price refused rather than invented; unknown supplier
refused; the tool exposes no quantity argument; a fully-ordered or cancelled
request creates nothing; the viewer sees no procurement at all.

## Not verified

- **Multi-supplier requests.** A request whose items come from different
  suppliers is refused with an explanation; splitting it into one order per
  supplier is not implemented.
- **Purchase Receipt from the assistant.** Receipts are exercised in tests to
  prove the ordered/received distinction; there is no tool to book one in.
- **Multi-item purchase orders** end to end. The mapper handles them and the
  code loops; every run ordered one material.
- **A supplier with a different currency** to the company.
- Row-level User Permissions — unchanged and still the largest untested part of
  the security claim.

## Defects found

1. **The aggregator said nothing was blocking production** the moment a request
   was raised (above). Fixed by separating physical from procurement shortage.
2. **Every order came out free.** `set_missing_item_details` only fills fields
   that are `None`, and the mapper leaves `rate` at `0.0` — so the price list
   was consulted and its answer discarded. Rates are cleared before
   `set_missing_values`, and totals are calculated before the price is checked.
3. **A test receipt leaked 4 sheets of stock** and every later test failed with
   a shortage that no longer existed. The suite now restores the seeded level.

## Next product slice

**Receiving.** The chain now ends at "ordered, expected 22.08" and there is no
way to say «пришло». Until a receipt can be booked, `available` never moves and
production never unblocks — which makes it the next thing the workflow needs,
and it reuses the whole trace built here.
