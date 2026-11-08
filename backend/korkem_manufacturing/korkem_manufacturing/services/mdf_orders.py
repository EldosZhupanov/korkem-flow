# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The MDF order card: what the manager does in OnayBaza, on ERPNext's order.

The owner's decisions (NOW.md, 31.10 and 01.11.2026):

- **One window per order** — a head (client, due date, thickness, finish,
  decor face and back, patina, milling, edge, an extra name, a default price
  per m²) and lines (height × width × pieces, the line's own milling, note and
  price).
- **The owner's arithmetic**, checked on his order forms №36 and №1129: a
  line's area is height × width × pieces / 1 000 000 **rounded to 0.01 m²**,
  its amount that area × the price **to whole tenge**; no minimum area.
- **The price comes from «Цены фасадов»** by the line's milling and the
  order's finish, unless the manager typed one on the line. A pair nobody
  priced **does not stop the order**: the line counts at 0 ₸ and says so.
- **Draft → accepted → in the shop → ready → handed over**, plus on hold (with
  a reason) and cancelled. A draft is ERPNext's unsubmitted order and changes
  freely; «Принять» submits it, which fixes the prices. **The manager ticks the
  stages** (Кесу, Фреза, Жону, Вакуум, Бояу), each with its date, as in
  OnayBaza; which of them an order has follows its finish.

Nothing is invented here that ERPNext already keeps: the customer, the due
date, the lines, the payments (`payments.record_payment`, `advance_paid`) and
cancelling are ERPNext's own. This module is the order of operations and the
owner's arithmetic on top.
"""

from __future__ import annotations

from decimal import ROUND_HALF_UP, Decimal, InvalidOperation

import frappe
from frappe.utils import add_days, flt, getdate, nowdate

from korkem_manufacturing.services import (
	audit,
	directions,
	facade_materials,
	facade_order,
	facade_prices,
	facade_spec,
	material_stock,
	mdf_tags,
)
from korkem_manufacturing.services.scope import current_company, enforce_tenant_scope

AREA = Decimal("0.01")
TENGE = Decimal("1")
MIN_MM, MAX_MM = 10, 3000
MAX_LINES = 300

#: Stage → field, in the order the shop works (owner, 09.11.2026): раскрой,
#: фреза, шлифовка, краска, вакуум, готово.
STAGES = {
	"cut": "korkem_stage_cut",
	"mill": "korkem_stage_mill",
	"sand": "korkem_stage_sand",
	"paint": "korkem_stage_paint",
	"vacuum": "korkem_stage_vacuum",
	"ready": "korkem_stage_ready",
}
#: The stages a rework may add to an order whose finish does not have them.
EXTRA_STAGES = ("paint", "vacuum")
#: What a film group is coated with (owner, 09.11.2026): a type, then a colour
#: from that type's own list, so a paint never lands in a film group. The
#: type decides the shop's stage: a film is pressed, a paint is painted, a
#: raw («черновой») facade neither. Fixed here because the stages are.
COATINGS = ("pvc", "paint", "raw")
COATING_LIST = {"pvc": facade_spec.DECOR, "paint": "Краска", "raw": None}
COATING_STAGE = {"pvc": "vacuum", "paint": "paint", "raw": None}
#: Who did the stage: an Employee, written with the tick (OnayBaza «Жұмыс көлемі»).
STAGE_BY = {stage: f"{field}_by" for stage, field in STAGES.items()}
HEAD = {
	"thickness_mm": "korkem_thickness_mm",
	"finish": "korkem_finish",
	"decor_top": "korkem_decor_top",
	"decor_bottom": "korkem_decor_bottom",
	"patina": "korkem_patina",
	"milling": "korkem_milling",
	"edge_profile": "korkem_edge_profile",
	"extra_name": "korkem_extra_name",
	"default_rate": "korkem_default_rate",
	"material": "korkem_material",
	"film_rates": "korkem_film_rates",
	"tags": "korkem_tags",
	"coatings": "korkem_coatings",
}
#: Every new position's edge radius unless the manager picks another (owner,
#: 08.11.2026); «R0» is a sharp corner.
DEFAULT_EDGE = "R3"
#: The radii every position may have without anyone adding them to the list.
STANDARD_EDGES = ("R0", DEFAULT_EDGE)
#: A warning this many days before the due date, if the order is not ready.
DUE_SOON_DAYS = 2


def stages_for(finish: str | None, extra: str | list | None = None, coatings: str | list | None = None) -> list[str]:
	"""The stages an order with this finish goes through, «готово» last.

	Film is pressed and never painted; enamel is painted and never pressed;
	a raw («черновая») facade is cut, milled and sanded. A finish the rule does
	not recognise gets every stage — a tick too many is harmless, a missing
	one hides work. `extra` adds what a rework needs (a film facade repainted,
	a painted one pressed), in the shop's order.
	"""
	name = (finish or "").lower()
	kinds = [c for c in (coatings if isinstance(coatings, (list, tuple)) else (coatings or "").split(","))
			 if c in COATINGS]
	if kinds:
		# Its groups' coatings decide: a film group is pressed, a paint group
		# painted; an order of both goes through both.
		base = {"cut", "mill", "sand"} | {COATING_STAGE[c] for c in kinds if COATING_STAGE[c]}
	elif facade_prices.is_film(finish):
		base = {"cut", "mill", "sand", "vacuum"}
	elif "эмал" in name or "краск" in name or "бояу" in name:
		base = {"cut", "mill", "sand", "paint"}
	elif "чернов" in name:
		base = {"cut", "mill", "sand"}
	else:
		base = set(STAGES)
	base |= set(_extra(extra)) | {"ready"}
	return [s for s in STAGES if s in base]


def _extra(raw) -> list[str]:
	items = raw if isinstance(raw, (list, tuple)) else (raw or "").split(",")
	return [s for s in EXTRA_STAGES if s in {str(i).strip() for i in items}]


def stages_of(row) -> list[str]:
	"""An order's stages: its finish's, with what was added to it."""
	return stages_for(row.get("korkem_finish"), row.get("korkem_extra_stages"), row.get("korkem_coatings"))


def coating_of(finish: str | None) -> str | None:
	"""The coating type a finish's name says — for an order written before groups had one."""
	name = (finish or "").lower()
	if facade_prices.is_film(finish):
		return "pvc"
	if "эмал" in name or "краск" in name or "бояу" in name:
		return "paint"
	if "чернов" in name:
		return "raw"
	return None


def _finish_for(coating: str | None, company: str) -> str | None:
	"""The finish a coating type is priced under: the «Покрытие» list's own word for it."""
	if not coating:
		return None
	for name in facade_prices.finishes(company):
		if coating_of(name) == coating:
			return name
	return {"pvc": facade_prices.PVC, "paint": facade_prices.ENAMEL, "raw": facade_prices.ROUGH}[coating]


# --- the arithmetic --------------------------------------------------------


