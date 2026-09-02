# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Клиент согласился — КП становится заказом.

Звено, которое соединяет две половины цепочки. До него была передняя половина:
обращение, клиент, заявка, замер, предложение. После него начинается та, что
уже построена и работает: материал, закупка, задания цеху, отгрузка. Между ними
до сегодня не было ничего, и заказ приходилось заводить руками — то есть
набирать заново то, что уже написано в КП.

**Заказ собирает штатный маппер ERPNext**, а не мы. `quotation.mapper` знает,
как перенести позиции, цены, налоги, скидки, валюту и сроки, и делает это
одинаково с тем, что происходит при нажатии кнопки в панели. Свой перенос
означал бы второе место, где решается, чему равна цена в заказе, — и однажды
эти два места разошлись бы на скидке.

**Заказ создаётся черновиком, а не проведённым.** Проведённый заказ резервирует
материал и запускает производство, а в цепочке владельца между согласием
клиента и запуском стоит предоплата. Пока приём денег не подключён, решение
«запускать» остаётся человеку — и это честнее, чем запустить и надеяться.

**Склад отгрузки берётся из настроек компании, а не выдумывается.** Заказ на
складскую позицию без склада ERPNext не принимает, и это верно: отгружать
придётся откуда-то конкретно. Если у компании не задан склад готовой продукции,
служба отказывается — заказ с наугад выбранным складом однажды спишет товар
не с той полки, и найдут это при инвентаризации.

**Срок обязателен, и это не формальность ERPNext.** Заказ без обещанной даты
не принимает сам ERPNext, и он прав: «когда готово?» — тот самый вопрос, из-за
которого владелец обходит цех ногами, и ради ответа на который построен весь
продукт. Заказ, у которого нет срока, отвечать на него не умеет.
"""

from __future__ import annotations

import frappe

from korkem_manufacturing.services.scope import scoped


def accept(*, quotation: str, deliver_on: str) -> dict:
	"""Принять КП: провести его и собрать по нему черновик заказа.

	Повторный вызов возвращает уже созданный заказ. Клиент соглашается один раз,
	а кнопку нажимают сколько угодно.
	"""
	doc = _visible_quotation(quotation)

	if not deliver_on:
		frappe.throw(
			"Назовите срок. Заказ без обещанной даты не сможет ответить клиенту "
			"на вопрос «когда готово», а ради этого ответа всё и делается."
		)

	existing = _order_for(doc.name)
	if existing:
		return {
			"quotation": doc.name,
			"sales_order": existing,
			"status": "already_accepted",
		}

	if doc.docstatus == 0:
		# Согласие клиента — это и есть момент, когда предложение перестаёт быть
		# черновиком. Оставить его черновиком значит потерять след того, на что
		# именно согласились.
		doc.submit()
		doc.reload()

	if doc.docstatus == 2:
		frappe.throw("Это предложение отменено — по нему нельзя принять заказ.")

	from erpnext.selling.doctype.quotation.mapper import make_sales_order

	order = make_sales_order(doc.name)
	order.delivery_date = deliver_on
	warehouse = _shipping_warehouse(order)
	for row in order.items:
		row.delivery_date = deliver_on
		if not row.warehouse and _is_stock_item(row.item_code):
			row.warehouse = warehouse
	order.insert()

	return {
		"quotation": doc.name,
		"sales_order": order.name,
		"status": "accepted",
		"total": frappe.utils.flt(order.grand_total),
		"submitted": False,
		"deliver_on": str(deliver_on),
	}


def _visible_quotation(name: str):
	if not frappe.get_list("Quotation", filters=scoped({"name": name}), pluck="name"):
		frappe.throw("Нет такого предложения в этой компании.", frappe.PermissionError)
	return frappe.get_doc("Quotation", name)


def _order_for(quotation: str) -> str | None:
	"""Заказ, уже собранный по этому предложению, если он есть.

	Связь живёт на строках заказа (`prevdoc_docname`), а не на его шапке — так
	устроен маппер ERPNext, и искать надо там же, где он пишет.
	"""
	rows = frappe.get_list(
		"Sales Order Item",
		filters={"prevdoc_docname": quotation, "parenttype": "Sales Order"},
		parent_doctype="Sales Order",
		pluck="parent",
		limit_page_length=1,
	)
	if not rows:
		return None
	visible = frappe.get_list(
		"Sales Order",
		filters=scoped({"name": rows[0], "docstatus": ["<", 2]}),
		pluck="name",
		limit_page_length=1,
	)
	return visible[0] if visible else None


def _is_stock_item(item_code: str) -> bool:
	return bool(frappe.db.get_value("Item", item_code, "is_stock_item"))


def _shipping_warehouse(order) -> str:
	"""Откуда отгружаем. Из настроек компании, а не наугад."""
	warehouse = frappe.db.get_value("Company", order.company, "default_fg_warehouse")
	if warehouse:
		return warehouse
	frappe.throw(
		"У компании не задан склад готовой продукции, а без него заказ не знает, "
		"откуда отгружать. Задайте его в настройках компании."
	)
