# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The paint shop's own store: what paint is here, where it came from, what
it cost, and whether it is enough for the orders on their way (owner,
15.11.2026: «источник краски — откуда купили, поставщик, город, цена, оплата,
такси или логистика, принял — как в разделе ПВХ плёнок»).

A paint is a material of its own kind (`material_stock.PAINT`), kept by its
colour from the «Краска» list and by what it is — «эмаль ПУ матовая»,
«грунт», «лак»: one Item per colour and kind, counted in kilograms. A
receipt is an ERPNext Material Receipt like any other, so on hand and the
average price are ERPNext's own; how it came and how it was paid — supplier,
city, transport and its cost, who paid, who took it in, paid now, on credit
or by the supplier's invoice — are the film department's terms
(`film_dept.receipt_terms`), word for word. The receipt is marked as the
paint shop's, so it is not counted in the film department's cash.

**Enough for the queue.** The paint board knows the m² still to paint in
each colour (`mdf_paint.queue_by_colour`, the customer's own paint left
out); by the shop's recipe (`paint_recipe`: primer, enamel, lacquer and
what goes into each — hardener, thinner) each colour says the enamel it
needs, and the queue as a whole the primer, hardener and thinner.

**Taken off by itself** (owner, 15.11.2026: «водишь м² — система сама
определяет, сколько уходит краски»). «Покрашено» on an order issues its m²
by the recipe, material by material: the enamel of each colour from the
paint of that colour that has most, the others by their name; unticked, it
is put back. Never more than is there: what was short is
said in the log, and a count (`count`) puts the store right — the painter
weighs what is left. Over a month, what was taken and what the counts found
missing against the m² painted is what a m² **really** takes.
"""

from __future__ import annotations

from decimal import Decimal, InvalidOperation

import frappe
from frappe.utils import flt, get_fullname, getdate

from korkem_manufacturing.services import (
	audit,
	film_cash,
	film_dept,
	film_sources,
	material_stock,
	mdf_paint,
	mdf_paints,
	paint_recipe,
	price_visibility,
)
from korkem_manufacturing.services.scope import current_company

UNIT = "кг"
DEPT = "paint"
#: Whose supplier it is — paint's own, apart from film (owner, 15.11.2026).
SUPPLIER_DEPT = "korkem_supplier_dept"
#: The card a paint supplier keeps: the company, its person, how to reach it,
#: its smallest batch.
SUPPLIER_CARD = ("city", "contact", "phone", "whatsapp", "min_order", "note")
#: A photo of the supplier's invoice (owner, 20.11.2026: «фото накладной»).
PHOTO_MAX = 10 * 1024 * 1024
PHOTO_EXT = (".jpg", ".jpeg", ".png", ".webp", ".heic", ".pdf")
MAX_BASE = 60
#: Why paint left the store: painted an order, or a count found less.
USE_ORDER, USE_COUNT = "order", "count"
USAGE_DAYS = 30


def set_recipe(value) -> dict:
	"""The shop's recipe (`paint_recipe`); the store as it now reads."""
	paint_recipe.set_recipe(value)
	return stock()


def component(base: str | None, company: str | None = None) -> bool:
	"""Is it one of the recipe's colourless materials — primer, lacquer,
	hardener, thinner — kept by its name, not by a colour."""
	low = " ".join(str(base or "").split()).lower()
	if not low:
		return False
	for layer in paint_recipe.recipe(company)["layers"]:
		names = [p["name"] for p in layer["parts"]] + ([] if layer["colour"] else [layer["name"]])
		if any(low == n.lower() or low.startswith(n.lower() + " ") for n in names):
			return True
	return False


def _clean(value, limit: int) -> str:
	return " ".join(str(value or "").split())[:limit]


def _title(colour: str, base: str) -> str:
	if not colour:
		return base
	return f"Краска {colour}" + (f" · {base}" if base else "")


def _item(colour: str, base: str) -> str:
	"""The paint's Item — the same colour and kind is the same paint."""
	company = current_company()
	name = frappe.db.get_value(
		"Item",
		{"korkem_material_company": company, "korkem_material_kind": material_stock.PAINT,
		 "korkem_color": colour or ["is", "not set"], "korkem_paint_base": base or ["is", "not set"]},
		"name",
	)
	if name:
		frappe.db.set_value("Item", name, "disabled", 0)
		return name
	made = material_stock.define_material(material_stock.PAINT, UNIT, name=_title(colour, base))
	frappe.db.set_value("Item", made["item"], {"korkem_color": colour or None, "korkem_paint_base": base or None})
	return made["item"]