def price(lines, *, finish: str | None, default_rate=None, company: str | None = None, film_rates=None) -> dict:
	"""Price lines the owner's way. Pure arithmetic and price lookups; saves nothing.

	Each line: `height_mm`, `width_mm`, `qty`, and optionally `milling`,
	`note`, `rate` (a price typed by hand), `film`, `film_back`, `material`.
	Returns the lines with `area_m2`, `rate_m2`, `amount`, `manual_rate`,
	`no_price`, and the totals.

	The price of a line, first found: typed on the line; its film's price in
	`film_rates` (an order of several films, 08.11.2026); the price list for
	its milling and the finish; the order's default.
	"""
	if isinstance(lines, str):
		lines = frappe.parse_json(lines)
	if not isinstance(lines, list):
		frappe.throw("Позиции заказа — это список.")
	if len(lines) > MAX_LINES:
		frappe.throw(f"Не больше {MAX_LINES} позиций в одном заказе.")
	company = company or current_company()
	fallback = _money(default_rate, "Цена за м² по умолчанию") if default_rate not in (None, "") else None
	if isinstance(film_rates, str):
		film_rates = frappe.parse_json(film_rates) if film_rates.strip() else {}
	by_film = {k: _money(v, f"Цена за м² плёнки «{k}»") for k, v in (film_rates or {}).items() if v not in (None, "")}

	priced, pieces, area_total, total = [], 0, Decimal("0"), Decimal("0")
	for index, raw in enumerate(lines, start=1):
		if not isinstance(raw, dict):
			frappe.throw(f"Позиция {index}: непонятный формат.")
		label = f"Позиция {index}"
		height = _number(raw.get("height_mm"), f"{label}, высота")
		width = _number(raw.get("width_mm"), f"{label}, ширина")
		for size, name in ((height, "высота"), (width, "ширина")):
			if not MIN_MM <= size <= MAX_MM:
				frappe.throw(f"{label}: {name} {size:f} мм — вне {MIN_MM}–{MAX_MM} мм.")
		qty = _number(raw.get("qty", 1), f"{label}, количество")
		if qty != qty.to_integral_value() or qty < 1:
			frappe.throw(f"{label}: количество — целое число от 1.")

		milling = (raw.get("milling") or "").strip()
		coating = raw.get("coating") or coating_of(finish)
		if coating is not None and coating not in COATINGS:
			frappe.throw(f"{label}: покрытие — одно из: ПВХ, краска, черновой.")
		line_finish = _finish_for(coating, company) if raw.get("coating") else finish
		film, film_back, material = _line_spec(raw, label, company, coating)
		edge, patina = _line_finish(raw, label, company)
		thickness = _line_thickness(raw, label, material)
		manual = raw.get("rate") not in (None, "")
		if manual:
			rate = _money(raw.get("rate"), f"{label}, цена")
		elif film and film in by_film:
			rate = by_film[film]
		else:
			found = facade_prices.price_for(milling, line_finish or "", company) if milling and line_finish else None
			rate = found if found is not None else fallback
		no_price = rate is None
		rate = rate or Decimal("0")

		area = (height * width * qty / Decimal(1_000_000)).quantize(AREA, rounding=ROUND_HALF_UP)
		amount = (area * rate).quantize(TENGE, rounding=ROUND_HALF_UP)

		pieces += int(qty)
		area_total += area
		total += amount
		priced.append(
			{
				"line": index,
				"height_mm": int(height),
				"width_mm": int(width),
				"qty": int(qty),
				"milling": milling or None,
				"note": (raw.get("note") or "").strip()[:140] or None,
				"area_m2": float(area),
				"rate_m2": float(rate),
				"amount": float(amount),
				"manual_rate": manual,
				"no_price": no_price,
				"film": film,
				"film_back": film_back,
				"material": material,
				"thickness_mm": thickness,
				"edge": edge,
				"patina": patina,
				"coating": coating,
				"finish": line_finish,
			}
		)
	return {
		"lines": priced,
		"pieces": pieces,
		"area_m2": float(area_total),
		"total": float(total),
		"no_price_lines": [line["line"] for line in priced if line["no_price"]],
	}


def thickness_of(material: str | None) -> int | None:
	"""«16 мм ЛМДФ» → 16: the thickness a material's name starts with."""
	digits = ""
	for ch in (material or "").strip():
		if ch.isdigit():
			digits += ch
		elif digits:
			break
	return int(digits) if digits else None


def _line_spec(raw: dict, label: str, company: str,
			   coating: str | None = "pvc") -> tuple[str | None, str | None, str | None]:
	"""A position's own colour, back colour and material — each from its list.

	An order of several films (08.11.2026) carries the film on the position;
	the back film only when the manager switched the back side on for it. A
	paint group's colours come from the paint list, a film group's from the
	film list (09.11.2026); a raw group has none.
	"""
	from korkem_manufacturing.services import mdf_dictionaries

	film = facade_spec._text(raw.get("film"))
	film_back = facade_spec._text(raw.get("film_back"))
	material = facade_spec._text(raw.get("material"))
	kind = COATING_LIST.get(coating or "pvc")
	if kind is None and (film or film_back):
		frappe.throw(f"{label}: у чернового фасада нет цвета.")
	known = facade_spec._values(kind, company) if kind and (film or film_back) else set()
	for value, name in ((film, "цвет"), (film_back, "цвет обратной стороны")):
		if value and value not in known:
			frappe.throw(f"{label}: {name} «{value}» нет в справочнике «{kind}».")
	if material and material not in facade_spec._values(mdf_dictionaries.MATERIAL, company):
		frappe.throw(f"{label}: материала «{material}» нет в справочнике «{mdf_dictionaries.MATERIAL}».")
	return film, film_back, material


def _line_thickness(raw: dict, label: str, material: str | None) -> int | None:
	"""A position's own thickness, mm (09.11.2026: thickness and material apart).

	Typed as a number, or «16 мм» from the thickness list; a position without
	one takes the thickness its material's name starts with — an order written
	when the material list said «16 мм МДФ».
	"""
	raw_value = raw.get("thickness_mm")
	if raw_value in (None, ""):
		return thickness_of(material)
	value = raw_value if isinstance(raw_value, int) else thickness_of(str(raw_value))
	if value is None or not facade_spec.MIN_THICKNESS <= value <= facade_spec.MAX_THICKNESS:
		frappe.throw(f"{label}: толщина «{raw_value}» — {facade_spec.MIN_THICKNESS}–{facade_spec.MAX_THICKNESS} мм.")
	return value


def _line_finish(raw: dict, label: str, company: str) -> tuple[str | None, str | None]:
	"""A position's edge radius and patina, each from its list when the list has values.

	R0 and R3 need no list: R3 is every position's radius unless the manager
	says otherwise, R0 a sharp corner (owner, 08.11.2026).
	"""
	edge = facade_spec._text(raw.get("edge"))
	patina = facade_spec._text(raw.get("patina"))
	for value, kind, name in ((edge, facade_spec.EDGE, "радиус края"), (patina, "Патина", "патина")):
		if value and value not in STANDARD_EDGES:
			known = facade_spec._values(kind, company)
			if known and value not in known:
				frappe.throw(f"{label}: {name} «{value}» нет в справочнике «{kind}».")
	return edge, patina


