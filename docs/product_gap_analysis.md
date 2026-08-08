# KORKEM — product gap analysis

**Date:** 2026-08-09. Verified against the running bench and the current code,
not against the phase reports. Where a phase report and the bench disagree, the
bench wins and the disagreement is noted.

---

## 1. Current state

**25 registered tools — 20 READ, 5 WRITE.** No generic HTTP/SQL/shell tool; all
writes go through Pending Action → ConfirmationCard → server revalidation →
audit.

| Domain | Tools | Write |
|---|---|---|
| `sales.*` | 2 | — |
| `manufacturing.*` | 4 | — |
| `inventory.*` | 5 | `create_material_request`, `receive_purchase_order` |
| `procurement.*` | 4 | `create_purchase_order` |
| `crm.*` + `tasks.*` + `profile.*` | 10 | `create_lead`, `create_task` |

Offered per persona: Administrator 25, planner 18, viewer 18.

## 2. What genuinely works

**One spine, proven end to end on a real device as a non-admin user:**

```
Sales Order → production readiness → shortage → Material Request
           → Purchase Order → Purchase Receipt → stock → can_start = true
```

Every step `LIVE VERIFIED` on `emulator-5554` as `korkem.planner@example.com`,
each write confirmed on screen and each result checked in ERPNext afterwards.
Numbers come from ERPNext's own planning engine; the model never does the
arithmetic.

Also real: factory-wide shortage with severity and horizons, procurement status
with a `NOT_REQUESTED → REQUESTED → ORDERED → PARTIALLY_RECEIVED → RECEIVED`
trace, role-level permissions with a genuine negative case.

## 3. What is demo data or scaffold

**The bench is 96% ERPNext's own test fixtures.** Twenty-three companies exist;
twenty-two are `_Test`. KORKEM's share:

| | total | KORKEM |
|---|---|---|
| Sales Order | 55 | **3** |
| BOM | 267 | **3** |
| Work Order | 3 | 3 |
| Item / Customer / Supplier | 39 / 15 / 12 | 0 by company field |
| Purchase Order / Receipt / Delivery Note | 0 | 0 |
| Sales Invoice | 416 | **0** |
| **Job Card / Routing / Workstation Type** | **0 / 0 / 0** | 0 |

**A correctness hole follows from this and is not theoretical.** No tool filters
by company. `active_sales_orders()` filters on `docstatus=1` and open status
only. Today the answers are clean *by accident* — the 52 non-KORKEM orders
happen to be drafts. Submit one `_Test Company` order and a KORKEM planner's
«какие заказы просрочены» starts including it. **P0.**

**Scaffold found that nobody is using:** `korkem_manufacturing` already contains
`production.create_production_order()` (CRM Deal → Work Order, with an
`originating_deal` custom field) and `shop_floor.complete_task()`. Both are
tested, neither is exposed as an AI tool. The assistant cannot reach working
code that already exists.

## 4. What is missing

1. **Production execution.** Nothing can start a work order, run an operation,
   or finish one. `can_start = true` is where the product stops.
2. **The furniture workflow itself.** Раскрой → Кромление → CNC → Сверление →
   Покраска → Сборка → ОТК exists nowhere in the data. The seeded BOMs are
   `with_operations = 0`.
3. **Capacity.** «Какая загрузка производства?» is unanswerable — there are no
   routings, one `_Test` workstation, and zero job cards.
4. **Delivery.** Zero Delivery Notes; the chain ends at finished goods.
5. **Priority.** «Что запускать первым?» has no backend answer.
6. **Profitability.** BOM carries `raw_material_cost` / `operating_cost` /
   `total_cost` and Sales Order carries `grand_total` — margin is computable and
   nothing computes it.
7. **CRM ↔ production.** `Work Order.originating_deal` exists and **no tool
   traverses it.** «Покажи всё по Мебель Астана» cannot be answered.
8. **Company scoping** (§3).

## 5. ERPNext entities already available

The execution and capacity layers need **no new doctypes**. All of this is
installed and unused:

