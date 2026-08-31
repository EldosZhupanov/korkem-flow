> **АРХИВ. Это не описание системы сегодня.**
> Документ сохранён ради причин, стоящих за решениями. Актуальное состояние — в `NOW.md`, `ROADMAP.md`, `PLAN.md`.
> Не строить по этому файлу.

---

# Phase 15 — Receiving

**Date:** 2026-08-09 · Slice 4. Follows `ai_phase14_procurement.md`.

## Goal

The chain ended at "ordered, expected 22.08". Nothing could say «пришло», so
`available` never moved and production never unblocked — the story the last
three slices built had no ending. This is the ending.

## The scenario, end to end

`LIVE VERIFIED` on `emulator-5554` as `korkem.planner@example.com`:

| | |
|---|---|
| «Что мы сейчас ждём от поставщиков?» | PUR-ORD-2026-00001, 4 листа, Мебельная база Астана |
| «Можно ли сейчас запускать Мебель Астана?» | **нет** — ДСП 16мм, не хватает 4 |
| «ДСП пришла, прими поставку по этому заказу.» | card → Confirm → `MAT-PRE-2026-00001` |
| «Теперь можно запускать Мебель Астана?» | **да** |

Read out of ERPNext afterwards, not from the transcript:

```
Bin ДСП 16мм @ Stores - KRK   actual 38 → 42   ordered 4 → 0
MAT-PRE-2026-00001  docstatus 1  owner korkem.planner@example.com
   ДСП 16мм · received 4 · warehouse Stores - KRK
   purchase_order PUR-ORD-2026-00001 · purchase_order_item ior25ucc54
PUR-ORD-2026-00001  per_received 100%  status To Bill
audit  Approved · korkem.planner@example.com · Google Gemini · 02:13:59
production_readiness  can_start True  blocking []
```

Neither 38 nor 42 is written anywhere in the test: it asserts `before` and
`before + 4`, read from the ledger.

## What was added

**One READ, one WRITE, and two existing tools extended.** The brief suggested
`procurement.pending_receipts` and `procurement.receipt_status`; both would have
duplicated `search_purchase_orders` and `procurement_status`, which already
report pending quantities and overdue deliveries. Duplicating them is the
mistake that cost `production.list_work_orders` its registration in Phase 13,
so instead:

- **`procurement.search_receipts`** (READ, new) — what has actually arrived,
  from whom, into which warehouse. Answers «что пришло сегодня», «пришла ли ДСП
  16мм», «пришёл ли заказ от Мебельная база Астана». Deliberately separate from
  `search_purchase_orders`: *expected* and *arrived* are opposite questions.
- **`inventory.receive_purchase_order`** (WRITE, new) — books the delivery in
  through ERPNext's own Purchase Receipt.
- **`procurement_status`** (extended) — `stage` is now a machine-readable
  vocabulary: `NOT_REQUESTED` → `REQUESTED` → `ORDERED` → `PARTIALLY_RECEIVED` →
  `RECEIVED`, with `received_qty` and `awaiting_qty` beside it. «Заказано» and
  «пришло» are the two words a shop most needs kept apart.
- **`search_purchase_orders`** — unchanged; it already answered «что мы ждём».

Total registered tools: **21**.

## ERPNext relationships

```
Purchase Order .status .per_received
  └─ Purchase Order Item .qty .received_qty
        ▲
        │ Purchase Receipt Item .purchase_order + .purchase_order_item
        │
Purchase Receipt (submitted)  ──→  Stock Ledger  ──→  Bin .actual_qty ↑
                                                       Bin .ordered_qty ↓
```

The document is built by `buying/doctype/purchase_order/mapper.py:make_purchase_receipt`
— ERPNext's own mapper, which carries both links. **No second stock system.**
`Bin.actual_qty` is never written directly: that would leave the ledger
disagreeing with the shelf and every valuation built on it wrong.

## Calculation rules

**The model supplies no authoritative quantity.** Outstanding quantity is
`Purchase Order Item.qty − received_qty`, read at execution. `items` may narrow
a delivery to a partial one, and each line is then trimmed **down** to what is
genuinely outstanding.

`LIVE VERIFIED`: asking to receive **400** sheets against an order for four
booked in **4**, reported `adjusted: [{asked: 400, received: 4}]`, and moved
stock by exactly 4.

**Receiving cannot happen twice.** A second call returns `not_needed` and writes
nothing — booking the same delivery twice invents stock that never arrived,
which is the one error here that a stocktake finds months later.

Partial receiving uses ERPNext's own running totals: ordered 4 / received 1 /
remaining 3, then received 4 / remaining 0. No parallel arithmetic.

## Security

Unchanged in kind. `Risk.WRITE` → create *and* submit checked before insert;
`get_list` throughout; closed schema; no generic HTTP, SQL, shell or raw Frappe
tool. The full chain remains proposal → Pending Action → ConfirmationCard →
explicit tap → server re-reads the order → insert → submit → audit.

**No permission changes were needed.** The planner already holds Purchase
Receipt create and submit through `Stock User` and `Purchase User` — verified
against `DocPerm` before writing anything. The viewer is refused and is not
offered the tool.

Guarded and tested: an unsubmitted or Closed/Cancelled/On Hold order, a
non-positive quantity, an unknown order, a line with no warehouse, a second
receipt, and a viewer attempting the write.

## Tests

**368** `korkem_ai` (+11), 13 `korkem_manufacturing`, 311 Flutter, 12
integration. `analyze` and `format` clean.

The eleven new ones are the six the brief asked for and no more: the whole cycle
unblocks production; the receipt is a real linked document; what arrived is
readable afterwards; over-receiving books only what was ordered; a partial
delivery leaves the rest outstanding; the rest can be received later; a
non-positive quantity is refused; a second receipt creates nothing and invents
no stock; it is a write needing confirmation; an unknown order is a sentence;
a viewer cannot book stock in.

Three Phase 14 tests were updated to the new `stage` vocabulary.

## What is not done

- **Rejected quantities.** ERPNext's `rejected_qty` and rejected warehouse are
  set to zero; a delivery that arrives damaged cannot be recorded as such.
- **Receiving against several orders at once**, and receiving into a warehouse
  other than the one the order names.
- **Purchase Invoice, payment, returns** — out of scope by instruction.
- **Multi-supplier requests** — still refused with an explanation rather than
  split, unchanged from Phase 14.
- Row-level User Permissions — unchanged and still the largest untested part of
  the security claim.

## Commits

`korkem_ai` — receiving tools and tests; root — Android smoke and this report.