def _coatings_into(values: dict, lines: list[dict]) -> None:
	"""The order's coatings, from its groups; its finish, if the head names none, the first group's."""
	kinds = [c for c in COATINGS if any(line.get("coating") == c for line in lines)]
	values["coatings"] = ",".join(kinds) or None
	if not values.get("finish"):
		values["finish"] = next((line.get("finish") for line in lines if line.get("finish")), None)


def _put_standard_edges(head, lines, company: str) -> None:
	"""R0 and R3 on the «Профиль кромки» list once an order uses them.

	The item's facade fields take an edge from that list only; the two
	standard radii should not wait for someone to add them first.
	"""
	head = frappe.parse_json(head) if isinstance(head, str) else (head or {})
	lines = frappe.parse_json(lines) if isinstance(lines, str) else (lines or [])
	used = {facade_spec._text(head.get("edge_profile"))} | {
		facade_spec._text(line.get("edge")) for line in lines if isinstance(line, dict)
	}
	missing = used.intersection(STANDARD_EDGES) - facade_spec._values(facade_spec.EDGE, company)
	for edge in sorted(missing):
		material_stock.put_option(facade_spec.EDGE, edge)


def _film_rates(raw, company: str) -> str | None:
	"""Each film's price per m², stored as JSON on the order: {"Палома": 18000}."""
	import json

	if raw in (None, "", {}):
		return None
	if isinstance(raw, str):
		raw = frappe.parse_json(raw)
	if not isinstance(raw, dict):
		frappe.throw("Цены плёнок — это пары «плёнка: цена».")
	films = facade_spec._values(facade_spec.DECOR, company)
	rates = {}
	for film, rate in raw.items():
		film = facade_spec._text(film)
		if not film:
			continue
		if film not in films:
			frappe.throw(f"Плёнки «{film}» нет в справочнике «{facade_spec.DECOR}».")
		if rate in (None, ""):
			continue
		rates[film] = float(_money(rate, f"Цена за м² плёнки «{film}»"))
	return json.dumps(rates, ensure_ascii=False, sort_keys=True) if rates else None


# --- the card --------------------------------------------------------------


def save_draft(*, customer: str, delivery_date: str, head=None, lines=None, order: str | None = None,
			   notes: str | None = None) -> dict:
	"""Create a draft, or change one that is still a draft. Returns the card."""
	facade_prices.ensure_editor()
	company = current_company()
	head = frappe.parse_json(head) if isinstance(head, str) else (head or {})
	customer = facade_order._customer(customer, company)
	wanted = _due(delivery_date)
	_put_standard_edges(head, lines, company)
	values = _head(head, company)
	quote = price(lines or [], finish=values["finish"], default_rate=values["default_rate"], company=company,
				  film_rates=values["film_rates"])
	_coatings_into(values, quote["lines"])
	if not quote["lines"]:
		frappe.throw("Добавьте хотя бы одну позицию.")
	facade_order._ensure_items()

	if order:
		doc = _order(order)
		if doc.docstatus != 0:
			frappe.throw("Заказ уже принят — меняйте его через «Изменить заказ».")
		doc.set("items", [])
	else:
		doc = frappe.new_doc("Sales Order")
		doc.update(
			{
				"company": company,
				"transaction_date": nowdate(),
				"order_type": "Sales",
				"korkem_direction": directions.FACADES,
				"ignore_pricing_rule": 1,
				"disable_rounded_total": 1,
			}
		)
	doc.customer = customer
	doc.delivery_date = str(wanted)
	doc.terms = (notes or "").strip()[:2000] or None
	for key, field in HEAD.items():
		doc.set(field, values[key])
	for line in quote["lines"]:
		doc.append("items", _item(line, values, wanted))
	doc.save()
	_check_total(doc, quote["total"])
	audit.record_audit(
		action="mdf.order_draft_saved",
		entity_type="Sales Order",
		entity_id=doc.name,
		diff={"customer": customer, "pieces": quote["pieces"], "area_m2": quote["area_m2"], "total": quote["total"]},
	)
	return card(doc.name)


def accept(order: str) -> dict:
	"""«Принять»: the prices are fixed, the material is held."""
	facade_prices.ensure_editor()
	doc = _order(order)
	if doc.docstatus != 0:
		frappe.throw("Заказ уже принят.")
	doc.submit()
	facade_materials.reserve(doc.name)
	audit.record_audit(action="mdf.order_accepted", entity_type="Sales Order", entity_id=doc.name,
					   diff={"total": flt(doc.grand_total)})
	return card(doc.name)


