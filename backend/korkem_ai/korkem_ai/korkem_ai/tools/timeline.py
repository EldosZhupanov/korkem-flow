# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""One customer, end to end — «покажи всё по Мебель Астана».

## Why this is one tool and not seven calls

The chain is CRM Deal → Sales Order → Work Order → operations → shortage →
Material Request → Purchase Order → Receipt → Delivery Note. A model could call
seven tools and staple the answers together, and the joins would then depend on
it noticing that `MAT-MR-2026-00001` belongs to `SAL-ORD-2026-00001` rather than
to the other order on screen. The links are relational and they are traversed
here, in one pass, under the caller's own permissions and company scope.

## Three states, not two

Every section reports one of:

* **present** — the document exists and is genuinely linked
* **`none`** — no such document exists yet
* **`no_access`** — the user is not allowed to look

The third is the one worth having. A production planner on this bench holds no
CRM role at all, so «нет сделки» would be a lie: there may be a deal and they
cannot see it. Saying "you do not have access to the CRM" is the true answer,
and it is a different sentence.

## Links are relational, never by name

Customers are matched by their ERPNext `Customer` record, and everything after
that hangs off document references — `Sales Order.customer`,
`Work Order.sales_order`, `Material Request Item.sales_order`,
`Purchase Order Item.material_request`, `Work Order.originating_deal`,
`Customer.crm_deal`. Nothing is joined because two names look alike. On this
bench that matters concretely: there are 2094 CRM deals and not one of them
belongs to a customer this factory produces for, so a name-similarity join
would invent a relationship that does not exist.
"""

from __future__ import annotations

import frappe
from frappe.utils import flt, getdate, nowdate

from korkem_ai.korkem_ai.tools import scope
from korkem_ai.korkem_ai.tools.registry import Risk, ToolSpec, register
from korkem_ai.korkem_ai.tools.scope import scoped

#: Sales Order statuses that no longer represent live work.
CLOSED = ("Completed", "Closed", "Cancelled")


def _readable(doctype: str) -> bool:
	return bool(frappe.has_permission(doctype, "read"))


def _absent(doctype: str, note: str) -> dict:
	"""Nothing here — and whether that is a fact or a blind spot."""
	if not _readable(doctype):
		return {
			"status": "no_access",
			"note": f"you do not have permission to read {doctype}",
		}
	return {"status": "none", "note": note}


def _find_customer(name: str) -> str:
	"""The ERPNext customer record, by name or by a contains search.

	`Customer` has no company field — it is a shared master — so this is not
	company-scoped. Everything hanging off it is.
	"""
	if frappe.db.exists("Customer", name):
		return name

	matches = frappe.get_list(
		"Customer",
		filters={"customer_name": ["like", f"%{name.strip()}%"]},
		fields=["name"],
		limit_page_length=5,
	)
	if not matches:
		frappe.throw(f"No customer matching '{name}'.")
	if len(matches) > 1:
		names = ", ".join(row["name"] for row in matches)
		frappe.throw(f"Several customers match '{name}': {names}. Which one?")
	return matches[0]["name"]


def _crm_section(customer: str) -> dict:
	"""The CRM side, traversed by link and never by name."""
	if not _readable("CRM Deal"):
		return {
			"status": "no_access",
			"note": "you do not have permission to read CRM deals",
		}

	# `Customer.crm_deal` is ERPNext's own pointer at the deal a customer came
	# from. It is the only explicit link between the two systems on this bench.
	deal = frappe.db.get_value("Customer", customer, "crm_deal")
	if not deal or not frappe.db.exists("CRM Deal", deal):
		return {
			"status": "none",
			"note": (
				"this customer is not linked to a CRM deal — the sale was not "
				"recorded through the CRM, or the link was never set"
			),
			"linked_by": None,
		}

	row = frappe.db.get_value(
		"CRM Deal", deal, ["name", "organization", "status", "deal_owner"], as_dict=True
	)
	return {"status": "present", "linked_by": "Customer.crm_deal", **row}


def _sales_section(customer: str) -> tuple[list[dict], list[str]]:
	if not _readable("Sales Order"):
		return [], []

	orders = frappe.get_list(
		"Sales Order",
		filters=scoped({"customer": customer, "docstatus": 1}),
		fields=["name", "status", "transaction_date", "delivery_date", "grand_total", "currency", "per_delivered"],
		order_by="delivery_date asc",
		limit_page_length=0,
	)
	today = getdate(nowdate())
	reported = []
	for order in orders:
		due = getdate(order["delivery_date"]) if order["delivery_date"] else None
		items = frappe.get_all(
			"Sales Order Item",
			filters={"parent": order["name"]},
			fields=["item_code", "item_name", "qty", "uom", "delivered_qty"],
		)
		reported.append(
			{
				"sales_order": order["name"],
				"status": order["status"],
				"ordered_on": str(order["transaction_date"]),
				"delivery_date": str(due) if due else None,
				"days_to_delivery": (due - today).days if due else None,
				"overdue": bool(due and due < today and flt(order["per_delivered"]) < 100),
				"value": flt(order["grand_total"]),
				"currency": order["currency"],
				"delivered_percent": flt(order["per_delivered"]),
				"items": [
					{
						"item_code": row["item_code"],
						"item_name": row["item_name"],
						"qty": flt(row["qty"]),
						"uom": row["uom"],
						"delivered_qty": flt(row["delivered_qty"]),
					}
					for row in items
				],
			}
		)
	return reported, [row["sales_order"] for row in reported]


def _production_section(order_names: list[str]) -> dict:
	from korkem_ai.korkem_ai.tools.production import work_order_stages

	if not _readable("Work Order"):
		return {"status": "no_access", "note": "you do not have permission to read work orders"}
	if not order_names:
		return {"status": "none", "note": "there are no sales orders to produce"}

	jobs = frappe.get_list(
		"Work Order",
		filters=scoped({"sales_order": ["in", order_names], "docstatus": ["<", 2]}),
		fields=["name", "sales_order", "production_item", "qty", "produced_qty", "status", "originating_deal"],
		order_by="creation asc",
		limit_page_length=0,
	)
	if not jobs:
		return {
			"status": "none",
			"note": "nothing has been planned into production for these orders yet",
		}

	reported = []
	for job in jobs:
		stages = work_order_stages(job["name"])
		reported.append(
			{
				"work_order": job["name"],
				"sales_order": job["sales_order"],
				"item_code": job["production_item"],
				"qty": flt(job["qty"]),
				"produced_qty": flt(job["produced_qty"]),
				"remaining_qty": round(flt(job["qty"]) - flt(job["produced_qty"]), 3),
				"status": job["status"],
				# Used where it is set. It is a real link and not a guess — but
				# on this bench it is populated on one work order out of three.
				"originating_deal": job["originating_deal"],
				"current_operation": stages["current_operation"],
				"current_workstation": stages["current_workstation"],
				"next_operation": stages["next_operation"],
				"operations": stages["operations"],
			}
		)
	return {"status": "present", "work_orders": reported}


def _materials_section(order_names: list[str]) -> dict:
	from korkem_ai.korkem_ai.tools.procurement import material_shortage

	if not (_readable("Bin") and _readable("BOM")):
		return {"status": "no_access", "note": "you do not have permission to read stock or bills of material"}
	if not order_names:
		return {"status": "none", "note": "there are no orders to need material"}

	short = []
	for name in order_names:
		for row in material_shortage(name)["not_on_the_shelf"]:
			short.append(
				{
					"sales_order": name,
					"item_code": row["item_code"],
					"required_qty": row["required_qty"],
					"available_qty": row["available_qty"],
					"short_by": row["physical_shortage_qty"],
					"uom": row["uom"],
				}
			)

	if not short:
		return {"status": "present", "shortages": [], "note": "everything needed is on the shelf"}
	return {"status": "present", "shortages": short}


def _procurement_section(order_names: list[str]) -> dict:
	if not _readable("Material Request"):
		return {"status": "no_access", "note": "you do not have permission to read purchase requests"}
	if not order_names:
		return {"status": "none", "note": "there are no orders to buy for"}

	lines = frappe.get_all(
		"Material Request Item",
		filters={"sales_order": ["in", order_names], "docstatus": ["<", 2]},
		fields=["parent", "item_code", "qty", "uom", "ordered_qty", "received_qty", "sales_order"],
	)
	if not lines:
		return {
			"status": "none",
			"note": "nothing has been requested for purchase against these orders",
		}

	requests = {}
	for row in lines:
		entry = requests.setdefault(
			row["parent"],
			{
				"material_request": row["parent"],
				"status": frappe.db.get_value("Material Request", row["parent"], "status"),
				"sales_order": row["sales_order"],
				"items": [],
				"purchase_orders": [],
				"receipts": [],
			},
		)
		entry["items"].append(
			{
				"item_code": row["item_code"],
				"qty": flt(row["qty"]),
				"uom": row["uom"],
				"ordered_qty": flt(row["ordered_qty"]),
				"received_qty": flt(row["received_qty"]),
			}
		)

	if _readable("Purchase Order"):
		for row in frappe.get_all(
			"Purchase Order Item",
			filters={"material_request": ["in", list(requests)], "docstatus": ["<", 2]},
			fields=["parent", "material_request", "item_code", "qty", "received_qty"],
		):
			requests[row["material_request"]]["purchase_orders"].append(
				{
					"purchase_order": row["parent"],
					"supplier": frappe.db.get_value("Purchase Order", row["parent"], "supplier"),
					"item_code": row["item_code"],
					"ordered_qty": flt(row["qty"]),
					"received_qty": flt(row["received_qty"]),
					"expected_on": str(
						frappe.db.get_value("Purchase Order", row["parent"], "schedule_date") or ""
					)
					or None,
				}
			)

	if _readable("Purchase Receipt"):
		for row in frappe.get_all(
			"Purchase Receipt Item",
			filters={"material_request": ["in", list(requests)], "docstatus": 1},
			fields=["parent", "material_request", "item_code", "received_qty"],
		):
			requests[row["material_request"]]["receipts"].append(
				{
					"purchase_receipt": row["parent"],
					"item_code": row["item_code"],
					"received_qty": flt(row["received_qty"]),
				}
			)

	return {"status": "present", "requests": sorted(requests.values(), key=lambda r: r["material_request"])}


def _delivery_section(order_names: list[str]) -> dict:
	if not _readable("Delivery Note"):
		return {"status": "no_access", "note": "you do not have permission to read delivery notes"}
	if not order_names:
		return {"status": "none", "note": "there are no orders to deliver"}

	rows = frappe.get_all(
		"Delivery Note Item",
		filters={"against_sales_order": ["in", order_names], "docstatus": 1},
		fields=["parent", "against_sales_order", "item_code", "qty"],
	)
	if not rows:
		return {"status": "none", "note": "nothing has been shipped to this customer yet"}

	return {
		"status": "present",
		"deliveries": [
			{
				"delivery_note": row["parent"],
				"sales_order": row["against_sales_order"],
				"item_code": row["item_code"],
				"qty": flt(row["qty"]),
			}
			for row in rows
		],
	}


def customer_timeline(customer: str | None = None):
	"""Everything this customer has, in the order it happened.

	Sections that have nothing say so, and sections the caller cannot see say
	*that* instead — an empty CRM section and an invisible one are different
	answers, and only one of them is "there is no deal".
	"""
	# A customer asking about "their" timeline gets their own, whatever they
	# named. The argument narrows within a scope; it never chooses one.
	pinned = scope.customer_scope()
	if not pinned and not customer:
		frappe.throw("Name the customer whose history you want.")
	name = pinned if pinned else _find_customer(customer)
	orders, order_names = _sales_section(name)

	crm = _crm_section(name)
	production = _production_section(order_names)
	materials = _materials_section(order_names)
	procurement = _procurement_section(order_names)
	delivery = _delivery_section(order_names)

	# Only real problems, each traceable to a document.
	issues = []
	for order in orders:
		if order["overdue"]:
			issues.append(
				{
					"kind": "overdue",
					"sales_order": order["sales_order"],
					"detail": f"delivery date {order['delivery_date']} has passed",
				}
			)
	for row in materials.get("shortages", []):
		issues.append(
			{
				"kind": "material_short",
				"sales_order": row["sales_order"],
				"detail": f"{row['item_code']} short {row['short_by']} {row['uom']} on the shelf",
			}
		)
	for request in procurement.get("requests", []):
		if not request["purchase_orders"]:
			issues.append(
				{
					"kind": "not_ordered",
					"sales_order": request["sales_order"],
					"detail": f"{request['material_request']} has no purchase order yet",
				}
			)

	return {
		"customer": name,
		"as_of": nowdate(),
		"crm": crm,
		"sales": {"status": "present", "orders": orders}
		if orders
		else _absent("Sales Order", "this customer has no submitted orders"),
		"production": production,
		"materials": materials,
		"procurement": procurement,
		"delivery": delivery,
		"issues": issues,
	}


register(
	ToolSpec(
		name="crm.customer_timeline",
		description=(
			"Everything about one customer in one call: their CRM deal, orders, "
			"production progress, material shortages, purchasing, receiving and "
			"deliveries, with the real links between them. Use for «покажи всё "
			"по клиенту X», «что происходит с заказом X», «есть ли проблемы у "
			"X», «сколько уже изготовлено». A section that says none has no such "
			"document; a section that says no_access means the user cannot see "
			"it — do not report the second as the first."
		),
		input_schema={
			"type": "object",
			"properties": {
				"customer": {"type": "string", "description": "Customer name, e.g. Мебель Астана"},
			},
			"required": [],
		},
		handler=customer_timeline,
		risk=Risk.READ,
		doctypes=("Customer",),
		audit_category="crm",
		timeout=60,
	)
)
