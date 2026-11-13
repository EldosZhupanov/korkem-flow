# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""«К заказу» и приход несколькими плёнками — тонкая обёртка над
services/film_orders.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import film_orders as service


@frappe.whitelist(methods=["GET"])
def wanted() -> dict:
	"""Что заказать — по поставщикам; что отправлено и ждёт ответа."""
	return service.wanted()


@frappe.whitelist(methods=["POST"])
def add(item: str, metres: float | str, customer: str | None = None, supplier: str | None = None,
		note: str | None = None) -> dict:
	"""Добавить плёнку к заказу: метры, для клиента или на склад."""
	return service.add(item, metres, customer=customer, supplier=supplier, note=note)


@frappe.whitelist(methods=["POST"])
def update(line: str, metres: float | str | None = None, supplier: str | None = None,
		   customer: str | None = None) -> dict:
	"""Другие метры, другой поставщик, другой клиент."""
	return service.update(line, metres=metres, supplier=supplier, customer=customer)


@frappe.whitelist(methods=["POST"])
def drop(line: str | None = None, item: str | None = None) -> dict:
	"""Убрать из заказа; предложенную самой программой — на сегодня."""
	return service.drop(line=line, item=item)


@frappe.whitelist(methods=["POST"])
def sent(supplier: str | None = None) -> dict:
	"""Список поставщику отправлен — ждём ответа."""
	return service.sent(supplier)


@frappe.whitelist(methods=["POST"])
def receive_many(supplier: str, lines: str | list, arrives_on: str | None = None,
				 delivery: str | dict | None = None, received_by: str | None = None,
				 note: str | None = None) -> dict:
	"""Приход от одного поставщика: несколько плёнок, одна доставка."""
	return service.receive_many(supplier, lines, arrives_on=arrives_on, delivery=delivery,
								received_by=received_by, note=note)


@frappe.whitelist(methods=["POST"])
def arrived_batch(batch: str) -> dict:
	"""Вся поставка пришла."""
	return service.arrived_batch(batch)


@frappe.whitelist(methods=["GET"])
def for_production(item: str) -> list[dict]:
	"""Заказы на фасады, которым не хватает этой плёнки."""
	return service.for_production(item)
