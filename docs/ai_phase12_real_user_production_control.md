# Phase 12 — a real user, and the production floor

**Date:** 2026-08-08 · Follows `ai_phase11_material_request.md`.

Labels: `LIVE VERIFIED` (executed against the running bench and real Gemini,
output quoted) · `TEST VERIFIED` · `NOT VERIFIED` · `BLOCKED`.

---

## 1. Objective

Two things, in order. Make the Phase 11 workflow work for somebody who is not
the administrator — and prove the permission boundary is real by finding a user
it stops. Then answer «Что сейчас происходит в производстве?» from the database.

Both are done. `LIVE VERIFIED` on `emulator-5554`, signed in as
`korkem.planner@example.com`, holding no administrative role:

```
Что сейчас происходит в производстве?
  → manufacturing.production_control
    Активных заказов: 3 · В производстве: 2 · Не начато: 1
    Просрочено: 1 · С дефицитом: 1 · Готово к запуску: 1

Какой заказ заблокирован по материалам?
  → SAL-ORD-2026-00001 — не хватает ДСП 16мм, 4 листа

Почему?
  → срок 22.08, произведено 6 из 10, ДСП 16мм: нужно 42, есть 38

Создай заявку на закупку.
  → ConfirmationCard → MAT-MR-2026-00001, owner korkem.planner@example.com
```

After the first question nothing names an order, an item or a quantity.

## 2. Real ERPNext permission discovery

Read from `DocPerm` on the running bench, not from documentation:

| DocType | Roles that can read | Create / submit |
|---|---|---|
| Customer | Sales User, Sales Manager, Stock User, Stock Manager, Accounts | Sales User, Sales Master Manager |
| Sales Order | Sales User, Sales Manager, Stock User, Accounts User | Sales User, Sales Manager, Maintenance User |
| Item | Sales/Stock/Purchase/Manufacturing User, Item Manager | Item Manager |
| Warehouse | Sales/Stock/Purchase/Manufacturing User | Item Manager |
| BOM | **Manufacturing User, Manufacturing Manager only** | same |
| Work Order | Manufacturing User, Stock User (read) | Manufacturing User |
| Bin | Sales/Stock/Purchase User + Managers | — |
| Production Plan | **Manufacturing User only** | same |
| Material Request | Stock User, Purchase User, + Managers | same (RWCS together) |

**The indirect dependency Phase 11 flagged is real and now handled.**
`inventory.material_shortage` reads Sales Orders, BOMs and Bins — but ERPNext's
requirement engine opens with
`frappe.has_permission("Production Plan", "read", throw=True)`, even though no
plan is created. The tool declared only `("Sales Order", "BOM", "Bin")`, so it
was **offered to users who could not run it**, and the failure arrived as a bare
"You do not have permission to do that" naming nothing.

Fixed by declaring what the tool actually touches:
`("Sales Order", "BOM", "Bin", "Work Order", "Production Plan")`. In stock
ERPNext, BOM read and Production Plan read happen to come from the same role, so
nothing was reachable-then-broken today — but the declaration was wrong, and the
next role configuration would have found it.

## 3. User roles

Two ordinary System Users, assembled from **stock ERPNext roles**. No custom
role, no Custom DocPerm, no permission tweak — so what they can and cannot do is
ERPNext's answer, not ours. Both live in `seed_demo.seed_users()`.

| User | Roles | Can |
|---|---|---|
| `korkem.planner@example.com` | Manufacturing User + Stock User | the whole workflow |
| `korkem.viewer@example.com` | Manufacturing User + Sales User | read everything, buy nothing |

`TEST VERIFIED`: neither holds System Manager or Administrator — asserted,
because if either did, every other test here would pass while proving nothing.

## 4. Minimum permissions

For the full workflow: **Manufacturing User + Stock User**.

- *Manufacturing User* — BOM, Work Order, Production Plan (the engine's
  entry check), Item, Warehouse.
- *Stock User* — Bin, Material Request create+submit, and read on Sales Order
  and Customer.

Sales User is **not** needed; Stock User's read on Sales Order and Customer is
enough. That matters: Sales User would also grant Sales Order *create*, which a
production planner has no business having.

The viewer swaps Stock User for Sales User, which grants no Material Request
permission at all — the reason the negative test is meaningful rather than
decorative.

## 5. Negative permission tests

All `TEST VERIFIED`, and reproduced live before being written down.

| | Viewer |
|---|---|
| `manufacturing.production_control` | **allowed** — sees all 3 orders |
| `sales.get_sales_order`, `production_readiness`, `material_shortage` | allowed |
| `inventory.create_material_request` | **refused**, `permission_denied` |
| Material Requests created | **0** |
| Tool offered to the model at all | **no** |

Refusing at execution is the guarantee; not offering the tool is the courtesy —
a model handed something it can never use will keep retrying it.

Also asserted: **no wording of the request changes the answer.** The permission
check does not read the conversation, so nothing said in it can move the
boundary.

