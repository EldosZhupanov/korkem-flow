# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""PVC glue — what it is, where it is bought, what a facade takes, and that it
is taken off the store by itself (owner, 17.11.2026: «расход клея на каждую
позицию ПВХ… клей с отвердителем в одной бочке… производитель в основном
Китай, покупаем в Алмате, Астане, Семее у JS Group, Delta Machines… можем
перепродавать с наценкой… продаётся ведром и литром»).

**A glue and its supplier are two things.** A glue is a material of its own
kind (`material_stock.GLUE`), counted in kilograms — the unit its norm (g/m²)
and its bucket are written in — with a card: where it is made, its bucket,
kilograms a litre, its norm, how much is kept back for the shop, and its two
mark-ups, bucket and litre. A supplier is a company in a city that sells it:
one company may sell film and glue and is one supplier, marked with what it
sells (`SELLS`), seen in each of its departments and in no other. The same
glue may come from several; what a kilo costs from each, with its bringing,
says which is cheaper.

**One barrel, glue and hardener together**: nothing is mixed, so a glue is one
material, not a kit as paint is.

**What a position takes** (by the glue makers' own sheets: 80–120 g/m², twice
on edges and relief):

    kg = qty × (face × sides × milling + edges × 2) × norm
    face = height × width; edges = perimeter × thickness

with the norm of the glue «в работе» — the barrel open now — and the milling's
factor (1.0 until a count says otherwise). Only PVC positions; the client's
own film still takes our glue.

**Taken off by itself** when «Вакуум» is ticked, from the glue in work, and
put back when unticked; a count (the storekeeper weighs what is left) puts
the store right, and a month of both says what a m² really took, glue by
glue — the one cheaper per m², not per kilo, is the one to buy.
"""

from __future__ import annotations

import json
from collections import defaultdict
from decimal import Decimal, InvalidOperation

import frappe
from frappe.utils import add_days, flt, get_fullname, getdate, nowdate

from korkem_manufacturing.services import (
	audit,
	directions,
	film_cash,
	film_dept,
	film_sources,
	material_stock,
	price_visibility,
)
from korkem_manufacturing.services.scope import current_company

UNIT = "кг"
DEPT = "glue"
#: What a supplier sells, one word a line: «glue», later «film», «paint».
SELLS = "korkem_supplier_sells"
SUPPLIER_CARD = ("city", "contact", "phone", "whatsapp", "min_order", "note")
MILLING_LIST = "Фрезеровка"
USE_ORDER, USE_COUNT = "order", "count"
USAGE_DAYS = 30
#: Edges take a second coat (the glue makers' sheets).
EDGE_COATS = 2
#: A landed price is the average over the receipts of this many days.
LANDED_DAYS = 180
_KEY = "korkem_glue_settings"

#: A new glue's card until it says its own.
CARD_DEFAULT = {"origin": "Китай", "bucket_kg": None, "kg_per_litre": 1.0, "norm_g_m2": 100.0,
				"reserve_kg": 0.0, "markup_bucket": 0.0, "markup_litre": 0.0}
LIMITS = {"bucket_kg": (0.1, 1000), "kg_per_litre": (0.5, 2.0), "norm_g_m2": (10, 1000), "reserve_kg": (0, 100000),
		  "markup_bucket": (0, 1000), "markup_litre": (0, 1000)}
MILLING_MAX = 5.0


# --------------------------------------------------------------------------
# Settings: each glue's card, the glue in work, the millings' factors
# --------------------------------------------------------------------------


def _settings(company: str) -> dict:
	raw = frappe.db.get_default(f"{_KEY}:{company}")
	try:
		value = json.loads(raw) if raw else {}
	except ValueError:
		value = {}
	return {"glues": dict(value.get("glues") or {}), "in_work": value.get("in_work"),
			"milling": dict(value.get("milling") or {})}


def _save(company: str, settings: dict) -> None:
	frappe.db.set_default(f"{_KEY}:{company}", json.dumps(settings, ensure_ascii=False))


def _number(value, key: str) -> float | None:
	if value in (None, ""):
		return None
	try:
		number = Decimal(str(value).replace(",", ".").strip())
	except (InvalidOperation, ValueError):
		frappe.throw("Нужно число.")
	low, high = LIMITS[key]
	if not number.is_finite() or number < low or number > high:
		frappe.throw(f"Значение должно быть от {low} до {high}.")
	return float(number)


def card(item: str, company: str | None = None) -> dict:
	"""A glue's card, the common one where it says nothing of its own."""
	own = _settings(company or current_company())["glues"].get(item) or {}
	return {**CARD_DEFAULT, **{k: v for k, v in own.items() if k in CARD_DEFAULT}}


