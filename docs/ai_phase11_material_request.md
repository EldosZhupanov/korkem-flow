# Phase 11 — shortage becomes a purchase request

**Date:** 2026-08-08 · Follows `ai_phase10_production_slice.md`.

Labels: `LIVE VERIFIED` (executed against the running bench and real Gemini,
output quoted) · `TEST VERIFIED` · `NOT VERIFIED` · `BLOCKED`.

---

## 1. Executive summary

The first business action the assistant can take is done, on a phone, in
Russian, without anyone typing an ERPNext document ID.

Three prompts, each the way a foreman would speak, the last two naming no
order at all — `LIVE VERIFIED` on `emulator-5554`:

| | |
|---|---|
| **«Покажи заказ клиента Мебель Астана.»** | `sales.search_sales_orders` → `sales.get_sales_order` |
| **«Можно его запускать в производство?»** | `manufacturing.production_readiness` |
| **«Не хватает материалов. Создай заявку на закупку.»** | `inventory.material_shortage` → proposes `inventory.create_material_request` |

The card appears, nothing is written, Confirm is tapped, and ERPNext gains one
real document:

```
MAT-MR-2026-00001  docstatus 1  status Pending  type Purchase
  ДСП 16мм  4.0 Лист  Stores - KRK  ← SAL-ORD-2026-00001  by 2026-08-15
```

Independently verified from the database, not from the screen: **0** Material
Requests before the tap, **1** after, and the Pending Action row
`iose9ajkp9 Approved executed_at 2026-08-08 20:43:09`.

## 2. Real ERPNext, read before anything was written

ERPNext **17.0.0-dev**, Frappe **17.0.0-dev**, read from the running bench.

**Material Request** — submittable, `naming_series: MAT-MR-.YYYY.-`.
Required: `naming_series`, `material_request_type`, `company`,
`transaction_date`, `items`. Optional: `schedule_date`, `set_warehouse`.
`material_request_type` ∈ Purchase · Material Transfer · Material Issue ·
Manufacture · Subcontracting. `status` ∈ Draft · Submitted · Stopped ·
Cancelled · Pending · Partially Ordered · Ordered.

**Material Request Item** — `autoname: hash`. Required: `item_code`,
`schedule_date`, `qty`, `uom`, `stock_uom`, `conversion_factor`. Links out to
`warehouse`, `from_warehouse`, `bom_no`, **`sales_order`**, `production_plan`.
That `sales_order` link is what makes a request auditable back to why it exists,
and it is what duplicate detection keys on.

**Draft or submitted?** Both are allowed; the tool **submits**. A draft does not
update `Bin.indented_qty`, so it neither reaches purchasing nor prevents the
same shortage being requested again tomorrow. A request nobody can see is not a
business action. `TEST VERIFIED` — asserted `docstatus == 1`, and separately
that `indented_qty` goes to 4.

## 3. Reusing ERPNext — and the one place it could not be reused

`erpnext.manufacturing.doctype.production_plan.services.material_request.get_items_for_material_requests`
is the engine behind Production Plan. It explodes multi-level BOMs, resolves
purchase UOM and conversion factors, aggregates `Bin` across child warehouses,
applies minimum order quantities and rounds whole-number UOMs. All of that is
called, none of it reimplemented.

**Its `quantity` output could not be used, and this is the finding of the
phase.** That engine assumes the demand it is given is not yet reserved
anywhere. A Sales Order that already has a Work Order is the opposite case: the
Work Order reserved the requirement, and `Bin.projected_qty` already has it
subtracted. Measured on the seeded order — 42 sheets needed, 38 in stock, Work
Order for all ten cabinets:

```
ignore_existing_ordered_qty = 0  ->  ДСП 42, Кромка 180, Петля 40
ignore_existing_ordered_qty = 1  ->  ДСП 42, Кромка 120, Петля 28
true answer                      ->  ДСП  4, Кромка   0, Петля  0
```

