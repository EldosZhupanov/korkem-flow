# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""How loaded the shop is, and what to start first.

## What the data actually supports

Read off this bench rather than assumed:

* **Workstations carry real capacity** — a working-hours window (08:00–16:00)
  and `production_capacity`, how many jobs run side by side. Both are ERPNext's
  own fields and both are populated.
* **`Work Order Operation.time_in_mins` is real** — the planned minutes for the
  whole order quantity, scaled from the routing.
* **`planned_start_time` / `planned_end_time` are not trusted.** ERPNext's
  scheduler populated them, and on this factory they disagree with
  `time_in_mins` on three of seven operations — 120 planned minutes dropped into
  a twenty-minute window. Building a load profile on those would produce a
  confident hour-by-hour picture that is wrong, so this module ignores them.

That leaves an honest model and rules out a dishonest one. There is enough to
say *how much work is queued at each station against a day of its capacity*.
There is not enough to say *when* a given operation will run, so nothing here
claims to.

## Utilisation means backlog, not a timetable

    available_hours = working window × production_capacity      (per day)
    queued_hours    = Σ remaining minutes of unfinished operations
    utilisation     = queued_hours ÷ available_hours

Over 100% means more than one day's work is waiting — real, and the number a
foreman acts on. It does not mean the station is overbooked *today*, and the
tool says so rather than implying a schedule it cannot support.

## Risk is only claimed when it can be proved

An order's operations run one after another, so the fastest it can possibly
finish is the sum of its own remaining minutes — that is, assuming it has the
whole factory and never waits. If even *that* exceeds the time left before the
delivery date, the order provably cannot make it, and `AT_RISK` is a fact rather
than a guess.

The reverse is not claimed. Fitting inside the optimistic bound only means the
order is not provably late, which is why the other band is called `ON_TRACK`
rather than "will be delivered".