def _clean_card(values: dict, base: dict) -> dict:
	out = dict(base)
	if "origin" in values:
		out["origin"] = " ".join(str(values.get("origin") or "").split())[:60] or None
	for key in LIMITS:
		if key in values:
			number = _number(values.get(key), key)
			out[key] = number if number is not None else (None if key == "bucket_kg" else CARD_DEFAULT[key])
	return out


def _glue_item(item: str, company: str) -> None:
	if frappe.db.get_value("Item", item, ["korkem_material_company", "korkem_material_kind"]) != (
			company, material_stock.GLUE):
		frappe.throw("Такого клея нет.", frappe.DoesNotExistError)


def add_glue(name: str, **values) -> dict:
	"""A glue: its name, where it is made, its bucket, kilograms a litre, its
	norm. The first one is the one in work."""
	material_stock._ensure_editor()
	clean = " ".join(str(name or "").split())[:120]
	if len(clean) < 2:
		frappe.throw("Как называется клей?")
	company = current_company()
	made = material_stock.define_material(material_stock.GLUE, UNIT, name=clean)
	settings = _settings(company)
	settings["glues"][made["item"]] = _clean_card(values, card(made["item"], company))
	if not settings["in_work"] or settings["in_work"] not in settings["glues"]:
		settings["in_work"] = made["item"]
	_save(company, settings)
	audit.record_audit(action="glue.added", entity_type="Item", entity_id=made["item"],
					   diff={"name": clean, **settings["glues"][made["item"]]})
	return stock()


def set_glue(item: str, **values) -> dict:
	"""Change a glue's card — what is sent changes."""
	material_stock._ensure_editor()
	company = current_company()
	_glue_item(item, company)
	settings = _settings(company)
	settings["glues"][item] = _clean_card(values, card(item, company))
	_save(company, settings)
	audit.record_audit(action="glue.card", entity_type="Item", entity_id=item, diff=settings["glues"][item])
	return stock()


def set_in_work(item: str) -> dict:
	"""A new barrel opened: this glue is the one taken from now on."""
	material_stock._ensure_editor()
	company = current_company()
	_glue_item(item, company)
	settings = _settings(company)
	settings["in_work"] = item
	settings["glues"].setdefault(item, card(item, company))
	_save(company, settings)
	audit.record_audit(action="glue.in_work", entity_type="Item", entity_id=item, diff={})
	return stock()


def set_milling(factors) -> dict:
	"""How much more glue a milling takes than a smooth face: 1.0 is the same."""
	material_stock._ensure_editor()
	if isinstance(factors, str):
		factors = frappe.parse_json(factors) if factors.strip() else {}
	company = current_company()
	known = material_stock.enabled_values(MILLING_LIST, company)
	clean = {}
	for name, value in (factors or {}).items():
		if name not in known:
			continue
		try:
			number = float(str(value).replace(",", "."))
		except ValueError:
			frappe.throw("Поправка — число, например 1,2.")
		if not 0.5 <= number <= MILLING_MAX:
			frappe.throw(f"Поправка — от 0,5 до {MILLING_MAX:g}.")
		if number != 1.0:
			clean[name] = round(number, 2)
	settings = _settings(company)
	settings["milling"] = clean
	_save(company, settings)
	audit.record_audit(action="glue.milling", entity_type="Company", entity_id=company, diff=clean)
	return stock()


def in_work(company: str | None = None) -> str | None:
	company = company or current_company()
	item = _settings(company)["in_work"]
	if item and frappe.db.get_value("Item", item, "disabled") == 0:
		return item
	return None


# --------------------------------------------------------------------------
# What a position takes
# --------------------------------------------------------------------------


