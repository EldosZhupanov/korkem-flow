> **АРХИВ. Это не описание системы сегодня.**
> Документ сохранён ради причин, стоящих за решениями. Актуальное состояние — в `NOW.md`, `ROADMAP.md`, `PLAN.md`.
> Не строить по этому файлу.

---

# Phase 18 — Capacity & Priority

**Date:** 2026-08-09. Follows Phase 17 (Job Cards & Shop Floor). Read-only slice.

## DONE

Two READ tools, no writes:

| Tool | Answers |
|---|---|
| `manufacturing.capacity` | «какая загрузка производства», «какой станок перегружен», «как загружен ЧПУ» |
| `manufacturing.production_priority` | «что запускать первым», «почему этот заказ первый», «какие заказы под угрозой» |

Registry: **30 tools**. Neither takes a `company` argument; both use the
existing server-side scope.

## DATA LIMITATIONS — what actually exists

Read off the bench, not from the schema.

**Trustworthy and used:**

- `Workstation.working_hours` — 08:00–16:00 on all four stations
- `Workstation.production_capacity` — 1 or 2 jobs in parallel
- `Workstation.hour_rate` — 4500 / 3800 / 7200 / 3200 KZT
- `Work Order Operation.time_in_mins` — planned minutes for the order quantity
- `Work Order Operation.completed_qty` and `status`
- `Work Order.expected_delivery_date`

**Present and deliberately NOT used:**

- **`Work Order Operation.planned_start_time` / `planned_end_time`.** ERPNext's
  scheduler populated them and they disagree with `time_in_mins` on **three of
  seven** operations — 120 planned minutes dropped into an 08:00–08:20 window,
  150 into a fifty-minute one. A load profile built on those would be an
  hour-by-hour picture that is confidently wrong.

**Absent, so nothing is claimed about it:**

- No `holiday_list` on any workstation → non-working days are unknown, so no
  claim about calendar scheduling.
- No `Employee` on time logs → no per-person capacity.

**Consequence:** week-level capacity cannot be computed honestly, so it is not
offered. Only day-level, and it is labelled as backlog rather than a timetable.

## DECISION LOG

**Utilisation means backlog against one day, not a schedule.**

```
available_hours = working window × production_capacity      (per day)
queued_hours    = Σ remaining minutes of unfinished operations
utilisation     = queued_hours ÷ available_hours
```

Above 100% means more than a day's work is waiting. The tool says so in its own
`basis` field rather than letting the phrasing imply a timetable it cannot
support. Remaining minutes are scaled by the *operation's* own `completed_qty`,
not the work order's `produced_qty` — a job can be six units through assembly
and have touched nothing on the saw.

**Bottleneck = the busiest measurable station.** Not the one that looks
important. A station whose working hours are missing has no utilisation and
therefore cannot be the bottleneck — it is reported with
`reason_unknown` instead, and its queued hours are still shown so the work does
not vanish.

**Risk is only claimed when it can be proved.** An order's operations are
serial, so the fastest it can possibly finish is the sum of its own remaining
minutes — assuming it has the whole shop and never waits. If even that exceeds
the time before the delivery date, the order provably cannot make it.

- `AT_RISK` — overdue, or the optimistic bound fails
- `ON_TRACK` — **not provably late**, which is a weaker claim than "will arrive"
  and is named that way on purpose
- `UNKNOWN` — no delivery date, or no working hours to measure against
- Blocked orders are not in the queue at all

**Priority is constraint-ordered, not scored.** In order: cannot start →
excluded and listed separately as a purchasing problem; then provably late;
then orders that free the overloaded station; then soonest delivery date. Every
row carries a sentence, and a test asserts no row carries a score.

## LIVE VERIFIED

`capacity_e2e_test.dart`, `emulator-5554`, as `korkem.planner@example.com`:
`00:59 +1: All tests passed!`

Five questions, all answered from tool data:

```
Какая загрузка производства? → 45,5 ч в очереди на 4 участках
   Покраска и сборка 156% (25,0 / 16 ч) · ЧПУ 94% · Раскрой 75% · Кромка 44%
Какой станок перегружен?     → Покраска и сборка, 156%
Что запускать первым?        → Тумба Караганда (MFG-WO-2026-00006)
Почему этот заказ первый?    → просрочен на 3 дня, и освобождает
                                самый загруженный участок
Какие заказы под угрозой?    → Шкаф Астана заблокирован: ДСП 16мм, не хватает 4
```

Gemini chose one tool per question — `capacity` for the first two,
`production_priority` for the rest.

## ERPNext VERIFIED

The load was recomputed straight from the database, independently of the tool,
and matches to the percent:

```
Кромка и сверловка   7.0 h / 16.0 h/day =  44%
Покраска и сборка   25.0 h / 16.0 h/day = 156%
Раскрой              6.0 h /  8.0 h/day =  75%
ЧПУ                  7.5 h /  8.0 h/day =  94%

overdue: MFG-WO-2026-00006 Тумба Караганда, due 2026-08-06
```

**Why that order is first, from the data:** it is the only live work order past
its delivery date (three days), and its routing includes Покраска и сборка, the
one station over 100%. Rule 3 puts it first; rule 5 would have anyway.

## Tests

**423** `korkem_ai` (+18), 13 `korkem_manufacturing`, 311 Flutter, 15
integration. `analyze` and `format` clean.

The eighteen cover: available hours are shift × parallel jobs; utilisation is
queued ÷ capacity; overloaded is above one day; the bottleneck is the busiest
measurable station; finished operations carry no load; a station with no working
hours yields no utilisation and cannot be the bottleneck; an order with no
delivery date is not called late; blocked orders stay out of the queue;
overdue orders are at risk and say by how much; at-risk sorts first; every
position has a reason and no score; on-track quotes both numbers; the bottleneck
is named when an order frees it; neither tool takes a company; both are reads;
another company's work never reaches the load; a viewer may read it.

## NOT VERIFIED

- **Week-level capacity** — not implemented, because holiday lists and reliable
  planned times are absent (see DATA LIMITATIONS).
- **Queueing between orders.** The optimistic bound assumes an order never waits
  behind another. Two orders competing for the saw are each measured alone, so
  `ON_TRACK` is weaker than it looks — hence the wording.
- **Sub-operations and process loss.**
- **A station with several working-hour windows** — all four have one shift.
- **Cancelled work orders** are excluded by the status filter; no test asserts
  it directly.

## BLOCKERS

None.

## NEXT STEP

CRM ↔ Production, as agreed. `Work Order.originating_deal` already exists and no
tool traverses it.
