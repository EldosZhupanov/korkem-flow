# Phase 22 — Production Ledger Integrity

**Date:** 2026-08-10. Follows Phase 21 (Manufacture / Finished Goods).

## Goal

Make the demo factory internally truthful. No `produced_qty` without a stock
movement behind it, no finished goods that no work order made, and no test that
quietly adds either.

## What fake state existed

**`produced_qty` was written with `db_set`.** `seed_demo._work_order` set it to
6 and 5 and posted nothing. **It is not a field we may set.** ERPNext derives it
in `work_order/services/status.py:_update_qty_for_purpose` as

```
Σ Stock Entry Detail.transfer_qty
  where is_finished_item = 1
  and the parent Stock Entry has docstatus = 1, purpose = 'Manufacture',
      work_order = this job
```

and recomputes it on **every** stock transaction touching the job — submit *and*
cancel, from `stock_entry/services/manufacturing.py:804` and
`material_transfer.py:386`. So the fixture value was not merely dishonest, it
was **unstable**: the audit found `MFG-WO-2026-00006` already reset to 0 with
`status` back to `Not Started`, silently, with no error, while `MFG-WO-2026-00005`
still carried its 6 only because nothing had touched it.

`status` was `db_set` too, and is derived by the same service.

**`_finished_goods()` was a manufacturing transaction in a receipt's clothes.**
A Material Receipt labelled "opening stock at go-live" put 6 Шкаф Астана and 5
Тумба Караганда on the shelf — quantities computed from the same `produced`
column that fed the `db_set`. Not an opening balance; the missing Manufacture
entry.

**Test fixtures were topping up the permanent ledger.** `test_delivery.py`
restored the shelf by posting a compensating Material Receipt/Issue after every
run. Ten such entries had accumulated in KORKEM by Phase 21.

**`MFG-WO-2026-00001` (Kitchen Facade)** — a Sprint 1 sample job left behind by
an early run, submitted and "In Process" with no operations, no warehouse and
nothing produced, appearing in every production answer as though real.

## Affected work orders

| | before | after |
|---|---|---|
| `MFG-WO-2026-00005` Шкаф Астана · SAL-ORD-2026-00001 · qty 10 | produced 6 by `db_set`, no entries | produced **6**, two real entries |
| `MFG-WO-2026-00006` Тумба Караганда · SAL-ORD-2026-00002 · qty 20 | produced **0** — ERPNext had erased the seeded 5 | produced **5**, two real entries |
| `MFG-WO-2026-00001` Kitchen Facade | submitted, In Process, in KORKEM | retired |

## What changed

**The seed manufactures.** `_produce(work_order, qty)` posts a
`Material Transfer for Manufacture` and then a `Manufacture` entry through
ERPNext's own `make_stock_entry`. Idempotent — a job that already has a
submitted Manufacture entry is skipped, so `seed()` twice creates nothing twice
(verified: 5 stock entries → 5).

Removed: both `db_set` calls, `_finished_goods()`, and the `produced` parameter
of `_work_order`.

**`remove()` now undoes in reverse chronological order.** A work order cannot be
cancelled while a Manufacture entry stands against it, and opening stock cannot
be reversed before the entries that consumed it.

**`_retire_legacy_work_orders()`** removes stray Kitchen Facade jobs — but only
ones with no stock entry and no job card behind them; anything with a
transaction is real by definition and is kept and reported. The item and BOM
stay: `test_end_to_end.py` is built on them.

## Exact ERPNext documents

Created by the seed (all `docstatus = 1`, company KORKEM):

```
MAT-STE-…-00006  Material Receipt                     opening raw stock
MAT-STE-…-00007  Material Transfer for Manufacture    WO-00005  Stores → WIP
MAT-STE-…-00008  Manufacture                          WO-00005  6 Шкаф Астана
MAT-STE-…-00009  Material Transfer for Manufacture    WO-00006  Stores → WIP
MAT-STE-…-00010  Manufacture                          WO-00006  5 Тумба Караганда
```

Removed: the finished-goods Material Receipt, ten test top-up/restore entries,
one Kitchen Facade work order.

## The valuation defect this uncovered

Every Manufacture failed with *"Valuation Rate for Шкаф Астана is required"*.
The opening stock was created with `basic_rate: 1000` **and**
`allow_zero_valuation_rate: 1`, and the flag wins — ERPNext booked every sheet
at zero. A Manufacture entry values the finished cabinet from the material it
consumed plus operating cost, and material worth nothing gives a cabinet no
value to post.

Invisible for as long as the seed only moved this stock around. The flag is
gone; board that cost nothing was never true anyway. A cabinet now carries
26 200 KZT of material plus its share of 37 520 KZT of routing cost.

## The shortage formula