def _line_kg(line, norm_g_m2: float, milling: dict, coating) -> float:
	if coating != "pvc":
		return 0.0
	h, w = flt(line.korkem_height_mm) / 1000, flt(line.korkem_width_mm) / 1000
	qty, t = flt(line.qty), flt(line.korkem_thickness_mm) / 1000
	face = flt(line.korkem_area_m2) or h * w * qty
	sides = 2 if line.korkem_double_sided else 1
	edges = 2 * (h + w) * t * qty
	factor = flt(milling.get(line.korkem_milling or "") or 1.0)
	return (face * sides * factor + edges * EDGE_COATS) * norm_g_m2 / 1000


def _lines(orders: list[str]):
	if not orders:
		return []
	from korkem_manufacturing.services import facade_order

	return frappe.get_all(
		"Sales Order Item",
		filters={"parent": ["in", orders], "item_code": facade_order.FACADE_ITEM},
		fields=["name", "parent", "qty", "korkem_height_mm", "korkem_width_mm", "korkem_thickness_mm",
				"korkem_area_m2", "korkem_double_sided", "korkem_milling", "korkem_line_coating",
				"korkem_finish"],
		order_by="idx asc",
		limit_page_length=0,
	)


def order_glue(order: str, company: str | None = None) -> dict:
	"""Each PVC position's glue, and the order's: by the glue in work."""
	from korkem_manufacturing.services import mdf_orders

	company = company or frappe.db.get_value("Sales Order", order, "company") or current_company()
	settings = _settings(company)
	item = in_work(company)
	norm = flt(card(item, company)["norm_g_m2"]) if item else CARD_DEFAULT["norm_g_m2"]
	head = frappe.db.get_value("Sales Order", order, "korkem_finish")
	lines, total, m2 = {}, 0.0, 0.0
	for line in _lines([order]):
		coating = line.korkem_line_coating or mdf_orders.coating_of(line.korkem_finish or head)
		kg = _line_kg(line, norm, settings["milling"], coating)
		if kg:
			lines[line.name] = round(kg, 3)
			total += kg
			m2 += flt(line.korkem_area_m2) * (2 if line.korkem_double_sided else 1)
	return {"lines": lines, "kg": round(total, 2), "m2": round(m2, 2), "item": item,
			"title": frappe.db.get_value("Item", item, "item_name") if item else None, "norm_g_m2": norm}


def _vacuum_queue(company: str) -> list[str]:
	"""Orders whose facades are still to go through the vacuum press."""
	from korkem_manufacturing.services import mdf_orders

	rows = frappe.get_all(
		"Sales Order",
		filters={"company": company, "korkem_direction": directions.FACADES, "docstatus": 1,
				 "korkem_ready_on": ["is", "not set"], "korkem_handed_over_on": ["is", "not set"],
				 "korkem_hold_reason": ["is", "not set"]},
		fields=["name", "korkem_finish", "korkem_extra_stages", "korkem_coatings", "korkem_tags",
				*mdf_orders.STAGES.values()],
		limit_page_length=2000,
	)
	return [r.name for r in rows if "vacuum" in mdf_orders.stages_of(r) and not r.get(mdf_orders.STAGES["vacuum"])]


def queue_need(company: str) -> dict:
	"""What the orders still to go through the vacuum press need."""
	kg = m2 = 0.0
	orders = 0
	for order in _vacuum_queue(company):
		glue = order_glue(order, company)
		if glue["kg"]:
			kg += glue["kg"]
			m2 += glue["m2"]
			orders += 1
	return {"kg": round(kg, 2), "m2": round(m2, 2), "orders": orders}


# --------------------------------------------------------------------------
# Suppliers: who sells glue — a mark on the supplier, not a list of its own
# --------------------------------------------------------------------------


def _sells(supplier: str) -> list[str]:
	return [t for t in (frappe.db.get_value("Supplier", supplier, SELLS) or "").split("\n") if t]


def _mark(supplier: str) -> None:
	tags = _sells(supplier)
	if DEPT not in tags:
		frappe.db.set_value("Supplier", supplier, SELLS, "\n".join([*tags, DEPT]))


