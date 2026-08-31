# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Production Order creation and shop-floor task assignment.

`domain_model.md` names Production Order the platform's core entity, realised as
ERPNext's Work Order (ADR-0001: extend ERPNext, don't rebuild manufacturing).
This module turns an approved CRM Deal into a real Work Order and attaches the
shop-floor task a worker will complete.
"""

import frappe
from frappe.utils import add_days, nowdate

from korkem_manufacturing import setup

# ADR-0023: Task attaches to any doctype via Frappe's native polymorphic
# reference pair, so CRM Task works on a Work Order with no schema change --
# verified against crm_task.json, whose reference_doctype is an unrestricted Link.
TASK_DOCTYPE = "CRM Task"


def create_production_order(deal: str, qty: float = 1, item_code: str | None = None) -> str:
	"""Create a Work Order for an approved deal.

	Links back to the originating CRM Deal via the custom field added in
	korkem_manufacturing's patch (domain_model.md §3.4) -- this is what closes
	the Sales-to-Production loop.
	"""
	item_code = item_code or setup.FINISHED_ITEM
	bom = setup.get_default_bom()
	if not bom:
		frappe.throw(
			f"No active BOM for {item_code}. Run korkem_manufacturing.setup.provision first."
		)

	work_order = frappe.get_doc(
		{
			"doctype": "Work Order",
			"production_item": item_code,
			"bom_no": bom,
			"qty": qty,
			"company": setup.COMPANY,
			"wip_warehouse": f"Work In Progress - {setup.ABBR}",
			"fg_warehouse": f"Finished Goods - {setup.ABBR}",
			"source_warehouse": f"Stores - {setup.ABBR}",
			"planned_start_date": nowdate(),
			"expected_delivery_date": add_days(nowdate(), 14),
			"originating_deal": deal,
		}
	)
	# skip_transfer: this slice doesn't model raw-material stock transfer, so the
	# order isn't blocked on stock it was never given.
	work_order.skip_transfer = 1
	work_order.insert(ignore_permissions=True)
	work_order.submit()
	return work_order.name


def assign_production_task(
	work_order: str, assigned_to: str | None = None, title: str | None = None
) -> str | int:
	"""Create the shop-floor task for a Work Order and assign it to a worker.

	Returns an int: CRM Task uses naming_rule "Autoincrement".
	"""
	work_order_doc = frappe.get_doc("Work Order", work_order)
	task = frappe.get_doc(
		{
			"doctype": TASK_DOCTYPE,
			"title": title or f"Produce {work_order_doc.production_item} ({work_order})",
			"status": "Todo",
			"priority": "Medium",
			"reference_doctype": "Work Order",
			"reference_docname": work_order,
			"assigned_to": assigned_to,
		}
	)
	task.insert(ignore_permissions=True)
	return task.name


def create_production_order_for_deal(deal: str, qty: float = 1, assigned_to: str | None = None):
	"""Command dispatched by an approved Pending Action: order + its task.

	Returns both names so the Pending Action's result_data records what was made.
	"""
	work_order = create_production_order(deal=deal, qty=qty)
	task = assign_production_task(work_order, assigned_to=assigned_to)
	return {"work_order": work_order, "task": task}
