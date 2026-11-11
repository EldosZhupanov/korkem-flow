# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Плёнка, отложенная за клиентом (владелец, 11.11.2026): метры одной плёнки,
до какого дня. Пока бронь активна, эти метры не продаются другим и не
уходят в цех; продажа этому клиенту бронь гасит. Логика — services/film_dept.py."""

from frappe.model.document import Document


class FilmHold(Document):
	pass
