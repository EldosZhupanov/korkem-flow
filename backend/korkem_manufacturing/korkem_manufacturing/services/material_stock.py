# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Materials the factory buys, how many came in, from whom, and at what price.

**Three things the administrator and the managers keep up to date**, because
what the factory buys changes — a maker stops shipping, a colour is dropped:

1. *Lists* (`Material Option`): MDF thicknesses, manufacturers, film colours,
   film widths and thicknesses. Added and removed freely; an entry a material
   already uses can only be switched off, so old receipts still read right.
2. *Suppliers*: ERPNext's own `Supplier` — the same one purchase orders use —
   so «Profi» here and «Profi» on a purchase order are one party, not two.
3. *Materials*: each one is an ERPNext `Item` described by those lists
   («МДФ 16 мм Kastamonu», «Плёнка ПВХ Графит 1400×0,30 JS group»).

**A receipt** is an ERPNext Material Receipt (`Stock Entry`): quantity at a
price per unit, into a warehouse, with the supplier recorded on it. Stock on
hand and the average price are therefore ERPNext's own figures — there is no
second ledger to disagree with the first. A receipt entered by mistake is
cancelled, which ERPNext reverses; nothing is deleted.

Prices are money: the shop floor sees quantities, never what was paid, unless
the administrator has switched prices on (`price_visibility`).
"""

from __future__ import annotations

from decimal import Decimal, InvalidOperation

import frappe
from frappe.utils import flt, getdate, nowdate

from korkem_manufacturing.services import audit, price_visibility
from korkem_manufacturing.services.identity import is_staff
from korkem_manufacturing.services.scope import current_company


EDITORS = frozenset(
	{"System Manager", "Sales Manager", "Purchase Manager", "Purchase User", "Stock Manager"}
)
MDF, FILM, OTHER = "МДФ", "Плёнка ПВХ", "Прочее"
KINDS = (MDF, FILM, OTHER)
LISTS = ("Толщина МДФ", "Производитель", "Цвет плёнки", "Ширина плёнки", "Толщина плёнки", "Профиль кромки")
#: Units a material is counted in. Created in ERPNext if missing.
UNITS = {"лист": True, "рулон": True, "шт": True, "м": False, "м²": False}
MAX_QTY = Decimal("100000")


def can_edit() -> bool:
	return bool(EDITORS.intersection(frappe.get_roles()))


def _ensure_editor() -> None:
	if not can_edit():
		frappe.throw("Склад материалов ведут администратор и менеджеры.", frappe.PermissionError)


def _ensure_staff() -> None:
	if not is_staff():
		frappe.throw("Склад видят сотрудники.", frappe.PermissionError)


# --------------------------------------------------------------------------
# Lists
# --------------------------------------------------------------------------


def lists() -> dict:
	_ensure_staff()
	company = current_company()
	rows = frappe.get_all(
		"Material Option",
		filters={"company": company},
		fields=["name", "kind", "value", "enabled"],
		order_by="kind asc, value asc",
	)
	result = {kind: [] for kind in LISTS}
	for r in rows:
		result.setdefault(r.kind, []).append({"option": r.name, "value": r.value, "enabled": bool(r.enabled)})
	return {
		"lists": result,
		"suppliers": suppliers(),
		"units": list(UNITS),
		"kinds": list(KINDS),
		"can_edit": can_edit(),
	}


def add_option(kind: str, value: str) -> dict:
	_ensure_editor()
	if kind not in LISTS:
		frappe.throw(f"Список — один из: {', '.join(LISTS)}.")
	company = current_company()
	value = " ".join((value or "").split())
	existing = frappe.db.get_value("Material Option", {"company": company, "kind": kind, "value": value}, "name")
	if existing:
		# Adding back something switched off turns it back on.
		frappe.db.set_value("Material Option", existing, "enabled", 1)
	else:
		frappe.get_doc(
			{"doctype": "Material Option", "company": company, "kind": kind, "value": value, "enabled": 1}
		).insert(ignore_permissions=True)
	audit.record_audit(action="stock.option_added", entity_type="Material Option", entity_id=f"{kind}: {value}")
	return lists()


def remove_option(option: str) -> dict:
	"""Delete an unused entry; switch off one that a material already uses."""
	_ensure_editor()
	row = frappe.db.get_value("Material Option", option, ["company", "kind", "value"], as_dict=True)
	if not row or row.company != current_company():
		frappe.throw("Такого значения нет.", frappe.DoesNotExistError)
	if _option_in_use(row.kind, row.value, row.company):
		frappe.db.set_value("Material Option", option, "enabled", 0)
		outcome = "disabled"
	else:
		frappe.delete_doc("Material Option", option, ignore_permissions=True, force=True)
		outcome = "deleted"
	audit.record_audit(
		action=f"stock.option_{outcome}", entity_type="Material Option", entity_id=f"{row.kind}: {row.value}"
	)
	return {**lists(), "outcome": outcome}


#: Where a value of each list is used: a material's description, and — for
#: the decor and the edge profile — the facade positions of orders.
_ITEM_FIELD = {
	"Толщина МДФ": "korkem_thickness_mm",
	"Производитель": "korkem_manufacturer",
	"Цвет плёнки": "korkem_color",
	"Ширина плёнки": "korkem_film_width_mm",
	"Толщина плёнки": "korkem_film_thickness_mm",
}
_ORDER_FIELDS = {
	"Цвет плёнки": ("korkem_decor_top", "korkem_decor_bottom"),
	"Профиль кромки": ("korkem_edge_profile",),
}


def _option_in_use(kind: str, value: str, company: str) -> bool:
	field = _ITEM_FIELD.get(kind)
	if field and frappe.db.exists("Item", {"korkem_material_company": company, field: value}):
		return True
	for field in _ORDER_FIELDS.get(kind, ()):
		if not frappe.db.has_column("Sales Order Item", field):
			continue
		used = frappe.db.sql(
			f"""select 1 from `tabSales Order Item` i join `tabSales Order` o on o.name = i.parent
			where i.parenttype = 'Sales Order' and o.company = %s and i.`{field}` = %s limit 1""",
			(company, value),
		)
		if used:
			return True
	return False


def enabled_values(kind: str, company: str) -> set[str]:
	"""The values of one list a new record may use: the enabled ones."""
	return _enabled_values(kind, company)


def _enabled_values(kind: str, company: str) -> set[str]:
	return set(
		frappe.get_all(
			"Material Option", filters={"company": company, "kind": kind, "enabled": 1}, pluck="value"
		)
	)


# --------------------------------------------------------------------------
# Suppliers (ERPNext Supplier)
# --------------------------------------------------------------------------


def suppliers() -> list[dict]:
	return [
		{"supplier": r.name, "name": r.supplier_name or r.name, "enabled": not r.disabled}
		for r in frappe.get_all(
			"Supplier", fields=["name", "supplier_name", "disabled"], order_by="supplier_name asc", limit_page_length=500
		)
	]


def add_supplier(name: str) -> dict:
	_ensure_editor()
	name = " ".join((name or "").split())
	if len(name) < 2:
		frappe.throw("Название поставщика слишком короткое.")
	existing = frappe.db.get_value("Supplier", {"supplier_name": name}, "name")
	if existing:
		frappe.db.set_value("Supplier", existing, "disabled", 0)
	else:
		group = frappe.db.get_single_value("Buying Settings", "supplier_group") or frappe.db.get_value(
			"Supplier Group", {"is_group": 0}, "name"
		)
		frappe.get_doc(
			{"doctype": "Supplier", "supplier_name": name, "supplier_group": group, "supplier_type": "Company"}
		).insert(ignore_permissions=True)
	audit.record_audit(action="stock.supplier_added", entity_type="Supplier", entity_id=name)
	return lists()


def disable_supplier(supplier: str) -> dict:
	"""Suppliers are never deleted: purchase orders and receipts name them."""
	_ensure_editor()
	if not frappe.db.exists("Supplier", supplier):
		frappe.throw("Такого поставщика нет.", frappe.DoesNotExistError)
	frappe.db.set_value("Supplier", supplier, "disabled", 1)
	audit.record_audit(action="stock.supplier_disabled", entity_type="Supplier", entity_id=supplier)
	return lists()


# --------------------------------------------------------------------------
# Materials (ERPNext Item)
# --------------------------------------------------------------------------


def _title(kind: str, attrs: dict) -> str:
	if kind == MDF:
		return f"МДФ {attrs['thickness']} мм {attrs['manufacturer']}"
	if kind == FILM:
		return (
			f"Плёнка ПВХ {attrs['color']} {attrs['width']}×{attrs['film_thickness']} "
			f"{attrs['manufacturer']}"
		)
	return attrs["name"]


def define_material(kind: str, unit: str, **attrs) -> dict:
	"""Describe a material from the lists. The same description is the same material."""
	_ensure_editor()
	company = current_company()
	if kind not in KINDS:
		frappe.throw(f"Вид материала — один из: {', '.join(KINDS)}.")
	if unit not in UNITS:
		frappe.throw(f"Единица — одна из: {', '.join(UNITS)}.")
	attrs = {k: " ".join(str(v or "").split()) for k, v in attrs.items()}

	def require(kind_list: str, key: str):
		if attrs.get(key) not in _enabled_values(kind_list, company):
			frappe.throw(f"«{attrs.get(key) or '—'}» нет в списке «{kind_list}». Добавьте его в справочник.")

	if kind == MDF:
		require("Толщина МДФ", "thickness")
		require("Производитель", "manufacturer")
	elif kind == FILM:
		require("Цвет плёнки", "color")
		require("Ширина плёнки", "width")
		require("Толщина плёнки", "film_thickness")
		require("Производитель", "manufacturer")
	elif len(attrs.get("name", "")) < 2:
		frappe.throw("Назовите материал.")

	title = _title(kind, attrs)[:140]
	existing = frappe.db.get_value("Item", {"korkem_material_company": company, "item_name": title}, "name")
	if existing:
		frappe.db.set_value("Item", existing, "disabled", 0)
		return material(existing)

	_ensure_uom(unit)
	group = next(
		(g for g in ("Raw Material", "Сырьё", "All Item Groups") if frappe.db.exists("Item Group", g)), None
	)
	item = frappe.get_doc(
		{
			"doctype": "Item",
			"item_code": f"MAT-{frappe.generate_hash(length=8).upper()}",
			"item_name": title,
			"description": title,
			"item_group": group,
			"stock_uom": unit,
			"is_stock_item": 1,
			"is_purchase_item": 1,
			"is_sales_item": 0,
			"include_item_in_manufacturing": 1,
			"korkem_material_kind": kind,
			"korkem_material_company": company,
			"korkem_thickness_mm": attrs.get("thickness") if kind == MDF else None,
			"korkem_manufacturer": attrs.get("manufacturer") if kind in (MDF, FILM) else None,
			"korkem_color": attrs.get("color") if kind == FILM else None,
			"korkem_film_width_mm": attrs.get("width") if kind == FILM else None,
			"korkem_film_thickness_mm": attrs.get("film_thickness") if kind == FILM else None,
		}
	)
	item.insert(ignore_permissions=True)
	audit.record_audit(action="stock.material_defined", entity_type="Item", entity_id=item.name, diff={"title": title})
	return material(item.name)


def set_material_enabled(item: str, enabled: bool | int | str) -> dict:
	"""Materials with stock history are switched off, never deleted."""
	_ensure_editor()
	_own_item(item)
	enabled = bool(int(enabled)) if isinstance(enabled, str) else bool(enabled)
	frappe.db.set_value("Item", item, "disabled", 0 if enabled else 1)
	audit.record_audit(action="stock.material_enabled" if enabled else "stock.material_disabled", entity_type="Item", entity_id=item)
	return material(item)


def _own_item(item: str) -> None:
	if frappe.db.get_value("Item", item, "korkem_material_company") != current_company():
		frappe.throw("Такого материала нет.", frappe.DoesNotExistError)


def _ensure_uom(unit: str) -> None:
	# MariaDB compares names without case: an existing «Лист» answers for «лист»,
	# and that is the UOM the item will carry. It must still count whole sheets.
	existing = frappe.db.get_value("UOM", unit, ["name", "must_be_whole_number"], as_dict=True)
	if not existing:
		frappe.get_doc({"doctype": "UOM", "uom_name": unit, "must_be_whole_number": 1 if UNITS[unit] else 0}).insert(
			ignore_permissions=True
		)
	elif UNITS[unit] and not existing.must_be_whole_number:
		frappe.db.set_value("UOM", existing.name, "must_be_whole_number", 1)


def _whole_units(unit: str | None) -> bool:
	"""Sheets, rolls and pieces come whole — by our list or by ERPNext's own flag."""
	if not unit:
		return False
	return bool(UNITS.get(unit.lower())) or bool(frappe.db.get_value("UOM", unit, "must_be_whole_number"))


