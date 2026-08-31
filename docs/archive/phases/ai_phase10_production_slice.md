> **АРХИВ. Это не описание системы сегодня.**
> Документ сохранён ради причин, стоящих за решениями. Актуальное состояние — в `NOW.md`, `ROADMAP.md`, `PLAN.md`.
> Не строить по этому файлу.

---

# Phase 10 — the first production vertical slice

**Date:** 2026-08-08 · Follows `ai_phase9_android_reconnect.md`.

Labels: `LIVE VERIFIED` · `TEST VERIFIED` · `NOT VERIFIED` · `BLOCKED`.

---

## 1. Executive summary

The assistant now answers a real production question by reading real ERPNext
data and doing the comparison in the database rather than in the model.
`LIVE VERIFIED` against Gemini:

> **Покажи заказ клиента Мебель Астана и скажи, можно ли его сейчас запускать в
> производство.**
>
> Tools the model chose, unprompted: `sales.search_sales_orders` →
> `manufacturing.production_readiness`
>
> **Заказ `SAL-ORD-2026-00001`** · Шкаф Астана — 10 шт · срок 22.08.2026
> Рабочий заказ `MFG-WO-2026-00002`: произведено **6 из 10**.
>
> **Запустить полный объём сейчас нельзя.**
> **ДСП 16мм:** требуется 42 листа, на складе 38 — не хватает **4**.
> Петля 40/52 ✓ · Кромка 180/240 ✓

That is the target output from the brief, produced end to end.

## 2. Inspection first — what the bench actually held

The brief's DocType list was checked against the running bench rather than
assumed, and three things came back that changed the plan.

**Two CRM stacks coexist.** Frappe CRM holds the real data (CRM Lead 1371,
CRM Deal 1262); ERPNext sales holds fixtures. `Opportunity` is empty. ERPNext
`Task` is empty — the real one is `CRM Task`.

**Almost everything was ERPNext's own test fixtures.** Of 210 BOMs, 209 were
`_Test *`. All 41 Sales Orders were `docstatus=0` (Draft) and belonged to
`_Test Company`.

**There was no stock.** `Bin` held 5 rows, and every real item read `0`.

So the real KORKEM island was one item (`Kitchen Facade`), one BOM, one work
order not linked to any order, and zero stock. The headline question could not
be answered on that data — not because the tools were missing, but because the
factory did not exist in the database.

**Recorded as a blocker and resolved by decision, not by invention:** a seeded
dataset was agreed rather than tools that return truthful nothing.

## 3. The seed — `korkem_manufacturing/seed_demo.py`

One honest slice of a cabinet shop, idempotent, with `remove()` deleting exactly
what `seed()` creates:

| | |
|---|---|
| Items | ДСП 16мм, Кромка 2мм, Петля, Шкаф Астана |
| BOM | `BOM-Шкаф Астана-001` — 4.2 листа, 18 м, 4 шт per cabinet |
| Stock | 38 / 240 / 52 in `Stores - KRK`, via a real Material Receipt |
| Order | `SAL-ORD-2026-00001`, Мебель Астана, ×10, **submitted** |
| Work order | `MFG-WO-2026-00002`, 6 of 10, In Process, linked to the order |

Only the quantities are chosen, and deliberately: 4.2 × 10 = 42 against 38 on
hand gives a shortage worth looking at instead of a tidy "all fine" that proves
nothing.

Stock arrives through a submitted **Stock Entry**, not by writing `Bin`
directly — a hand-set `actual_qty` leaves the ledger disagreeing with the stock,
and every valuation built on it is then wrong.

**One real ERPNext constraint found on the way:** `Nos` is marked *must be a
whole number*, so 4.2 was rejected. Correct for hinges, wrong for board, so
board gets a `Лист` UOM that permits fractions.

## 4. Tool matrix — grounded, not guessed

Built after reading the schema. **Only the READ column exists so far**; the rest
is the proposal, unimplemented.

### Implemented — READ / ANALYTICS

| Tool | Reads |
|---|---|
| `sales.search_sales_orders` | Sales Order |
| `sales.get_sales_order` | Sales Order + items |
| `manufacturing.get_bom_materials` | BOM Explosion Item |
| `manufacturing.search_work_orders` | Work Order |
| `inventory.get_stock` | Bin |
| `manufacturing.production_readiness` | the composite above |