def receive(colour: str, kg, price_kg, supplier: str, base: str | None = None, received_on: str | None = None,
			note: str | None = None, delivery=None, received_by: str | None = None, supplier_pay=None) -> dict:
	"""So many kilograms of a colour at so much a kilo, from a supplier —
	and how it came and was paid, as a film receipt says it. Primer,
	hardener, thinner, lacquer (`component`) come with no colour."""
	material_stock._ensure_editor()
	# Paint's own suppliers only — checked before anything is made.
	if frappe.db.get_value("Supplier", supplier, SUPPLIER_DEPT) != DEPT:
		frappe.throw("Это не поставщик краски — выберите из своих или добавьте нового.")
	colour = _clean(colour, 140)
	base = _clean(base, MAX_BASE)
	company = current_company()
	if component(base, company):
		colour = ""
	elif not colour:
		frappe.throw("Какой цвет пришёл?")
	elif colour not in material_stock.enabled_values(mdf_paints.PAINT_LIST, company):
		frappe.throw(f"«{colour}» нет в справочнике красок. Добавьте его.")
	item = _item(colour, base)
	logistics, fields = film_dept.receipt_terms(supplier, delivery, received_by, supplier_pay)
	if fields.get("korkem_supplier_paid_from") == film_cash.FROM_DEPT:
		# The film department's cash does not pay for paint.
		fields["korkem_supplier_paid_from"] = film_cash.FROM_ELSEWHERE
	result = material_stock.receive(item, kg, price_kg, supplier, received_on=received_on, note=note,
									delivery=logistics)
	frappe.db.set_value("Stock Entry", result["receipt"], {**fields, "korkem_receipt_dept": DEPT},
						update_modified=False)
	audit.record_audit(action="paint.received", entity_type="Stock Entry", entity_id=result["receipt"],
					   diff={"colour": colour, "base": base, "kg": flt(kg), "price_kg": flt(price_kg)})
	return {"receipt": result["receipt"], **stock()}


def _same(a: str, b: str) -> bool:
	"""«RAL 9016» on an order and «RAL 9016 Транспортный белый» in the store."""
	return mdf_paints._number(mdf_paint.colour_only(a)) == mdf_paints._number(mdf_paint.colour_only(b))


def stock() -> dict:
	"""Every paint here, by colour; the queue's need beside what is on hand;
	what was last paid, to whom, from where — and what is owed for paint."""
	material_stock._ensure_staff()
	company = current_company()
	allowed = price_visibility.can_see_prices()
	items = frappe.get_all(
		"Item",
		filters={"korkem_material_company": company, "korkem_material_kind": material_stock.PAINT, "disabled": 0},
		fields=["name", "item_name", "korkem_color", "korkem_paint_base"],
		order_by="item_name asc",
		limit_page_length=0,
	)
	on_hand = material_stock._stock([i.name for i in items], company)
	last = _last_receipts([i.name for i in items], company)
	rec = paint_recipe.recipe(company)
	queue = mdf_paint.queue_by_colour(company)
	paints = []
	for i in items:
		kg, avg = on_hand.get(i.name, (0.0, 0.0))
		paints.append({
			"item": i.name, "title": i.item_name, "colour": i.korkem_color, "base": i.korkem_paint_base,
			"on_hand_kg": kg, "average_price": price_visibility.money(avg, allowed=allowed),
			"last": _last_row(last.get(i.name), allowed),
		})
	# The queue by colour: what it needs against all the paint of that colour.
	colours = []
	for colour, m2 in sorted(queue.items(), key=lambda kv: -kv[1]):
		if colour == mdf_paint.NO_COLOUR:
			continue
		have = sum(p["on_hand_kg"] for p in paints if p["colour"] and _same(p["colour"], colour)
				   and not component(p["base"], company))
		need = round(sum(r["kg"] for r in paint_recipe.materials(m2, rec) if r["colour"]), 2)
		colours.append({"colour": colour, "queue_m2": round(m2, 2), "need_kg": need, "on_hand_kg": round(have, 3),
						"short_kg": round(max(need - have, 0), 2)})
	# Primer, hardener, thinner for the whole queue — whatever its colours.
	total_m2 = sum(m2 for colour, m2 in queue.items())
	materials = []
	for r in paint_recipe.materials(total_m2, rec) if total_m2 else []:
		if r["colour"]:
			continue
		ids = paint_recipe.items_of(r["name"], company)
		have = sum(p["on_hand_kg"] for p in paints if p["item"] in ids)
		materials.append({"name": r["name"], "need_kg": r["kg"], "on_hand_kg": round(have, 3),
						  "short_kg": round(max(r["kg"] - have, 0), 2)})
	return {
		"paints": paints,
		"queue": colours,
		"materials": materials,
		"recipe": rec,
		"kg_per_m2": paint_recipe.kg_m2(rec),
		"owed": _owed(company, allowed),
		"prices_visible": allowed,
		# Whom paint can be bought from — the same suppliers as film's and the
		# warehouse's — the ones paint came from first.
		"suppliers": _suppliers(company),
		"usage": usage(company),
		"delivery_owed": _delivery_owed(company, allowed),
	}