def materials(kind: str | None = None, include_disabled: bool = False) -> dict:
	_ensure_staff()
	company = current_company()
	filters = {"korkem_material_company": company}
	if kind:
		filters["korkem_material_kind"] = kind
	if not include_disabled:
		filters["disabled"] = 0
	items = frappe.get_all(
		"Item",
		filters=filters,
		fields=[
			"name", "item_name", "stock_uom", "disabled", "korkem_material_kind", "korkem_thickness_mm",
			"korkem_manufacturer", "korkem_color", "korkem_film_width_mm", "korkem_film_thickness_mm",
		],
		order_by="item_name asc",
		limit_page_length=1000,
	)
	stock = _stock([i.name for i in items], company)
	allowed = price_visibility.can_see_prices()
	return {
		"materials": [_material_row(i, stock.get(i.name, (0.0, 0.0)), allowed) for i in items],
		"can_edit": can_edit(),
		"prices_visible": allowed,
	}


def material(item: str) -> dict:
	company = current_company()
	row = frappe.db.get_value(
		"Item",
		item,
		[
			"name", "item_name", "stock_uom", "disabled", "korkem_material_kind", "korkem_thickness_mm",
			"korkem_manufacturer", "korkem_color", "korkem_film_width_mm", "korkem_film_thickness_mm",
		],
		as_dict=True,
	)
	return _material_row(row, _stock([item], company).get(item, (0.0, 0.0)), price_visibility.can_see_prices())