Registry total: **14 tools**, all `Risk.READ`.

### Proposed — not built

`WRITE`: `sales.create_quotation`, `manufacturing.create_work_order`,
`inventory.create_material_request`, `purchasing.create_purchase_order`.
`ACTION`: `manufacturing.start_work_order`, `complete_work_order`,
`create_material_transfer`. `ANALYTICS`: `capacity_summary`,
`order_profitability`, `delivery_risk`.

**Sales Order creation is heavier than it looks** and is deliberately not first:
it requires ten fields including `currency`, `conversion_rate`,
`selling_price_list`, `price_list_currency`, `plc_conversion_rate`.

## 5. Two things reused rather than rebuilt

- **`BOM Explosion Item`.** ERPNext already maintains the full multi-level
  expansion. Walking `BOM Item` recursively would duplicate it and drift the
  first time somebody nests an assembly.
- **`Bin.projected_qty`.** Stock minus what production has already reserved,
  plus what is on order. Arithmetic on `actual_qty` alone gives a confidently
  wrong answer for an order already half committed elsewhere. ERPNext had
  already computed `-4` for the board before any tool ran.

## 6. Why the comparison is one tool, not five

The model can chain the pieces itself, and does. But then the subtraction
happens inside a language model, and a shortage that reads `-4` is not something
to leave to a token predictor. `production_readiness` does the arithmetic in
Python against the database and hands the model a result to explain.

The granular tools are registered too, so the model can still answer questions
the composite does not cover.

## 7. Evidence

| Step | Result | Evidence |
|---|---|---|
| Schema read from the live bench | `LIVE VERIFIED` | `get_meta` on 30 DocTypes |
| Fixture-vs-real data identified | `LIVE VERIFIED` | 209/210 BOMs `_Test`; all SOs Draft |
| Seed creates a coherent factory | `LIVE VERIFIED` | SO submitted, WO 6/10, stock 38/240/52 |
| BOM explodes and scales | `TEST VERIFIED` | 4.2 → 42 for ten |
| Shortage computed against stock | `LIVE VERIFIED` | ДСП short by exactly 4 |
| Running work orders included | `TEST VERIFIED` | WO 6/10 in the readiness result |
| Model picks the right tools | `LIVE VERIFIED` | `search_sales_orders` → `production_readiness` |
| Answer in Russian with real numbers | `LIVE VERIFIED` | quoted in §1 |
| All tools read-only | `TEST VERIFIED` | risk asserted per tool |

## 8. Tests

**273** `korkem_ai` (+9) · **13** `korkem_manufacturing` · **308** Flutter ·
7 integration. `analyze` clean, `format` clean.

The new tests skip rather than fail when the seed is absent — an empty bench is
a missing fixture, not a broken tool.

## 9. NOT VERIFIED

- Any of this **on Android**. The tools are server-side; the device path was
  proven in Phases 7–9 and is unchanged, but this question has not been asked
  from a phone.
- The other fifteen questions in the brief (capacity, profitability, overdue
  orders, machine load) — no tools exist for them yet.
- Anything involving **write** in production: no `create_work_order`,
  no `create_material_request`. The "[Создать заявку на закупку]" action at the
  end of the target output is **not implemented**.
- Multi-level BOMs. The seeded BOM is one level; `BOM Explosion Item` handles
  nesting by design, but no nested case has been exercised here.

## 10. Remaining risks

- The seeded data is demo data on a dev bench. It is labelled, reproducible and
  removable, but it is not a customer's factory and the numbers are chosen.
- `production_readiness` compares against `actual_qty`, reporting
  `projected_qty` alongside. For an order competing with other work orders,
  `projected` is the stricter and arguably more correct basis — a deliberate
  choice worth revisiting with a real shop's data.
- Only one company (`KORKEM`) is assumed by the seed; the tools do not filter
  by company and would mix fixtures in on a multi-company site.

## 11. Next

1. `inventory.create_material_request` — the first production **write**, and the
   button the target output ends on. The confirmation chain already exists.
2. Ask this question from Android, closing the loop with Phases 7–9.
3. Company scoping on the read tools before any multi-company use.
4. Then breadth: overdue orders, capacity, profitability.

## Reproducing

```sh
bench --site korkem.localhost execute korkem_manufacturing.seed_demo.seed
bench --site korkem.localhost execute korkem_manufacturing.seed_demo.remove   # undo
```
