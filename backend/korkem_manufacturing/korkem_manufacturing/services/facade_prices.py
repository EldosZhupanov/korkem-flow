# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The facade price matrix: milling × finish, per m², per company.

**Who may change it:** the administrator and the people who take orders
(`EDITORS`). Prices are money, so nobody on the shop floor reads them either —
`Facade Price` grants them nothing at all.

**Starting prices** come from the factory's own price list, as given when this
feature was asked for (2026-10-26). They are written once per company and never
again: a price somebody edited is theirs, and a migration that "restores
defaults" over it would silently reprice every new order.

A missing cell is a real answer. Квадро and Тегіс have no rough («Черновая»)
price because the factory does not sell them that way; a quote for one is
refused rather than priced at something invented.
"""

from __future__ import annotations

from decimal import Decimal

import frappe
from frappe.utils import flt

from korkem_manufacturing.services import audit
from korkem_manufacturing.services.scope import current_company

EDITORS = frozenset({"System Manager", "Sales Manager", "Sales User"})

PVC, ENAMEL, ROUGH = "ПВХ плёнка", "Эмаль", "Черновая"
FINISHES = (PVC, ENAMEL, ROUGH)

#: ₸ per m², from the factory's price list.
STARTING_PRICES: dict[tuple[str, str], int] = {
	("Квадро", PVC): 21_000,
	("Квадро", ENAMEL): 35_000,
	("Классика", PVC): 19_500,
	("Классика", ENAMEL): 33_000,
	("Классика", ROUGH): 9_000,
	("Рифлёный", PVC): 19_500,
	("Рифлёный", ENAMEL): 32_000,
	("Рифлёный", ROUGH): 9_500,
	("Тегіс", PVC): 17_000,
	("Тегіс", ENAMEL): 29_000,
}


def seed_company(company: str) -> int:
	"""Write the starting prices a company does not have yet. Returns how many."""
	written = 0
	for (milling, finish), price in STARTING_PRICES.items():
		if frappe.db.exists("Facade Price", {"company": company, "milling": milling, "finish": finish}):
			continue
		doc = frappe.get_doc(
			{
				"doctype": "Facade Price",
				"company": company,
				"milling": milling,
				"finish": finish,
				"price_per_m2": price,
				"enabled": 1,
			}
		)
		doc.flags.korkem_seed = True
		doc.insert(ignore_permissions=True)
		written += 1
	return written


def seed_all_companies() -> None:
	for company in frappe.get_all("Company", pluck="name"):
		seed_company(company)


def on_company_created(doc, method=None) -> None:
	"""doc_events hook: a new company starts with the factory's price list."""
	seed_company(doc.name)


def can_edit(user: str | None = None) -> bool:
	return bool(EDITORS.intersection(frappe.get_roles(user)))


def ensure_editor() -> None:
	if not can_edit():
		frappe.throw("Цены фасадов видят администратор и менеджеры по заказам.", frappe.PermissionError)


def table() -> dict:
	"""The whole matrix for this company, for the settings screen."""
	ensure_editor()
	company = current_company()
	rows = frappe.get_all(
		"Facade Price",
		filters={"company": company},
		fields=["name", "milling", "finish", "price_per_m2", "enabled"],
		order_by="milling asc, finish asc",
	)
	return {
		"company": company,
		"finishes": list(FINISHES),
		"prices": [
			{
				"milling": row.milling,
				"finish": row.finish,
				"price_per_m2": flt(row.price_per_m2),
				"enabled": bool(row.enabled),
			}
			for row in rows
		],
		"can_edit": can_edit(),
	}


def set_price(milling: str, finish: str, price_per_m2, enabled: bool | int | str = True) -> dict:
	"""Change one cell, or add a new milling to the matrix."""
	ensure_editor()
	company = current_company()
	milling = (milling or "").strip()
	if finish not in FINISHES:
		frappe.throw(f"Отделка должна быть одной из: {', '.join(FINISHES)}.")
	try:
		price = Decimal(str(price_per_m2))
	except Exception:
		frappe.throw("Цена должна быть числом.")
	enabled = bool(int(enabled)) if isinstance(enabled, str) else bool(enabled)

	name = frappe.db.get_value(
		"Facade Price", {"company": company, "milling": milling, "finish": finish}, "name"
	)
	doc = frappe.get_doc("Facade Price", name) if name else frappe.new_doc("Facade Price")
	before = {"price_per_m2": flt(doc.price_per_m2), "enabled": bool(doc.enabled)} if name else None
	doc.update(
		{
			"company": company,
			"milling": milling,
			"finish": finish,
			"price_per_m2": float(price),
			"enabled": 1 if enabled else 0,
		}
	)
	doc.save()

	audit.record_audit(
		action="settings.facade_price",
		entity_type="Facade Price",
		entity_id=doc.name,
		diff={"cell": f"{milling} / {finish}", "before": before, "after": {"price_per_m2": float(price), "enabled": enabled}},
	)
	return table()


def price_for(milling: str, finish: str, company: str | None = None) -> Decimal | None:
	"""₸ per m² for one cell, or None when the factory does not sell it."""
	value = frappe.db.get_value(
		"Facade Price",
		{"company": company or current_company(), "milling": milling, "finish": finish, "enabled": 1},
		"price_per_m2",
	)
	return Decimal(str(value)) if value else None