**Create-without-submit** — ERPNext's model does distinguish these (separate
`submit` flag), though no stock role expresses it; an administrator can untick
Submit in the permission manager. That case found a real defect, now fixed:
the tool did `insert()` then `submit()`, so a user who could do the first and
not the second left behind a **draft nobody asked for** — invisible to
purchasing, indistinguishable from one a person started and abandoned. Submit
permission is now checked *before* anything is written. `TEST VERIFIED`, with
the assertion that zero requests remain.

## 6. Production control tool

`manufacturing.production_control` · `Risk.READ` · no confirmation ·
input `{"limit": <=20}`, all optional.

Definitions are choices, so they are written down rather than implied:

- **active** — submitted, not Completed/Closed/Cancelled
- **overdue** — delivery date passed **and** not fully delivered (a late order
  that shipped is history, not a problem)
- **in production** — a submitted work order that is not finished
- **not started** — no submitted work order at all
- **blocked** — material short; overlaps with overdue on purpose
- **ready to start** — unstarted and lacking nothing; the only category that is
  an invitation to act

`attention` is returned pre-sorted (overdue first, then soonest due) so «какой
заказ самый проблемный» does not depend on the model re-sorting a list.

### Reuse, and one deliberate non-reuse

Shortages come from `procurement.material_shortage`, which wraps ERPNext's
Production Plan requirement engine — so the shortage this overview reports is,
by construction, the same quantity `create_material_request` will order.
`TEST VERIFIED` by comparing the two directly. Two paths to one number is how an
overview and an action come to disagree in front of a customer.

**ERPNext's `Production Planning Report` was read and not used.** It answers a
similar question, but it returns display columns rather than a stable contract,
it maintains its own raw-material and bin pipeline (so it would be a *second*
shortage number), and it reaches for `frappe.get_all` internally — which
bypasses the permission query conditions that make "the assistant sees what you
see" true. A tool built on it would have shown a planner rows they cannot open.

## 7. Real production data

The bench held one order, which cannot demonstrate an overview. The seed was
extended — labelled demo data, `remove()` still deletes exactly what `seed()`
creates — to three orders covering three states, on a **second product with its
own materials** so the four-sheet shortage the procurement slice depends on is
not disturbed.

`LIVE VERIFIED`, run as the planner:

```
summary: active 3 · overdue 1 · in production 2 · not started 1
         shortage 1 · ready to start 1 · truncated false
attention: [SAL-ORD-2026-00002, SAL-ORD-2026-00001]

SAL-ORD-2026-00002  Караганда Мебель  due 2026-08-05 (-3d) OVERDUE   WO 5/20
SAL-ORD-2026-00001  Мебель Астана     due 2026-08-22 (+14d) SHORTAGE WO 6/10
                                        ДСП 16мм short 4 Лист
SAL-ORD-2026-00003  Павлодар Уют      due 2026-08-29 (+21d) READY    no WO
```

**One real ERPNext constraint found while seeding:** an overdue order cannot be
created by back-dating only the delivery date — *"Expected Delivery Date should
be after Sales Order Date"*. An order that is late was placed a while ago, so
the transaction date is back-dated with it.

## 8. Android E2E

`LIVE VERIFIED` — `production_control_e2e_test.dart`, signed in through the real
login form as the planner, driving the real composer and the real card:

```
01:14 +1: All tests passed!
```

Asserted on the device: the user holds no System Manager role · 0 Material
Requests before the tap · exactly 1 after · `docstatus 1`, type Purchase,
**owner `korkem.planner@example.com`** · one line, `ДСП 16мм`, qty **4.0**,
citing `SAL-ORD-2026-00001` · the real document number reaches the screen ·
replay refused, still 1.

Verified independently in ERPNext afterwards: **0 Material Requests remaining**
(the test cleans up), and the Pending Action row quoted in §11.

## 9. Material Request action

Unchanged from Phase 11 except for the submit pre-check. The proposal Gemini
made as the planner, `LIVE VERIFIED`:

```json
{"sales_order": "SAL-ORD-2026-00001",
 "items": [{"item_code": "ДСП 16мм", "warehouse": "Stores - KRK", "qty": 4}]}
```

0 before confirmation → 1 after → 1 after replay.

## 10. Security

**AI permissions ⊆ the logged-in user's ERPNext permissions.** Held by
construction rather than by diligence: the turn job runs `frappe.set_user(user)`
and every tool executes in-process under that session, so Frappe applies the
same checks it would to a form.

| Claim | How |
|---|---|
| No Administrator credentials | the acceptance run is a two-role System User |
| No service account | the created document's `owner` **is** the real user |
| No bypass of `has_permission` | registry checks per declared doctype, risk-typed |
| No raw SQL in tools | `frappe.get_list` throughout; `get_all` banned |
| No unrestricted API | closed registry; no `http`/`api`/`url`/`sql`/`query` tool |
| User Permissions respected | `get_list` applies permission query conditions |
| Conversation cannot widen it | asserted: no wording changes the answer |

**The generic tool safety policy was not weakened this phase.** One boundary
question came up and was decided the other way — see §16.

