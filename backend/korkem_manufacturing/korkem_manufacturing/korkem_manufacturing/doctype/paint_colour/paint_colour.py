# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

from __future__ import annotations

from frappe.model.document import Document


class PaintColour(Document):
	"""What the shop says about one paint colour beyond its name on the
	«Краска» list: its shade on screen, a star, hidden from the catalogue,
	a note (owner, 19.11.2026: «каталог красок … добавлять, редактировать»).

	Keyed by the colour's number («ral9010») or, for a colour of its own,
	its name. Written only through `services/paint_catalogue.py`.
	"""
