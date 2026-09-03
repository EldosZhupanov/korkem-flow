# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Договор — этап 4 цепочки, и половина его от нас не зависит.

Между «клиент согласился с ценой» и «мы начали пилить» стоит подпись. У мебели
на заказ это не формальность: предоплату без договора не берут, а без предоплаты
не покупают материал.

**Подписание с юридической силой заблокировано** — нужен аккаунт TrustMe, и это
решение владельца, а не строчка кода. Но сам документ от этого не зависит: он
нужен уже сегодня, хотя бы чтобы распечатать и подписать на бумаге, и место для
его состояния должно существовать до того, как появится TrustMe.

**Ничего своего не заводится.** У ERPNext есть `Contract` ровно с тем, что нужно:
кто сторона, текст договора, подписан ли, кем и когда, с какого адреса, и ссылка
на документ, из которого он вырос. Заводить своё значило бы держать второе место,
где написано, подписан ли договор, — и однажды они разойдутся.

**Подпись — это кто и когда, а не галочка.** Сегодня отметку ставит человек,
завтра её поставит TrustMe. Меняется способ, а не смысл: в обоих случаях в
документе остаётся имя подписавшего и время. Поэтому `sign` требует имени и не
принимает пустое: договор, подписанный «кем-то», не договор.

**Пока не подписан — не проведён.** Проведение здесь означает «договор
действует»; черновик — это текст, с которым ещё не согласились.
"""

from __future__ import annotations

import frappe

from korkem_manufacturing.services.scope import scoped


def draft(*, sales_order: str, terms: str | None = None) -> dict:
	"""Собрать договор по заказу.

	Повторный вызов возвращает уже собранный: у одного заказа один договор, и
	второй с другим текстом — это спор о том, на что клиент согласился.
	"""
	frappe.only_for("System Manager")

	order = _visible_order(sales_order)

	existing = _contract_for(order.name)
	if existing:
		return {"sales_order": order.name, "contract": existing, "status": "already_drafted"}

	text = (terms or "").strip() or _default_terms(order)

	doc = frappe.get_doc(
		{
			"doctype": "Contract",
			"party_type": "Customer",
			"party_name": order.customer,
			"contract_terms": text,
			"start_date": frappe.utils.nowdate(),
			"document_type": "Sales Order",
			"document_name": order.name,
			"status": "Unsigned",
		}
	)
	doc.insert()

	return {
		"sales_order": order.name,
		"contract": doc.name,
		"customer": order.customer,
		"signed": False,
		"status": "drafted",
	}


def sign(*, contract: str, signee: str, signed_on: str | None = None) -> dict:
	"""Отметить, что договор подписан — кем и когда.

	Сегодня это делает человек, увидевший подписанную бумагу. Когда появится
	TrustMe, отметку поставит он же, тем же вызовом: смысл не меняется.
	"""
	frappe.only_for("System Manager")

	doc = _visible_contract(contract)

	signee = (signee or "").strip()
	if not signee:
		frappe.throw(
			"Назовите, кто подписал. Договор, подписанный «кем-то», — не договор."
		)

	if doc.is_signed:
		return {
			"contract": doc.name,
			"signee": doc.signee,
			"signed_on": str(doc.signed_on or ""),
			"status": "already_signed",
		}

	doc.is_signed = 1
	doc.signee = signee
	doc.signed_on = signed_on or frappe.utils.nowdate()
	doc.status = "Active"
	doc.save()
	if doc.docstatus == 0:
		doc.submit()

	return {
		"contract": doc.name,
		"sales_order": doc.document_name,
		"signee": signee,
		"signed_on": str(doc.signed_on),
		"status": "signed",
	}


def status(*, sales_order: str) -> dict:
	"""Что с договором по заказу: есть ли, подписан ли, кем."""
	order = _visible_order(sales_order)
	name = _contract_for(order.name)
	if not name:
		return {"sales_order": order.name, "contract": None, "signed": False}

	row = frappe.db.get_value(
		"Contract", name, ["name", "is_signed", "signee", "signed_on", "status"], as_dict=True
	)
	return {
		"sales_order": order.name,
		"contract": row["name"],
		"signed": bool(row["is_signed"]),
		"signee": row.get("signee"),
		"signed_on": str(row["signed_on"]) if row.get("signed_on") else None,
		"state": row.get("status"),
	}


def _default_terms(order) -> str:
	"""Текст по умолчанию — перечень того, о чём договорились.

	Не юридический договор: составить его должен юрист, и подставлять вместо
	него сочинённое приложением значило бы выдать заготовку за документ. Здесь
	перечислено то, что система знает точно, — чтобы человеку было что править,
	а не пустое поле.
	"""
	lines = [
		f"Заказ: {order.name}",
		f"Заказчик: {order.customer}",
		f"Срок поставки: {order.delivery_date}",
		f"Сумма: {frappe.utils.fmt_money(order.grand_total, currency=order.currency)}",
		"",
		"Позиции:",
	]
	lines += [
		f"  — {row.item_name or row.item_code}: {row.qty} {row.uom}"
		for row in order.items
	]
	lines += [
		"",
		"Текст договора составляется по форме вашей организации.",
		"Здесь перечислено то, о чём договорились по заказу.",
	]
	return "\n".join(lines)


def _visible_order(name: str):
	if not frappe.get_list("Sales Order", filters=scoped({"name": name}), pluck="name"):
		frappe.throw("Нет такого заказа в этой компании.", frappe.PermissionError)
	return frappe.get_doc("Sales Order", name)


def _visible_contract(name: str):
	row = frappe.db.get_value(
		"Contract", name, ["name", "document_type", "document_name"], as_dict=True
	)
	if not row:
		frappe.throw(f"Нет такого договора: «{name}».")
	if row["document_type"] == "Sales Order" and row["document_name"]:
		_visible_order(row["document_name"])
	return frappe.get_doc("Contract", name)


def _contract_for(sales_order: str) -> str | None:
	rows = frappe.get_all(
		"Contract",
		filters={
			"document_type": "Sales Order",
			"document_name": sales_order,
			"docstatus": ["<", 2],
		},
		pluck="name",
		order_by="creation desc",
		limit_page_length=1,
	)
	return rows[0] if rows else None