## 11. Audit

```json
{"name": "c9vblu45pq", "status": "Approved",
 "owner": "korkem.planner@example.com",
 "resolved_by": "korkem.planner@example.com",
 "resolved_at": "2026-08-08 21:26:45.171542",
 "executed_at": "2026-08-08 21:26:46.591602",
 "provider": "Google Gemini", "model": "gemini-flash-latest", "error": null,
 "action_data": {"sales_order": "SAL-ORD-2026-00001",
                 "items": [{"item_code": "ДСП 16мм", "qty": 4,
                            "warehouse": "Stores - KRK"}]}}
```

Requested by, resolved by, provider, model, tool, arguments, confirmation,
execution time, result and error — all present, all naming the real user.
Permission *denials* are recorded by the tool logger (tool, outcome, user) but
**not** as Pending Action rows: nothing is proposed when a tool is refused, so
there is no row to write. Noted in §14 as a gap rather than claimed as covered.

## 12. LIVE VERIFIED

- The full four-turn conversation as a non-administrator, on Android, end to end.
- `production_control` returning real counts over three real orders.
- «Какой заказ заблокирован» and «Почему?» answered from tool data.
- «Создай заявку на закупку» with no ID, item or quantity repeated.
- Exactly one Material Request, owned by the planner; replay created none.
- The viewer refused, with zero writes.
- ERPNext's refusal to back-date a delivery date alone.

## 13. TEST VERIFIED

**309** `korkem_ai` (+15) · **13** `korkem_manufacturing` · **308** Flutter ·
**9** integration. `analyze` clean, `format` clean (189 files).

The 15 new tests: neither demo user is an administrator; the roles are
ERPNext's own; every workflow step succeeds as the planner; the document is
owned by the planner; the viewer can read and cannot write; the write tool is
not offered to the viewer; no wording changes the answer; create-without-submit
leaves nothing behind; the summary cannot disagree with its own detail; overdue
means past-due *and* undelivered; the overview and the write agree on the
shortage; an unstarted order lacking nothing is ready; the most pressing order
sorts first; the tool is a read.

## 14. NOT VERIFIED

- **User Permissions** (row-level restrictions — e.g. a user limited to one
  company or one warehouse). The tools go through `get_list`, which applies
  them, but no restricted user was configured and exercised. This is the
  largest remaining gap in the permission story.
- **Multi-company.** One company exists; the tools do not filter by company.
- **A user who can create but not submit, configured for real** in the
  permission manager. The defect and its fix are covered by patching that
  permission; no such user exists on the bench.
- **Permission denial as a durable audit record.** Logged, not stored.
- **The viewer on Android.** The negative case was proven server-side; the
  device run was the planner.
- **More than 20 orders.** The cap is reported in the result, never silently
  applied, but no run has exceeded it.
- Multi-level BOMs, multi-item requests, purposes other than Purchase — all
  still untested, unchanged from Phase 11.

## 15. BLOCKED

Nothing.

## 16. Defects discovered

1. **Undeclared permission dependency** (§2). `material_shortage` declared three
   doctypes and needed five. Latent today because BOM and Production Plan read
   ship in the same role; wrong regardless. **Fixed.**
2. **Draft left behind on a partial permission** (§5). `insert()` then
   `submit()` with only the first allowed leaves an orphan draft. **Fixed** —
   submit is checked before anything is written.
3. **A user cannot read their own audit trail.** `Pending Action` is
   System-Manager-only. Owner-scoped read (`if_owner`) was tried and **reverted**:
   `if_owner` alone does not satisfy `get_list` in this Frappe version, and
   widening it further would have moved a real security boundary to make a test
   convenient. The test now reads the call id from the app's own state — which
   the client already holds — and the doctype stays closed. Recorded as a
   product question for Phase 13, not a fix.
4. **Seeded overdue orders were impossible** (§7) — ERPNext validates delivery
   date against order date. **Fixed** in the seed.

## 17. Exact commits

| Repo | Commit | What |
|---|---|---|
| `korkem_ai` | `3d6ab81` | production control tool, permission fixes, real-user tests |
| `korkem_manufacturing` | `4cbe1e6` | three-order dataset and the two demo users |
| root | the commit carrying this file | Android planner E2E and this report |

---

## Recommendation for Phase 13

**User Permissions are the last untested part of the security claim.** Everything
in §10 is now proven at the *role* level; none of it is proven at the *row*
level. A planner restricted to one warehouse, or a sales user restricted to
their own customers, is the normal ERPNext deployment — and `get_list` is
supposed to handle it. "Supposed to" is exactly the phrase this project keeps
turning into a defect. One restricted user, the same four-turn conversation, and
an assertion that the counts shrink accordingly would close it.

Second, and smaller: decide whether a user should be able to see their own
Pending Actions (§16.3). It is their own audit trail, and today they cannot read
it. That is a product decision, not a bug — but it should be made deliberately
rather than left as a permission nobody revisited.

Only then the next business capability. Phase 13 should not start automatically.
