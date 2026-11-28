# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

from __future__ import annotations

from frappe.model.document import Document


class CuttingJob(Document):
	"""A cutting job for the panel saw — «Раскрой Р-0042» (owner, 28.11.2026).

	The parts as entered, the saw's settings as they were when it was made,
	the layout chosen, and per sheet who sawed it. Written only by
	`services/saw_cutting.py`; its history is the audit trail."""