The first mode re-orders the entire requirement. The second subtracts
availability from a requirement that is already inside that availability, and
so orders 120 metres of edge banding on top of the 180 already reserved. Both
would have somebody buy material they already own.

So the requirement, the bin figures and the units come from ERPNext, and one
subtraction is done here, against the reservation ERPNext itself records:

```
shortage = max(0, (required − already_reserved_for_this_order) − projected)
```

With a Work Order the bracket is zero and the shortage is whatever
`projected_qty` has gone negative by. Without one, nothing is reserved, the
bracket is the full requirement, and it is compared against stock. One formula,
both situations, no double count. `TEST VERIFIED` in both directions.

## 4. Tool schemas

### `inventory.material_shortage` — READ

```json
{"sales_order": "SAL-ORD-2026-00001"}
```

```json
{"sales_order": "...", "customer": "...", "company": "...",
 "has_shortage": true,
 "items": [{"item_code": "ДСП 16мм", "item_name": "ДСП 16мм",
            "required_qty": 42.0, "reserved_qty": 42.0, "available_qty": 38.0,
            "projected_qty": -4.0, "ordered_qty": 0.0, "shortage_qty": 4.0,
            "uom": "Лист", "warehouse": "Stores - KRK"}],
 "shortages": [ … ]}
```

Machine-readable throughout. Every quantity is a number the model turns into a
sentence, never a sentence it has to parse back into a number.

### `inventory.create_material_request` — WRITE, confirmation required

```json
{"sales_order": "SAL-ORD-2026-00001",
 "purpose": "Purchase",
 "items": [{"item_code": "ДСП 16мм", "qty": 4, "warehouse": "Stores - KRK"}],
 "schedule_date": "2026-08-15",
 "allow_duplicate": false}
```

`purpose` is an enum of three: Purchase, Material Transfer, Manufacture.
ERPNext also offers **Material Issue** and **Subcontracting**; issuing stock and
subcontracting have consequences an assistant should not reach for unprompted,
so widening the list stays a deliberate decision.

## 5. Security — what is checked, and why each one is not theoretical

An argument list is the one part of a turn written by the model rather than by a
person, and it arrives with exactly the authority of the user it runs as.

| Check | Behaviour | Status |
|---|---|---|
| Unknown argument | schema is closed; `docstatus: 1` refused | `TEST VERIFIED` |
| Purpose outside allowlist | `Material Issue` refused by enum | `TEST VERIFIED` |
| Sales Order exists | "not found", no traceback | `TEST VERIFIED` |
| Sales Order readable | `get_doc` + `check_permission("read")` | `TEST VERIFIED` |
| Item exists | refused | `TEST VERIFIED` |
| Warehouse exists | refused | `TEST VERIFIED` |
| Warehouse is not a group | refused — a group holds nothing | `TEST VERIFIED` |
| Warehouse readable | `has_permission` | `TEST VERIFIED` |
| Quantity numeric and > 0 | `0` and `−5` refused | `TEST VERIFIED` |
| **Quantity ≤ the real shortage** | 400 refused: "only 4.0 is short" | `TEST VERIFIED` |
| **Item is actually short** | edge banding refused | `TEST VERIFIED` |
| Create permission, not read | `Risk.WRITE` → `"create"` | `TEST VERIFIED` |
| Confirmation before execution | generic Pending Action | `TEST VERIFIED` |
| Replay | claim is atomic; second confirm writes nothing | `TEST VERIFIED` |

The quantity check is the one that matters most. The shortage is **recomputed
from the database inside the same call**, so a model that asks for four hundred
sheets — misread, mis-summarised, or steered by something in the data it was
shown — gets the same answer as one that invented the order outright. Nothing
downstream depends on the model having done arithmetic correctly.

Nothing Gemini-specific exists in any of this. The tools are provider-agnostic;
the only provider-aware code remains in the gateway.

## 6. Duplicate protection

An open request against the same order and item is **reported, never repeated**:

```json
{"status": "duplicate", "sales_order": "SAL-ORD-2026-00001",
 "existing": [{"item_code": "ДСП 16мм", "material_requests": ["MAT-MR-2026-00001"]}]}
```