def change_order(order: str, *, lines, reason: str, head=None, delivery_date: str | None = None) -> dict:
	"""«Изменить заказ» after «Принять»: new lines (and head, due date), the reason
	written into the order's history, the payments untouched.

	ERPNext's own update of a submitted order's lines does the change, so
	what was paid stays paid; the owner's arithmetic prices the new lines
	exactly as on a draft. The material held for the order is held again for
	what it now needs.
	"""
	import json

	from erpnext.controllers.accounts_controller import update_child_qty_rate

	facade_prices.ensure_editor()
	reason = _reason(reason, "Укажите, что и почему меняется в заказе.")
	doc = _accepted(order)
	if doc.korkem_handed_over_on:
		frappe.throw("Заказ уже выдан — его не меняют.")
	head = frappe.parse_json(head) if isinstance(head, str) else head
	_put_standard_edges(head, lines, doc.company)
	values = _head(head, doc.company) if head else {key: doc.get(field) for key, field in HEAD.items()}
	wanted = _due(delivery_date) if delivery_date else getdate(doc.delivery_date)
	quote = price(lines or [], finish=values["finish"], default_rate=values["default_rate"], company=doc.company,
				  film_rates=values["film_rates"])
	_coatings_into(values, quote["lines"])
	if not quote["lines"]:
		frappe.throw("В заказе должна остаться хотя бы одна позиция.")
	before = {"total": flt(doc.grand_total), "lines": [
		f"{i.korkem_height_mm}×{i.korkem_width_mm}×{int(i.qty)}" for i in doc.items
		if i.item_code == facade_order.FACADE_ITEM]}

	existing = [i for i in doc.items if i.item_code == facade_order.FACADE_ITEM]
	keep = [i for i in doc.items if i.item_code != facade_order.FACADE_ITEM]
	rows = [_item(line, values, wanted) for line in quote["lines"]]
	trans = [{"docname": i.name, "item_code": i.item_code, "qty": i.qty, "rate": i.rate, "uom": i.uom,
			  "conversion_factor": i.conversion_factor, "delivery_date": str(i.delivery_date)} for i in keep]
	for index, row in enumerate(rows):
		entry = {"item_code": row["item_code"], "qty": row["qty"], "rate": row["rate"], "uom": "Nos",
				 "conversion_factor": 1, "delivery_date": str(wanted)}
		if index < len(existing):
			entry["docname"] = existing[index].name
		trans.append(entry)
	update_child_qty_rate("Sales Order", json.dumps(trans), doc.name)

	doc.reload()
	facade_rows = sorted((i for i in doc.items if i.item_code == facade_order.FACADE_ITEM), key=lambda i: i.idx)
	custom = [{k: v for k, v in row.items() if k.startswith("korkem_") or k in ("item_name", "description")}
			  for row in rows]
	for item, fields in zip(facade_rows, custom, strict=False):
		frappe.db.set_value("Sales Order Item", item.name, fields, update_modified=False)
	for key, field in HEAD.items():
		if doc.get(field) != values[key]:
			doc.db_set(field, values[key], update_modified=False)
	if str(getdate(doc.delivery_date)) != str(wanted):
		doc.db_set("delivery_date", str(wanted), update_modified=False)
	doc.reload()
	_check_total(doc, quote["total"])

	on_hold = frappe.db.exists("Stock Reservation", {"sales_order": doc.name, "status": "Active"})
	if on_hold:
		from korkem_manufacturing.services import stock_reservation

		stock_reservation.release_reservations_for_order(doc.name, reason="Заказ изменён")
	facade_materials.reserve(doc.name)

	after = {"total": flt(doc.grand_total), "lines": [f"{line['height_mm']}×{line['width_mm']}×{line['qty']}"
													  for line in quote["lines"]]}
	doc.add_comment("Comment", f"Изменён: {reason}. Было {before['total']:,.0f} ₸, стало {after['total']:,.0f} ₸."
					.replace(",", " "))
	audit.record_audit(action="mdf.order_changed", entity_type="Sales Order", entity_id=doc.name,
					   diff={"reason": reason, "before": before, "after": after})
	return card(doc.name)


def history(order: str) -> list[dict]:
	"""What happened to the order, newest first: comments and the audit trail."""
	facade_prices.ensure_editor()
	doc = _order(order)
	rows = frappe.get_all(
		"Comment",
		filters={"reference_doctype": "Sales Order", "reference_name": doc.name, "comment_type": "Comment"},
		fields=["creation", "owner", "content"],
		order_by="creation desc",
		limit_page_length=100,
	)
	return [{"at": str(r.creation)[:16], "by": r.owner, "text": frappe.utils.strip_html(r.content or "")}
			for r in rows]


def delete_draft(order: str) -> dict:
	"""Only a draft is deleted; an accepted order is cancelled, with a reason."""
	facade_prices.ensure_editor()
	doc = _order(order)
	if doc.docstatus != 0:
		frappe.throw("Принятый заказ не удаляется — отмените его с причиной.")
	# force: a draft has no ledger entries, and a stale log written under the
	# same name (naming series reuse a deleted name) must not keep it alive.
	frappe.delete_doc("Sales Order", doc.name, force=True)
	audit.record_audit(action="mdf.order_draft_deleted", entity_type="Sales Order", entity_id=doc.name, diff={})
	return {"deleted": doc.name}


def cancel(order: str, reason: str) -> dict:
	facade_prices.ensure_editor()
	reason = _reason(reason, "Укажите, почему заказ отменён.")
	doc = _order(order)
	if doc.docstatus != 1:
		frappe.throw("Отменить можно только принятый заказ; черновик просто удалите.")
	if flt(doc.advance_paid) > 0:
		frappe.throw("По заказу есть оплаты — сначала верните их клиенту.")
	doc.add_comment("Comment", f"Отменён: {reason}")
	doc.cancel()
	audit.record_audit(action="mdf.order_cancelled", entity_type="Sales Order", entity_id=doc.name,
					   diff={"reason": reason})
	return card(doc.name)


def set_stage(order: str, stage: str, done=True, worker: str | None = None) -> dict:
	"""Tick or untick one stage. The date is today's; the last tick makes the order ready.

	`worker` — the Employee who did it, for the shop's work volume; optional,
	since the manager ticks and may not know. Unticking forgets them.
	"""
	facade_prices.ensure_editor()
	doc = _accepted(order)
	if stage not in STAGES:
		frappe.throw(f"Этап «{stage}» не знаю.")
	if doc.korkem_handed_over_on:
		frappe.throw("Заказ уже выдан.")
	done = directions.flag(done)
	if worker:
		if frappe.db.get_value("Employee", worker, "company") != doc.company:
			frappe.throw("Такого сотрудника в компании нет.")
	needed = stages_of(doc)
	if stage not in needed:
		frappe.throw("У этого заказа такого этапа нет — добавьте его кнопкой «+ этап».")
	if stage == "ready" and done:
		missing = [s for s in needed if s != "ready" and not doc.get(STAGES[s])]
		if missing:
			frappe.throw("«Готово» — после всех этапов. Не отмечено: " + ", ".join(STAGE_NAMES[s] for s in missing) + ".")
	doc.db_set({STAGES[stage]: nowdate() if done else None, STAGE_BY[stage]: (worker or None) if done else None},
			   update_modified=True)
	doc.reload()
	# Ready is «готово» ticked — checked and packed, not the last machine stage.
	ready = all(doc.get(STAGES[s]) for s in needed)
	doc.db_set("korkem_ready_on", (doc.korkem_ready_on or nowdate()) if ready else None, update_modified=False)
	audit.record_audit(action="mdf.stage", entity_type="Sales Order", entity_id=doc.name,
					   diff={"stage": stage, "done": done, "ready": ready, "worker": worker if done else None})
	return card(doc.name)


STAGE_NAMES = {"cut": "раскрой", "mill": "фреза", "sand": "шлифовка", "paint": "краска", "vacuum": "вакуум",
			   "ready": "готово"}


def extra_stage(order: str, stage: str, on=True) -> dict:
	"""«+ этап»: a rework needs a stage its finish has not — paint, or vacuum.

	Taking one off again is allowed while it is unticked.
	"""
	facade_prices.ensure_editor()
	doc = _accepted(order)
	if stage not in EXTRA_STAGES:
		frappe.throw("Добавить можно краску или вакуум.")
	if doc.korkem_handed_over_on:
		frappe.throw("Заказ уже выдан.")
	on = directions.flag(on)
	extra = set(_extra(doc.get("korkem_extra_stages")))
	if not on and doc.get(STAGES[stage]):
		frappe.throw("Этап уже отмечен — сначала снимите отметку.")
	extra = extra | {stage} if on else extra - {stage}
	doc.db_set("korkem_extra_stages", ",".join(s for s in EXTRA_STAGES if s in extra) or None, update_modified=True)
	# One more stage to go, or one fewer: ready is every stage of the order ticked.
	ready = all(doc.get(STAGES[s]) for s in stages_of(doc))
	doc.db_set("korkem_ready_on", (doc.korkem_ready_on or nowdate()) if ready else None, update_modified=False)
	audit.record_audit(action="mdf.extra_stage", entity_type="Sales Order", entity_id=doc.name,
					   diff={"stage": stage, "on": on})
	return card(doc.name)


