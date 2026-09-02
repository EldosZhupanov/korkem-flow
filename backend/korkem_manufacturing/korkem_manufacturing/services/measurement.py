# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Замер — этап 2 цепочки, звено между заявкой и ценой.

До замера известно, что клиент чего-то хочет. После — известно, чего именно и
сколько, и только тогда можно назвать цену. Поэтому здесь заканчивается «мы
приняли обращение» и начинается «мы знаем, что делаем».

Решения, из-за которых файл выглядит так.

**Замер закрывает задачу, а не создаёт новую сущность.** Задача замерщику уже
создана на этапе 1 и уже привязана к сказанному. Заводить отдельный документ
«Замер» значило бы держать два места, где написано одно и то же, и однажды они
разойдутся. Результат замера ложится на заявку, а задача становится
выполненной — тем же действием, потому что человек делает это одним движением.

**Адрес — не заметка.** Он нужен доставке и монтажу, то есть двум звеньям в
конце цепочки, до которых полгода. Записанный текстом в комментарий, он к тому
моменту будет потерян среди других комментариев. Поэтому адрес идёт в
`Address` ERPNext, привязанный к клиенту, — туда, где его будут искать.

**Размеры остаются текстом, и это осознанно.** «3200 на 600, высота 2100, угол
слева» — это то, что говорит замерщик, и разбирать это на поля значит
навязывать форму, которой у мебели на заказ нет. Разбор придёт вместе с
импортом из БАЗИС, где размеры уже структурированы технологом.
"""

from __future__ import annotations

import frappe

from korkem_manufacturing.services.scope import scoped


def record(
	*,
	enquiry: str,
	dimensions: str | None = None,
	notes: str | None = None,
	address_line: str | None = None,
	city: str | None = None,
	measured_on: str | None = None,
) -> dict:
	"""Записать результат замера на заявку и закрыть задачу замерщика."""
	opportunity = _visible_enquiry(enquiry)

	dimensions = (dimensions or "").strip()
	notes = (notes or "").strip()
	if not dimensions and not notes:
		frappe.throw(
			"Замер без единого измерения и без единого слова — это не замер. "
			"Запишите хотя бы размеры или то, что увидели."
		)

	address = None
	if address_line:
		address = _address(opportunity, address_line, city)

	_write_result(opportunity, dimensions, notes, measured_on)
	closed = _close_the_task(opportunity)

	return {
		"enquiry": opportunity.name,
		"address": address,
		"task_closed": closed,
		"measured_on": measured_on or frappe.utils.nowdate(),
	}


def _visible_enquiry(name: str):
	if not frappe.get_list("Opportunity", filters=scoped({"name": name}), pluck="name"):
		frappe.throw("Нет такой заявки в этой компании.", frappe.PermissionError)
	return frappe.get_doc("Opportunity", name)


def _address(opportunity, line: str, city: str | None) -> str | None:
	"""Адрес там, где его будет искать доставка, а не в ленте комментариев."""
	savepoint = "korkem_measure_addr_" + frappe.generate_hash(length=8)
	try:
		frappe.db.savepoint(savepoint)
		doc = frappe.get_doc(
			{
				"doctype": "Address",
				"address_title": opportunity.party_name or opportunity.name,
				"address_type": "Shipping",
				"address_line1": line.strip(),
				"city": (city or "").strip() or None,
				"links": [
					{"link_doctype": "Customer", "link_name": opportunity.party_name}
				]
				if opportunity.party_name
				else [],
			}
		)
		doc.flags.ignore_mandatory = True
		doc.insert(ignore_permissions=True)
		frappe.db.release_savepoint(savepoint)
		return doc.name
	except Exception:
		try:
			frappe.db.rollback(save_point=savepoint)
		except Exception:
			pass
		# Адрес важен, но не настолько, чтобы потерять из-за него весь замер:
		# размеры записаны, задача закрыта, а адрес добавят руками.
		frappe.log_error(
			title="Could not store a measurement address",
			message=frappe.get_traceback(with_context=True),
		)
		return None


def _write_result(opportunity, dimensions: str, notes: str, measured_on: str | None) -> None:
	parts = [f"KORKEM: замер {measured_on or frappe.utils.nowdate()}"]
	if dimensions:
		parts.append(f"Размеры: {dimensions}")
	if notes:
		parts.append(notes)

	frappe.get_doc(
		{
			"doctype": "Comment",
			"comment_type": "Info",
			"reference_doctype": "Opportunity",
			"reference_name": opportunity.name,
			"content": "\n".join(parts),
		}
	).insert(ignore_permissions=True)


def _close_the_task(opportunity) -> str | None:
	"""Закрыть задачу замерщика, если она есть.

	Задача привязана к сказанному, а не к заявке: её создали в тот момент, когда
	заявки ещё не было. Поэтому идём через захват, который эту заявку породил.
	"""
	captures = frappe.get_list(
		"Capture",
		filters=scoped({"enquiry": opportunity.name}),
		fields=["name", "task"],
		limit_page_length=1,
	)
	if not captures or not captures[0].get("task"):
		return None

	task = captures[0]["task"]
	if not frappe.db.exists("CRM Task", task):
		return None

	frappe.db.set_value("CRM Task", task, "status", "Done")
	return str(task)