`_requirements()` asks the Production Plan engine for the **whole order** — ten
cabinets, 42 sheets — while `_reserved_for()` nets `consumed_qty` out of its
side of the subtraction. Symmetrical until something is genuinely made; after
that every produced unit is counted twice, once as material that left the bin
and once as material still to buy.

Measured on the bench inside a rolled-back transaction, producing six for real:

```
                 required  reserved  available  projected   SHORT
before              42.0      42.0      38.0       -4.0       4.0
after (broken)      42.0      16.8      12.8       -4.0      29.2   ← Кромка 48, Петля 12
physical truth: 16.8 needed, 12.8 on hand, short 4.0
```

Fixed by `_consumed_for(order)`, applied in **both** `material_shortage` and
`factory_shortage` so the two can never disagree:

```
remaining_required = max(0, ordered_requirement − consumed)
unreserved         = max(0, remaining_required − reserved)
shortage           = max(0, unreserved − projected_qty)
physical_shortage  = max(0, remaining_required − actual_qty)
```

`_consumed_for` counts **every** submitted work order regardless of status,
unlike `_reserved_for` which looks only at live ones — a finished job reserves
nothing and has consumed everything, and dropping it would restore its whole
requirement to the shopping list the moment it completed.

Two new fields are reported alongside the existing ones rather than replacing
them: `consumed_qty` and `remaining_required_qty`. `required_qty` still means
what the whole order takes, so "нужно всего" and "нужно ещё" can never be read
as the same number.

**Invariant held.** Shortage before and after real production: **4.0**, both
per-order and factory-wide. Кромка and Петля stay at 0.

## Ambiguity guard

`complete_production(sales_order=…)` used to take `(unfinished or jobs)[0]` —
the first work order by creation date. It now refuses when more than one job
could be released and names every candidate with item, produced, remaining and
status. Releasing against the wrong job consumes the wrong material and finishes
the wrong order, and both are real stock movements somebody then has to reverse.

The existing refusal when `sales_order` and `work_order` disagree is unchanged.

## Test fixtures cleaned

| fixture | was | now |
|---|---|---|
| `test_delivery.py` | posted a compensating entry after every run | cancels and deletes its own, tagged `KORKEM test fixture — delivery` |
| `test_production.py` | cancelled **every** transfer and Manufacture entry on the site | scoped to `own_work_orders()` — the one order the tests start |
| `test_buying.py` | restored board to the constant `38.0` | reads the baseline in `setUpClass` |
| `test_factory_shortage.py` | issued a fixed 195 panels | issues down to 5 from whatever is there |

The site-wide sweep in `test_production.py` was the sharpest of these: it
cancelled the seed's own production, took `produced_qty` back to zero and
emptied the shelf, and the *delivery* suite then failed thirty tests later
looking exactly like a delivery bug.

**Proven:** a full 484-test run leaves the bench byte-identical to the seed —
5 stock entries, 2 Manufacture entries, correct bins, no leftover notes,
requests or orders.

## Invariants proved

1. **No code of ours sets `produced_qty`.** One `db_set` of a production
   quantity existed in the codebase; it is gone. A sweep for `db_set`,
   `db.set_value`, direct `Bin` writes and `Stock Reconciliation` finds only
   configuration writes and scoped test-only state.
2. **`produced_qty` == the submitted Manufacture ledger** — asserted per work
   order and across every KORKEM job, computed from transactions, never against
   a seed number.
3. **Work Order status is ERPNext's.** No `db_set("status")` remains.
4. **Manufacture: WIP ↓, Finished Goods ↑** — asserted on the ledger.
5. **Delivery: Finished Goods ↓, Sales Order delivered ↑** — `per_delivered` 60.
6. **Shortage counts remaining, not the original order quantity** — 4.0 either
   side of real production.
7. **Company isolation intact** — 8 scope tests unchanged and passing.
8. **Several work orders on one order are never chosen silently.**
9. **Test-only stock entries no longer accumulate.**
10. **Kitchen Facade is not a KORKEM production job** — `[]`.

Partial manufacture is covered as ERPNext actually allows it: **0 → 2 → 5**
across two entries, plus a cancellation taking the field back down with the
stock.

## Android E2E

`ledger_truth_e2e_test.dart`, `emulator-5554`, as `korkem.planner@example.com`
(non-admin): **`01:06 +1: All tests passed!`**

```
precondition read from ERPNext: produced 6, Manufacture entries sum to 6, shelf 6
Сколько уже произведено по заказу Мебель Астана?  → 6
Сколько осталось произвести по этому заказу?      → 4
Чего не хватает, чтобы доделать заказ?            → 4
Отгрузи то, что готово.  → card → Confirm → shelf 6 → 0
```

The first two answers were `db_set` fiction before this phase; the third would
have read 29.2 without the formula fix.

