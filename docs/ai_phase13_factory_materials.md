# Phase 13 — Factory Materials & Shortage

**Date:** 2026-08-09 · Slice 2 of the product build. Follows
`ai_phase12_real_user_production_control.md`.

## Goal

Everything before this answered questions about **one order**. A production
manager's morning is the opposite shape: what is short, what to buy, what to
start. A user could be told «по заказу Мебель Астана не хватает 4 листов ДСП»
and still have no way to learn that other orders need the same board, or that
one purchase would cover them all.

Slice 2 adds a factory-wide shortage read and a consolidated purchase request.

## User journeys

All six asked live, as `korkem.planner@example.com` (no administrative role).
Every one routed to a **single** tool — no overlapping calls:

| Question | Tool | Answer |
|---|---|---|
| «Что сейчас не хватает на складе?» | `inventory.factory_shortage` | ДСП 16мм — 4 листа, блокирует SAL-ORD-2026-00001 |
| «Какие материалы нужно купить на этой неделе?» | same, `within_days=7` | «На этой неделе дефицита нет», then what is due later |
| «Какие заказы блокируются из-за материалов?» | same | 1 заказ, named, with its delivery date |
| «Какой материал самый критичный?» | same | ДСП 16мм, severity `medium`, with the numbers |
| «На сколько заказов не хватает этого материала?» | same | 1 |
| «Покажи все критические материалы.» | same | «критических нет», one medium |
| «Создай заявку на закупку всего необходимого.» | `create_material_request` | card → `MAT-MR-2026-00001` |

## Tools

**`inventory.factory_shortage`** — READ, no confirmation. Optional
`within_days` (server-side horizon) and `limit` (≤20 orders). Returns per item:
`total_required`, `available_qty`, `projected_qty`, `shortage_qty`, `uom`,
`warehouse`, `orders_blocked[]` with customer and delivery date,
`earliest_required_date`, `days_until_required`, `lead_time_days`, `severity`.

**`inventory.create_material_request`** — WRITE, confirmation required.
`sales_order` is now **optional**: given, quantities are checked against that
order's shortage; omitted, against the factory's. Accepts one item or many, in
one document. The single-item flow is unchanged and still tested.

**`production.list_work_orders` deregistered.** It and
`manufacturing.search_work_orders` read the same doctype; in a live run Gemini
called both in one turn, spending a round trip to learn nothing. The canonical
tool is `manufacturing.search_work_orders` (filters by order and item, returns
`remaining_qty`). The Python function stays — `production_readiness` calls it
directly — and the mobile client still maps the old name to a progress label so
older transcripts read correctly. Registered tools remain **19**.

## Calculation rules

**Per-order shortages cannot be added.** `projected_qty` is one shared pool, so
two orders each needing 30 against 40 in stock each report 0 while the factory
is 20 short. Subtracting availability once per order is wrong the other way.
Demand is aggregated first and availability subtracted **once**:

```
unreserved_demand = Σ over orders of max(0, required_i − reserved_i)
shortage          = max(0, unreserved_demand − projected_qty)
```

With a single order this reduces exactly to the per-order formula — the
no-double-subtraction property, asserted directly (`factory == per-order == 4`).

Pooled by **(item, warehouse)**: the same board in two stores is two
availabilities, and adding them claims stock that cannot be moved.

**Severity** is data only — how short, how many orders it stops, how soon they
are due, whether any is already late. `critical` if overdue or due within 3
days; `high` at 3+ blocked orders or due within 7; `low` when no date is known;
`medium` otherwise.

**Requirement, units and availability all come from ERPNext's Production Plan
engine** — the same one `material_shortage` uses, so the overview and the
purchase can never disagree. `active_sales_orders()` is now one function shared
with `production_control`, so "active order" has one definition.

**Quantities are decided at execution, not at proposal.** They are clamped
**down** to the live shortage, never up. If everything clamps to zero, nothing
is written and the result is `status: not_needed`. `requested_qty` and
`adjusted` are returned so the model tells the user the number moved.

