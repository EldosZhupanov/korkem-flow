# Phase 19 — CRM ↔ Production

**Date:** 2026-08-09. Follows Phase 18 (Capacity & Priority). Read-only slice.

## DONE

One tool: **`crm.customer_timeline`** (READ). Registry: **31 tools**.

«Покажи всё по Мебель Астана» returns CRM · Sales · Production · Materials ·
Procurement · Delivery in one call, following real document links, under the
caller's own permissions and company scope.

## ARCHITECTURE DECISION — option B, one aggregating tool

The alternative was letting Gemini call seven existing tools and staple the
answers together. Rejected, because the joins would then depend on the model
noticing that `MAT-MR-2026-00001` belongs to `SAL-ORD-2026-00001` rather than to
the other order on screen. The chain is relational; it is traversed server-side
in one pass.

**Three states per section, not two:**

- **present** — the document exists and is genuinely linked
- **`none`** — no such document exists
- **`no_access`** — the caller may not look

The third is the point of the slice. A planner holds no CRM role on this bench,
so reporting «нет сделки» would be a claim they cannot support. "You do not have
permission to read CRM deals" is a different sentence and the true one.

## MISSING RELATIONSHIPS — what the bench actually has

Measured, not assumed:

| Link | Reality |
|---|---|
| `Customer.crm_deal` | exists, but is a **`Data`** field and is **populated on 0 of 15 customers** |
| CRM Deal ↔ Sales Order | **no field exists in either direction** |
| `Work Order.originating_deal` | exists; **populated on 1 of 3 work orders** — and that one has no sales order and is not part of the seeded factory |
| CRM Organization for our customers | **none** — 2094 deals exist, not one belongs to a customer this factory produces for |
| Delivery Note | **0 rows** |

So the CRM and ERPNext datasets on this bench are **disjoint**. The honest
consequence: for every real factory customer the CRM section reports `none`
(to an administrator) or `no_access` (to a planner). Nothing was back-filled to
make the demo look better.

`Work Order.originating_deal` **is used** where it is set — it is read and
returned per work order — but it cannot carry the timeline on its own, because
the two work orders that belong to real orders do not have it.

**Links are followed, never guessed.** Everything hangs off document
references: `Sales Order.customer`, `Work Order.sales_order`,
`Material Request Item.sales_order`, `Purchase Order Item.material_request`,
`Purchase Receipt Item.material_request`, `Delivery Note Item.against_sales_order`,
`Customer.crm_deal`, `Work Order.originating_deal`. A test asserts the customer
is *not* matched to a CRM deal by name similarity — with 2094 deals present, a
fuzzy join would have manufactured a relationship out of nothing.

## PERMISSION FINDINGS

**The planner cannot read any CRM doctype.** `CRM Deal` read belongs to Sales
Manager, Sales User and System Manager; the planner holds Manufacturing User,
Stock User and Purchase User.

**No permission was widened.** Giving the planner a CRM role to make the demo
fuller would have been exactly the "widen rights to pass a test" this project
has refused throughout. The timeline reports the blind spot instead.

Also recorded: the **viewer** (Manufacturing + Sales User) sees Sales as
`present` and Procurement as `no_access` — Sales User grants no Material Request
permission. Two users, two genuinely different views of the same customer, both
truthful.

## LIVE VERIFIED

`customer_timeline_e2e_test.dart`, `emulator-5554`, as
`korkem.planner@example.com`: `00:45 +1: All tests passed!`

```
Покажи всё по Мебель Астана.
  → SAL-ORD-2026-00001, срок 23.08, 1 200 000 KZT, Шкаф Астана ×10
    Производство: MFG-WO-2026-00005, изготовлено 6 из 10
    Текущая операция: Раскрой → следующая: Кромление
    Материалы: ДСП 16мм — не хватает 4
Что сейчас происходит с этим заказом?  → Раскрой
Есть проблемы с этим заказом?          → ДСП 16мм
Сколько уже изготовлено?               → 6
```

## CRM VERIFIED

`Customer.crm_deal` for Мебель Астана is `None`; no CRM Organization matches any
seeded customer. The timeline reports `none`/`no_access` accordingly and names
no deal — which is the correct answer, and the one a fuzzy match would have got
wrong.

## ERPNext VERIFIED

Read from the database independently of the assistant:

```
SAL-ORD-2026-00001  delivery 2026-08-23  1 200 000 KZT  per_delivered 0
MFG-WO-2026-00005   qty 10  produced 6  In Process  originating_deal None
current operation   Раскрой @ Раскрой
Bin ДСП 16мм        38 on hand (needs 42 → short 4)
Material Requests 0 · Delivery Notes 0
```

Every figure the assistant gave matches.

## Tests

**439** `korkem_ai` (+16), 13 `korkem_manufacturing`, 311 Flutter, 16
integration. `analyze` and `format` clean.

The sixteen: orders belong to the customer; production hangs off the sales
order; progress is the work order's own; the current stage comes from the
routing; the shortage matches the shortage tool; an absent stage says `none`;
a customer with no CRM deal is not matched by name; `no_access` differs from
`none`; a customer with no orders reports `none` rather than failing; an unknown
customer is a sentence; a request and its purchase order appear against the
right sales order; a request with no purchase order is raised as an issue;
no company argument; it is a read; another company's orders never appear; a
viewer sees sales but not purchasing.

## NOT VERIFIED

- **A timeline that actually contains a CRM deal.** No customer on this bench
  has one, so the `present` branch of the CRM section is covered only by the
  code path, not by data.
- **Delivery** — zero Delivery Notes exist; the section is exercised only in its
  `none` state.
- **`originating_deal` as the join** — populated on one work order that has no
  sales order, so the field is returned but never used to reach a deal.
- Customers with several concurrent orders, and orders with several work orders.

## BLOCKERS

None for this slice. But the CRM ↔ ERPNext datasets being disjoint is a
**product** blocker for any future CRM-driven feature: until a real sale flows
Deal → Customer → Sales Order with the link set, "show me the deal behind this
order" has nothing to answer with.

## NEXT

Delivery / customer fulfilment, as agreed. It is also the cheapest way to make
the last section of this timeline real.