def hold(order: str, reason: str | None = None) -> dict:
	"""Put an order on hold (a reason is required), or take it off hold (no reason)."""
	facade_prices.ensure_editor()
	doc = _accepted(order)
	text = (reason or "").strip()
	doc.db_set("korkem_hold_reason", text[:1000] or None, update_modified=True)
	audit.record_audit(action="mdf.hold" if text else "mdf.resume", entity_type="Sales Order",
					   entity_id=doc.name, diff={"reason": text or None})
	return card(doc.name)


def hand_over(order: str, comment: str | None = None) -> dict:
	"""«Выдан». Not with a debt, unless an administrator says why."""
	facade_prices.ensure_editor()
	doc = _accepted(order)
	if not doc.korkem_ready_on:
		frappe.throw("Заказ ещё не готов — не все этапы отмечены.")
	debt = _debt(doc)
	if debt > 0:
		if "System Manager" not in frappe.get_roles():
			frappe.throw(f"Остаток долга {debt:,.0f} ₸ — выдать может администратор с комментарием.".replace(",", " "))
		_reason(comment, "Укажите, почему заказ выдан с долгом.")
		doc.add_comment("Comment", f"Выдан с долгом {debt:,.0f} ₸: {comment.strip()}".replace(",", " "))
	doc.db_set("korkem_handed_over_on", nowdate(), update_modified=True)
	audit.record_audit(action="mdf.handed_over", entity_type="Sales Order", entity_id=doc.name,
					   diff={"debt": float(debt)})
	return card(doc.name)


def card(order: str) -> dict:
	"""Everything the card shows, in one answer."""
	facade_prices.ensure_editor()
	doc = _order(order)
	needed = stages_of(doc)
	lines = [
		{
			"name": item.name,
			"height_mm": item.korkem_height_mm,
			"width_mm": item.korkem_width_mm,
			"qty": int(item.qty),
			"milling": item.korkem_milling,
			"note": item.korkem_line_note,
			"area_m2": flt(item.korkem_area_m2, 2),
			"rate_m2": flt(item.korkem_rate_m2),
			"amount": flt(item.amount),
			"manual_rate": bool(item.korkem_manual_rate),
			"no_price": not flt(item.korkem_rate_m2),
			"film": item.korkem_decor_top,
			"film_back": item.korkem_decor_bottom if item.korkem_double_sided else None,
			"material": item.korkem_material,
			"thickness_mm": item.korkem_thickness_mm,
			"edge": item.korkem_edge_profile,
			"patina": item.get("korkem_line_patina"),
			"coating": item.get("korkem_line_coating") or coating_of(item.korkem_finish or doc.korkem_finish),
		}
		for item in doc.items
		if item.item_code == facade_order.FACADE_ITEM
	]
	payments = frappe.get_all(
		"Payment Entry Reference",
		filters={"reference_doctype": "Sales Order", "reference_name": doc.name, "docstatus": 1},
		fields=["parent", "allocated_amount"],
	)
	paid_rows = []
	for row in payments:
		entry = frappe.db.get_value("Payment Entry", row.parent,
									["posting_date", "mode_of_payment", "korkem_bank", "owner"],
									as_dict=True)
		from korkem_manufacturing.services.mdf_cash import method_and_bank

		method, bank = method_and_bank(entry.mode_of_payment, entry.korkem_bank)
		paid_rows.append({"amount": flt(row.allocated_amount), "date": str(entry.posting_date),
						  "method": method, "bank": bank, "received_by": entry.owner})
	return {
		"name": doc.name,
		"status": status_of(doc),
		"overdue": _overdue(doc),
		"due_soon": _due_soon(doc),
		"customer": doc.customer,
		"customer_name": doc.customer_name,
		"phone": frappe.db.get_value("Customer", doc.customer, "mobile_no"),
		"customer_tags": mdf_tags.parse(frappe.db.get_value("Customer", doc.customer, "korkem_tags")),
		"tags": mdf_tags.parse(doc.get("korkem_tags")),
		"created_on": str(doc.transaction_date),
		"delivery_date": str(doc.delivery_date),
		"head": {**{key: doc.get(field) for key, field in HEAD.items()},
				 "film_rates": frappe.parse_json(doc.korkem_film_rates) if doc.korkem_film_rates else {},
				 "tags": mdf_tags.parse(doc.get("korkem_tags"))},
		"lines": lines,
		"pieces": sum(line["qty"] for line in lines),
		"area_m2": flt(sum(Decimal(str(line["area_m2"])) for line in lines), 2),
		"total": flt(doc.grand_total),
		"paid": flt(doc.advance_paid),
		"debt": float(_debt(doc)),
		"payments": paid_rows,
		"stages": [
			{"stage": s, "done_on": _done_on(doc, s),
			 "extra": s in _extra(doc.get("korkem_extra_stages")),
			 "worker": doc.get(STAGE_BY[s]),
			 "worker_name": frappe.db.get_value("Employee", doc.get(STAGE_BY[s]), "employee_name")
			 if doc.get(STAGE_BY[s]) else None}
			for s in needed
		],
		"ready_on": str(doc.korkem_ready_on) if doc.korkem_ready_on else None,
		"handed_over_on": str(doc.korkem_handed_over_on) if doc.korkem_handed_over_on else None,
		"hold_reason": doc.korkem_hold_reason,
		"notes": doc.terms,
		"history": history(doc.name),
	}


def _done_on(doc, stage: str) -> str | None:
	done = doc.get(STAGES[stage])
	# An order made ready before «готово» was a stage: its ready day stands for it.
	if not done and stage == "ready":
		done = doc.korkem_ready_on
	return str(done) if done else None


def new_customer(name: str, phone: str | None = None) -> dict:
	"""A customer written down on the card itself — name and phone, nothing else.

	The same phone twice is the same customer: the one already on file is
	returned rather than a second card for the same person.
	"""
	facade_prices.ensure_editor()
	name = " ".join((name or "").split())[:140]
	if len(name) < 2:
		frappe.throw("Укажите имя клиента.")
	digits = "".join(ch for ch in (phone or "") if ch.isdigit())
	if phone and not 10 <= len(digits) <= 12:
		frappe.throw("Телефон — 10–12 цифр, например 8 777 123 45 67.")
	if digits:
		for row in frappe.get_all("Customer", filters={"disabled": 0, "mobile_no": ["is", "set"]},
								  fields=["name", "customer_name", "mobile_no"]):
			if "".join(ch for ch in row.mobile_no if ch.isdigit())[-10:] == digits[-10:]:
				return {"name": row.name, "customer_name": row.customer_name, "phone": row.mobile_no,
						"existing": True}
	doc = frappe.get_doc(
		{
			"doctype": "Customer",
			"customer_name": name,
			"customer_type": "Individual",
			"mobile_no": (phone or "").strip() or None,
		}
	)
	doc.insert()
	audit.record_audit(action="mdf.customer_created", entity_type="Customer", entity_id=doc.name,
					   diff={"name": name})
	return {"name": doc.name, "customer_name": doc.customer_name, "phone": doc.mobile_no, "existing": False}