def _stock(items: list[str], company: str) -> dict[str, tuple[float, float]]:
	"""Quantity on hand and average price, across this company's warehouses."""
	if not items:
		return {}
	warehouses = frappe.get_all("Warehouse", filters={"company": company, "is_group": 0}, pluck="name")
	if not warehouses:
		return {}
	result: dict[str, list[float]] = {}
	for b in frappe.get_all(
		"Bin",
		filters={"item_code": ["in", items], "warehouse": ["in", warehouses]},
		fields=["item_code", "actual_qty", "stock_value"],
	):
		acc = result.setdefault(b.item_code, [0.0, 0.0])
		acc[0] += flt(b.actual_qty)
		acc[1] += flt(b.stock_value)
	return {k: (round(q, 3), round(v / q, 2) if q else 0.0) for k, (q, v) in result.items()}


def _material_row(i, stock: tuple[float, float], allowed: bool) -> dict:
	return {
		"item": i.name,
		"title": i.item_name,
		"kind": i.korkem_material_kind,
		"unit": i.stock_uom,
		"enabled": not i.disabled,
		"thickness": i.korkem_thickness_mm,
		"manufacturer": i.korkem_manufacturer,
		"color": i.korkem_color,
		"width": i.korkem_film_width_mm,
		"film_thickness": i.korkem_film_thickness_mm,
		"on_hand": stock[0],
		"average_price": price_visibility.money(stock[1], allowed=allowed),
	}


