# Phase 17 — Job Cards & the shop floor

**Date:** 2026-08-09. Follows the Company Scoping + Production Execution slice.

## Goal

Work Orders already carried seven real operations, but nothing recorded them
happening. A foreman should be able to say «начали раскрой» and «раскрой
закончен» and have ERPNext's own Job Cards, time logs and Work Order Operations
move — not a status flag of ours.

## What was reused, and what was not

**ERPNext creates Job Cards itself**, on Work Order submit
(`work_order.on_submit` → `create_job_card_from_wo`). Nothing in KORKEM creates
one; the 42 cards on this bench arrived that way. Starting and finishing go
through the card's own time logs, and **submitting the card is what updates the
Work Order Operation** — that update is ERPNext's, not ours.

**`korkem_manufacturing.shop_floor.complete_task()` was read and deliberately
not built on.** It completes a *CRM Task* attached to a Work Order and adds a
timeline comment. It touches no Job Card, no Work Order Operation and no time
log, so it is a parallel notion of "shop floor" rather than an implementation of
this one. Left alone; flagged as something to reconcile or retire later.

## Tools

| Tool | | |
|---|---|---|
| `manufacturing.shop_floor` | **new**, READ | what each workstation is running and what is queued, with completed/for quantities |
| `manufacturing.start_operation` | **new**, WRITE | «начали кромление» — opens a time log |
| `manufacturing.complete_operation` | **new**, WRITE | «раскрой закончен» — closes the log, submits the card, advances the job |
| `manufacturing.production_control` | extended | now carries the live job card and its progress per work order |

Registry: **28 tools**. A person names a stage and an order, never a card
number — `_resolve_card` finds the order, then the operation by name, then
whatever the floor is currently on.

## Calculation rules

Nothing is computed by the model. `completed_qty`, `for_quantity`,
`remaining_qty`, current and next operation, workstation, and job-card status
all come from `Job Card`, `Job Card Time Log` and `Work Order Operation`.
Sequence comes from the routing, so "next" is the routing's next rather than a
guess from how much has been done.

A quantity larger than the card holds is trimmed to it — a card cannot complete
more than it was opened for. Verified: booking 500 against a card for 5 records
5.

## Security

Company scoping throughout — `scoped()` on every Job Card query,
`ensure_company` on every named Work Order or Sales Order, and no tool accepts a
`company` argument. Asserted, including that another company's work order is
refused as "not found".

Both writes are `Risk.WRITE` behind the existing Pending Action →
ConfirmationCard → server revalidation → audit chain. No permission was widened:
the planner already holds Job Card read/write/create/submit through
`Manufacturing User`.

**Idempotent by design.** Starting a running stage returns `already_running` and
adds no second time log — two open logs would double the hours the operation is
costed at. Finishing a finished stage returns `already_complete` and books no
further quantity.

## Android verification — `LIVE VERIFIED`

`shop_floor_e2e_test.dart`, `emulator-5554`, signed in as
`korkem.planner@example.com`: `01:28 +1: All tests passed!`

«Что сейчас на производстве?» → Раскрой · «Начали раскрой.» → card → Confirm ·
«Сколько сделано?» · «Раскрой закончен.» → card → Confirm · «Что сейчас на
станке?» → Кромление.

## ERPNext verification

Read from the database afterwards, not from the transcript:

```
Work Order MFG-WO-2026-00007  In Process  qty 5
Job Card PO-JOB00001  Раскрой @ Раскрой  status Completed  docstatus 1
  total_completed_qty 5.0 / for_quantity 5.0   owner korkem.planner@example.com
  time log  12:06:09 → 12:06:35   completed_qty 5.0
Work Order Operation  Раскрой Completed 5.0 · Кромление Pending · ЧПУ Pending
audit  start_operation  Approved 12:06:10  · complete_operation Approved 12:06:35
        both korkem.planner@example.com · Google Gemini
```

## Tests

**405** `korkem_ai` (+16), 13 `korkem_manufacturing`, 311 Flutter, 14
integration. `analyze` and `format` clean.

The sixteen cover the brief's list and no more: cards exist for every stage;
the first is queued; progress against the card's own quantity; starting puts the
stage on its workstation; a time log is what records it; finishing submits the
card and advances the work order; the next stage becomes current; finishing
without a start still records both ends; starting twice adds no second log;
finishing twice books no further quantity; both writes need confirmation; the
read does not; no tool takes a company; an unknown stage names the real ones;
more than the card holds cannot be booked; another company's job cannot be
touched.

## Defects found

1. **Orphaned Job Cards.** Deleting a Work Order left its cards pointing at a
   document that no longer existed, and every ERPNext call against one failed
   with "Could not find Work Order". Fixture cleanup now removes cards first.
2. **A blank time-log row** appeared on completion — zero minutes, zero
   quantity, a blank line on a costing document. Rows with neither end are now
   dropped before saving. Where it originated was not traced further; the guard
   is defensive either way.

## Not verified

- **Partial completion across two sittings** — finishing 2 of 5, then the rest.
  The quantity path is tested; resuming a partly-done card is not.
- **Employees on time logs.** ERPNext supports naming who did the work; the
  planner has no `Employee` record and none is attached, so hours are recorded
  against the card and not against a person.
- **`produced_qty` on the Work Order stays 0** until the final operation and a
  manufacture Stock Entry. Correct ERPNext behaviour, but it means «сколько
  изготовлено» still answers from operation progress rather than finished goods.
- Sub-operations, process loss, and the `Stopped`/`On Hold` card states.

## Next

Capacity + priority, as agreed — now that operations genuinely record when they
run, the workstation load has real data behind it.