def sells_glue(supplier: str | None) -> bool:
	return bool(supplier) and DEPT in _sells(supplier)


def _suppliers(company: str, allowed: bool) -> list[dict]:
	"""Who sells glue, with its card, and what a kilo of each glue last cost
	from it — its bringing shared over it — the cheapest first."""
	card_fields = {key: film_sources.CARD[key] for key in SUPPLIER_CARD}
	rows = frappe.get_all("Supplier", filters={"disabled": 0, SELLS: ["like", f"%{DEPT}%"]},
						  fields=["name", "supplier_name", SELLS, *card_fields.values()], limit_page_length=500)
	last: dict[str, list[dict]] = defaultdict(list)
	seen = set()
	for d in frappe.db.sql(
		"""select se.korkem_supplier as supplier, sed.item_code, sed.item_name, sed.qty, sed.basic_rate,
			se.korkem_delivery_cost, se.posting_date
		from `tabStock Entry Detail` sed join `tabStock Entry` se on se.name = sed.parent
		where se.company = %(company)s and se.docstatus = 1 and se.korkem_material_receipt = 1
			and se.korkem_receipt_dept = %(dept)s
		order by se.posting_date desc, se.creation desc limit 500""",
		{"company": company, "dept": DEPT},
		as_dict=True,
	):
		if (d.supplier, d.item_code) in seen:
			continue
		seen.add((d.supplier, d.item_code))
		kg = flt(d.qty)
		landed = flt(d.basic_rate) + (flt(d.korkem_delivery_cost) / kg if kg else 0)
		last[d.supplier].append({
			"item": d.item_code, "title": d.item_name, "date": str(d.posting_date),
			"price_kg": price_visibility.money(round(flt(d.basic_rate), 2), allowed=allowed),
			"delivery_kg": price_visibility.money(round(landed - flt(d.basic_rate), 2), allowed=allowed),
			"landed_kg": price_visibility.money(round(landed, 2), allowed=allowed), "_landed": landed,
		})
	out = []
	for r in rows:
		if DEPT not in (r.get(SELLS) or "").split("\n"):
			continue
		bought = last.get(r.name, [])
		cheapest = min((b["_landed"] for b in bought), default=None)
		out.append({
			"supplier": r.name, "name": r.supplier_name or r.name,
			"sells": [t for t in (r.get(SELLS) or "").split("\n") if t],
			**{key: r.get(field) for key, field in card_fields.items()},
			"bought": [{k: v for k, v in b.items() if k != "_landed"} for b in bought],
			"_rank": cheapest if cheapest is not None else float("inf"),
		})
	out.sort(key=lambda s: (s["_rank"], s["name"].casefold()))
	# The cheapest, glue by glue, is marked.
	best: dict[str, tuple[float, str]] = {}
	for s in out:
		for b in last.get(s["supplier"], []):
			if b["item"] not in best or b["_landed"] < best[b["item"]][0]:
				best[b["item"]] = (b["_landed"], s["supplier"])
	for s in out:
		s.pop("_rank")
		for b in s["bought"]:
			b["cheapest"] = best.get(b["item"], (0, None))[1] == s["supplier"] and len(
				[x for x in out if any(y["item"] == b["item"] for y in x["bought"])]) > 1
	return out


def add_supplier(name: str, **card) -> dict:
	"""A glue supplier. A company already known — it sells film or paint too —
	is the same supplier, now also selling glue: never a second one."""
	material_stock._ensure_editor()
	clean = " ".join(str(name or "").split())
	material_stock.add_supplier(clean)
	supplier = frappe.db.get_value("Supplier", {"supplier_name": clean}, "name")
	_mark(supplier)
	audit.record_audit(action="glue.supplier", entity_type="Supplier", entity_id=supplier, diff={"name": clean})
	return set_supplier(supplier, **card)


def set_supplier(supplier: str, **card) -> dict:
	"""A glue supplier's card: city, person, phones, smallest batch, a note."""
	material_stock._ensure_editor()
	if not sells_glue(supplier):
		frappe.throw("Такого поставщика клея нет.", frappe.DoesNotExistError)
	values = {key: card[key] for key in SUPPLIER_CARD if key in card}
	if card.get("name"):
		values["name"] = card["name"]
	if values:
		film_sources.set_card(supplier, **values)
	return stock()


