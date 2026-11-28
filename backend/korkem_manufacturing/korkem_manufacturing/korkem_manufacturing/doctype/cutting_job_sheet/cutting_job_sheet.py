# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

from __future__ import annotations

from frappe.model.document import Document


class CuttingJobSheet(Document):
	"""One sheet of a cutting job: who sawed it and when, what was spoilt, the offcuts it
	left. Written only by `services/saw_cutting.py`."""