| Need | ERPNext mechanism | Status |
|---|---|---|
| Shop-floor stages | `Operation` + `Routing` + `BOM Operation` | present, 106 `BOM Operation` rows exist on `_Test` BOMs |
| Stage execution | `Job Card` (`work_order`, `operation`, `workstation`, `time_logs`, `status`, `employee`) | present, 0 rows |
| Capacity | `Workstation.production_capacity`, `working_hours`, `total_working_hours`, `hour_rate`, `holiday_list` | present |
| Create job cards | `work_order/mapper.py:make_job_card`, `create_job_card(enable_capacity_planning=…)` | present |
| Start/finish production | `Work Order` + `Stock Entry` (Material Transfer for Manufacture / Manufacture) | present |
| Shipping | `sales_order/mapper.py:make_delivery_note` | present |
| Cost & margin | `BOM.total_cost`, `Sales Order.grand_total` | present |

**The gap is data and tools, not ERP capability.** Building a scheduler or a
workflow engine on top would be the mistake.

## 6–8. Tool audit — keep, merge, delete

**Keep as-is (14).** The whole `sales.*`, `inventory.*` and `procurement.*`
spine, `manufacturing.production_control`, `manufacturing.search_work_orders`,
`profile.current_user`.

**Merge (3):**

| Tools | Why | Proposal |
|---|---|---|
| `manufacturing.production_readiness` + `manufacturing.production_control` | Control already computes readiness per order by calling the shortage tool; readiness is the same answer for one order | `production_control(sales_order=…)` covers both; retire `production_readiness` |
| `manufacturing.get_bom_materials` | Subsumed by the shortage tools; **never once chosen by the model** in any live run | fold into `material_shortage` output |
| `crm.get_deal` | `search_deals` returns the same fields; never chosen by the model | add a `name` filter to `search_deals` |

**Watch, do not delete yet (4):** `crm.search_leads`,
`crm.search_organizations`, `crm.search_users`, `tasks.list` — real CRM data
behind them (1511 leads, 1390 deals), but never chosen by the model in any
recorded run and never Android-verified. They become useful the moment the
CRM ↔ production slice lands; decide then.

**Keep, narrow scope:** `inventory.get_stock` — never chosen by the model, but
«сколько ДСП на складе» is a real question the shortage tools answer clumsily.

**Never Android-verified writes:** `crm.create_lead`. Backend-tested only.

**No tool bypasses permissions, allows model arithmetic on critical numbers, or
mutates without confirmation.** The escape-hatch guard is intact. The one real
weakness is §3's missing company filter.

## 9. Mobile UX

Current primary navigation is **CRM-shaped**: Assistant · Dashboard · Sales ·
Tasks · Profile. Production and Warehouse screens exist, are wired to real data,
and are **buried at `/dashboard/production`**. The server dashboard
(`korkem_ai.dashboard.get_summary`) counts deals, leads, tasks and work orders —
not orders, materials, shortages or deliveries.

**Proposed:** Assistant · Today · Production · Procurement · Profile, with
Orders/Warehouse/CRM reachable from Today. The assistant stays the primary
interface; Today is an action surface, not a table:

```
СЕГОДНЯ
🔴 2 критических   🟠 3 под угрозой   📦 4 материала ожидаются
🏭 5 в производстве   ✅ 2 готовы к отгрузке

ТРЕБУЕТ ДЕЙСТВИЯ
[Принять поставку]  [Запустить производство]  [Создать закупку]
```

Each tile opens the assistant with the question pre-asked — one surface, not two.

## 10. Production Control Center — target shape

`production_control` today returns per order: customer, status, delivery date,
overdue, work orders with progress, material status, shortages, ready-to-start.
**Missing for the target:** current/next operation, procurement stage, blocking
reason as a sentence, priority, risk band, expected completion.

Target per order — every field from ERPNext, none derived by the model:

```
Мебель Астана · Шкаф Астана ×10 · срок 22.08
██████░░░░ 6/10
Материалы:   ✓ Петля  ✓ Кромка  ✕ ДСП 16мм −4
Закупка:     PO PUR-ORD-…, 4 заказано, ожидается 22.08
Производство: ⏸ заблокировано (нет ДСП)
Этап:        Раскрой → следующий: Кромление
Действие:    Получить ДСП → запустить
```

Bands: 🔴 Critical (overdue or blocked with no PO) · 🟠 At Risk (due inside lead
time, or PO overdue) · 🟡 Waiting (ordered, not received) · 🟢 Ready · 🔵 In
Production · ⚪ Completed. All computed server-side.

