# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Клей для ПВХ — тонкая обёртка над services/glue_stock.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import glue_stock as service

GLUE_CARD = ("origin", "bucket_kg", "kg_per_litre", "norm_g_m2", "reserve_kg", "markup_bucket", "markup_litre")


def _sent(keys) -> dict:
	"""Only what was sent — a field left out stays as it is."""
	form = frappe.form_dict
	return {k: form.get(k) for k in keys if k in form}


@frappe.whitelist(methods=["GET"])
def stock() -> dict:
	"""Клеи с карточками, остатки, цена кг и м², поставщики, нужда очереди вакуума, долги, факт расхода."""
	return service.stock()


@frappe.whitelist(methods=["POST"])
def add_glue(name: str) -> dict:
	"""Новый клей: название, производство, ведро кг, кг в литре, норма г/м², запас себе, наценки."""
	return service.add_glue(name, **_sent(GLUE_CARD))


@frappe.whitelist(methods=["POST"])
def set_glue(item: str) -> dict:
	"""Карточка клея — меняется то, что прислано."""
	return service.set_glue(item, **_sent(GLUE_CARD))


@frappe.whitelist(methods=["POST"])
def set_in_work(item: str) -> dict:
	"""Открыли новую бочку: с этого клея списываем дальше."""
	return service.set_in_work(item)


@frappe.whitelist(methods=["POST"])
def set_milling(factors: str | dict) -> dict:
	"""Поправки фрезеровок: во сколько раз больше клея, чем на гладкое лицо."""
	return service.set_milling(factors)


@frappe.whitelist(methods=["POST"])
def receive(item: str, qty: float | str, unit: str, price: float | str, price_per: str, supplier: str,
			received_on: str | None = None, note: str | None = None, delivery: str | dict | None = None,
			received_by: str | None = None, supplier_pay: str | dict | None = None) -> dict:
	"""Приход клея: сколько (кг, литры, вёдра), почём (за кг, литр, ведро), от кого; доставка, оплата."""
	return service.receive(item, qty, unit, price, price_per, supplier, received_on=received_on, note=note,
						   delivery=delivery, received_by=received_by, supplier_pay=supplier_pay)


@frappe.whitelist(methods=["POST"])
def add_supplier(name: str) -> dict:
	"""Поставщик клея. Уже известная компания (продаёт плёнку или краску) — тот же поставщик, теперь и клея."""
	return service.add_supplier(name, **_sent(service.SUPPLIER_CARD))


@frappe.whitelist(methods=["POST"])
def set_supplier(supplier: str) -> dict:
	"""Карточка поставщика клея: город, контакт, телефоны, минимальная партия, заметка."""
	return service.set_supplier(supplier, **_sent((*service.SUPPLIER_CARD, "name")))


@frappe.whitelist(methods=["POST"])
def count(item: str, kg: float | str) -> dict:
	"""Пересчёт: взвесили — столько кг этого клея на самом деле."""
	return service.count(item, kg)


@frappe.whitelist(methods=["POST"])
def pay_supplier(receipt: str, method: str | None = None, bank: str | None = None) -> dict:
	"""Оплатили долг за клей — сегодня."""
	return service.pay_supplier(receipt, method, bank)


@frappe.whitelist(methods=["POST"])
def settle_delivery(receipt: str, method: str | None = None, bank: str | None = None) -> dict:
	"""Доставку клея вернули сотруднику или оплатили перевозчику — сегодня."""
	return service.settle_delivery(receipt, method, bank)
