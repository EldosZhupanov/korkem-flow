"""Remove the second stock ledger, `Domain Stock Movement`, and its rows.

By the owner's decision of 2026-10-28. Stock is counted by ERPNext alone:
receipts, transfers and write-offs are Stock Entries, and a reservation is a
promise (`Stock Reservation`), not a movement. The ledger's last writer, the
prototype `services/manufacturing_flow.py`, was removed with it. Rows already
written are test and pilot traffic of a ledger nothing reads any more.
"""

import frappe

DOCTYPE = "Domain Stock Movement"


def execute():
	if frappe.db.exists("DocType", DOCTYPE):
		frappe.delete_doc("DocType", DOCTYPE, force=True, ignore_permissions=True)
	if frappe.db.table_exists(DOCTYPE):
		frappe.db.sql_ddl(f"DROP TABLE IF EXISTS `tab{DOCTYPE}`")
