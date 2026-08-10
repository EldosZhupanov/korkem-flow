# Phase 25 — Parallel Production & Rework

**Date:** 2026-08-11. Follows Phase 24 (Rework / Corrective Production).

## The problem

Phase 24 held a damaged piece by leaving its job card open. That stopped the
line: the other four pieces could not move to the next stage.

The cause is exact, and it is ERPNext's, not ours:

> An **unsubmitted** job card contributes nothing to
> `Work Order Operation.completed_qty` — and that is the field
> `Job Card.validate_previous_operation` reads. Four finished pieces looked
> like none, so the next stage refused to start with *"complete the operation
> Раскрой before the operation Кромление"*.

## What changed

**The stage splits.** ERPNext already allows several job cards per operation —
`get_current_operation_data` sums across them — so the good pieces go out on a
card that **submits**, and the held piece waits on one that does not.
`validate_job_card_qty` sums `for_quantity` over the operation, so the original
is resized first; together they still come to what the stage was opened for.

```
Раскрой: сделали 5, одна в браке — отправь на исправление
  card A  for_quantity 4  completed 4  submitted   → operation completed_qty 4
  card B  for_quantity 1  draft                    → the piece, held
  corrective card, for_job_card = B
Кромление закончено          → runs on 4, carried_forward_loss 0
Исправление не удалось       → unresolved, the piece stays, retry allowed
…снова на исправление        → a second corrective card
Исправление удалось          → card B books 1 good → operation 5, Completed
                             → catch-up cards carry it through the later stages
```

**Held pieces are not loss.** A downstream stage short of pieces because an
upstream one is holding them resizes to what arrived, instead of writing the
missing piece off as its own process loss.

**Three rework outcomes**, where Phase 24 had two: recovered, **unresolved**
(retryable — the piece stays exactly where it was), and written off.

## Defects found and fixed

1. **`frappe.copy_doc` carries the source's `docstatus`.** The card being copied
   had just been submitted, so `insert()` on the copy ran *submit* validation
   against a card with nothing on it and threw *"Time logs are required"* naming
   a document nobody had heard of. This was the whole direct-call-versus-fixture
   divergence. Found by instrumenting both paths — the split helper was never
   reached and the completion never threw, which located the failure in the
   insert between them. Permissions, `registry.execute` and `frappe.flags.in_test`
   were each tested and eliminated first. **Twenty-one failures became two.**

2. **The rework verdict was looked up through the open corrective card.** That
   card is submitted the moment an attempt is recorded, so after a failed try
   there was none — and «списать в брак» answered that nothing was at the bench
   while the piece sat there. The verdict is about the *piece*, which lives on
   the holding card; the corrective card is about one *attempt*.

3. **An ordinary "стадия закончена" resurrected a held piece.** With the hold
   card being the stage's only open card, completing the stage booked the
   damaged piece as good output with nobody having repaired it. Refused now: the
   fate of a piece at the bench belongs to the rework result.

4. **Releasing while a piece was still at the bench put it on the shelf.** An
   unresolved rework is neither good nor lost, and `complete_production` now
   subtracts held pieces from what it releases.

5. **A card that is entirely process loss cannot exist in ERPNext.**
   `Job Card.set_process_loss` derives loss only when the card completed
   something, so a fully-lost card resets its own loss to zero and then
   completed + loss + pending no longer equals `for_quantity` — it cannot be
   submitted at all. So a write-off **removes** the holding card: the piece
   never arrives, and the stages after it carry it forward as their loss, which
   is Phase 23's mechanism and collapses correctly under the maximum ERPNext
   takes across operations.

## Tools

No new tools. `manufacturing.complete_operation` gained `rework_qty` in Phase 24
and now splits the stage; `manufacturing.complete_rework` gained the third
outcome. Registry stays at **36**.

## ERPNext mechanisms used

- Several job cards per operation, summed by `get_current_operation_data`.
- `Job Card.validate_job_card_qty` — why the original is resized.
- `job_card/mapper.py:make_corrective_job_card`, with `operation_id` cleared.
- `Job Card.complete_job_card` throughout.
- `Stock Entry.set_process_loss_qty` — the maximum across operations.

## Tests

**545** `korkem_ai` (+27), **13** `korkem_manufacturing`, **311** Flutter, **19**
integration. `analyze` clean, `format` clean (203 files), secret scan clean,
`git diff --check` clean, four vendored repositories pristine.

Covering the brief: 5 started → 4 good + 1 held; the stage reports its four to
the work order; the next stage runs on four with no false loss; the held piece
stays out of it; a failed attempt leaves the piece where it was; a second
attempt opens a second corrective card and can succeed; a piece cannot be sent
to two benches at once; a recovered piece is walked through the rest; every
stage ends at five and none at six; the recovered piece reaches finished goods
with `produced_qty` equal to the Manufacture ledger; a written-off piece never
does; a piece still at the bench is not released; company isolation.

## Android E2E — NOT PASSING

`parallel_rework_e2e_test.dart` gets through the interesting part and then
stalls:

```
Запусти производство…                          → card → Confirm  ✓
Раскрой: сделали 5, одна в браке…               → card → Confirm  ✓
   card A 4 submitted · card B 1 draft · operation completed_qty 4
Кромление закончено.                            → card → Confirm  ✓
   Кромление completed 4 · process_loss 0
Исправление не удалось.                         → card → Confirm  ✓
   corrective card submitted · piece still held
Списать эту деталь в брак.                      → confirmed, then no answer
```

The confirmation card appears and names `manufacturing.complete_rework`, the tap
resolves the pending action, and then the turn produces no reply and the holding
card is still there after six minutes. Run twice with the same result.

**The product is not what fails.** Executing that exact call against that exact
bench state returns `scrapped` and removes the holding card, and the backend
suite covers the same path end to end. The device failure is at the model or
turn-completion layer and has not been diagnosed.

## Independent ERPNext verification

From the device run, read from the database rather than the transcript:

```
Job Card  Раскрой   for_quantity 4.0  submitted     ← the good pieces
Job Card  Раскрой   for_quantity 1.0  draft         ← the held piece
Job Card  Исправление брака  1.0  submitted         ← the failed attempt
Job Card  Кромление for_quantity 4.0  submitted
Work Order Operation  Раскрой 4.0/0.0 · Кромление 4.0/0.0
```

And on the bench, the write-off through to release:

```
ops after write-off:  ЧПУ 4.0/1.0 · Сверление 4.0/1.0 · Покраска 4.0/1.0 · Сборка 4.0/1.0
release: released_qty 5.0 · produced_qty 4.0 · scrap_qty 1.0
```

Five started, one written off, **four produced**.

## Remaining limitations

- **The Android run is unverified past the write-off**, above.
- A recovered piece must be walked through the later stages by naming them; the
  assistant does not offer to do it unprompted.
- `corrective_operation_cost` still stays 0 — ERPNext only rolls it into the
  work order when `add_corrective_operation_cost_in_finished_good_valuation` is
  set, which would change costing for every job.
- Row-level User Permissions remain unverified, unchanged since Phase 12.

## Commits

`korkem_ai`, root — listed in the final report.