*This replaces Phase 11's refusal-on-over-request.* Refusing was correct for a
hallucinated 400 and wrong for the case that actually happens — stock moving
between the proposal and the tap — where it left the user with nothing and a
puzzle. Clamping covers both, and the database still decides the number.

**Dates are real.** `schedule_date` comes from the `delivery_date` of the orders
the material blocks, not `today + 7`. `Item.lead_time_days` is reported when set
and never used to invent a date; it is unset on every item on this bench.

## Security

Unchanged contracts. `Risk.WRITE` → create **and** submit checked before insert
(no orphan drafts); `frappe.get_list` throughout, never `get_all`, so a user
sees what they can see; closed schema, no escape hatch; the confirmation chain
and audit are the existing generic ones, untouched.

Verified: the planner can read and buy; the viewer can read the same factory and
is refused the write, with the tool not offered.

## Android verification

`LIVE VERIFIED` — `factory_materials_e2e_test.dart`, `emulator-5554`, signed in
through the real login form as the planner:

```
01:10 +1: All tests passed!
```

Three prompts, none naming an order, material or quantity; the card rendered
with the material spelled out; 0 requests before the tap, 1 after, 1 after a
replayed confirmation.

Verified independently in ERPNext afterwards:

```json
{"status": "Approved", "owner": "korkem.planner@example.com",
 "resolved_by": "korkem.planner@example.com",
 "provider": "Google Gemini", "model": "gemini-flash-latest",
 "executed_at": "2026-08-09 00:59:34", "error": null}
result: {"material_request": "MAT-MR-2026-00001", "sales_order": null,
         "items": [{"item_code": "ДСП 16мм", "qty": 4.0, "uom": "Лист",
                    "needed_by": "2026-08-22", "adjusted": false,
                    "blocking_orders": ["SAL-ORD-2026-00001"]}]}
```

`sales_order: null` is the point — a factory-wide request that still cites the
order it unblocks. Material Requests remaining afterwards: **0** (the test
cleans up).

## What was actually verified

`LIVE VERIFIED` — the six questions above and their tool selection; the
consolidated request on a device; factory-wide numbers on real ERPNext data;
the audit row.

`TEST VERIFIED` — **330** `korkem_ai` (+21), 13 `korkem_manufacturing`, **311**
Flutter (+3), 10 integration. The 20 new backend tests cover: factory == per-order
for a single-order material; pooling across orders; well-stocked material
excluded; blocked orders named with dates; earliest date; lead time reported only
when set; severity from data; horizon applied server-side; one document for
several materials (built by deliberately shorting a second material, so it cannot
pass on an empty result); over-request trimmed; shortage closed before
confirmation → no write; planner allowed, viewer refused; closed schema. Three
Flutter tests assert the card names every material and shows no raw list syntax.

## Defects found and fixed

1. **A purchase request could be dated in the past.** The overdue order wants
   its material three days ago, and ERPNext rightly refuses *"Required By cannot
   be before Transaction Date"*. The wanted-by date is now never earlier than
   today. Being late is real and is reported in the shortage — it cannot be
   fixed by back-dating a purchase.
2. **"Nothing is short" surfaced as "no warehouse could be resolved."** The
   warehouse was validated before the shortage was consulted, so a request for
   material somebody else had already bought failed with the wrong sentence.
   Warehouses are now resolved only for lines that survive the clamp.

Both were found by the new tests, not in review.

## Not verified

- More than 20 orders, or more than one warehouse holding the same item. The cap
  is reported in the result (`truncated`), never applied silently, and the
  (item, warehouse) key is right by construction — neither has been exercised.
- Two orders that are **both short of the same material**. The seed has a shared
  product but ample stock; pooling is tested, a shared *shortage* is not.
- Multi-level BOMs, purposes other than Purchase, `allow_duplicate` from a
  conversation — unchanged from Phase 11.
- User Permissions (row-level). Still the largest untested part of the security
  claim, unchanged from Phase 12.

## Next product slice

**Slice 3 — Procurement completes.** The chain still dead-ends at Material
Request: `Purchase Order = 0`, every Supplier is `_Test`. A user can raise a
request and cannot answer "что мы заказали и когда придёт". That is the next
thing a real shop needs, and it reuses everything here.
