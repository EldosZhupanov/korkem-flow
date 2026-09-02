# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Коммерческое предложение из заявки — этап 3 цепочки.

Первый шаг, на котором в разговоре появляются деньги. До него всё было про то,
чтобы не потерять обращение; здесь начинается вопрос «сколько это стоит», и
ответ на него клиент получает в письменном виде.

Два решения, из-за которых этот файл выглядит именно так.

**КП — это `Quotation` ERPNext, а не наш документ.** У Quotation уже есть
позиции, налоги, валюта, срок действия, печатная форма и — главное —
превращение в `Sales Order` одним штатным действием. Своё КП пришлось бы
превращать в заказ руками, и на этом переходе теряются позиции.

**Черновик, а не готовое предложение.** Модель может расслышать «кухня три
двести», но цену называет человек. Служба готовит документ с заполненным
клиентом, ссылкой на заявку и словами клиента — а цифры остаются владельцу.
Автоматически выставленное КП с придуманной ценой это не экономия времени,
это потерянный заказ или работа в убыток.

**КП без позиций не бывает, и это правило ERPNext, а не наше.** Я собирался
разрешить пустой черновик — «замера ещё не было, но клиент уже не потеряется».
ERPNext отказался вставлять такой документ, и он прав: предложение без строк
это не предложение. Роль «обращение принято, цена ещё не известна» уже играет
`Opportunity`; дублировать её пустым КП значит завести два документа с одним
смыслом. Поэтому здесь позиции обязательны, а до них живёт заявка.
"""

from __future__ import annotations

import frappe

from korkem_manufacturing.services.scope import scoped


def draft(*, enquiry: str, items: list[dict] | None = None, valid_days: int = 14) -> dict:
	"""Собрать черновик КП по заявке.

	Повторный вызов на заявке, у которой уже есть черновик, возвращает его же:
	два предложения по одному обращению — это два разных ответа клиенту, и
	второй из них однажды уедет вместо первого.
	"""
	opportunity = _visible_enquiry(enquiry)

	rows = _items(items)
	if not rows:
		frappe.throw(
			"КП без позиций не бывает. Пока цена не известна, обращение живёт "
			"заявкой — вернитесь сюда после замера."
		)

	existing = frappe.get_list(
		"Quotation",
		filters=scoped({"opportunity": enquiry, "docstatus": 0}),
		pluck="name",
		limit_page_length=1,
	)
	if existing:
		return {"quotation": existing[0], "status": "already_drafted", "items": None}

	quotation = frappe.get_doc(
		{
			"doctype": "Quotation",
			"quotation_to": "Customer",
			"party_name": opportunity.party_name,
			"company": _company(),
			"opportunity": enquiry,
			"transaction_date": frappe.utils.nowdate(),
			"valid_till": frappe.utils.add_days(frappe.utils.nowdate(), max(1, valid_days)),
			"items": rows,
		}
	)
	# Позиция без цены — нормальный черновик: цену назовёт человек, глядя на
	# слова клиента. Обязательна именно строка, а не ставка в ней.
	quotation.flags.ignore_mandatory = True
	quotation.insert()

	_carry_the_words(quotation, opportunity)

	return {
		"quotation": quotation.name,
		"status": "drafted",
		"items": len(quotation.items or []),
		"customer": opportunity.party_name,
		"valid_till": str(quotation.valid_till),
	}


def _items(items: list[dict] | None) -> list[dict]:
	"""Позиции предложения. Строка без цены допустима, отсутствие строк — нет."""
	rows = []
	for row in items or []:
		code = (row.get("item_code") or "").strip()
		if not code:
			continue
		rows.append(
			{
				"item_code": code,
				"qty": frappe.utils.flt(row.get("qty")) or 1,
				"rate": frappe.utils.flt(row.get("rate")),
				"description": row.get("description"),
			}
		)
	return rows


def _visible_enquiry(name: str):
	if not frappe.get_list("Opportunity", filters=scoped({"name": name}), pluck="name"):
		frappe.throw("Нет такой заявки в этой компании.", frappe.PermissionError)
	return frappe.get_doc("Opportunity", name)


def _company() -> str:
	company = scoped().get("company")
	if not company:
		frappe.throw("Компания не определена.")
	return company


def _carry_the_words(quotation, opportunity) -> None:
	"""Перенести слова клиента с заявки на КП.

	Тот, кто ставит цену, должен видеть, что именно просили, а не только
	название позиции. «Белый глянец» и «белый матовый» стоят по-разному.
	"""
	savepoint = "korkem_quote_words_" + frappe.generate_hash(length=8)
	try:
		frappe.db.savepoint(savepoint)
		said = frappe.get_all(
			"Comment",
			filters={
				"reference_doctype": "Opportunity",
				"reference_name": opportunity.name,
				"comment_type": "Info",
			},
			pluck="content",
			order_by="creation asc",
			limit=1,
		)
		if said:
			frappe.get_doc(
				{
					"doctype": "Comment",
					"comment_type": "Info",
					"reference_doctype": "Quotation",
					"reference_name": quotation.name,
					"content": said[0],
				}
			).insert(ignore_permissions=True)
		frappe.db.release_savepoint(savepoint)
	except Exception:
		try:
			frappe.db.rollback(save_point=savepoint)
		except Exception:
			pass
		frappe.log_error(
			title="Could not carry the customer's words onto a quotation",
			message=frappe.get_traceback(with_context=True),
		)