# --------------------------------------------------------------------------
# Receipts
# --------------------------------------------------------------------------


def _decimal(value, what: str) -> Decimal:
	try:
		number = Decimal(str(value).replace(",", ".").replace(" ", ""))
	except (InvalidOperation, ValueError):
		frappe.throw(f"{what} — число.")
	if not number.is_finite() or number <= 0 or number > material_stock.MAX_QTY:
		frappe.throw(f"{what} — больше нуля.")
	return number


def to_kg(item: str, qty, unit: str, company: str | None = None) -> float:
	"""Kilograms of so many kilograms, litres or buckets of this glue."""
	glue = card(item, company)
	number = _decimal(qty, "Количество")
	if unit in ("кг", None, ""):
		return float(number)
	if unit == "л":
		return round(float(number) * flt(glue["kg_per_litre"]), 3)
	if unit == "ведро":
		if not glue["bucket_kg"]:
			frappe.throw("Сколько кг в ведре этого клея? Укажите в карточке клея.")
		return round(float(number) * flt(glue["bucket_kg"]), 3)
	frappe.throw("Единица — кг, литры или вёдра.")


def receive(item: str, qty, unit: str, price, price_per: str, supplier: str, received_on: str | None = None,
			note: str | None = None, delivery=None, received_by: str | None = None, supplier_pay=None) -> dict:
	"""So many kilograms, litres or buckets of a glue at so much a kilo, a
	litre or a bucket, from a glue supplier — and how it came and was paid,
	as a film receipt says it."""
	material_stock._ensure_editor()
	if not sells_glue(supplier):
		frappe.throw("Это не поставщик клея — выберите из своих или добавьте нового.")
	company = current_company()
	_glue_item(item, company)
	kg = to_kg(item, qty, unit, company)
	per_unit = float(_decimal(price, "Цена"))
	price_kg = round(per_unit / to_kg(item, 1, price_per, company), 2)
	logistics, fields = film_dept.receipt_terms(supplier, delivery, received_by, supplier_pay)
	if fields.get("korkem_supplier_paid_from") == film_cash.FROM_DEPT:
		fields["korkem_supplier_paid_from"] = film_cash.FROM_ELSEWHERE
	result = material_stock.receive(item, kg, price_kg, supplier, received_on=received_on, note=note,
									delivery=logistics)
	frappe.db.set_value("Stock Entry", result["receipt"], {**fields, "korkem_receipt_dept": DEPT},
						update_modified=False)
	audit.record_audit(action="glue.received", entity_type="Stock Entry", entity_id=result["receipt"],
					   diff={"item": item, "kg": kg, "price_kg": price_kg, "supplier": supplier})
	return {"receipt": result["receipt"], **stock()}


def _landed(items: list[str], company: str) -> dict[str, float]:
	"""What a kilo of each glue cost with its bringing, over recent receipts."""
	if not items:
		return {}
	out: dict[str, list[float]] = defaultdict(lambda: [0.0, 0.0])
	for d in frappe.db.sql(
		"""select sed.item_code, sed.qty, sed.basic_rate, se.korkem_delivery_cost
		from `tabStock Entry Detail` sed join `tabStock Entry` se on se.name = sed.parent
		where se.company = %(company)s and se.docstatus = 1 and se.korkem_material_receipt = 1
			and se.korkem_receipt_dept = %(dept)s and sed.item_code in %(items)s and se.posting_date >= %(since)s""",
		{"company": company, "dept": DEPT, "items": tuple(items), "since": add_days(nowdate(), -LANDED_DAYS)},
		as_dict=True,
	):
		out[d.item_code][0] += flt(d.qty) * flt(d.basic_rate) + flt(d.korkem_delivery_cost)
		out[d.item_code][1] += flt(d.qty)
	return {item: round(v[0] / v[1], 2) for item, v in out.items() if v[1]}