# --------------------------------------------------------------------------
# Receipts (ERPNext Material Receipt)
# --------------------------------------------------------------------------


def _receiving_warehouse(company: str, warehouse: str | None) -> str:
	if warehouse:
		if frappe.db.get_value("Warehouse", warehouse, "company") != company:
			frappe.throw("Такого склада нет.", frappe.DoesNotExistError)
		return warehouse
	stores = frappe.db.get_value(
		"Warehouse", {"company": company, "warehouse_name": "Stores", "is_group": 0, "disabled": 0}, "name"
	) or frappe.db.get_value("Warehouse", {"company": company, "is_group": 0, "disabled": 0}, "name")
	if not stores:
		frappe.throw("У компании нет склада. Создайте его в настройках складов.")
	return stores


def receive(
	item: str,
	qty,
	price_per_unit,
	supplier: str,
	warehouse: str | None = None,
	received_on: str | None = None,
	note: str | None = None,
) -> dict:
	"""Bought `qty` of `item` from `supplier` at `price_per_unit` each."""
	_ensure_editor()
	company = current_company()
	_own_item(item)
	if frappe.db.get_value("Item", item, "disabled"):
		frappe.throw("Материал отключён. Включите его, чтобы оприходовать.")
	if not frappe.db.exists("Supplier", {"name": supplier, "disabled": 0}):
		frappe.throw("Такого поставщика нет или он отключён.", frappe.DoesNotExistError)
	try:
		quantity = Decimal(str(qty))
		price = Decimal(str(price_per_unit))
	except (InvalidOperation, ValueError):
		frappe.throw("Количество и цена — числа.")
	if not quantity.is_finite() or quantity <= 0 or quantity > MAX_QTY:
		frappe.throw("Количество должно быть больше нуля.")
	unit = frappe.db.get_value("Item", item, "stock_uom")
	if _whole_units(unit) and quantity != quantity.to_integral_value():
		frappe.throw(f"«{unit}» считается только целыми.")
	if not price.is_finite() or price <= 0:
		frappe.throw("Цена за единицу должна быть больше нуля.")
	day = getdate(received_on) if received_on else getdate(nowdate())
	if day > getdate(nowdate()):
		frappe.throw("Приход не может быть в будущем.")

	target = _receiving_warehouse(company, warehouse)
	entry = frappe.get_doc(
		{
			"doctype": "Stock Entry",
			"stock_entry_type": "Material Receipt",
			"purpose": "Material Receipt",
			"company": company,
			"posting_date": str(day),
			"set_posting_time": 1 if received_on else 0,
			"korkem_supplier": supplier,
			"korkem_material_receipt": 1,
			"remarks": (note or "").strip()[:500] or None,
			"items": [
				{
					"item_code": item,
					"qty": float(quantity),
					"uom": unit,
					"stock_uom": unit,
					"conversion_factor": 1,
					"basic_rate": float(price),
					"t_warehouse": target,
					"allow_zero_valuation_rate": 0,
				}
			],
		}
	)
	# Who may receive is decided above, by role; the warehouse clerk role is
	# not required to be a stock accountant in ERPNext.
	entry.insert(ignore_permissions=True)
	entry.submit()
	audit.record_audit(
		action="stock.material_received",
		entity_type="Stock Entry",
		entity_id=entry.name,
		diff={"item": item, "qty": float(quantity), "price": float(price), "supplier": supplier, "warehouse": target},
	)
	return {"receipt": entry.name, "material": material(item)}


