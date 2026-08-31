# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Minimal, real action functions used to exercise Pending Action's dynamic dispatch
mechanism in tests. Real business actions (e.g. RecordQuoteApproval) are added in later
Sprint 1 phases as their owning contexts are implemented; this module only proves the
generic approve -> resolve action_class -> call(**action_data) -> record result path
actually works end to end.
"""

import frappe


def set_todo_description(todo: str, description: str):
	"""Update a ToDo's description and return its new value. Used by Pending Action tests."""
	doc = frappe.get_doc("ToDo", todo)
	doc.description = description
	doc.save(ignore_permissions=True)
	return {"todo": doc.name, "description": doc.description}
