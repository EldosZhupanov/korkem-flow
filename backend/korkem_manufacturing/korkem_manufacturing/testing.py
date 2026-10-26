# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Removing what a test left behind after something on its path committed.

Frappe rolls every test back, but a BOM submit or a durable job commits in the
middle of one, and everything written before that commit outlives the
rollback. On a shared bench it piles up: in one day of runs 33 abandoned orders
for «Клиент …» pushed the seeded orders out of every "first twenty" list the
assistant reads, and four korkem_ai tests failed for a reason that was not
theirs.

A test that knows it commits registers its order here with ``addCleanup``.
Removal is ordinary ERPNext: what is submitted is cancelled first, so stock
reservations are given back rather than left pointing at nothing.

Never imported by product code. It deletes.
"""

from __future__ import annotations

import sys

import frappe

#: Kept, silently, when anything still links to them: a customer or an item
#: may be shared with a record this test did not make.
_KEEP_IF_LINKED = frozenset({"Customer", "Item"})


def remove_order(sales_order: str, *, also: list[tuple[str, str]] | tuple = ()) -> list[str]:
	"""Remove an order, everything that hangs off it, then ``also``.

	``also`` is removed after the order, in the order given — a customer, a
	BOM, a price, an item. Returns what could not be removed.
	"""
	frappe.db.rollback()
	trail = order_trail(sales_order)
	_forget_lost_enquiries(trail)
	return remove([*trail, *also])


def _forget_lost_enquiries(trail: list[tuple[str, str]]) -> None:
	"""Unlink a quotation from an enquiry that no longer exists.

	The rollback can take the enquiry and leave the committed order. ERPNext
	then refuses to cancel the order or its quotation, because cancelling
	updates the enquiry's status and the enquiry is not found.
	"""
	for doctype, name in trail:
		if doctype != "Quotation":
			continue
		enquiry = frappe.db.get_value("Quotation", name, "opportunity")
		if enquiry and not frappe.db.exists("Opportunity", enquiry):
			frappe.db.set_value("Quotation", name, "opportunity", None, update_modified=False)


def order_trail(sales_order: str) -> list[tuple[str, str]]:
	"""The order and its trail, newest first — the order they can be removed in."""
	if not sales_order or not frappe.db.exists("Sales Order", sales_order):
		return []
	after: list[tuple[str, str]] = []
	for child, parent, field in (
		("Sales Invoice Item", "Sales Invoice", "sales_order"),
		("Delivery Note Item", "Delivery Note", "against_sales_order"),
	):
		for name in _parents(child, field, sales_order):
			after.append((parent, name))
	# A deposit or a signed contract blocks cancelling the order, so they go
	# first. The lifecycle test leaves both.
	for name in _parents("Payment Entry Reference", "reference_name", sales_order):
		after.append(("Payment Entry", name))
	for name in frappe.get_all(
		"Contract",
		filters={"document_type": "Sales Order", "document_name": sales_order},
		pluck="name",
		order_by="creation desc",
	):
		after.append(("Contract", name))
	for work_order in frappe.get_all(
		"Work Order", filters={"sales_order": sales_order}, pluck="name", order_by="creation desc"
	):
		for doctype in ("Stock Entry", "Job Card"):
			after += [
				(doctype, name)
				for name in frappe.get_all(
					doctype, filters={"work_order": work_order}, pluck="name", order_by="creation desc"
				)
			]
		after.append(("Work Order", work_order))
	after.append(("Sales Order", sales_order))
	for quotation in _parents("Sales Order Item", "prevdoc_docname", None, parent=sales_order):
		after.append(("Quotation", quotation))
		opportunity = frappe.db.get_value("Quotation", quotation, "opportunity")
		if opportunity:
			after.append(("Opportunity", opportunity))
	return after


def remove(records: list[tuple[str, str]]) -> list[str]:
	"""Remove each record in the order given, and commit.

	One that cannot go is reported on stderr and left; a cleanup that raises
	would turn a passing test red for a reason it does not test.
	"""
	user = frappe.session.user
	frappe.set_user("Administrator")
	left: list[str] = []
	try:
		for doctype, name in records:
			if not name or not frappe.db.exists(doctype, name):
				continue
			frappe.db.savepoint("korkem_leftover")
			try:
				if frappe.db.get_value(doctype, name, "docstatus") == 1:
					frappe.get_doc(doctype, name).cancel()
				frappe.delete_doc(
					doctype,
					name,
					force=doctype not in _KEEP_IF_LINKED,
					ignore_permissions=True,
					delete_permanently=True,
				)
			except frappe.LinkExistsError as error:
				frappe.db.rollback(save_point="korkem_leftover")
				# Expected for a shared customer or item; anything else that is
				# still linked is a leftover, and must be said out loud.
				if doctype not in _KEEP_IF_LINKED:
					left.append(f"{doctype} {name}: {error}")
			except Exception as error:
				frappe.db.rollback(save_point="korkem_leftover")
				left.append(f"{doctype} {name}: {error}")
		frappe.db.commit()
	finally:
		frappe.set_user(user)
	if left:
		print("korkem: test leftovers not removed:", *left, sep="\n  ", file=sys.stderr)
	return left


def _parents(child: str, field: str, value: str | None, *, parent: str | None = None) -> list[str]:
	"""Distinct parents of ``child`` rows matching ``field``, or that field's values on ``parent``."""
	if parent:
		rows = frappe.get_all(child, filters={"parent": parent, field: ["is", "set"]}, pluck=field)
	else:
		rows = frappe.get_all(child, filters={field: value}, pluck="parent")
	return list(dict.fromkeys(rows))