def _delivery_owed(company: str, allowed: bool) -> list[dict]:
	"""Bringing paint that an employee paid out of his pocket, or nobody has
	paid yet — to be given back, or paid to the carrier (owner, 15.11.2026)."""
	out = []
	for d in frappe.get_all(
		"Stock Entry",
		filters={"company": company, "korkem_material_receipt": 1, "docstatus": 1, "korkem_receipt_dept": DEPT,
				 "korkem_delivery_payer": ["in", [film_dept.PAYER_EMPLOYEE, film_dept.PAYER_UNPAID]],
				 "korkem_delivery_settled_on": ["is", "not set"], "korkem_delivery_cost": [">", 0]},
		fields=["name", "posting_date", "korkem_supplier", "korkem_delivery_payer", "korkem_delivery_paid_by",
				"korkem_delivery_cost", "korkem_delivery_transport", "korkem_delivery_driver",
				"korkem_delivery_phone"],
		order_by="posting_date asc",
		limit_page_length=0,
	):
		employee = d.korkem_delivery_payer == film_dept.PAYER_EMPLOYEE
		out.append({
			"receipt": d.name, "date": str(d.posting_date),
			"amount": price_visibility.money(d.korkem_delivery_cost, allowed=allowed),
			"employee": get_fullname(d.korkem_delivery_paid_by) if employee and d.korkem_delivery_paid_by else None,
			"transport": d.korkem_delivery_transport, "driver": d.korkem_delivery_driver,
			"phone": d.korkem_delivery_phone,
			"supplier": frappe.db.get_value("Supplier", d.korkem_supplier, "supplier_name") or d.korkem_supplier,
		})
	return out


def settle_delivery(receipt: str, method: str | None = None, bank: str | None = None) -> dict:
	"""Given back to the employee, or paid to the carrier, today."""
	if frappe.db.get_value("Stock Entry", receipt, "korkem_receipt_dept") != DEPT:
		frappe.throw("Такого долга за доставку краски нет.", frappe.DoesNotExistError)
	film_cash.settle(receipt, method, bank)
	return stock()


def _suppliers(company: str) -> list[dict]:
	"""Paint's own suppliers with their cards — the one bought from most
	recently first; film's are not here."""
	recent = [r.korkem_supplier for r in frappe.get_all(
		"Stock Entry", filters={"company": company, "korkem_receipt_dept": DEPT, "docstatus": 1},
		fields=["korkem_supplier"], order_by="posting_date desc, creation desc", limit_page_length=500)]
	rank = {s: i for i, s in reversed(list(enumerate(recent)))}
	card = {key: film_sources.CARD[key] for key in SUPPLIER_CARD}
	rows = frappe.get_all("Supplier", filters={"disabled": 0, SUPPLIER_DEPT: DEPT},
						  fields=["name", "supplier_name", *card.values()], limit_page_length=500)
	rows.sort(key=lambda r: (rank.get(r.name, len(rank)), (r.supplier_name or r.name).casefold()))
	return [
		{"supplier": r.name, "name": r.supplier_name or r.name, "paint": True,
		 **{key: r.get(field) for key, field in card.items()}}
		for r in rows
	]


