# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Строка «К заказу» (владелец, 12.11.2026): какую плёнку, сколько метров, у
кого заказать и для кого — клиента или на склад. Копится за день; поставщику
уходит одним сообщением; подтверждённая становится плёнкой в пути, и когда
та приходит — откладывается за клиентом. Логика — services/film_orders.py."""

from frappe.model.document import Document


class FilmOrderLine(Document):
	pass