def debts(since: str | None = None, until: str | None = None) -> dict:
	"""Who owes what — OnayBaza's «Қарыз»: by order, and summed by customer.

	An accepted, not cancelled order whose payments fall short of its total.
	`since` / `until` narrow by the order's date; without them, every debt.
	"""
	facade_prices.ensure_editor()
	filters = {"company": current_company(), "korkem_direction": directions.FACADES, "docstatus": 1}
	if since and until:
		filters["transaction_date"] = ["between", [getdate(since), getdate(until)]]
	elif since:
		filters["transaction_date"] = [">=", getdate(since)]
	elif until:
		filters["transaction_date"] = ["<=", getdate(until)]
	rows = frappe.get_all(
		"Sales Order",
		filters=filters,
		fields=["name", "transaction_date", "delivery_date", "customer", "customer_name", "grand_total",
				"advance_paid", "docstatus", "korkem_handed_over_on", "korkem_tags"],
		order_by="transaction_date asc, name asc",
		limit_page_length=2000,
	)
	orders, by_customer = [], {}
	for row in rows:
		debt = _debt(row)
		if debt <= 0:
			continue
		orders.append({"name": row.name, "created_on": str(row.transaction_date), "customer": row.customer,
					   "customer_name": row.customer_name, "total": flt(row.grand_total),
					   "paid": flt(row.advance_paid), "debt": float(debt),
					   "handed_over": bool(row.korkem_handed_over_on)})
		entry = by_customer.setdefault(row.customer, {"customer": row.customer, "customer_name": row.customer_name,
													  "orders": 0, "debt": Decimal(0)})
		entry["orders"] += 1
		entry["debt"] += debt
	customers = sorted(
		({**c, "debt": float(c["debt"])} for c in by_customer.values()), key=lambda c: -c["debt"]
	)
	return {"orders": orders, "customers": customers,
			"total": float(sum((Decimal(str(o["debt"])) for o in orders), Decimal(0)))}


def batch(decor: str | None = None, milling: str | None = None, include_in_shop=True) -> dict:
	"""Every part of the open orders that share a film and a milling, as one list.

	OnayBaza's «Тапсырыс Кестесі»: pick the film on the face (and the
	milling), and the parts of every order waiting for it come out together
	— one cut, one press load for several orders. Identical sizes (a part
	turned 90° is the same part) are one row with the pieces summed and the
	orders listed, largest first, the way the shop cuts.
	"""
	facade_prices.ensure_editor()
	decor = (decor or "").strip() or None
	milling = (milling or "").strip() or None
	filters = {"company": current_company(), "korkem_direction": directions.FACADES, "docstatus": 1,
			   "korkem_ready_on": ["is", "not set"], "korkem_handed_over_on": ["is", "not set"],
			   "korkem_hold_reason": ["is", "not set"]}
	if decor:
		filters["korkem_decor_top"] = decor
	orders = frappe.get_all("Sales Order", filters=filters,
							fields=["name", "customer_name", "delivery_date", "korkem_decor_top", *STAGES.values()],
							order_by="delivery_date asc, name asc", limit_page_length=500)
	if not directions.flag(include_in_shop):
		orders = [o for o in orders if not any(o.get(f) for f in STAGES.values())]
	names = [o.name for o in orders]
	parts: dict[tuple, dict] = {}
	used = set()
	if names:
		for line in frappe.get_all(
			"Sales Order Item",
			filters={"parent": ["in", names], "item_code": facade_order.FACADE_ITEM},
			fields=["parent", "korkem_height_mm", "korkem_width_mm", "qty", "korkem_milling", "korkem_area_m2"],
		):
			if milling and (line.korkem_milling or "") != milling:
				continue
			h, w = int(line.korkem_height_mm or 0), int(line.korkem_width_mm or 0)
			key = (max(h, w), min(h, w), line.korkem_milling or "")
			row = parts.setdefault(key, {"long_mm": key[0], "short_mm": key[1], "milling": key[2] or None,
										 "qty": 0, "area_m2": Decimal(0), "orders": []})
			row["qty"] += int(line.qty)
			row["area_m2"] += Decimal(str(flt(line.korkem_area_m2)))
			if line.parent not in row["orders"]:
				row["orders"].append(line.parent)
			used.add(line.parent)
	rows = sorted(parts.values(), key=lambda r: (-r["long_mm"], -r["short_mm"], r["milling"] or ""))
	for row in rows:
		row["area_m2"] = float(row["area_m2"].quantize(AREA, rounding=ROUND_HALF_UP))
	return {
		"decor": decor,
		"milling": milling,
		"orders": [{"name": o.name, "customer_name": o.customer_name, "delivery_date": str(o.delivery_date)}
				   for o in orders if o.name in used],
		"parts": rows,
		"pieces": sum(r["qty"] for r in rows),
		"area_m2": float(sum((Decimal(str(r["area_m2"])) for r in rows), Decimal(0))),
	}