def add_supplier(name: str, **card) -> dict:
	"""A paint supplier — a company or a person — added from the receipt,
	with its card. A film supplier's name is not taken over: paint's are its
	own (owner, 15.11.2026)."""
	material_stock._ensure_editor()
	clean = " ".join(str(name or "").split())
	row = frappe.db.get_value("Supplier", {"supplier_name": clean}, ["name", SUPPLIER_DEPT], as_dict=True)
	if row and row.get(SUPPLIER_DEPT) != DEPT:
		frappe.throw(f"«{clean}» — уже поставщик плёнки. Назовите поставщика краски иначе, "
					 f"например «{clean} (краска)».")
	material_stock.add_supplier(clean)
	supplier = frappe.db.get_value("Supplier", {"supplier_name": clean}, "name")
	frappe.db.set_value("Supplier", supplier, SUPPLIER_DEPT, DEPT)
	return set_supplier(supplier, **card)


def set_supplier(supplier: str, **card) -> dict:
	"""A paint supplier's card: city, person, phones, smallest batch, a note."""
	material_stock._ensure_editor()
	if frappe.db.get_value("Supplier", supplier, SUPPLIER_DEPT) != DEPT:
		frappe.throw("Такого поставщика краски нет.", frappe.DoesNotExistError)
	values = {key: card[key] for key in SUPPLIER_CARD if key in card}
	if card.get("name"):
		values["name"] = card["name"]
	if values:
		film_sources.set_card(supplier, **values)
	return stock()


def _last_receipts(items: list[str], company: str) -> dict[str, dict]:
	if not items:
		return {}
	out: dict[str, dict] = {}
	for d in frappe.db.sql(
		"""select sed.item_code, sed.qty, sed.basic_rate, se.name, se.posting_date, se.korkem_supplier,
			se.korkem_delivery_city, se.korkem_delivery_transport, se.korkem_delivery_cost, se.remarks
		from `tabStock Entry Detail` sed join `tabStock Entry` se on se.name = sed.parent
		where se.company = %(company)s and se.docstatus = 1 and se.korkem_material_receipt = 1
			and sed.item_code in %(items)s
		order by se.posting_date desc, se.creation desc""",
		{"company": company, "items": tuple(items)},
		as_dict=True,
	):
		out.setdefault(d.item_code, d)
	return out


def _last_row(d, allowed: bool) -> dict | None:
	if not d:
		return None
	return {
		"receipt": d.name, "date": str(d.posting_date), "kg": flt(d.qty),
		"price_kg": price_visibility.money(d.basic_rate, allowed=allowed),
		"supplier": d.korkem_supplier,
		"supplier_name": frappe.db.get_value("Supplier", d.korkem_supplier, "supplier_name") or d.korkem_supplier,
		"city": d.korkem_delivery_city, "transport": d.korkem_delivery_transport,
		"delivery_cost": price_visibility.money(d.korkem_delivery_cost, allowed=allowed),
		# «4 × 5 кг»: how it came last time, for this time's cans.
		"note": d.remarks,
	}


def attach_photo(receipt: str, file_name: str, content: bytes) -> dict:
	"""The invoice's photo onto a paint receipt — kept, not looked for on
	paper later (owner, 20.11.2026)."""
	material_stock._ensure_editor()
	if (frappe.db.get_value("Stock Entry", receipt, ["company", "korkem_receipt_dept"])
			!= (current_company(), DEPT)):
		frappe.throw("Такого прихода краски нет.", frappe.DoesNotExistError)
	if not content or len(content) > PHOTO_MAX:
		frappe.throw(f"Фото — до {PHOTO_MAX // (1024 * 1024)} МБ.")
	name = " ".join((file_name or "").split())[:120] or "invoice.jpg"
	if not name.lower().endswith(PHOTO_EXT):
		frappe.throw("Фото накладной — jpg, png, webp, heic или pdf.")
	f = frappe.get_doc({
		"doctype": "File", "file_name": name, "attached_to_doctype": "Stock Entry", "attached_to_name": receipt,
		"is_private": 1, "content": content,
	}).insert(ignore_permissions=True)
	audit.record_audit(action="paint.receipt_photo", entity_type="Stock Entry", entity_id=receipt,
					   diff={"file": f.name})
	return {"receipt": receipt, "file": f.file_url}