Open means Draft · Pending · Partially Ordered · Ordered. Cancelled, Stopped and
Received requests no longer cover a shortage and must not suppress a new one.

**The order of the checks is itself a fix.** Submitting a request raises
`indented_qty`, which lifts `projected_qty`, which closes the shortage. Checked
in the obvious order, a second identical request is refused with "this item is
not short" — true, caused by the user's own earlier request, and useless as an
explanation. The duplicate check therefore runs *before* the shortage is
consulted. `TEST VERIFIED`, including a test asserting the message is not the
misleading one.

## 7. Contextual follow-up

`LIVE VERIFIED`. The order ID is carried from the assistant's own earlier answer
— history is the app's real thread, and the third prompt names no order:

```
USER: Создай заявку на закупку.
  tools: [('inventory.material_shortage', True)]
  PROPOSED: inventory.create_material_request
            {"items":[{"item_code":"ДСП 16мм","warehouse":"Stores - KRK","qty":4}],
             "sales_order":"SAL-ORD-2026-00001"}
```

Context is a convenience, not a credential: the server still loads the document,
checks permission, and recomputes the shortage. A history entry claiming an
order exists proves nothing — and `_to_messages` has always refused to
reconstruct tool *results* from client input for the same reason.

## 8. Result on the device

```
Заявка на закупку создана:
* Номер заявки: MAT-MR-2026-00001
* Заказ: SAL-ORD-2026-00001
* Материал: ДСП 16мм — 4 листов
* Склад назначения: Stores - KRK
* Планируемая дата: 15.08.2026
```

The real ERPNext name, from the document that was created.

## 9. Audit

```json
{"name": "hfqvebgvns", "tool": "inventory.create_material_request",
 "status": "Approved", "owner": "Administrator", "resolved_by": "Administrator",
 "resolved_at": "2026-08-08 19:46:18.655722",
 "executed_at": "2026-08-08 19:46:19.526225",
 "provider": "Google Gemini", "model": "gemini-flash-latest", "error": null}

action_data: {"items": [{"item_code": "ДСП 16мм", "warehouse": "Stores - KRK",
                         "qty": 4}], "sales_order": "SAL-ORD-2026-00001"}
result_data: {"data": {"status": "created",
                       "material_request": "MAT-MR-2026-00001", …}}
```

What was proposed, who agreed, when, which model proposed it, and what came
back. Execution runs from `action_data` — the row — never from what a model
says at confirmation time.

## 10. Android: four failures worth recording

The E2E passed on the fifth attempt, and the first four were all test defects
that looked like product defects. Each is now a comment in the test, because
each would cost the next person a cycle.

1. **`find.textContaining` on the transcript.** The transcript is a lazy list,
   so answers below the fold are real, correct, and invisible to the finder.
   Turn 1 passed and turn 2 "failed" while the app was behaving perfectly.
   Answer content is now read from the thread state; what is *rendered* is still
   asserted, but for the confirmation card, which is what a person has to see.
2. **Typing while the assistant was busy.** `answersWith` returns as soon as a
   fragment has streamed — seconds before the turn ends — and the composer
   ignores input until then. The message was silently dropped, and the next
   assertion described a model that never answered a question it was never
   asked. Now waits for idle.
3. **`receiveAction(TextInputAction.send)`.** The composer declares
   `TextInputAction.newline`; by the second turn the input connection is stale,
   `enterText` reports success and the controller stays empty. Now taps the real
   send button — after tapping the field to restore the connection, and after
   letting its `ScaleTransition` finish, because a button scaled to nothing is
   in the tree and not tappable.
4. **The confirm tap that proved nothing.** `find.byType(FilledButton).last`
   landed off a partially-visible button, and the card then scrolled out of the
   lazy list — which the "card is gone" wait read as success. The run went green
   with the proposal sitting untouched at `status: Pending` in the database.
   Now the button is found *inside* the card, scrolled into view first, and
   dismissal is read from `pendingConfirmationProvider`, not from the finder.