def plan(days: int = 14) -> dict:
	"""«Жоспар» — the shop's plan: what waits at each stage, and in m².

	An order waits at the first stage of its finish that is not ticked; one
	on hold, ready or handed over waits nowhere. Within a stage the earliest
	due date comes first. Below, the orders taken in over the last `days`
	days, by day, the way OnayBaza shows «Қабылданған күні».
	"""
	facade_prices.ensure_editor()
	company = current_company()
	days = max(1, min(int(days or 14), 92))
	rows = frappe.get_all(
		"Sales Order",
		filters={"company": company, "korkem_direction": directions.FACADES, "docstatus": 1,
				 "korkem_ready_on": ["is", "not set"], "korkem_handed_over_on": ["is", "not set"],
				 "korkem_hold_reason": ["is", "not set"]},
		fields=["name", "docstatus", "customer", "customer_name", "delivery_date", "transaction_date",
				"korkem_finish", "korkem_decor_top", "korkem_milling", "advance_paid", "grand_total",
				"korkem_ready_on", "korkem_handed_over_on", "korkem_hold_reason", "korkem_tags",
				"korkem_extra_stages", "korkem_coatings", *STAGES.values()],
		order_by="delivery_date asc, name asc",
		limit_page_length=1000,
	)
	queues = {stage: {"stage": stage, "orders": [], "area_m2": Decimal(0)} for stage in STAGES}
	for row in rows:
		needed = stages_of(row)
		waiting = next((s for s in needed if not row.get(STAGES[s])), None)
		if waiting is None:
			continue
		area = Decimal(str(_area(row.name)))
		left = len(needed) - needed.index(waiting)
		days_left = (getdate(row.delivery_date) - getdate(nowdate())).days
		tags = mdf_tags.parse(row.korkem_tags)
		queues[waiting]["area_m2"] += area
		queues[waiting]["orders"].append(
			{"name": row.name, "customer_name": row.customer_name, "delivery_date": str(row.delivery_date),
			 "decor_top": row.korkem_decor_top, "milling": row.korkem_milling, "area_m2": float(area),
			 "overdue": _overdue(row), "due_soon": _due_soon(row), "debt": float(_debt(row)),
			 "tags": tags, "stage": waiting, "stages_left": left, "days_left": days_left,
			 "at_risk": _at_risk(left, days_left)}
		)
	for queue in queues.values():
		queue["orders"].sort(key=lambda o: ("urgent" not in o["tags"], o["delivery_date"], o["name"]))
	since = add_days(nowdate(), -days + 1)
	intake = {}
	for row in frappe.get_all(
		"Sales Order",
		filters={"company": company, "korkem_direction": directions.FACADES, "docstatus": 1,
				 "transaction_date": [">=", since]},
		fields=["name", "transaction_date"],
		limit_page_length=2000,
	):
		day = intake.setdefault(str(row.transaction_date), {"date": str(row.transaction_date), "orders": 0,
														   "area_m2": Decimal(0)})
		day["orders"] += 1
		day["area_m2"] += Decimal(str(_area(row.name)))
	return {
		"stages": [{**q, "area_m2": float(q["area_m2"])} for q in queues.values()],
		"intake": [{**d, "area_m2": float(d["area_m2"])} for d in sorted(intake.values(), key=lambda d: d["date"],
																		  reverse=True)],
		"in_work_m2": float(sum((q["area_m2"] for q in queues.values()), Decimal(0))),
	}


#: How many stages the shop gets through in a day, for «не успевает».
STAGES_PER_DAY = 2


def _at_risk(stages_left: int, days_left: int) -> bool:
	"""Will it miss its date? More stages left than the days left can carry.

	The due day itself counts: an order due today with two stages left still
	makes it, one with three does not. Overdue is past risk — it is late.
	"""
	if days_left < 0:
		return False
	return stages_left > (days_left + 1) * STAGES_PER_DAY


def last_head() -> dict:
	"""The head of the last MDF order this person wrote — what a new one starts from."""
	facade_prices.ensure_editor()
	name = frappe.db.get_value(
		"Sales Order",
		{"company": current_company(), "korkem_direction": directions.FACADES, "owner": frappe.session.user},
		"name",
		order_by="creation desc",
	)
	if not name:
		return {}
	doc = frappe.get_doc("Sales Order", name)
	head = {key: doc.get(field) for key, field in HEAD.items()}
	head.pop("extra_name", None)
	head.pop("tags", None)  # urgent or a rework is this order's, not the next one's
	head.pop("coatings", None)  # its groups', not a head to start from
	return head


STATUS_FILTERS = ("draft", "accepted", "in_shop", "ready", "handed_over", "on_hold", "cancelled")


def status_of(doc) -> str:
	if doc.docstatus == 0:
		return "draft"
	if doc.docstatus == 2:
		return "cancelled"
	if doc.korkem_handed_over_on:
		return "handed_over"
	if doc.korkem_hold_reason:
		return "on_hold"
	if doc.korkem_ready_on:
		return "ready"
	if any(doc.get(field) for field in STAGES.values()):
		return "in_shop"
	return "accepted"


def listing(search: str | None = None, status: str | None = None, overdue=False, with_debt=False,
			start: int = 0, limit: int = 50, tag: str | None = None) -> dict:
	"""The list of MDF orders, newest first, a page at a time; urgent open ones first.

	`tag` narrows to one tag — an order's (urgent, rework, …) or its customer's (vip, …).
	"""
	facade_prices.ensure_editor()
	company = current_company()
	limit = max(1, min(int(limit or 50), 200))
	start = max(0, int(start or 0))
	filters = {"company": company, "korkem_direction": directions.FACADES}
	or_filters = None
	text = (search or "").strip()
	if text:
		like = f"%{text}%"
		or_filters = {"name": ["like", like], "customer_name": ["like", like], "korkem_decor_top": ["like", like],
					  "contact_mobile": ["like", like]}
		phones = frappe.get_all("Customer", filters={"mobile_no": ["like", like]}, pluck="name", limit_page_length=50)
		if phones:
			or_filters["customer"] = ["in", phones]
	fields = ["name", "docstatus", "transaction_date", "delivery_date", "customer", "customer_name",
			  "grand_total", "advance_paid", "korkem_finish", "korkem_decor_top", "korkem_milling",
			  "korkem_edge_profile", "korkem_ready_on", "korkem_handed_over_on", "korkem_hold_reason",
			  "korkem_tags", "korkem_extra_stages", "korkem_coatings", *STAGES.values()]
	if tag and tag not in mdf_tags.ORDER + mdf_tags.CUSTOMER:
		frappe.throw(f"Метки «{tag}» нет.")
	if tag in mdf_tags.ORDER:
		filters["korkem_tags"] = ["like", f"%{tag}%"]
	elif tag:
		tagged = frappe.get_all("Customer", filters={"korkem_tags": ["like", f"%{tag}%"]}, pluck="name",
								limit_page_length=0)
		filters["customer"] = ["in", tagged or [""]]
	rows = frappe.get_all("Sales Order", filters=filters, or_filters=or_filters, fields=fields,
						  order_by="creation desc", limit_start=start, limit_page_length=limit * 3 if (
							  status or overdue or with_debt) else limit)
	customer_tags = {
		c.name: mdf_tags.parse(c.korkem_tags)
		for c in frappe.get_all("Customer", filters={"name": ["in", list({r.customer for r in rows}) or [""]]},
								fields=["name", "korkem_tags"], limit_page_length=0)
	}
	out = []
	for row in rows:
		row_status = status_of(row)
		if status and row_status != status:
			continue
		if directions.flag(overdue) and not _overdue(row):
			continue
		debt = _debt(row)
		if directions.flag(with_debt) and debt <= 0:
			continue
		done = [s for s in stages_of(row) if row.get(STAGES[s])]
		out.append(
			{
				"name": row.name,
				"status": row_status,
				"overdue": _overdue(row),
				"due_soon": _due_soon(row),
				"created_on": str(row.transaction_date),
				"delivery_date": str(row.delivery_date),
				"customer_name": row.customer_name,
				"phone": frappe.db.get_value("Customer", row.customer, "mobile_no"),
				"finish": row.korkem_finish,
				"decor_top": row.korkem_decor_top,
				"milling": row.korkem_milling,
				"edge_profile": row.korkem_edge_profile,
				"area_m2": _area(row.name),
				"total": flt(row.grand_total),
				"paid": flt(row.advance_paid),
				"debt": float(debt),
				"stage": done[-1] if done else None,
				"tags": mdf_tags.parse(row.korkem_tags),
				"customer_tags": customer_tags.get(row.customer, []),
			}
		)
		if len(out) >= limit:
			break
	# An urgent order still in work goes to the top of its page.
	out.sort(key=lambda o: not ("urgent" in o["tags"] and o["status"] in ("accepted", "in_shop")))
	return {"orders": out, "start": start, "limit": limit}