def cancel_receipt(receipt: str) -> dict:
	_ensure_editor()
	row = frappe.db.get_value(
		"Stock Entry", receipt, ["company", "docstatus", "korkem_material_receipt"], as_dict=True
	)
	if not row or row.company != current_company() or not row.korkem_material_receipt:
		frappe.throw("Такого прихода нет.", frappe.DoesNotExistError)
	if row.docstatus != 1:
		frappe.throw("Этот приход уже отменён.")
	doc = frappe.get_doc("Stock Entry", receipt)
	doc.flags.ignore_permissions = True
	# ERPNext refuses when the stock has already been used — that refusal is
	# the right answer and is passed on as it is.
	doc.cancel()
	audit.record_audit(action="stock.receipt_cancelled", entity_type="Stock Entry", entity_id=receipt)
	return {"receipt": receipt, "status": "cancelled"}


def receipts(item: str | None = None, limit: int = 100) -> dict:
	_ensure_staff()
	company = current_company()
	filters = {"company": company, "korkem_material_receipt": 1}
	entries = frappe.get_all(
		"Stock Entry",
		filters=filters,
		fields=["name", "posting_date", "korkem_supplier", "docstatus", "owner"],
		order_by="posting_date desc, creation desc",
		limit_page_length=max(1, min(int(limit or 100), 500)),
	)
	if not entries:
		return {"receipts": []}
	detail_filters = {"parent": ["in", [e.name for e in entries]]}
	if item:
		detail_filters["item_code"] = item
	details = frappe.get_all(
		"Stock Entry Detail",
		filters=detail_filters,
		fields=["parent", "item_code", "item_name", "qty", "uom", "basic_rate", "amount"],
	)
	by_entry = {e.name: e for e in entries}
	allowed = price_visibility.can_see_prices()
	return {
		"receipts": [
			{
				"receipt": d.parent,
				"date": str(by_entry[d.parent].posting_date),
				"supplier": by_entry[d.parent].korkem_supplier,
				"item": d.item_code,
				"title": d.item_name,
				"qty": flt(d.qty),
				"unit": d.uom,
				"price_per_unit": price_visibility.money(d.basic_rate, allowed=allowed),
				"total": price_visibility.money(d.amount, allowed=allowed),
				"cancelled": by_entry[d.parent].docstatus == 2,
				"by": by_entry[d.parent].owner,
			}
			for d in sorted(details, key=lambda d: str(by_entry[d.parent].posting_date), reverse=True)
		]
	}