def _photos(receipts: list[str]) -> dict[str, str]:
	if not receipts:
		return {}
	out: dict[str, str] = {}
	for f in frappe.get_all("File", filters={"attached_to_doctype": "Stock Entry",
											 "attached_to_name": ["in", receipts]},
							fields=["attached_to_name", "file_url"], order_by="creation asc", limit_page_length=0):
		out.setdefault(f.attached_to_name, f.file_url)
	return out


def history(item: str) -> dict:
	"""One paint's receipts, newest first: when, how much, at what price,
	from whom and where, how it came, who took it in."""
	material_stock._ensure_staff()
	company = current_company()
	if frappe.db.get_value("Item", item, ["korkem_material_company", "korkem_material_kind"]) != (
			company, material_stock.PAINT):
		frappe.throw("Такой краски нет.", frappe.DoesNotExistError)
	allowed = price_visibility.can_see_prices()
	rows = frappe.db.sql(
		"""select se.name, se.posting_date, se.docstatus, se.korkem_supplier, se.korkem_delivery_city,
			se.korkem_delivery_transport, se.korkem_delivery_cost, se.korkem_received_by,
			se.korkem_supplier_owed, se.korkem_supplier_paid_on, se.korkem_supplier_paid_method,
			se.korkem_supplier_paid_bank, se.korkem_supplier_invoice_no, sed.qty, sed.basic_rate
		from `tabStock Entry Detail` sed join `tabStock Entry` se on se.name = sed.parent
		where se.company = %(company)s and se.korkem_material_receipt = 1 and sed.item_code = %(item)s
			and se.docstatus != 0
		order by se.posting_date desc, se.creation desc limit 200""",
		{"company": company, "item": item},
		as_dict=True,
	)
	out = []
	photos = _photos([r.name for r in rows])
	for r in rows:
		kg, price, cost = flt(r.qty), flt(r.basic_rate), flt(r.korkem_delivery_cost)
		out.append({
			"photo": photos.get(r.name),
			"receipt": r.name, "date": str(r.posting_date), "cancelled": r.docstatus == 2, "kg": kg,
			"price_kg": price_visibility.money(price, allowed=allowed),
			"amount": price_visibility.money(round(kg * price, 2), allowed=allowed),
			"delivery_cost": price_visibility.money(cost, allowed=allowed),
			# What a kilo really cost, the bringing shared out over it.
			"landed_kg": price_visibility.money(round(price + (cost / kg if kg else 0), 2), allowed=allowed),
			"supplier": frappe.db.get_value("Supplier", r.korkem_supplier, "supplier_name") or r.korkem_supplier,
			"city": r.korkem_delivery_city, "transport": r.korkem_delivery_transport,
			"received_by": get_fullname(r.korkem_received_by) if r.korkem_received_by else None,
			"owed": bool(r.korkem_supplier_owed and not r.korkem_supplier_paid_on),
			"paid_method": " · ".join(x for x in (r.korkem_supplier_paid_method, r.korkem_supplier_paid_bank) if x)
			or None, "invoice_no": r.korkem_supplier_invoice_no,
		})
	return {"receipts": out}


def _owed(company: str, allowed: bool) -> list[dict]:
	"""Paint taken on credit or by invoice and not paid yet, oldest first."""
	out = []
	for e in frappe.get_all(
		"Stock Entry",
		filters={"company": company, "korkem_material_receipt": 1, "docstatus": 1, "korkem_receipt_dept": DEPT,
				 "korkem_supplier_owed": 1, "korkem_supplier_paid_on": ["is", "not set"]},
		fields=["name", "posting_date", "korkem_supplier", "korkem_supplier_invoice_no", "korkem_supplier_due_on"],
		order_by="posting_date asc",
		limit_page_length=0,
	):
		line = frappe.db.get_value("Stock Entry Detail", {"parent": e.name}, ["item_name", "qty", "basic_rate"],
								   as_dict=True)
		if not line:
			continue
		out.append({
			"receipt": e.name, "date": str(e.posting_date), "paint": line.item_name, "kg": flt(line.qty),
			"amount": price_visibility.money(round(flt(line.qty) * flt(line.basic_rate), 2), allowed=allowed),
			"supplier": frappe.db.get_value("Supplier", e.korkem_supplier, "supplier_name") or e.korkem_supplier,
			"invoice_no": e.korkem_supplier_invoice_no,
			"due_on": str(e.korkem_supplier_due_on) if e.korkem_supplier_due_on else None,
			"overdue": bool(e.korkem_supplier_due_on and getdate(e.korkem_supplier_due_on) < getdate()),
		})
	return out