Where the data runs out — no delivery date, no workstation on an operation, no
working hours on a station — the order or station is reported as
`unknown` with the reason named. Nothing is filled in.
"""

from __future__ import annotations

import frappe
from frappe.utils import flt, get_datetime, getdate, nowdate

from korkem_ai.korkem_ai.tools.registry import Risk, ToolSpec, register
from korkem_ai.korkem_ai.tools.scope import scoped

#: Work Orders whose operations still represent work to do.
LIVE_STATUSES = ("Not Started", "In Process")

#: Operation states that still have work left in them.
UNFINISHED = ("Pending", "Work in Progress")

#: Utilisation at which a station is called overloaded. One day's capacity is
#: the unit, so this is "more work queued than a day can absorb" — not a
#: tuned coefficient.
OVERLOADED = 1.0


def _workstation_capacity() -> dict[str, dict]:
	"""Hours a day each station can absorb, from its own configuration."""
	found = {}
	for name in frappe.get_all("Workstation", pluck="name"):
		station = frappe.get_cached_doc("Workstation", name)
		windows = [row for row in station.working_hours if row.enabled]
		hours = sum(
			(get_datetime(f"2000-01-01 {row.end_time}") - get_datetime(f"2000-01-01 {row.start_time}")).seconds
			/ 3600
			for row in windows
		)
		parallel = max(1, int(station.production_capacity or 1))
		found[name] = {
			"workstation": name,
			"hours_per_day": round(hours * parallel, 2) if hours else None,
			"shift_hours": round(hours, 2),
			"parallel_jobs": parallel,
			"hour_rate": flt(station.hour_rate),
		}
	return found


def _outstanding_operations() -> list[dict]:
	"""Every unfinished operation on a live job, with its remaining minutes.

	Remaining is scaled by how much of the *operation* is done, not by the work
	order's `produced_qty` — a job can be six units through assembly and have
	touched nothing on the saw.
	"""
	jobs = frappe.get_list(
		"Work Order",
		filters=scoped({"docstatus": 1, "status": ["in", LIVE_STATUSES]}),
		fields=["name", "qty", "produced_qty", "sales_order", "production_item", "expected_delivery_date"],
		limit_page_length=0,
	)
	if not jobs:
		return []

	by_name = {job["name"]: job for job in jobs}
	rows = []
	for op in frappe.get_all(
		"Work Order Operation",
		filters={"parent": ["in", list(by_name)], "status": ["in", UNFINISHED]},
		fields=[
			"parent",
			"operation",
			"workstation",
			"status",
			"completed_qty",
			"time_in_mins",
			"sequence_id",
		],
		order_by="sequence_id asc",
	):
		job = by_name[op["parent"]]
		total = flt(job["qty"]) or 1
		done = min(flt(op["completed_qty"]), total)
		remaining = flt(op["time_in_mins"]) * (1 - done / total)
		rows.append({**op, "work_order": op["parent"], "remaining_mins": round(remaining, 2), "job": job})
	return rows


def factory_capacity():
	"""How much work is queued at each station, against a day of its capacity."""
	stations = _workstation_capacity()
	outstanding = _outstanding_operations()

	load: dict[str, float] = {}
	unknown_station = []
	for row in outstanding:
		if not row["workstation"]:
			unknown_station.append({"work_order": row["work_order"], "operation": row["operation"]})
			continue
		load[row["workstation"]] = load.get(row["workstation"], 0.0) + row["remaining_mins"]

	reported = []
	for name, queued_mins in sorted(load.items()):
		station = stations.get(name)
		hours = round(queued_mins / 60, 2)
		if not station or not station["hours_per_day"]:
			# Named rather than filled in. A station with no working hours has
			# no capacity to divide by, and inventing one would produce a
			# utilisation figure with nothing behind it.
			reported.append(
				{
					"workstation": name,
					"queued_hours": hours,
					"available_hours_per_day": None,
					"utilisation": None,
					"overloaded": None,
					"reason_unknown": "no working hours are configured for this workstation",
				}
			)
			continue

		utilisation = round(hours / station["hours_per_day"], 3)
		reported.append(
			{
				**station,
				"queued_hours": hours,
				"available_hours_per_day": station["hours_per_day"],
				"utilisation": utilisation,
				"utilisation_percent": round(utilisation * 100),
				"overloaded": utilisation > OVERLOADED,
				"days_of_work_queued": round(utilisation, 2),
			}
		)

	measurable = [row for row in reported if row["utilisation"] is not None]
	busiest = max(measurable, key=lambda row: row["utilisation"], default=None)

	return {
		"as_of": nowdate(),
		"basis": (
			"Queued hours are the remaining planned minutes of unfinished "
			"operations. Utilisation is those hours against one day of the "
			"station's own capacity, so above 100% means more than a day's work "
			"is waiting — not that the station is overbooked today."
		),
		"summary": {
			"workstations_with_work": len(reported),
			"overloaded_workstations": len([row for row in reported if row.get("overloaded")]),
			"total_queued_hours": round(sum(row["queued_hours"] for row in reported), 2),
			"unmeasurable_workstations": len(reported) - len(measurable),
		},
		"workstations": reported,
		"bottleneck": (
			{
				"workstation": busiest["workstation"],
				"utilisation_percent": busiest["utilisation_percent"],
				"queued_hours": busiest["queued_hours"],
				"available_hours_per_day": busiest["available_hours_per_day"],
				"overloaded": busiest["overloaded"],
			}
			if busiest
			else None
		),
		# Reported, never silently dropped: an operation with no workstation is
		# work nobody has anywhere to do.
		"operations_without_a_workstation": unknown_station,
	}


def _risk_for(job: dict, remaining_hours: float, day_hours: float | None) -> tuple[str, str]:
	"""Whether this job can be proved late, and why in one sentence."""
	due = job.get("expected_delivery_date")
	if not due:
		return "unknown", "no delivery date is set, so lateness cannot be judged"

	days_left = (getdate(due) - getdate(nowdate())).days
	if days_left < 0:
		return "at_risk", f"already {abs(days_left)} days past its delivery date of {due}"

	if not day_hours:
		return "unknown", "no workstation working hours are configured, so time left cannot be measured"

	# The most optimistic possible schedule: this job alone, never waiting.
	hours_available = round(days_left * day_hours, 2)
	if remaining_hours > hours_available:
		return "at_risk", (
			f"needs {remaining_hours} h of work and only {hours_available} h remain before "
			f"{due}, even with the whole shop to itself"
		)

	return "on_track", (
		f"{remaining_hours} h of work left and {hours_available} h before {due}"
	)


def production_priority():
	"""What to start first, as ordered constraints rather than a score.

	Every position is a rule that either applies or does not, so «почему этот
	заказ первый» is answerable in one sentence from data. A weighted score
	would answer it with arithmetic nobody can check.
	"""
	from korkem_ai.korkem_ai.tools.procurement import material_shortage

	stations = _workstation_capacity()
	outstanding = _outstanding_operations()
	shift = [row["shift_hours"] for row in stations.values() if row["shift_hours"]]
	day_hours = min(shift) if shift else None

	capacity = factory_capacity()
	bottleneck = capacity["bottleneck"]
	overloaded_station = (
		bottleneck["workstation"] if bottleneck and bottleneck["overloaded"] else None
	)

	jobs: dict[str, dict] = {}
	for row in outstanding:
		entry = jobs.setdefault(
			row["work_order"],
			{**row["job"], "work_order": row["work_order"], "remaining_mins": 0.0, "stations": set()},
		)
		entry["remaining_mins"] += row["remaining_mins"]
		if row["workstation"]:
			entry["stations"].add(row["workstation"])

	blocked, queue = [], []
	for job in jobs.values():
		remaining_hours = round(job["remaining_mins"] / 60, 2)
		sales_order = job.get("sales_order")

		missing = []
		if sales_order:
			missing = material_shortage(sales_order)["not_on_the_shelf"]

		if missing:
			# Rule 1 and 2: it cannot be started at all, so it is a purchasing
			# problem and not a sequencing one. Kept out of the queue entirely
			# rather than sorted to the bottom of it.
			blocked.append(
				{
					"work_order": job["work_order"],
					"sales_order": sales_order,
					"item_code": job["production_item"],
					"delivery_date": str(job["expected_delivery_date"]) if job["expected_delivery_date"] else None,
					"blocking_materials": [
						{"item_code": m["item_code"], "short_by": m["physical_shortage_qty"], "uom": m["uom"]}
						for m in missing
					],
					"reason": "cannot start — "
					+ ", ".join(f"{m['item_code']} short {m['physical_shortage_qty']} {m['uom']}" for m in missing),
				}
			)
			continue

		risk, why = _risk_for(job, remaining_hours, day_hours)
		frees = overloaded_station in job["stations"] if overloaded_station else False
		queue.append(
			{
				"work_order": job["work_order"],
				"sales_order": sales_order,
				"item_code": job["production_item"],
				"delivery_date": str(job["expected_delivery_date"]) if job["expected_delivery_date"] else None,
				"days_to_delivery": (
					(getdate(job["expected_delivery_date"]) - getdate(nowdate())).days
					if job["expected_delivery_date"]
					else None
				),
				"remaining_hours": remaining_hours,
				"risk": risk.upper(),
				"frees_bottleneck": frees,
				"bottleneck": overloaded_station if frees else None,
				"reason": why
				+ (f"; also frees {overloaded_station}, the busiest station" if frees else ""),
			}
		)

	# Rules 3–6, in that order. `sorted` is stable, so each key only breaks the
	# ties the one before it left.
	rank = {"AT_RISK": 0, "UNKNOWN": 1, "ON_TRACK": 2}
	queue.sort(
		key=lambda row: (
			rank.get(row["risk"], 3),
			not row["frees_bottleneck"],
			row["days_to_delivery"] if row["days_to_delivery"] is not None else 9999,
		)
	)
	for position, row in enumerate(queue, start=1):
		row["position"] = position

	return {
		"as_of": nowdate(),
		"basis": (
			"Ordered by constraints, not by a score: anything that cannot start "
			"is excluded, then provably late orders, then orders that free the "
			"busiest station, then the soonest delivery date."
		),
		"summary": {
			"ready_to_sequence": len(queue),
			"blocked_by_material": len(blocked),
			"at_risk": len([row for row in queue if row["risk"] == "AT_RISK"]),
			"unknown_risk": len([row for row in queue if row["risk"] == "UNKNOWN"]),
			"bottleneck": overloaded_station,
		},
		"queue": queue,
		"blocked": blocked,
	}


register(
	ToolSpec(
		name="manufacturing.capacity",
		description=(
			"How loaded each workstation is: hours of work queued against a day "
			"of its own capacity, and which station is the bottleneck. Use for "
			"«какая загрузка производства», «какие станки перегружены», «как "
			"загружен ЧПУ». Report the numbers as given; utilisation above 100% "
			"means more than a day's work is waiting, not that the station is "
			"overbooked today."
		),
		input_schema={"type": "object", "properties": {}, "required": []},
		handler=factory_capacity,
		risk=Risk.READ,
		doctypes=("Workstation", "Work Order"),
		audit_category="manufacturing",
		timeout=60,
	)
)

register(
	ToolSpec(
		name="manufacturing.production_priority",
		description=(
			"What to start first, and why. Returns an ordered queue with a "
			"one-sentence reason for each position, plus the orders that cannot "
			"start at all because material is missing. Use for «что запускать "
			"первым», «почему этот заказ первый», «какие заказы под угрозой». "
			"Give the reasons as written — they are the answer, not a score."
		),
		input_schema={"type": "object", "properties": {}, "required": []},
		handler=production_priority,
		risk=Risk.READ,
		doctypes=("Work Order", "Workstation", "Sales Order", "BOM", "Bin"),
		audit_category="manufacturing",
		timeout=60,
	)
)