Point 4 is the one to remember: a widget-tree absence is not evidence of a state
change, and a test that infers one from the other passes for the wrong reason.

## 11. One production test was changed

`test_there_is_no_general_purpose_escape_hatch` forbids mechanism words in tool
names. It listed `request` — and ERPNext calls a purchase requisition a
**Material Request**, so `inventory.create_material_request` tripped a guard
aimed at `http_request`.

`request` came off the list; `api`, `url` and `raw` went on. The transport half
of any real escape hatch — `http`, `api`, `url`, `sql`, `query`, `execute`,
`eval`, `shell`, `run_doc`, `raw` — is still forbidden, so nothing is given up.
Recorded here rather than done quietly: weakening a safety test is exactly the
change that should be visible.

## 12. Tests

| Suite | Count |
|---|---|
| `korkem_ai` | **294** (+21) |
| `korkem_manufacturing` | 13 |
| Flutter unit/widget | 308 |
| Integration | **8** (3 Phase 7, 1 Phase 8, 3 Phase 9, 1 here) |

`flutter analyze` clean · `dart format` clean (188 files).

The 21 new tests are business behaviours, not schema restatements: double
counting, over-ordering, silent duplication, ordering of the duplicate check,
and the eleven refusals in §5. They skip rather than fail when the seed is
absent.

## 13. NOT VERIFIED

- **A user who is not Administrator.** Everything ran as Administrator.
  Notably, ERPNext's engine calls `frappe.has_permission("Production Plan",
  "read", throw=True)` internally — so `inventory.material_shortage` requires
  Production Plan read even though it creates no plan. A Sales user without it
  gets "You do not have permission to do that", and no test covers that path.
- **Multi-level BOMs.** The engine handles nesting by design; the seeded BOM is
  one level and no nested case was exercised.
- **Multi-item and multi-line requests.** Every run requested one material. The
  code loops, and `consumed_qty` in ERPNext's engine handles a material shared
  between two products, but neither was exercised.
- **Purposes other than Purchase.** `Material Transfer` and `Manufacture` are
  allowed and untested.
- **`allow_duplicate: true` end to end.** Unit-covered; never driven from a
  conversation, because after the first request nothing is short and the run
  correctly stops earlier.
- **Rejecting** the proposal from the device (Cancel). Phase 6 covers it
  server-side.

## 14. Remaining risks

- The shortage is computed against `projected_qty`, which includes incoming
  purchase orders. Material on order but not yet received counts as covering a
  shortage — correct for planning, optimistic for a factory that needs it
  Tuesday. Deliberate, and worth revisiting with a real shop's lead times.
- `schedule_date` defaults to seven days out. That is a placeholder, not a
  lead-time calculation; ERPNext has `Item.lead_time_days` and it is not read.
- The seeded dataset is one company and one warehouse. The tools do not filter
  by company.
- The integration suite needs a live bench and real Gemini credit, so it is
  still not a CI gate.

## 15. Next

Per the brief, the next business capability is **«Что сейчас происходит в
производстве?»** — active orders, work orders, overdue, shortages, workstation
load — rather than more infrastructure. The read tools for it do not exist yet.

Before that, one small thing is worth closing: run the whole flow as a
non-Administrator user, since §13's first bullet is the most likely thing to
break for a real customer on day one.

## Reproducing

```sh
bench --site korkem.localhost execute korkem_manufacturing.seed_demo.seed
# no open Material Request may exist for the order — duplicate protection
# will (correctly) refuse otherwise

cd mobile/korkem_flow
PW=$(grep -E '^ADMIN_PASSWORD=' ../../infra/frappe_bench/.env | cut -d= -f2-)
flutter test integration_test/procurement_e2e_test.dart -d emulator-5554 \
  --dart-define=KORKEM_BASE_URL=http://10.0.2.2:8000 \
  --dart-define=KORKEM_E2E_USER=Administrator \
  --dart-define=KORKEM_E2E_PASSWORD="$PW"
```

The test cancels and deletes the Material Request it creates.
