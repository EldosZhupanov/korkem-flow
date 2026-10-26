# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Who may see money: client prices, order totals, payments, supplier prices.

**The rule.** People whose job is money — the owner, sales, accounting,
purchasing, and a customer looking at their own order — always see it. Everyone
else (the shop floor, the warehouse, drivers, designers) sees it only if the
company's administrator has switched it on. Off by default: a cutter has no
need of a client's price, and a factory's margins are not shop-floor reading.

**Where it is enforced — on the server, twice.**

1. *KORKEM's own reads* (`api.queries`, order state, attention, AI tools) read
   the database directly and therefore pass through `redact()` here.
2. *Frappe's generic REST* (`/api/resource/Sales Order/...`) is closed at the
   field level: the money fields of the documents below are moved to
   permission level 1 (`apply_field_levels`), which Frappe strips from every
   response for a role without a level-1 read. Switching the setting on grants
   that read to the floor roles; switching it off takes it back.

**Known limit of layer 2.** Two child tables are shared with documents the
floor never opens — the payment schedule (`Payment Schedule`) and taxes
(`Sales/Purchase Taxes and Charges`) also sit under invoices and quotations.
Moving their fields to level 1 would take them from accountants on every one of
those documents unless each got its own Custom DocPerm, which freezes ERPNext's
standard permissions there. So over raw REST a worker can still read a
schedule's instalments. KORKEM's own endpoints — the only ones the app calls —
never send them. Also note Frappe returns a hidden currency field over REST as
0.0, not as an absent key; the real figure still never leaves the server.

Hiding a number in the app is not on this list on purpose. A screen that does
not draw a price still received it, and anybody with the app's session can
ask the server directly.
"""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import audit
from korkem_manufacturing.services.scope import current_company

#: Roles that always see money. Everything not listed follows the setting.
PRICE_ROLES = frozenset(
	{
		"System Manager",
		"Sales Manager",
		"Sales User",
		"Accounts Manager",
		"Accounts User",
		"Purchase Manager",
		"Purchase User",
		"Korkem Customer",
	}
)

#: Roles whose access to money the administrator's switch decides. These are
#: the roles KORKEM itself gives read on orders and deliveries (grant_order_read)
#: plus the warehouse, which reads purchase orders when receiving goods.
FLOOR_ROLES = (
	"Manufacturing User",
	"Manufacturing Manager",
	"Delivery User",
	"Delivery Manager",
	"Stock User",
	"Stock Manager",
	"Item Manager",
)

#: Money fields per doctype. Only fields present in the installed ERPNext are
#: touched, so a field that does not exist in this version is simply skipped.
MONEY_FIELDS: dict[str, tuple[str, ...]] = {
	"Sales Order": (
		"total", "net_total", "base_total", "base_net_total",
		"grand_total", "base_grand_total", "rounded_total", "base_rounded_total",
		"rounding_adjustment", "base_rounding_adjustment",
		"total_taxes_and_charges", "base_total_taxes_and_charges",
		"discount_amount", "base_discount_amount", "additional_discount_percentage",
		"advance_paid", "in_words", "base_in_words",
		"amount_eligible_for_commission", "commission_rate", "total_commission",
	),
	"Sales Order Item": (
		"rate", "amount", "net_rate", "net_amount", "base_rate", "base_amount",
		"base_net_rate", "base_net_amount", "price_list_rate", "base_price_list_rate",
		"discount_percentage", "discount_amount", "margin_rate_or_amount",
		"rate_with_margin", "base_rate_with_margin", "valuation_rate", "gross_profit",
		"stock_uom_rate",
	),
	"Delivery Note": (
		"total", "net_total", "base_total", "base_net_total",
		"grand_total", "base_grand_total", "rounded_total", "base_rounded_total",
		"total_taxes_and_charges", "base_total_taxes_and_charges",
		"discount_amount", "base_discount_amount", "in_words", "base_in_words",
	),
	"Delivery Note Item": (
		"rate", "amount", "net_rate", "net_amount", "base_rate", "base_amount",
		"base_net_rate", "base_net_amount", "price_list_rate", "base_price_list_rate",
		"discount_percentage", "discount_amount", "incoming_rate", "stock_uom_rate",
	),
	"Purchase Order": (
		"total", "net_total", "base_total", "base_net_total",
		"grand_total", "base_grand_total", "rounded_total", "base_rounded_total",
		"total_taxes_and_charges", "base_total_taxes_and_charges",
		"discount_amount", "base_discount_amount", "in_words", "base_in_words",
		"advance_paid",
	),
	"Purchase Order Item": (
		"rate", "amount", "net_rate", "net_amount", "base_rate", "base_amount",
		"base_net_rate", "base_net_amount", "price_list_rate", "base_price_list_rate",
		"discount_percentage", "discount_amount", "last_purchase_rate", "stock_uom_rate",
	),
}

#: Parent doctypes whose level-1 read the switch grants or withdraws.
_PARENTS = ("Sales Order", "Delivery Note", "Purchase Order")

def _setting_key(company: str) -> str:
	return f"korkem_floor_sees_prices::{company}"


def floor_sees_prices(company: str | None = None) -> bool:
	"""The administrator's switch for this company. Off unless switched on."""
	try:
		company = company or current_company()
	except Exception:
		return False
	return frappe.db.get_default(_setting_key(company)) == "1"


