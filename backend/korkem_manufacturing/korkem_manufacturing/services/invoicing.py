# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Счёт и акт по заказу — документ, который клиент подписывает.

Этап 12 цепочки. Приём денег заблокирован договором с Kaspi, но сам документ
от этого не зависит: сегодня клиент платит переводом, и счёт ему нужен уже
сейчас, а акт — чтобы закрыть сделку.

**Счёт собирает штатный маппер ERPNext**, как и заказ из КП. Позиции, налоги,
валюта, ссылка на заказ — всё это ERPNext умеет и делает одинаково с тем, что
происходит при нажатии кнопки в панели.

**Выставить можно только за отгруженное.** Счёт на непривезённую мебель — самый
быстрый способ поссориться с клиентом, который до этого был доволен. ERPNext
позволяет и то и другое; здесь выбрана строгая сторона, потому что мебель на
заказ делается неделями, и «выставим сейчас, привезём потом» превращается в
спор о том, за что именно заплачено.

Черновиком, а не проведённым: подписывает человек, а проведение счёта двигает
бухгалтерию.
"""

from __future__ import annotations

import frappe

from korkem_manufacturing.services.scope import scoped


def draft(*, sales_order: str) -> dict:
	"""Собрать черновик счёта по фактически отгруженному."""
	order = _visible_order(sales_order)

	if order.docstatus != 1:
		frappe.throw(
			"Заказ ещё не проведён. Счёт по черновику — это счёт за то, о чём "
			"никто окончательно не договорился."
		)

	delivered = _delivered(order.name)
	if delivered <= 0:
		frappe.throw(
			"По заказу ничего не отгружено. Счёт за непривезённую мебель — самый "
			"быстрый способ поссориться с довольным клиентом."
		)

	existing = _invoice_for(order.name)
	if existing:
		return {"sales_order": order.name, "invoice": existing, "status": "already_drafted"}

	from erpnext.selling.doctype.sales_order.mapper import make_sales_invoice

	invoice = make_sales_invoice(order.name)
	invoice.insert()

	return {
		"sales_order": order.name,
		"invoice": invoice.name,
		"total": frappe.utils.flt(invoice.grand_total),
		"delivered_qty": delivered,
		"status": "drafted",
	}


def _visible_order(name: str):
	if not frappe.get_list("Sales Order", filters=scoped({"name": name}), pluck="name"):
		frappe.throw("Нет такого заказа в этой компании.", frappe.PermissionError)
	return frappe.get_doc("Sales Order", name)


def _delivered(sales_order: str) -> float:
	rows = frappe.get_all(
		"Sales Order Item",
		filters={"parent": sales_order, "parenttype": "Sales Order"},
		parent_doctype="Sales Order",
		pluck="delivered_qty",
	)
	return sum(frappe.utils.flt(value) for value in rows)


def _invoice_for(sales_order: str) -> str | None:
	"""Счёт, уже выставленный по этому заказу.

	Связь, как и у заказа с КП, живёт на строках: маппер ERPNext пишет
	`sales_order` в `Sales Invoice Item`, а не в шапку.
	"""
	rows = frappe.get_list(
		"Sales Invoice Item",
		filters={"sales_order": sales_order, "parenttype": "Sales Invoice"},
		parent_doctype="Sales Invoice",
		pluck="parent",
		limit_page_length=1,
	)
	if not rows:
		return None
	visible = frappe.get_list(
		"Sales Invoice",
		filters=scoped({"name": rows[0], "docstatus": ["<", 2]}),
		pluck="name",
		limit_page_length=1,
	)
	return visible[0] if visible else None
