# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""A second company, built rather than found, so isolation can be tested.

## The defect this replaces

Eight tests assert the most important promise the system makes: one company
must never see, touch or advance another company's work. Every one of them
began by *looking* for somebody else's document:

    foreign = frappe.db.get_value("Work Order", {"company": ["!=", "KORKEM"]})
    if not foreign:
        self.skipTest("no other company's work order on this bench")

On the bench this was written on, that search succeeded — twenty-two `_Test *`
companies had accumulated there from ERPNext's own suites, along with their
items, customers and orders. So the tests ran, passed, and looked like proof.

On a site built from an empty volume — which is what a furniture factory
actually installs — KORKEM is the only company there is. The search returns
nothing and all eight tests quietly turn themselves off. The suite still prints
OK. The security boundary is simply not tested, on precisely the shape of site
where it matters, and nothing in the output says so.

One test in the family did not skip but crashed (`IndexError`, a `[0]` on the
empty list), and that is the only reason any of this was noticed. A test that
silently disables itself is worse than one that fails: a failure is a message.

## What this does instead

A test that needs a second company creates one, so the assertion runs
everywhere or the fixture's own construction fails loudly.

`ensure()` builds the chain a foreign work order needs — company, warehouses,
item group, item, customer, BOM, sales order, work order — and is idempotent,
so the second caller pays nothing. Inserting a `Company` is enough to get its
chart of accounts and its five default warehouses; ERPNext creates both in the
doctype's own `on_update`, so they are not repeated here.