def pay_supplier(receipt: str, method: str | None = None, bank: str | None = None) -> dict:
	"""Paint bought on credit is paid for today — not out of the film cash."""
	if frappe.db.get_value("Stock Entry", receipt, "korkem_receipt_dept") != DEPT:
		frappe.throw("Такого долга за краску нет.", frappe.DoesNotExistError)
	film_cash.pay_supplier(receipt, method, film_cash.FROM_ELSEWHERE, bank)
	return stock()


def _paints_of(company: str, colour: str) -> list[tuple[str, float]]:
	"""The paints of a colour, with what is on hand — the fullest first."""
	items = [i.name for i in frappe.get_all(
		"Item", filters={"korkem_material_company": company, "korkem_material_kind": material_stock.PAINT},
		fields=["name", "korkem_color", "korkem_paint_base"], limit_page_length=0)
		if i.korkem_color and _same(i.korkem_color, colour) and not component(i.korkem_paint_base, company)]
	on_hand = material_stock._stock(items, company)
	return sorted(((i, on_hand.get(i, (0.0, 0.0))[0]) for i in items), key=lambda x: -x[1])


def norm(company: str, colour: str, m2: float, rec: dict | None = None) -> dict:
	"""What the painter is to use for so many m² of a colour, by the recipe,
	against the batch on the shelf (owner, 15.11.2026: «поставщик даёт
	минималку 3–5 кг, а расход по факту меньше — остаток на склад, а маляру
	сказать, сколько использовать»). Only the norm is ever taken off; what
	is left of a batch stays on the shelf for the next order."""
	rec = rec or paint_recipe.recipe(company)
	use = [{"name": r["name"], "kg": r["kg"], "colour": r["colour"]} for r in paint_recipe.materials(m2, rec)]
	enamel = round(sum(r["kg"] for r in use if r["colour"]), 2)
	shelf = _paints_of(company, colour)
	have = round(sum(max(h, 0) for _, h in shelf), 3)
	last = sorted(_last_receipts([i for i, _ in shelf], company).values(),
				  key=lambda d: str(d.posting_date), reverse=True)
	return {
		"use": use, "enamel_kg": enamel, "on_hand_kg": have,
		"batch_kg": flt(last[0].qty) if last else None,
		# More on the shelf than the norm: the rest goes back, not on the facade.
		"left_kg": round(max(have - enamel, 0), 2) if enamel else 0,
	}


def _entry(company: str, purpose: str, item: str, kg: float, use: str, order: str | None = None,
		   m2: float | None = None, rate: float | None = None) -> str:
	warehouse = material_stock._receiving_warehouse(company, None)
	unit = frappe.db.get_value("Item", item, "stock_uom")
	line = {"item_code": item, "qty": kg, "uom": unit, "stock_uom": unit, "conversion_factor": 1}
	if purpose == "Material Issue":
		line["s_warehouse"] = warehouse
	else:
		line.update({"t_warehouse": warehouse, "basic_rate": rate or 0, "allow_zero_valuation_rate": 0 if rate else 1})
	entry = frappe.get_doc({
		"doctype": "Stock Entry", "stock_entry_type": purpose, "purpose": purpose, "company": company,
		"korkem_receipt_dept": DEPT, "korkem_paint_use": use, "korkem_paint_order": order,
		"korkem_paint_m2": m2 or 0, "remarks": f"Краска: {order}" if order else "Краска: пересчёт",
		"items": [line],
	})
	entry.insert(ignore_permissions=True)
	entry.submit()
	return entry.name