def prices(item: str, cost_kg: float | None, company: str | None = None) -> dict:
	"""What a bucket and a litre sell for: cost with bringing, plus the mark-up."""
	glue = card(item, company)
	if not cost_kg:
		return {"bucket": None, "litre": None}
	bucket = (round(cost_kg * flt(glue["bucket_kg"]) * (1 + flt(glue["markup_bucket"]) / 100))
			  if glue["bucket_kg"] else None)
	litre = round(cost_kg * flt(glue["kg_per_litre"]) * (1 + flt(glue["markup_litre"]) / 100))
	return {"bucket": bucket, "litre": litre}


# --------------------------------------------------------------------------
# The store
# --------------------------------------------------------------------------


def _money(value, allowed: bool):
	"""A price, None where there is none yet or it may not be seen."""
	return None if value is None else price_visibility.money(value, allowed=allowed)


def stock() -> dict:
	"""Every glue with its card, what is here and what it costs a kilo and a
	m² of facade; who sells it and for how much; what the vacuum queue needs;
	what is owed; and what a m² really took this month."""
	material_stock._ensure_staff()
	company = current_company()
	allowed = price_visibility.can_see_prices()
	settings = _settings(company)
	items = frappe.get_all(
		"Item",
		filters={"korkem_material_company": company, "korkem_material_kind": material_stock.GLUE, "disabled": 0},
		fields=["name", "item_name"], order_by="item_name asc", limit_page_length=0,
	)
	ids = [i.name for i in items]
	on_hand = material_stock._stock(ids, company)
	landed = _landed(ids, company)
	work = in_work(company)
	month = usage(company)
	facts = month["glues"]
	glues = []
	for i in items:
		kg, avg = on_hand.get(i.name, (0.0, 0.0))
		glue = card(i.name, company)
		cost = landed.get(i.name) or (round(avg, 2) if avg else None)
		glues.append({
			"item": i.name, "title": i.item_name, **glue, "in_work": i.name == work, "on_hand_kg": round(kg, 3),
			"cost_kg": _money(cost, allowed),
			"cost_m2": _money(round(cost * flt(glue["norm_g_m2"]) / 1000, 2) if cost else None, allowed),
			"sell": {k: _money(v, allowed) for k, v in prices(i.name, cost, company).items()},
			"fact": facts.get(i.name),
		})
	need = queue_need(company)
	have = next((g["on_hand_kg"] for g in glues if g["in_work"]), 0.0)
	return {
		"glues": glues,
		"in_work": work,
		"queue": {**need, "on_hand_kg": have, "short_kg": round(max(need["kg"] - have, 0), 2)},
		"milling": [{"name": m, "factor": flt(settings["milling"].get(m) or 1.0)}
					for m in sorted(material_stock.enabled_values(MILLING_LIST, company))],
		"edge_coats": EDGE_COATS,
		"suppliers": _suppliers(company, allowed),
		"owed": _owed(company, allowed),
		"delivery_owed": _delivery_owed(company, allowed),
		"usage": month,
		"prices_visible": allowed,
		"can_edit": material_stock.can_edit(),
	}


def _owed(company: str, allowed: bool) -> list[dict]:
	"""Glue taken on credit or by invoice and not paid yet, oldest first."""
	out = []
	for e in frappe.get_all(
		"Stock Entry",
		filters={"company": company, "korkem_material_receipt": 1, "docstatus": 1, "korkem_receipt_dept": DEPT,
				 "korkem_supplier_owed": 1, "korkem_supplier_paid_on": ["is", "not set"]},
		fields=["name", "posting_date", "korkem_supplier", "korkem_supplier_invoice_no", "korkem_supplier_due_on"],
		order_by="posting_date asc", limit_page_length=0,
	):
		line = frappe.db.get_value("Stock Entry Detail", {"parent": e.name}, ["item_name", "qty", "basic_rate"],
								   as_dict=True)
		if not line:
			continue
		out.append({
			"receipt": e.name, "date": str(e.posting_date), "glue": line.item_name, "kg": flt(line.qty),
			"amount": price_visibility.money(round(flt(line.qty) * flt(line.basic_rate), 2), allowed=allowed),
			"supplier": frappe.db.get_value("Supplier", e.korkem_supplier, "supplier_name") or e.korkem_supplier,
			"invoice_no": e.korkem_supplier_invoice_no,
			"due_on": str(e.korkem_supplier_due_on) if e.korkem_supplier_due_on else None,
			"overdue": bool(e.korkem_supplier_due_on and getdate(e.korkem_supplier_due_on) < getdate()),
		})
	return out


