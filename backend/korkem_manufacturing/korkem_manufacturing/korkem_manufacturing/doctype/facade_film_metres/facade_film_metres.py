# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

from __future__ import annotations

from frappe.model.document import Document


class FacadeFilmMetres(Document):
	"""Film metres for one decor of an order, set by hand instead of the press
	layout — with the reason. See services/press_layout.set_film_metres."""
