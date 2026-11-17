"""Departments, posts and the people on an order's stages (owner,
17.11.2026: «у заказа всегда свои люди»).

An Employee keeps his posts («pvc.sander», «paint.painter»…, `services.team`);
an order keeps, beside who did each stage (`…_by`), who it is given to
(`…_to`), set when the order is accepted and changed by the manager.
"""

import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_field

STAGES = ("cut", "mill", "sand", "paint", "vacuum", "ready")


def execute():
	if not frappe.db.exists("Custom Field", {"dt": "Employee", "fieldname": "korkem_team_roles"}):
		create_custom_field("Employee", {
			"fieldname": "korkem_team_roles", "label": "Posts (KORKEM)", "fieldtype": "Small Text",
			"insert_after": "designation",
		})
	for stage in STAGES:
		fieldname = f"korkem_stage_{stage}_to"
		if not frappe.db.exists("Custom Field", {"dt": "Sales Order", "fieldname": fieldname}):
			create_custom_field("Sales Order", {
				"fieldname": fieldname, "label": f"Stage {stage}: given to", "fieldtype": "Link",
				"options": "Employee", "insert_after": f"korkem_stage_{stage}_by", "read_only": 1,
				"allow_on_submit": 1,
			})
	frappe.clear_cache(doctype="Employee")
	frappe.clear_cache(doctype="Sales Order")
