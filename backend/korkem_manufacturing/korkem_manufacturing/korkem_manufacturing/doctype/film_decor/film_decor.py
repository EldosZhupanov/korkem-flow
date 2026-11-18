# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

from __future__ import annotations

from frappe.model.document import Document


class FilmDecor(Document):
	"""One decor of a maker's catalogue — its name, collection and picture
	(owner, 18.11.2026: «чтобы они при вводе виделись на глаз»).

	A reference, not stock: written only through `services/film_decors.py`.
	A film of the same maker and name shows this picture until it has a
	photo of its own.
	"""