Deliberately *not* built: routing and operations. Every consumer of this
fixture asserts a **refusal** — that the foreign document cannot be found or
advanced — so the job never runs a stage, and giving it stages would cost the
suite time to build something no test looks at.
"""

from __future__ import annotations

import frappe
from frappe.utils import add_days, nowdate

from korkem_ai.korkem_ai import environment

COMPANY = "KORKEM Elsewhere"
ABBR = "KEL"
STORES = f"Stores - {ABBR}"
WIP = f"Work In Progress - {ABBR}"
FINISHED = f"Finished Goods - {ABBR}"
ITEM_GROUP = "KORKEM Foreign"
PRODUCT = "KORKEM-FOREIGN-PRODUCT"
MATERIAL = "KORKEM-FOREIGN-MATERIAL"
CUSTOMER = "KORKEM Foreign Customer"


def ensure() -> dict[str, str]:
	"""Everything a cross-company test needs, created once.

	Returns names, not documents: consumers pass them straight into an API call
	and never edit them.
	"""
	environment.require_non_production("Building the foreign-company test fixture")

	company = _company()
	_item_group()
	material = _item(MATERIAL, is_stock=True)
	product = _item(PRODUCT, is_stock=True)
	customer = _customer()
	bom = _bom(product, material)
	sales_order = _sales_order(customer, product)
	work_order = _work_order(product, bom, sales_order)

	return {
		"company": company,
		"customer": customer,
		"product": product,
		"material": material,
		"bom": bom,
		"sales_order": sales_order,
		"work_order": work_order,
		"stores": STORES,
	}


def _company() -> str:
	if frappe.db.exists("Company", COMPANY):
		return COMPANY

	# Currency and country are copied from KORKEM rather than hard-coded: a
	# `Sales Order` whose company posts in a different currency needs a
	# conversion rate, and this fixture has no opinion about exchange rates.
	frappe.get_doc(
		{
			"doctype": "Company",
			"company_name": COMPANY,
			"abbr": ABBR,
			"default_currency": frappe.db.get_value("Company", "KORKEM", "default_currency")
			or "KZT",
			"country": frappe.db.get_value("Company", "KORKEM", "country") or "Kazakhstan",
		}
	).insert(ignore_permissions=True)
	return COMPANY


def _item_group() -> str:
	if not frappe.db.exists("Item Group", ITEM_GROUP):
		frappe.get_doc(
			{
				"doctype": "Item Group",
				"item_group_name": ITEM_GROUP,
				"parent_item_group": "All Item Groups",
				"is_group": 0,
			}
		).insert(ignore_permissions=True)
	return ITEM_GROUP


def _item(code: str, *, is_stock: bool) -> str:
	if frappe.db.exists("Item", code):
		return code

	frappe.get_doc(
		{
			"doctype": "Item",
			"item_code": code,
			"item_name": code,
			"item_group": ITEM_GROUP,
			"stock_uom": "Nos",
			"is_stock_item": 1 if is_stock else 0,
			"description": f"Foreign-company fixture — {code}",
			"item_defaults": [{"company": COMPANY, "default_warehouse": STORES}],
		}
	).insert(ignore_permissions=True)
	return code


def _customer() -> str:
	if not frappe.db.exists("Customer", CUSTOMER):
		frappe.get_doc(
			{
				"doctype": "Customer",
				"customer_name": CUSTOMER,
				"customer_type": "Company",
			}
		).insert(ignore_permissions=True)
	return CUSTOMER


def _bom(product: str, material: str) -> str:
	existing = frappe.get_all(
		"BOM", filters={"item": product, "company": COMPANY, "docstatus": 1}, pluck="name"
	)
	if existing:
		return existing[0]

	bom = frappe.get_doc(
		{
			"doctype": "BOM",
			"item": product,
			"company": COMPANY,
			"quantity": 1,
			"is_active": 1,
			"is_default": 1,
			"items": [
				{"item_code": material, "qty": 2, "uom": "Nos", "rate": 1000, "source_warehouse": STORES}
			],
		}
	)
	bom.insert(ignore_permissions=True)
	bom.submit()
	return bom.name


def _sales_order(customer: str, product: str) -> str:
	existing = frappe.get_all(
		"Sales Order", filters={"company": COMPANY, "docstatus": 1}, pluck="name"
	)
	if existing:
		return existing[0]

	# Back-dated wholly. ERPNext refuses a delivery date before the order date,
	# and an order that is overdue — which is what makes it loud enough for a
	# scope test to catch if the scope ever leaks — was placed a while ago.
	order = frappe.get_doc(
		{
			"doctype": "Sales Order",
			"company": COMPANY,
			"customer": customer,
			"transaction_date": add_days(nowdate(), -12),
			"delivery_date": add_days(nowdate(), -5),
			"currency": frappe.db.get_value("Company", COMPANY, "default_currency"),
			"conversion_rate": 1,
			"items": [
				{
					"item_code": product,
					"qty": 5,
					"rate": 100,
					"warehouse": FINISHED,
					"delivery_date": add_days(nowdate(), -5),
				}
			],
		}
	)
	order.insert(ignore_permissions=True)
	order.submit()
	return order.name


def _work_order(product: str, bom: str, sales_order: str) -> str:
	existing = frappe.get_all(
		"Work Order", filters={"company": COMPANY, "docstatus": 1}, pluck="name"
	)
	if existing:
		return existing[0]

	order = frappe.get_doc(
		{
			"doctype": "Work Order",
			"production_item": product,
			"bom_no": bom,
			"company": COMPANY,
			"qty": 5,
			"sales_order": sales_order,
			"wip_warehouse": WIP,
			"fg_warehouse": FINISHED,
			"source_warehouse": STORES,
			"planned_start_date": nowdate(),
		}
	)
	order.insert(ignore_permissions=True)
	order.submit()
	return order.name


def remove() -> None:
	"""Take the whole chain back down, newest link first.

	Needed because one consumer builds the fixture in `setUpClass` and commits
	it — data committed outside a test's transaction is not rolled back with
	the test, and would be left on the bench for every module that runs after.
	The order below is the dependency order reversed; anything else trips
	ERPNext's link validation.
	"""
	environment.require_non_production("Removing the foreign-company test fixture")

	for doctype in ("Work Order", "Sales Order", "BOM"):
		for name in frappe.get_all(doctype, filters={"company": COMPANY}, pluck="name"):
			doc = frappe.get_doc(doctype, name)
			if doc.docstatus == 1:
				doc.cancel()
			frappe.delete_doc(doctype, name, force=True, ignore_permissions=True)

	for doctype, name in (
		("Item", PRODUCT),
		("Item", MATERIAL),
		("Customer", CUSTOMER),
		("Item Group", ITEM_GROUP),
		("Company", COMPANY),
	):
		if frappe.db.exists(doctype, name):
			frappe.delete_doc(doctype, name, force=True, ignore_permissions=True)
