> **АРХИВ. Это не описание системы сегодня.**
> Документ сохранён ради причин, стоящих за решениями. Актуальное состояние — в `NOW.md`, `ROADMAP.md`, `PLAN.md`.
> Не строить по этому файлу.

---

# Phase 24 — Rework / Corrective Production

**Date:** 2026-08-10. Follows Phase 23 (Scrap / Process Loss / Quality Inspection).

## What was built

A spoiled piece no longer has only one destination. It can be **held** for
rework and come back as good output — or be written off after all, if the rework
fails.

```
Раскрой: 4 годные, 1 в браке — отправь её на исправление
  → card: 4 good · 0 loss · 1 pending · still open
  → corrective Job Card «Исправление брака», for_operation Раскрой, qty 1
Исправление завершено, деталь починили
  → corrective card submitted (the rework itself, and its cost)
  → original card: 5 good · 0 loss · Completed
```

## The finding that shaped the design

**ERPNext's corrective job card does not return quantity.**
`Job Card.update_work_order` returns early for `is_corrective_job_card` unless
`add_corrective_operation_cost_in_finished_good_valuation` is set, and even then
it only calls `update_corrective_in_work_order`, which writes
`corrective_operation_cost`. A corrective card is **cost of poor quality** — the
whole `Cost of Poor Quality` report is built on it — not a way to un-lose a
unit.

And process loss on a **submitted** card cannot be taken back.

So the piece is held as the card's own `pending_qty` instead of being booked as
loss, and the card stays open. ERPNext's invariant already has a place for it:

```
total_completed_qty + process_loss_qty + pending_qty == for_quantity
```

Deciding later which it becomes is then just completing the card — the path
every other unit takes. Nothing parallel was built.

## Tools

| Tool | Change |
|---|---|
| `manufacturing.complete_operation` | **extended** — `rework_qty` holds pieces and opens a corrective card |
| `manufacturing.complete_rework` | **new**, WRITE, confirmation — closes the rework, good or scrap |

Registry: **36 tools**. `rework_qty` mirrors `scrap_qty` on the tool that already
books a stage, so sending for rework needed no tool of its own.

## ERPNext mechanisms used

- **`job_card/mapper.py:make_corrective_job_card(source, operation, for_operation)`**
  — the whitelisted mapper the desk's *Make → Corrective Job Card* button calls.
- **`Operation.is_corrective_operation`** — marks «Исправление брака». It is
  deliberately **not** in the routing: rework is not a stage every cabinet goes
  through.
- **`Job Card.complete_job_card`** for both cards.
- **`Job Card.pending_qty`** as the holding state.
- `Work Order Operation.completed_qty` / `process_loss_qty`, written by ERPNext.

Two fields have to be corrected after the mapper runs, and both were measured
rather than guessed:

- **`operation_id`** is copied from the source card, and `validate_job_card_qty`
  sums `for_quantity` across every card sharing it — so the rework card is
  counted against the operation it is fixing and ERPNext refuses it with *"Qty
  To Manufacture in the job card cannot be greater than Qty To Manufacture in
  the work order for the operation Исправление брака"*. A corrective card is not
  that operation, so it carries no operation row.
- **`for_quantity`** is copied whole; only the failed pieces are being reworked.

## Tests

**533** `korkem_ai` (+15), **13** `korkem_manufacturing`, **311** Flutter, **18**
integration. `analyze` clean, `format` clean (202 files), secret scan clean,
`git diff --check` clean, four vendored repositories pristine.

The fifteen: a piece sent for rework is held, not lost; the rework is a real
corrective job card with the right links and quantity; a successful rework puts
the piece back in good output; ERPNext records the recovery on the operation;
the corrective card is submitted and adds no quantity of its own; a failed
rework is scrap and stays scrap; a piece already scrapped cannot be reworked; a
finished stage has nothing to rework; saying it twice changes nothing and opens
no second card; an unreadable result is refused; confirmation required and no
`company` argument; another company's job refused; more pieces than are held is
clamped; a recovered piece is manufactured like any other and `produced_qty`
equals the Manufacture ledger; a failed rework keeps the piece off the shelf.

Regression: the full Phase 14–23 suite passes unchanged.

## Defect found and fixed

**A failed rework was read as a success.** The verdict was matched by exact
membership, and «не исправили» contains «исправили» — so the tool would have
returned a broken cabinet to good output. Negation is now checked first and
separately. Of the two ways to be wrong here only one is dangerous, and it was
the one that would have shipped.

Also, on the device: `Work Order Operation` cannot be listed directly whatever
the user's rights on the Work Order — the same child-table constraint Phase 22
hit on `Stock Entry Detail`. The test reads through the parent document. **No
permission was widened.**

## Android E2E

`rework_e2e_test.dart`, `emulator-5554`, `korkem.planner@example.com`
(non-admin): **`00:42 +1: All tests passed!`**

```
Запусти производство по заказу Павлодар Уют.            → card → Confirm
Раскрой: 4 штуки годные, 1 штука в браке — отправь её
на исправление.                                          → card → Confirm
Исправление завершено, деталь починили.                  → card → Confirm
```

## Independent ERPNext verification

Read from the database afterwards, not from the transcript:

```
PO-JOB00015  Раскрой              5 good · 0 loss · submitted · owner planner
PO-JOB00022  Исправление брака    corrective · for_job_card PO-JOB00015
             for_operation Раскрой · for_quantity 1 · 1 completed
             submitted · owner korkem.planner@example.com
Work Order Operation Раскрой   completed 5.0 · process loss 0.0 · Completed
audit  start_production · complete_operation · complete_rework
       all Approved, all korkem.planner@example.com
```

Five started, one damaged, one fixed, **five good**. No loss anywhere, and the
rework is on the record as its own document.

## NOT VERIFIED

- **`corrective_operation_cost` reaching the work order.** It stays 0 because
  `Manufacturing Settings.add_corrective_operation_cost_in_finished_good_valuation`
  is off — ERPNext's default. The rework's time is recorded on its own card
  either way; rolling it into finished-goods valuation would change costing for
  every work order, so it was left alone rather than switched on for a demo.
- **A failed rework on the device.** Backend-tested; the device run succeeds.
- **Rework at a stage other than the first**, and rework of more than one piece
  at once. Both are backend-tested only.
- **Gemini tool routing per question** — the three device prompts each produced
  the right call, but no per-question trace was recorded. Unchanged since
  Phase 20.

## Remaining limitations

- **A held piece blocks its stage.** The card stays open until the rework
  result is recorded, which is correct — but the operations after it cannot
  start on the remaining good pieces in the meantime. ERPNext's sequence rule
  would allow four to move on; the tool does not offer it.
- **The rework itself is one step.** There is no "in progress at the rework
  bench" state between sending and finishing, and no second rework of the same
  piece if the first attempt only half-worked.
- A corrective card carries an empty time-log row alongside its real one —
  cosmetic noise on a costing document, the same shape Phase 17 noted.
- Row-level User Permissions remain unverified, unchanged since Phase 12.

## Commits

`korkem_manufacturing`, `korkem_ai`, root — listed in the final report.