def _delivery_owed(company: str, allowed: bool) -> list[dict]:
	"""Bringing glue an employee paid out of pocket, or nobody yet."""
	out = []
	for d in frappe.get_all(
		"Stock Entry",
		filters={"company": company, "korkem_material_receipt": 1, "docstatus": 1, "korkem_receipt_dept": DEPT,
				 "korkem_delivery_payer": ["in", [film_dept.PAYER_EMPLOYEE, film_dept.PAYER_UNPAID]],
				 "korkem_delivery_settled_on": ["is", "not set"], "korkem_delivery_cost": [">", 0]},
		fields=["name", "posting_date", "korkem_supplier", "korkem_delivery_payer", "korkem_delivery_paid_by",
				"korkem_delivery_cost", "korkem_delivery_transport"],
		order_by="posting_date asc", limit_page_length=0,
	):
		employee = d.korkem_delivery_payer == film_dept.PAYER_EMPLOYEE
		out.append({
			"receipt": d.name, "date": str(d.posting_date),
			"amount": price_visibility.money(d.korkem_delivery_cost, allowed=allowed),
			"employee": get_fullname(d.korkem_delivery_paid_by) if employee and d.korkem_delivery_paid_by else None,
			"transport": d.korkem_delivery_transport,
			"supplier": frappe.db.get_value("Supplier", d.korkem_supplier, "supplier_name") or d.korkem_supplier,
		})
	return out


def pay_supplier(receipt: str, method: str | None = None, bank: str | None = None) -> dict:
	"""Glue bought on credit is paid for today — not out of the film cash."""
	if frappe.db.get_value("Stock Entry", receipt, "korkem_receipt_dept") != DEPT:
		frappe.throw("Такого долга за клей нет.", frappe.DoesNotExistError)
	film_cash.pay_supplier(receipt, method, film_cash.FROM_ELSEWHERE, bank)
	return stock()


def settle_delivery(receipt: str, method: str | None = None, bank: str | None = None) -> dict:
	if frappe.db.get_value("Stock Entry", receipt, "korkem_receipt_dept") != DEPT:
		frappe.throw("Такого долга за доставку клея нет.", frappe.DoesNotExistError)
	film_cash.settle(receipt, method, bank)
	return stock()


# --------------------------------------------------------------------------
# Taken off by itself, put right by a count
# --------------------------------------------------------------------------


def _entry(company: str, purpose: str, item: str, kg: float, use: str, order: str | None = None,
		   m2: float | None = None, rate: float | None = None) -> str:
	warehouse = material_stock._receiving_warehouse(company, None)
	line = {"item_code": item, "qty": kg, "uom": UNIT, "stock_uom": UNIT, "conversion_factor": 1}
	if purpose == "Material Issue":
		line["s_warehouse"] = warehouse
	else:
		line.update({"t_warehouse": warehouse, "basic_rate": rate or 0, "allow_zero_valuation_rate": 0 if rate else 1})
	entry = frappe.get_doc({
		"doctype": "Stock Entry", "stock_entry_type": purpose, "purpose": purpose, "company": company,
		"korkem_receipt_dept": DEPT, "korkem_glue_use": use, "korkem_glue_order": order,
		"korkem_glue_m2": m2 or 0, "remarks": f"Клей: {order}" if order else "Клей: пересчёт",
		"items": [line],
	})
	entry.insert(ignore_permissions=True)
	entry.submit()
	return entry.name