def use_for_order(order: str) -> dict:
	"""«Покрашено»: the order's m² by the shop's recipe, colour by colour,
	off the store — once; not for an order painted with the customer's own
	paint. Returns what was taken and what was short."""
	from korkem_manufacturing.services import mdf_tags

	row = frappe.db.get_value("Sales Order", order, ["company", "korkem_tags"], as_dict=True)
	if not row or frappe.db.exists("Stock Entry", {"korkem_paint_order": order, "korkem_paint_use": USE_ORDER,
													"docstatus": 1}):
		return {"taken": [], "short": []}
	if mdf_tags.CLIENT_PAINT in mdf_tags.parse(row.korkem_tags):
		return {"taken": [], "short": []}
	rec = paint_recipe.recipe(row.company)
	taken, short = [], []
	for colour, m2 in mdf_paint._colours([order])[0].get(order, {}).items():
		if colour == mdf_paint.NO_COLOUR:
			continue
		needs = paint_recipe.materials(float(m2), rec)
		# The m² shared out over every kilogram taken, so a month's m² is
		# counted once however many materials it took.
		total = sum(r["kg"] for r in needs) or 1
		for r in needs:
			# Kilograms to the hundredth, as the stock ledger keeps them.
			left = r["kg"]
			if r["colour"]:
				shelf = _paints_of(row.company, colour)
			else:
				ids = paint_recipe.items_of(r["name"], row.company)
				on_hand = material_stock._stock(ids, row.company)
				shelf = sorted(((i, on_hand.get(i, (0.0, 0.0))[0]) for i in ids), key=lambda x: -x[1])
			for item, have in shelf:
				take = round(min(left, have), 2)
				if take <= 0:
					continue
				_entry(row.company, "Material Issue", item, take, USE_ORDER, order, round(float(m2) * take / total, 3))
				taken.append({"colour": colour, "material": r["name"], "item": item, "kg": take})
				left = round(left - take, 2)
				if left <= 0:
					break
			if left > 0:
				short.append({"colour": colour, "material": r["name"], "kg": left, "m2": float(m2)})
	audit.record_audit(action="paint.used", entity_type="Sales Order", entity_id=order,
					   diff={"taken": taken, "short": short, "kg_per_m2": paint_recipe.kg_m2(rec)})
	return {"taken": taken, "short": short}


def return_for_order(order: str) -> None:
	"""«Покрашено» taken back: what it took goes back on the shelf."""
	for name in frappe.get_all("Stock Entry", filters={"korkem_paint_order": order, "korkem_paint_use": USE_ORDER,
													   "docstatus": 1}, pluck="name"):
		entry = frappe.get_doc("Stock Entry", name)
		entry.flags.ignore_permissions = True
		entry.cancel()
	audit.record_audit(action="paint.returned", entity_type="Sales Order", entity_id=order, diff={})


def count(item: str, kg) -> dict:
	"""The painter weighed what is left: the store is put right to it, and
	the difference counts towards what a m² really takes."""
	material_stock._ensure_editor()
	company = current_company()
	if frappe.db.get_value("Item", item, ["korkem_material_company", "korkem_material_kind"]) != (
			company, material_stock.PAINT):
		frappe.throw("Такой краски нет.", frappe.DoesNotExistError)
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
		last = _last_receipts([item], company).get(item)
		_entry(company, "Material Receipt", item, diff, USE_COUNT, rate=average or (flt(last.basic_rate) if last else 0))
	audit.record_audit(action="paint.counted", entity_type="Item", entity_id=item,
					   diff={"was": have, "now": float(actual)})
	return stock()


def usage(company: str | None = None, days: int = USAGE_DAYS) -> dict:
	"""The last month: m² painted, kilograms taken for them by the figure,
	what counts found missing (or over) — and so what a m² really took."""
	from frappe.utils import add_days, nowdate

	company = company or current_company()
	m2 = kg_orders = kg_counted = 0.0
	for e in frappe.db.sql(
		"""select se.korkem_paint_use, se.korkem_paint_m2, se.purpose, sum(sed.qty) as qty
		from `tabStock Entry` se join `tabStock Entry Detail` sed on sed.parent = se.name
		where se.company = %(company)s and se.docstatus = 1 and se.korkem_receipt_dept = %(dept)s
			and se.korkem_paint_use in %(uses)s and se.posting_date >= %(since)s
		group by se.name""",
		{"company": company, "dept": DEPT, "uses": (USE_ORDER, USE_COUNT), "since": add_days(nowdate(), -days)},
		as_dict=True,
	):
		if e.korkem_paint_use == USE_ORDER:
			m2 += flt(e.korkem_paint_m2)
			kg_orders += flt(e.qty)
		else:
			kg_counted += flt(e.qty) if e.purpose == "Material Issue" else -flt(e.qty)
	fact = round((kg_orders + kg_counted) / m2, 3) if m2 else None
	return {"days": days, "m2": round(m2, 2), "kg_by_norm": round(kg_orders, 2), "kg_counted": round(kg_counted, 2),
			"fact_kg_m2": fact}