## 11–12. The full workflow, and where it breaks

```
CRM Deal ──✗── Sales Order ──✓── Work Order ──✓── BOM ──✓── Materials
                                     │                        │
                                     ✗                        ✓
                              Job Card / Operation      Material Request
                                     ✗                        ✓
                              Workstation capacity      Purchase Order
                                     ✗                        ✓
                              Finished Goods            Purchase Receipt
                                     ✗                        ✓
                              Delivery Note ──✗── Customer   Stock ✓
```

✓ = proven end to end. ✗ = missing. **The materials half is complete; the
execution half does not exist.**

## 13. Priority

**P0 — the product does not work without these**
1. Company scoping on every tool (§3) — a correctness hole in everything above.
2. Production execution: start a work order, run and finish operations.
3. The furniture routing in data (operations, workstations, BOM operations).
4. Delivery Note — the chain has no ending.

**P1 — a manager's morning is incomplete without these**
5. Capacity and bottleneck from `Workstation` mechanics.
6. Order prioritisation (formula below — your decision first).
7. CRM ↔ production unified customer timeline (`originating_deal` already there).
8. Today screen and navigation restructure.

**P2**
9. Profitability per order from BOM cost vs order value.
10. Tool consolidation (§6–8).
11. Row-level User Permissions verification.

## 14. Roadmap — 6 slices

Each answers *"what can a user do today that they could not yesterday?"*

| # | Slice | New capability |
|---|---|---|
| **1** | **Company scoping + demo factory** | Every answer is about *this* factory. Seed the real furniture routing: 7 operations, 4 workstations, routings on both BOMs. Nothing user-visible ships — but nothing after it is trustworthy without it. |
| **2** | **Production execution** | «Запусти производство» → material transfer to WIP → work order In Process. «Что сейчас в работе?» «На каком этапе заказ?» |
| **3** | **Shop floor / job cards** | «Раскрой закончен» → job card complete → next operation. «Что делать на участке сегодня?» |
| **4** | **Capacity & priority** | «Какая загрузка?» «Что запускать первым?» «Успеваем ли к сроку?» |
| **5** | **Delivery** | «Что готово к отгрузке?» «Создай отгрузку.» The chain finally closes at the customer. |
| **6** | **Unified customer timeline + Today screen** | «Покажи всё по Мебель Астана» — deal → order → production → materials → delivery. Plus the action-first home screen. |

Slice 1 is unglamorous and first on purpose: it is the only one whose absence
makes every other answer quietly wrong.

---

## Prioritisation formula — three options, your call

You asked for options rather than an implementation. All three use only
backend-computed inputs; none lets the model score anything.

### Option A — Deadline-driven (simplest, most explainable)

```
score = days_until_due − remaining_work_days
```

Negative = will miss. Rank ascending. Blocked orders excluded and listed
separately.

*For:* one number, trivially explainable to a foreman ("this one misses by 3
days"). Needs only delivery date and remaining quantity × cycle time.
*Against:* ignores customer importance and capacity contention.

### Option B — Weighted score (the shape you sketched)

```
score = 40×deadline_risk + 25×material_readiness + 15×capacity_fit
      + 10×customer_priority + 10×progress
```

Each term normalised 0–1 from ERPNext data. Weights configurable.

*For:* balances the real trade-offs; tunable per shop.
*Against:* the weights are invented. "Why is this order first?" answers with
arithmetic no foreman will trust or check.

### Option C — Constraint-ordered (recommended)

Not a score — an ordered set of rules, each a yes/no from data:

1. **Can it run at all?** No material → not in the list; it is a procurement
   problem, shown separately.
2. **Will it miss its date?** Late or projected late → first, ordered by how
   late.
3. **Does it free a bottleneck?** Frees the most-loaded workstation soonest.
4. **Everything else** by delivery date.

*For:* every position is explainable in one sentence from real data, which is
what makes it usable at 8am. No invented weights. Degrades honestly — without
capacity data it collapses to Option A and says so.
*Against:* no single number to sort or display.

**My recommendation: C**, because the answer a manager acts on has to survive
"почему?" — and A and B both answer that with a number rather than a reason.

---

## Stopping here

No code written. Awaiting your decision on the roadmap order and the
prioritisation formula.