def use_for_order(order: str) -> dict:
	"""«Вакуум» ticked: the order's glue off the store — from the glue in
	work, never more than is there; what was short is said, a count puts it
	right. Once per order."""
	company = frappe.db.get_value("Sales Order", order, "company")
	if not company or frappe.db.exists("Stock Entry", {"korkem_glue_order": order, "korkem_glue_use": USE_ORDER,
														"docstatus": 1}):
		return {"taken": 0, "short": 0}
	glue = order_glue(order, company)
	if not glue["kg"] or not glue["item"]:
		return {"taken": 0, "short": glue["kg"]}
	have = material_stock._stock([glue["item"]], company).get(glue["item"], (0.0, 0.0))[0]
	take = round(min(glue["kg"], max(have, 0)), 2)
	if take > 0:
		_entry(company, "Material Issue", glue["item"], take, USE_ORDER, order, round(glue["m2"] * take / glue["kg"], 3))
	short = round(glue["kg"] - take, 2)
	audit.record_audit(action="glue.used", entity_type="Sales Order", entity_id=order,
					   diff={"item": glue["item"], "taken": take, "short": short, "norm": glue["norm_g_m2"]})
	return {"taken": take, "short": short}


def return_for_order(order: str) -> None:
	"""«Вакуум» taken back: the glue goes back on the shelf."""
	for name in frappe.get_all("Stock Entry", filters={"korkem_glue_order": order, "korkem_glue_use": USE_ORDER,
													   "docstatus": 1}, pluck="name"):
		entry = frappe.get_doc("Stock Entry", name)
		entry.flags.ignore_permissions = True
		entry.cancel()
	audit.record_audit(action="glue.returned", entity_type="Sales Order", entity_id=order, diff={})


def count(item: str, kg) -> dict:
	"""The storekeeper weighed what is left: the store is put right to it, and
	the difference counts towards what a m² really takes."""
	material_stock._ensure_editor()
	company = current_company()
	_glue_item(item, company)
	try:
		actual = Decimal(str(kg).replace(",", "."))
	except (InvalidOperation, ValueError):
		frappe.throw("Остаток — число, в кг.")
	if not actual.is_finite() or actual < 0 or actual > material_stock.MAX_QTY:
		frappe.throw("Остаток — от нуля, в кг.")
	have, average = material_stock._stock([item], company).get(item, (0.0, 0.0))
	diff = round(float(actual) - have, 2)
	if diff < 0:
		_entry(company, "Material Issue", item, -diff, USE_COUNT)
	elif diff > 0:
		_entry(company, "Material Receipt", item, diff, USE_COUNT, rate=average or None)
	audit.record_audit(action="glue.counted", entity_type="Item", entity_id=item,
					   diff={"was": have, "now": float(actual)})
	return stock()


def usage(company: str | None = None, days: int = USAGE_DAYS) -> dict:
	"""The last month, glue by glue: m² through the vacuum, kilograms by the
	norm, what counts found missing (or over) — so what a m² really took."""
	company = company or current_company()
	by: dict[str, dict] = defaultdict(lambda: {"m2": 0.0, "kg_by_norm": 0.0, "kg_counted": 0.0})
	for e in frappe.db.sql(
		"""select sed.item_code, se.korkem_glue_use, se.korkem_glue_m2, se.purpose, sum(sed.qty) as qty
		from `tabStock Entry` se join `tabStock Entry Detail` sed on sed.parent = se.name
		where se.company = %(company)s and se.docstatus = 1 and se.korkem_receipt_dept = %(dept)s
			and se.korkem_glue_use in %(uses)s and se.posting_date >= %(since)s
		group by se.name, sed.item_code""",
		{"company": company, "dept": DEPT, "uses": (USE_ORDER, USE_COUNT), "since": add_days(nowdate(), -days)},
		as_dict=True,
	):
		row = by[e.item_code]
		if e.korkem_glue_use == USE_ORDER:
			row["m2"] += flt(e.korkem_glue_m2)
			row["kg_by_norm"] += flt(e.qty)
		else:
			row["kg_counted"] += flt(e.qty) if e.purpose == "Material Issue" else -flt(e.qty)
	glues = {}
	for item, row in by.items():
		fact = round((row["kg_by_norm"] + row["kg_counted"]) * 1000 / row["m2"]) if row["m2"] else None
		glues[item] = {"m2": round(row["m2"], 2), "kg_by_norm": round(row["kg_by_norm"], 2),
					   "kg_counted": round(row["kg_counted"], 2), "fact_g_m2": fact}
	return {"days": days, "glues": glues}
