# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Склад краски — тонкая обёртка над services/paint_stock.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import material_stock
from korkem_manufacturing.services import paint_recipe as recipe_service
from korkem_manufacturing.services import paint_stock as service


@frappe.whitelist(methods=["GET"])
def stock() -> dict:
	"""Краски на складе, хватит ли на очередь, долги за краску."""
	return service.stock()


@frappe.whitelist(methods=["GET"])
def history(item: str) -> dict:
	"""Приходы одной краски: когда, сколько, почём, от кого, откуда."""
	return service.history(item)


@frappe.whitelist(methods=["POST"])
def receive(colour: str, kg: float | str, price_kg: float | str, supplier: str, base: str | None = None,
			received_on: str | None = None, note: str | None = None, delivery: str | dict | None = None,
			received_by: str | None = None, supplier_pay: str | dict | None = None) -> dict:
	"""Приход краски: цвет, что это, кг, цена за кг, поставщик; доставка, оплата, кто принял."""
	return service.receive(colour, kg, price_kg, supplier, base=base, received_on=received_on, note=note,
						   delivery=delivery, received_by=received_by, supplier_pay=supplier_pay)


@frappe.whitelist(methods=["POST"])
def attach_photo(receipt: str, file_name: str, content_b64: str) -> dict:
	"""Фото накладной к приходу краски."""
	import base64

	try:
		content = base64.b64decode(content_b64, validate=True)
	except ValueError:
		frappe.throw("Файл не прочитался.")
	return service.attach_photo(receipt, file_name, content)


@frappe.whitelist(methods=["POST"])
def set_recipe(recipe: str | dict) -> dict:
	"""Рецепт покраски: слои (грунт, эмаль, лак) — г/м², сколько слоёв, цена; в каждом —
	отвердитель, разбавитель на 1 кг."""
	return service.set_recipe(recipe)


@frappe.whitelist(methods=["GET"])
def plan(m2: float | str, colour: str | None = None) -> dict:
	"""Сколько уйдёт на столько м²: каждый материал в кг, по цене; итого и за м²."""
	material_stock._ensure_staff()
	p = recipe_service.plan(m2, colour)
	return {**p, "text": recipe_service.text_of(p)}


@frappe.whitelist(methods=["POST"])
def pay_supplier(receipt: str, method: str | None = None, bank: str | None = None) -> dict:
	"""Оплатили долг за краску — сегодня; `bank` — банк перевода или карты."""
	return service.pay_supplier(receipt, method, bank)


@frappe.whitelist(methods=["POST"])
def add_supplier(name: str, city: str | None = None, contact: str | None = None, phone: str | None = None,
				 whatsapp: str | None = None, min_order: str | None = None, note: str | None = None) -> dict:
	"""Новый поставщик краски — компания или человек, со своей карточкой; отдельно от плёнки."""
	return service.add_supplier(name, **_card(city, contact, phone, whatsapp, min_order, note))


@frappe.whitelist(methods=["POST"])
def set_supplier(supplier: str, name: str | None = None, city: str | None = None, contact: str | None = None,
				 phone: str | None = None, whatsapp: str | None = None, min_order: str | None = None,
				 note: str | None = None) -> dict:
	"""Карточка поставщика краски: город, контакт, телефоны, минимальная партия, заметка."""
	card = _card(city, contact, phone, whatsapp, min_order, note)
	if name:
		card["name"] = name
	return service.set_supplier(supplier, **card)


def _card(city, contact, phone, whatsapp, min_order, note) -> dict:
	"""Only what was sent — a field left out stays as it is."""
	sent = frappe.form_dict
	values = {"city": city, "contact": contact, "phone": phone, "whatsapp": whatsapp, "min_order": min_order,
			  "note": note}
	return {k: v for k, v in values.items() if k in sent or v is not None}


@frappe.whitelist(methods=["POST"])
def count(item: str, kg: float | str) -> dict:
	"""Пересчёт: сколько кг этой краски на самом деле."""
	return service.count(item, kg)


@frappe.whitelist(methods=["POST"])
def settle_delivery(receipt: str, method: str | None = None, bank: str | None = None) -> dict:
	"""Доставку краски вернули сотруднику или оплатили перевозчику — сегодня; `bank` — банк
	перевода или карты."""
	return service.settle_delivery(receipt, method, bank)
