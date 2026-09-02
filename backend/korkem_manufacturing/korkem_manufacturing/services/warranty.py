# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Гарантия — последнее звено цепочки и первое, о чём вспоминают через год.

Кухня установлена, деньги получены, все разошлись. Через восемь месяцев
отваливается петля, и клиент звонит. Этот файл про то, что происходит дальше.

**Гарантия считается от отгрузки, а не от заказа.** Между подписанием и
установкой у мебели на заказ проходят недели, иногда месяцы, и все они —
не гарантийный срок клиента: он ещё ничем не пользовался. Считать от заказа
значит отнять у клиента то время, что он ждал.

**Срок хранится там, где его хранит ERPNext, — на номенклатуре.** У `Item` есть
`warranty_period` в днях, и это уже часть модели. Заводить своё поле значило бы
второе место, где написан срок гарантии, и однажды они разошлись бы — обычно
в тот момент, когда на них смотрит недовольный клиент.

**Просроченная рекламация отклоняется с датой, а не молча.** «Гарантия
закончилась 14 июня» — это ответ, с которым можно спорить или согласиться.
«Нельзя» — это ответ, после которого звонят и ругаются.
"""

from __future__ import annotations

import frappe

from korkem_manufacturing.services.scope import scoped


def status(*, sales_order: str) -> dict:
	"""Что с гарантией по заказу: с какого дня, по какой и действует ли.

	Пока ничего не отгружено, гарантии нет — и это не ошибка, а состояние.
	"""
	order = _visible_order(sales_order)
	shipped_on = _shipped_on(order.name)

	items = []
	for row in _order_items(order.name):
		days = int(frappe.db.get_value("Item", row["item_code"], "warranty_period") or 0)
		until = (
			frappe.utils.add_days(shipped_on, days) if shipped_on and days else None
		)
		items.append(
			{
				"item_code": row["item_code"],
				"item_name": row.get("item_name"),
				"days": days,
				"until": str(until) if until else None,
				"active": bool(until and frappe.utils.getdate(until) >= frappe.utils.getdate()),
			}
		)

	return {
		"sales_order": order.name,
		"customer": order.customer,
		"shipped_on": str(shipped_on) if shipped_on else None,
		"items": items,
	}


def claim(*, sales_order: str, item_code: str, complaint: str) -> dict:
	"""Принять рекламацию — если гарантия ещё действует."""
	order = _visible_order(sales_order)

	complaint = (complaint or "").strip()
	if not complaint:
		frappe.throw("Опишите, что случилось: рекламация без описания — это звонок.")

	line = next(
		(row for row in status(sales_order=order.name)["items"] if row["item_code"] == item_code),
		None,
	)
	if not line:
		frappe.throw(f"Позиции {item_code} нет в этом заказе.")

	if not line["until"]:
		frappe.throw(
			"По этой позиции гарантия не начиналась: либо она ещё не отгружена, "
			"либо у номенклатуры не задан гарантийный срок."
		)

	if not line["active"]:
		frappe.throw(f"Гарантия по этой позиции закончилась {line['until']}.")

	doc = frappe.get_doc(
		{
			"doctype": "Warranty Claim",
			"customer": order.customer,
			"item_code": item_code,
			"complaint_date": frappe.utils.nowdate(),
			"complaint": complaint,
			"warranty_expiry_date": line["until"],
			"warranty_amc_status": "Under Warranty",
			"status": "Open",
			"company": order.company,
		}
	)
	doc.flags.ignore_mandatory = True
	doc.insert()

	return {
		"sales_order": order.name,
		"claim": doc.name,
		"item_code": item_code,
		"warranty_until": line["until"],
		"status": "accepted",
	}


def _visible_order(name: str):
	if not frappe.get_list("Sales Order", filters=scoped({"name": name}), pluck="name"):
		frappe.throw("Нет такого заказа в этой компании.", frappe.PermissionError)
	return frappe.get_doc("Sales Order", name)


def _order_items(sales_order: str) -> list[dict]:
	return [
		dict(row)
		for row in frappe.get_all(
			"Sales Order Item",
			filters={"parent": sales_order, "parenttype": "Sales Order"},
			parent_doctype="Sales Order",
			fields=["item_code", "item_name", "delivered_qty"],
		)
	]


def _shipped_on(sales_order: str):
	"""День, когда клиент впервые получил вещь.

	Берётся первая проведённая накладная по заказу: гарантия начинается тогда,
	когда мебель оказалась у клиента, а не когда её доделали на складе.
	"""
	names = frappe.get_all(
		"Delivery Note Item",
		filters={"against_sales_order": sales_order, "parenttype": "Delivery Note"},
		parent_doctype="Delivery Note",
		pluck="parent",
	)
	if not names:
		return None
	dates = frappe.get_all(
		"Delivery Note",
		filters=scoped({"name": ["in", names], "docstatus": 1}),
		pluck="posting_date",
		order_by="posting_date asc",
		limit_page_length=1,
	)
	return dates[0] if dates else None