def can_see_prices(user: str | None = None, company: str | None = None) -> bool:
	"""Whether `user` may be shown money, decided here and nowhere else."""
	user = user or frappe.session.user
	if user == "Administrator":
		return True
	if PRICE_ROLES.intersection(frappe.get_roles(user)):
		return True
	return floor_sees_prices(company)


def redact(data, keys, *, allowed: bool | None = None):
	"""Return `data` with the money under `keys` replaced by None, if hidden.

	`data` is one dict or a list of dicts; only their own keys are touched, and
	a listed key is *set* to None even where it was absent — Frappe already drops
	a permission-level-1 field from `get_list` for such a caller, and a client
	must still be able to tell "hidden" (None) from "free" (0). Callers pass the
	keys they actually emit; there is deliberately no default, because a generic
	key like `total` also means "how many rows" in a paginated response.
	"""
	if allowed is None:
		allowed = can_see_prices()
	if allowed:
		return data
	if isinstance(data, list):
		return [redact(item, keys, allowed=False) for item in data]
	if isinstance(data, dict):
		return {**data, **{key: None for key in keys}}
	return data


def money(value, *, allowed: bool):
	"""One amount for a response: the number, or None for a caller who may not see it."""
	from frappe.utils import flt

	return flt(value) if allowed else None


def set_floor_sees_prices(enabled: bool) -> dict:
	"""The administrator turns the shop floor's view of money on or off."""
	frappe.only_for("System Manager")
	company = current_company()
	enabled = bool(int(enabled)) if isinstance(enabled, str) else bool(enabled)
	before = floor_sees_prices(company)

	frappe.db.set_default(_setting_key(company), "1" if enabled else "0")
	# Permission levels are per doctype, not per company, so Frappe's REST layer
	# can only follow the switch site-wide: open while *any* company has it on.
	# KORKEM's own endpoints still answer per company (`can_see_prices`).
	_grant_level_one_read(_any_company_shows_prices())

	audit.record_audit(
		action="settings.floor_sees_prices",
		entity_type="Company",
		entity_id=company,
		diff={"before": before, "after": enabled},
	)
	return status()


def _any_company_shows_prices() -> bool:
	return any(floor_sees_prices(name) for name in frappe.get_all("Company", pluck="name"))


def status() -> dict:
	return {
		"floor_sees_prices": floor_sees_prices(),
		"you_see_prices": can_see_prices(),
		"can_change": "System Manager" in frappe.get_roles(),
	}


def apply_field_levels() -> None:
	"""Move the money fields of the documents above to permission level 1.

	Idempotent. Done with Property Setters, so ERPNext itself is never edited,
	and roles that see money get the level-1 read they need first — otherwise
	Sales would lose the totals in their own forms.
	"""
	from frappe.custom.doctype.property_setter.property_setter import make_property_setter

	for parent in _PARENTS:
		_ensure_level_one_read(parent, PRICE_ROLES)

	for doctype, fields in MONEY_FIELDS.items():
		meta = frappe.get_meta(doctype)
		for fieldname in fields:
			field = meta.get_field(fieldname)
			if not field or field.permlevel == 1:
				continue
			make_property_setter(
				doctype, fieldname, "permlevel", 1, "Int", validate_fields_for_doctype=False
			)
		frappe.clear_cache(doctype=doctype)


def _ensure_level_one_read(doctype: str, roles) -> None:
	from frappe.permissions import add_permission, setup_custom_perms

	setup_custom_perms(doctype)
	for role in roles:
		if not frappe.db.exists("Role", role):
			continue
		# Only for roles that can read the document at all; a level-1 read on a
		# document you cannot open grants nothing and only confuses the table.
		if not frappe.db.exists("Custom DocPerm", {"parent": doctype, "role": role, "permlevel": 0, "read": 1}):
			continue
		if frappe.db.exists("Custom DocPerm", {"parent": doctype, "role": role, "permlevel": 1}):
			continue
		add_permission(doctype, role, 1, "read")
	frappe.clear_cache(doctype=doctype)


def _grant_level_one_read(enabled: bool) -> None:
	for parent in _PARENTS:
		if enabled:
			_ensure_level_one_read(parent, FLOOR_ROLES)
			continue
		for name in frappe.get_all(
			"Custom DocPerm",
			filters={"parent": parent, "permlevel": 1, "role": ["in", FLOOR_ROLES]},
			pluck="name",
		):
			frappe.delete_doc("Custom DocPerm", name, ignore_permissions=True, force=True)
		frappe.clear_cache(doctype=parent)
