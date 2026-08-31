# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""One-time company and manufacturing-master setup for KORKEM.

A fresh Frappe site has no Company, so ERPNext manufacturing doctypes (Work
Order in particular) have nothing valid to reference. This module provisions the
real KORKEM company plus the minimum manufacturing masters the Production Order
flow needs -- a finished facade Item, its raw materials, and a BOM.

Everything here is idempotent: safe to re-run on an existing site, and safe to
run as part of provisioning a new one.

Run with:
    bench --site <site> execute korkem_manufacturing.setup.provision
"""

import frappe

COMPANY = "KORKEM"
ABBR = "KRK"
CURRENCY = "KZT"
COUNTRY = "Kazakhstan"

# The facade the Sprint 1 slice manufactures, and what it's made of.
FINISHED_ITEM = "Kitchen Facade"
RAW_ITEMS = ("MDF Panel", "PVC Film")
ITEM_GROUP_FG = "Products"
ITEM_GROUP_RM = "Raw Material"


def provision():
	"""Provision company + manufacturing masters. Idempotent."""
	created = {}
	created["company"] = ensure_company()
	created["items"] = ensure_items()
	created["bom"] = ensure_bom()
	frappe.db.commit()
	return created


def ensure_company() -> str:
	"""Run ERPNext's setup wizard for the KORKEM company if it doesn't exist.

	setup_complete() is ERPNext's documented programmatic entry point (its own
	source comments it "Only for programmatical use") -- it installs country
	fixtures, the company with its chart of accounts, and the default warehouses
	that Work Order requires.
	"""
	if frappe.db.exists("Company", COMPANY):
		return COMPANY

	from erpnext.setup.setup_wizard.setup_wizard import setup_complete

	# Must be a frappe._dict: setup_complete -> setup_company -> install_company
	# reads args via attribute access (args.fy_start_date). Only setup_defaults
	# wraps it internally, so a plain dict raises AttributeError partway through.
	setup_complete(
		frappe._dict(
			{
				"currency": CURRENCY,
				"full_name": "KORKEM Administrator",
				"company_name": COMPANY,
				"company_abbr": ABBR,
				"industry": "Manufacturing",
				"country": COUNTRY,
				"fy_start_date": "2026-01-01",
				"fy_end_date": "2026-12-31",
				"language": "english",
				"company_tagline": "Furniture & door facade manufacturing",
				"email": "dev@korkem.local",
				"chart_of_accounts": "Standard",
			}
		)
	)
	ensure_desk_home_page()
	return COMPANY


def ensure_desk_home_page():
	"""Restore the desk home page default after running the setup wizard.

	frappe/desk/page/setup_wizard/setup_wizard.py wraps every stage in
	`except Exception: handle_setup_exception(...)` and does NOT re-raise, so a
	failure in any stage silently skips the final "Wrapping up" stage. That stage
	is the only caller of disable_future_access(), which sets this default to
	"workspace".

	When it is skipped, the default stays at the install-time value
	"setup-wizard" (set by frappe/utils/install.py) even though setup really did
	complete. That combination hangs the desk in an infinite reload loop: boot
	reports home_page="setup-wizard", pageview loads the setup wizard page, and
	its on_page_load sees frappe.boot.setup_complete is true and immediately
	redirects to /apps -> 301 -> /desk -> repeat.

	Resetting it here makes provisioning safe regardless of which stage failed.
	Frappe resolves "workspace" to the real "desktop" Page via the fallback in
	frappe/boot.py:add_home_page.
	"""
	if frappe.db.get_default("desktop:home_page") == "setup-wizard":
		frappe.db.set_default("desktop:home_page", "workspace")
		frappe.clear_cache()


def ensure_items() -> list[str]:
	"""Create the finished facade item and its raw materials."""
	items = []
	items.append(_ensure_item(FINISHED_ITEM, ITEM_GROUP_FG, is_purchase_item=0))
	for raw in RAW_ITEMS:
		items.append(_ensure_item(raw, ITEM_GROUP_RM, is_purchase_item=1))
	return items


def _ensure_item(item_code: str, item_group: str, is_purchase_item: int) -> str:
	if frappe.db.exists("Item", item_code):
		return item_code

	# Item Group is itself a master; fall back to "All Item Groups" rather than
	# failing if the expected group isn't part of this site's fixtures.
	if not frappe.db.exists("Item Group", item_group):
		item_group = "All Item Groups"

	item = frappe.get_doc(
		{
			"doctype": "Item",
			"item_code": item_code,
			"item_name": item_code,
			"item_group": item_group,
			"stock_uom": "Nos",
			"is_stock_item": 1,
			"is_purchase_item": is_purchase_item,
			"include_item_in_manufacturing": 1,
			"default_material_request_type": "Purchase" if is_purchase_item else "Manufacture",
		}
	)
	item.insert(ignore_permissions=True)
	return item.name


def ensure_bom() -> str:
	"""Create and submit the BOM for the finished facade.

	Work Order requires a submitted, active BOM -- a draft one is not selectable.
	"""
	existing = frappe.get_all(
		"BOM",
		filters={"item": FINISHED_ITEM, "company": COMPANY, "docstatus": 1, "is_active": 1},
		pluck="name",
		limit=1,
	)
	if existing:
		return existing[0]

	bom = frappe.get_doc(
		{
			"doctype": "BOM",
			"item": FINISHED_ITEM,
			"company": COMPANY,
			"currency": CURRENCY,
			"quantity": 1,
			"is_active": 1,
			"is_default": 1,
			"with_operations": 0,
			"items": [
				{"item_code": raw, "qty": 1, "uom": "Nos", "rate": 1000} for raw in RAW_ITEMS
			],
		}
	)
	bom.insert(ignore_permissions=True)
	bom.submit()
	return bom.name


def get_default_bom() -> str | None:
	"""Return the active BOM for the facade item, if provisioned."""
	return frappe.db.get_value(
		"BOM",
		{"item": FINISHED_ITEM, "company": COMPANY, "docstatus": 1, "is_active": 1},
		"name",
	)