**Defect found on device:** the test read `Stock Entry Detail` directly and
Frappe refused — *"Insufficient Permission for Stock Entry Detail"* — because a
child table cannot be listed however the user's rights on the parent stand. The
test now reads through the parent document. **No permission was widened.**

## Independent ERPNext verification

Read from the database afterwards, not from the transcript:

```
MFG-WO-2026-00005  qty 10  produced 6.0  ledger 6.0  In Process   OK
MFG-WO-2026-00006  qty 20  produced 5.0  ledger 5.0  In Process   OK

MAT-DN-2026-00001  Мебель Астана  KORKEM  docstatus 1  To Bill
   owner korkem.planner@example.com
   Шкаф Астана 6 from Finished Goods - KRK  against SAL-ORD-2026-00001
SAL-ORD-2026-00001  per_delivered 60.0

Stock Ledger, Шкаф Астана, live rows only:
   +6.0 → 6.0   Stock Entry    MAT-STE-2026-00008   (Manufacture)
   -6.0 → 0.0   Delivery Note  MAT-DN-2026-00001
Bins after: ДСП 12.8 · Кромка 132 · Петля 28 · ЛДСП 190 · Ручка 290
audit  sales.create_delivery · Approved · korkem.planner@example.com
Kitchen Facade work orders in KORKEM: []
```

Two ledger rows for the product, and they are the whole story: production put it
there, delivery took it away.

## What was deliberately NOT changed

- **`MAT-STE-…-00006`, the raw-material opening receipt.** Genuine opening
  stock, a real transaction, and the shortage scenario rests on it.
- **The Kitchen Facade item and BOM**, used by `test_end_to_end.py`.
- **Permissions.** The device defect was fixed in the test.
- **`required_qty`'s meaning** in the tool output.
- **`start_production`** — see below.

## Blocker: a partly-built job cannot be finished

Retiring the fiction made a real gap reachable, and I have not closed it because
it changes Phase 16 behaviour you approved.

`MFG-WO-2026-00005` is In Process with 6 of 10 built and **nothing left in WIP**
— the first run consumed it. Measured on the bench with the missing board
bought:

```
start_production     → already_started, "Production is already running"
complete_production  → ERPNext: "16.8 units of ДСП 16мм needed in Work In Progress"
```

`start_production` only transfers material for jobs in `Not Started`/`Draft`, so
there is no way through the assistant to move the next batch into WIP. This was
invisible before Phase 22 because no job was ever genuinely part-produced.

Options, and what I would do:

- **A — let `start_production` top up a running job** when WIP is short of the
  outstanding quantity. Smallest change, reuses the same mapper and the same
  confirmation, no new tool. Changes a verified Phase 16 return value
  (`already_started` becomes a transfer in this case). **Recommended.**
- **B — a separate `manufacturing.transfer_materials` tool.** Cleanest naming,
  but a 35th tool for a job the existing one nearly does, and two tools that
  could disagree about readiness.
- **C — leave it.** The demo cannot finish the Мебель Астана order.

## Tests and gates

**484** `korkem_ai` (+13), **13** `korkem_manufacturing`, **311** Flutter, **15**
integration. `flutter analyze` clean, `dart format` clean (199 files), secret
scan clean, `git diff --check` clean, four vendored repositories pristine.

The thirteen: `produced_qty` tracks the ledger through 0 → 2 → 5; five units are
two entries not one; cancelling takes the field back with the stock; no KORKEM
job claims unexplained production; consumed material is not asked for again; the
shortage survives real production; a material still held stays off the list; the
two shortage tools agree; two open jobs refuse and list themselves; refusing
writes nothing; naming the job resolves it; one open job is not ambiguous; a job
belonging to another order is refused.

## NOT VERIFIED

- **Gemini tool routing per question** — the four device prompts each answered
  correctly, which exercises routing implicitly, but no per-question tool trace
  was recorded. Unchanged since Phase 20.
- **The buy → receive → build → ship path for the remaining 4 cabinets**, end to
  end on the device. Blocked by the gap above; procurement and receiving are
  covered separately and still pass.
- **Manufacture with a scrap or process-loss item**, and quality inspection.
- **Row-level User Permissions**, unchanged since Phase 12.

## Remaining limitations

- `test_delivery.py` still conjures four cabinets with a Material Receipt for
  the fully-delivered case. They cannot be built for real — the board for them
  is precisely the shortage the rest of the suite is built on — so the entry is
  tagged and reversed rather than offset, and is confined to the fixture.
- Fourteen Job Cards exist for the seeded jobs (7 operations × 2), created by
  ERPNext on submit. Their completion state does not gate manufacture, which is
  ERPNext's own behaviour and unchanged since Phase 21.
- The device run leaves the order part-delivered; resetting is
  `seed_demo.remove(); seed_demo.seed()`.

## Commits

`korkem_manufacturing`, `korkem_ai`, root — listed in the final report.
