# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

from __future__ import annotations

from frappe.model.document import Document


class MDFStageCrew(Document):
	"""One person of a stage done (or given) by several, with his share in %.

	Owner, 26.11.2026: «бывает большой объём, тогда 2 или 3 вакуумщика делают
	вместе, и система делит». Written only by `services/stage_crew.py`; a
	stage of one person has no rows — the order's own field names him.
	"""
