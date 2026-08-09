# Phase 20 — Delivery / Customer Fulfilment

**Date:** 2026-08-09. Follows Phase 19 (CRM ↔ Production).

## Goal

Close the chain at the customer. Everything up to finished goods worked; the
timeline's last section was permanently empty because nothing could ship.

## What existed before

`Delivery Note = 0`. `crm.customer_timeline` already read
`Delivery Note Item.against_sales_order` and always reported `none`. No delivery
tool of any kind.

## Audit before implementation

Three findings, one of which changed the plan.

**There was nothing to deliver.** `Finished Goods - KRK` held `actual_qty = 0`
for both products. The seed's `produced_qty` of 6 and 5 was set with `db_set`
and never posted a stock entry, so **`produced_qty` and the stock ledger
disagreed** — a fixture defect that only shows up when something tries to ship.

Producing them for real was rejected: six cabinets consume board this factory
deliberately does not have, and the four-sheet shortage is what half the product
is built on. Instead the finished units arrive as **opening stock through a real
Material Receipt** — how a shop adopting a system mid-order actually onboards.
Labelled as such in the seed, and it leaves 6 against an order for 10, which is
the partial-delivery case.

**`make_delivery_note` exists** in `selling/doctype/sales_order/mapper.py` and
takes `filtered_children` for partial shipments. Used, not reimplemented.

**The planner already has Delivery Note read/create/submit/write** through Stock
User. No permission was widened.

## Tools

| Tool | | |
|---|---|---|
| `sales.delivery_status` | **new**, READ | what is owed, what is on the shelf, what blocks the rest, notes already sent |
| `sales.create_delivery` | **new**, WRITE | ships through ERPNext's mapper, confirmation required |

Registry: **33 tools**. One read tool covers both «что готово к отгрузке» across
the factory and «можно ли отгрузить этот заказ» — the same question at two
scopes, so one tool rather than two that could disagree. `crm.customer_timeline`
needed no change; its delivery section went from `none` to `present` on its own.

## ERPNext reuse

`make_delivery_note` builds the document, carries the link back to the order,
and its submit moves the stock ledger and updates `delivered_qty`. Statuses are
ERPNext's own (`To Bill`, `To Deliver and Bill`) and are reported **beside** our
reading (`READY` / `PARTIAL` / `BLOCKED` / `DELIVERED` / `CLOSED`), not instead
of it.

## Company scope

Both tools use the existing server-side scope and neither accepts a `company`
argument. A foreign order is refused as "not found" on both the read and the
write path — asserted.

## Partial delivery

Bounded by two numbers, and the model supplies neither:

```
pending   = ordered − delivered          (ERPNext's running total)
available = Bin.actual_qty in the order's warehouse
shippable = min(pending, available)
```

`available` is `actual_qty`, never `projected_qty` — projected counts goods on
order and production not yet finished, and a lorry cannot be loaded with either.

Quantities are recomputed at **execution**, not at proposal, and trimmed down.
`LIVE VERIFIED`: asking to ship **400** against an order for 10 with 6 on the
shelf shipped **6** and reported
`adjusted: [{asked: 400, shipped: 6}]`.

## Confirmation flow

Unchanged: proposal → Pending Action → ConfirmationCard → tap → server re-reads
the order and the shelf → `make_delivery_note` → insert → submit → audit.

Replay-safe. Once the shelf is empty the second attempt returns
`nothing_shippable` and writes nothing; once everything is delivered it returns
`already_delivered`.

## Tests

**459** `korkem_ai` (+20), 13 `korkem_manufacturing`, 311 Flutter, 17
integration. `analyze` and `format` clean.

The twenty: shippable is the smaller of owed and on-hand; availability is the
shelf not the projection; ERPNext status is reported beside ours; a partial
shipment sends what exists; the note is real, submitted and linked; the order
records what went out; what is left becomes `BLOCKED` rather than `READY`; over
-request ships what exists; a smaller shipment is honoured; non-positive
refused; an item not on the order refused; a second shipment with an empty shelf
creates nothing; a fully delivered order reports `already_delivered`; unknown
order; a Closed order cannot ship; no company argument; the write needs
confirmation; another company's order is invisible on both paths; the timeline's
delivery section moves `none` → `present`; and a blind spot stays a blind spot.

## Gemini routing

Not separately measured this phase. The Android run's four prompts each produced
the right answer, which exercises routing implicitly; there is no per-question
tool trace recorded, unlike Phases 13–18. Listed under **not verified**.

## Android LIVE VERIFIED

`delivery_e2e_test.dart`, `emulator-5554`, as `korkem.planner@example.com`:
`00:52 +1: All tests passed!`

```
Можно ли сейчас отгрузить заказ Мебель Астана?  → 6 из 10 на складе
Отгрузи.                                        → card → Confirm
Сколько осталось доставить по этому заказу?     → 4
```

## ERPNext VERIFIED

Read from the database afterwards, not from the transcript:

```
MAT-DN-2026-00001  customer Мебель Астана  company KORKEM
  docstatus 1  status To Bill  owner korkem.planner@example.com
  item Шкаф Астана · qty 6 · warehouse Finished Goods - KRK
       against_sales_order SAL-ORD-2026-00001  so_detail 5492f5mr7j
Sales Order   per_delivered 60.0   delivered_qty 6 of 10
Bin Finished Goods  6 → 0
Stock Ledger Entry  1 row for the note
audit  Approved · korkem.planner@example.com · Google Gemini · 13:24:54
```

## Defects found and fixed

1. **`produced_qty` disagreed with the stock ledger.** The seed set it directly
   and posted nothing, so the factory claimed eleven finished units and held
   none. Finished goods now arrive as opening stock through a real Stock Entry.
2. **A test asserted the wrong role model** — that the viewer could not read
   CRM. `Sales User` does grant it; the *planner* is the blind one. The test
   was corrected rather than the permissions.

## What is NOT verified

- **Gemini tool routing per question**, unlike previous phases.
- **A fully delivered order end to end on the device.** Backend-tested; the
  device run leaves the order at 6 of 10.
- **Multi-item and multi-warehouse orders** — every seeded order has one line.
- **Delivery against a customer's several concurrent orders.**
- Shipping to an address; `Delivery Note` carries the customer's default and no
  address handling was added.

## Remaining limitations

- **The finished goods are opening stock, not manufactured output.** Until a
  Manufacture Stock Entry closes a work order, `produced_qty` and the shelf are
  two independent numbers on this bench. Completing production into finished
  goods is a real gap and the natural next step.
- Row-level User Permissions remain unverified, unchanged since Phase 12.

## Blockers

None for this slice.

## Next slice

**Closing production into finished goods** — a Manufacture Stock Entry when the
last operation completes. It removes the opening-stock fixture, makes
`produced_qty` mean something, and is what makes delivery self-sustaining rather
than dependent on stock that was placed there by the seed.

## Commits

`korkem_manufacturing`, `korkem_ai`, root — listed in the final report.