# --- helpers ---------------------------------------------------------------


def _head(head: dict, company: str) -> dict:
	spec = facade_spec.read(head, "Заказ", company)
	finish = (head.get("finish") or "").strip() or None
	default_rate = head.get("default_rate")
	material = facade_spec._text(head.get("material"))
	if material:
		from korkem_manufacturing.services import mdf_dictionaries

		if material not in facade_spec._values(mdf_dictionaries.MATERIAL, company):
			frappe.throw(f"Заказ: материала «{material}» нет в справочнике «{mdf_dictionaries.MATERIAL}».")
	return {
		"thickness_mm": spec["thickness_mm"] or thickness_of(material),
		"finish": finish,
		"decor_top": spec["decor_top"],
		"decor_bottom": spec["decor_bottom"],
		"patina": (head.get("patina") or "").strip()[:140] or None,
		"milling": (head.get("milling") or "").strip()[:140] or None,
		"edge_profile": spec["edge_profile"],
		"extra_name": (head.get("extra_name") or "").strip()[:140] or None,
		"default_rate": float(_money(default_rate, "Цена за м²")) if default_rate not in (None, "") else None,
		"material": material,
		"film_rates": _film_rates(head.get("film_rates"), company),
		"tags": mdf_tags.clean(head.get("tags"), mdf_tags.ORDER, "Заказ"),
	}


def _item(line: dict, head: dict, wanted) -> dict:
	qty = Decimal(line["qty"])
	amount = Decimal(str(line["amount"]))
	milling = line["milling"] or head["milling"]
	title = f"{milling or 'Фасад'} {line['height_mm']}×{line['width_mm']}"[:140]
	return {
		"item_code": facade_order.FACADE_ITEM,
		"item_name": title,
		"description": title,
		"qty": int(qty),
		"uom": "Nos",
		# The amount is the owner's; ERPNext's qty × rate, rounded to two
		# decimals, lands back on it (the rate keeps six — add_mdf_order_fields).
		"rate": float((amount / qty).quantize(Decimal("0.000001"), rounding=ROUND_HALF_UP)),
		"delivery_date": str(wanted),
		"korkem_height_mm": line["height_mm"],
		"korkem_width_mm": line["width_mm"],
		"korkem_area_m2": line["area_m2"],
		"korkem_milling": milling,
		"korkem_finish": line.get("finish") or head["finish"],
		"korkem_line_coating": line.get("coating"),
		"korkem_line_note": line["note"],
		"korkem_rate_m2": line["rate_m2"],
		"korkem_manual_rate": 1 if line["manual_rate"] else 0,
		"korkem_material": line.get("material") or head.get("material"),
		"korkem_line_patina": line.get("patina"),
		# A position of its own film (and back film) is that film's; one
		# without takes the head's, as every order did before groups.
		"korkem_double_sided": 1 if line.get("film_back") else 0,
		**facade_spec.as_fields(
			{
				"thickness_mm": line.get("thickness_mm") or head["thickness_mm"],
				# A paint or raw group's colour is its own, never the head's film.
				"decor_top": line.get("film") or (head["decor_top"] if line.get("coating") in (None, "pvc") else None),
				"decor_bottom": line.get("film_back") or (head["decor_bottom"] if line.get("coating") in (None, "pvc")
														  else None),
				"edge_profile": line.get("edge") or head["edge_profile"],
				"color_group": line.get("film") or (head["decor_top"] if line.get("coating") in (None, "pvc") else None),
			}
		),
	}


def _check_total(doc, expected: float) -> None:
	if Decimal(str(flt(doc.grand_total))) != Decimal(str(expected)):
		frappe.throw(
			f"ERPNext посчитал заказ на {flt(doc.grand_total):,.2f} ₸, а расчёт — на {expected:,.0f} ₸. "
			"Вероятно, настроен налог или правило цены. Заказ не сохранён.".replace(",", " ")
		)


def _order(name: str):
	if not name or not frappe.db.exists("Sales Order", name):
		frappe.throw("Заказ не найден.", frappe.DoesNotExistError)
	doc = frappe.get_doc("Sales Order", name)
	enforce_tenant_scope(doc.company)
	if doc.get("korkem_direction") != directions.FACADES:
		frappe.throw("Это не заказ МДФ-фасадов.", frappe.DoesNotExistError)
	return doc


def _accepted(name: str):
	doc = _order(name)
	if doc.docstatus != 1:
		frappe.throw("Сначала примите заказ." if doc.docstatus == 0 else "Заказ отменён.")
	return doc


def _debt(row) -> Decimal:
	if row.docstatus != 1 or not mdf_tags.owed(row.get("korkem_tags")):
		return Decimal("0")
	return max(Decimal("0"), Decimal(str(flt(row.grand_total))) - Decimal(str(flt(row.advance_paid))))


def _overdue(row) -> bool:
	return status_of(row) in ("accepted", "in_shop") and getdate(row.delivery_date) < getdate(nowdate())


def _due_soon(row) -> bool:
	if status_of(row) not in ("accepted", "in_shop"):
		return False
	due = getdate(row.delivery_date)
	return getdate(nowdate()) <= due <= getdate(add_days(nowdate(), DUE_SOON_DAYS))


def _area(order: str) -> float:
	values = frappe.get_all("Sales Order Item", filters={"parent": order, "item_code": facade_order.FACADE_ITEM},
							pluck="korkem_area_m2")
	return flt(sum(Decimal(str(flt(v))) for v in values), 2)


def _due(value):
	if not value:
		frappe.throw("Укажите срок сдачи заказа.")
	try:
		return getdate(value)
	except Exception:
		frappe.throw(f"Срок «{value}» — не дата.")


def _reason(text, message: str) -> str:
	text = (text or "").strip()
	if not text:
		frappe.throw(message)
	return text[:1000]


def _number(value, field: str) -> Decimal:
	try:
		number = Decimal(str(value).strip().replace(",", "."))
	except (InvalidOperation, TypeError, ValueError):
		frappe.throw(f"{field}: нужно число, а пришло {value!r}.")
	if not number.is_finite():
		frappe.throw(f"{field}: нужно число.")
	return number


def _money(value, field: str) -> Decimal:
	number = _number(value, field)
	if number < 0:
		frappe.throw(f"{field}: не меньше нуля.")
	return number
