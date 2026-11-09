# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Заказы МДФ — тонкая обёртка над services/mdf_orders.py."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import mdf_orders as service

#: How the owner's customers pay (09.11.2026): перевод and карта name a bank
#: from the «Банк» list (Kaspi, Halyk, Forte …), наличные do not.
PAYMENT_METHODS = ("Перевод", "Наличные", "Карта")
WITH_BANK = ("Перевод", "Карта")
#: What an older app sends: «Kaspi» was a method before banks were.
LEGACY_METHODS = {"Kaspi": ("Перевод", "Kaspi")}


@frappe.whitelist(methods=["POST"])
def price(lines: str | list, finish: str | None = None, default_rate: float | str | None = None,
		  film_rates: str | dict | None = None) -> dict:
	"""Посчитать позиции, ничего не сохраняя — для мгновенного пересчёта на экране."""
	from korkem_manufacturing.services import facade_prices

	facade_prices.ensure_editor()
	return service.price(lines, finish=finish, default_rate=default_rate, film_rates=film_rates)


@frappe.whitelist(methods=["POST"])
def save_draft(customer: str, delivery_date: str, head: str | dict | None = None, lines: str | list | None = None,
			   order: str | None = None,
			   notes: str | None = None) -> dict:
	return service.save_draft(customer=customer, delivery_date=delivery_date, head=head, lines=lines,
							  order=order, notes=notes)


@frappe.whitelist(methods=["POST"])
def accept(order: str) -> dict:
	return service.accept(order)


@frappe.whitelist(methods=["POST"])
def change_order(order: str, lines: str | list, reason: str, head: str | dict | None = None,
				 delivery_date: str | None = None) -> dict:
	"""Изменить принятый заказ: позиции (и шапку, срок) с причиной в истории."""
	return service.change_order(order, lines=lines, reason=reason, head=head, delivery_date=delivery_date)


@frappe.whitelist(methods=["POST"])
def delete_draft(order: str) -> dict:
	return service.delete_draft(order)


@frappe.whitelist(methods=["POST"])
def cancel(order: str, reason: str) -> dict:
	return service.cancel(order, reason)


@frappe.whitelist(methods=["POST"])
def set_stage(order: str, stage: str, done: bool | int | str = 1, worker: str | None = None) -> dict:
	return service.set_stage(order, stage, done, worker=worker)


@frappe.whitelist(methods=["POST"])
def extra_stage(order: str, stage: str, on: bool | int | str = 1) -> dict:
	"""«+ этап» для переделки: краска или вакуум, которых нет у покрытия заказа."""
	return service.extra_stage(order, stage, on)


@frappe.whitelist(methods=["POST"])
def hold(order: str, reason: str | None = None) -> dict:
	return service.hold(order, reason)


@frappe.whitelist(methods=["POST"])
def hand_over(order: str, comment: str | None = None, taken_by: str | None = None,
			  taken_phone: str | None = None) -> dict:
	return service.hand_over(order, comment, taken_by=taken_by, taken_phone=taken_phone)


@frappe.whitelist(methods=["POST"])
def return_to_work(order: str, reason: str) -> dict:
	return service.return_to_work(order, reason)


@frappe.whitelist(methods=["GET"])
def card(order: str) -> dict:
	return service.card(order)


@frappe.whitelist(methods=["GET"])
def listing(search: str | None = None, status: str | None = None, overdue: bool | int | str = 0,
			with_debt: bool | int | str = 0, start: int = 0, limit: int = 50, tag: str | None = None) -> dict:
	return service.listing(search=search, status=status, overdue=overdue, with_debt=with_debt,
						   start=start, limit=limit, tag=tag)


@frappe.whitelist(methods=["POST"])
def new_customer(name: str, phone: str | None = None) -> dict:
	return service.new_customer(name, phone)


@frappe.whitelist(methods=["GET"])
def film_shortage() -> dict:
	"""Плёнка: сколько нужно по открытым заказам и сколько докупить."""
	from korkem_manufacturing.services import film_shortage as films

	return films.shortage()


@frappe.whitelist(methods=["GET"])
def debts(since: str | None = None, until: str | None = None) -> dict:
	"""Долги: по заказам и по клиентам."""
	return service.debts(since=since, until=until)


@frappe.whitelist(methods=["GET"])
def batch(decor: str | None = None, milling: str | None = None, include_in_shop: bool | int | str = 1) -> dict:
	"""Все детали открытых заказов одной плёнки (и фрезы) одним списком."""
	return service.batch(decor=decor, milling=milling, include_in_shop=include_in_shop)


@frappe.whitelist(methods=["GET"])
def plan(days: int | str = 14) -> dict:
	"""Жоспар: очередь каждого этапа с м² и приём заказов по дням."""
	return service.plan(days=int(days or 14))


@frappe.whitelist(methods=["GET"])
def cash(since: str | None = None, until: str | None = None) -> dict:
	"""Касса: оплаты по дням и способам, одобренные расходы, остаток за период."""
	from korkem_manufacturing.services import mdf_cash

	return mdf_cash.cash(since=since, until=until)


@frappe.whitelist(methods=["GET"])
def report(since: str | None = None, until: str | None = None) -> dict:
	"""Отчёт по заказам за период: сколько, м², сумма, оплачено, долг; по статусам, плёнкам, клиентам."""
	from korkem_manufacturing.services import mdf_report

	return mdf_report.report(since=since, until=until)


@frappe.whitelist(methods=["GET"])
def volume(since: str | None = None, until: str | None = None) -> dict:
	"""Объём работ: м² и заказы по сотрудникам и этапам за период."""
	from korkem_manufacturing.services import mdf_volume

	return mdf_volume.volume(since=since, until=until)


@frappe.whitelist(methods=["GET"])
def workers() -> list[dict]:
	"""Кого можно указать исполнителем этапа: активные сотрудники компании."""
	from korkem_manufacturing.services import mdf_volume

	return mdf_volume.workers()


@frappe.whitelist(methods=["GET"])
def dictionaries() -> dict:
	"""Справочники бланка: толщина, покрытие, цвет плёнки, патина, фрезеровка, кромка."""
	from korkem_manufacturing.services import mdf_dictionaries

	return mdf_dictionaries.dictionaries()


@frappe.whitelist(methods=["POST"])
def dictionary_add(kind: str, value: str) -> dict:
	from korkem_manufacturing.services import mdf_dictionaries

	return mdf_dictionaries.add(kind, value)


@frappe.whitelist(methods=["POST"])
def dictionary_rename(kind: str, option: str, value: str) -> dict:
	from korkem_manufacturing.services import mdf_dictionaries

	return mdf_dictionaries.rename(kind, option, value)


@frappe.whitelist(methods=["POST"])
def dictionary_remove(kind: str, option: str) -> dict:
	from korkem_manufacturing.services import mdf_dictionaries

	return mdf_dictionaries.remove(kind, option)


@frappe.whitelist(methods=["GET"])
def customer_list() -> list[dict]:
	"""Справочник клиентов: имя, телефон, организация."""
	from korkem_manufacturing.services import mdf_customers

	return mdf_customers.customers()


@frappe.whitelist(methods=["POST"])
def customer_add(name: str, phone: str | None = None, organization: str | None = None,
				 tags: str | list | None = None) -> dict:
	from korkem_manufacturing.services import mdf_customers

	return mdf_customers.add(name, phone, organization, tags)


@frappe.whitelist(methods=["POST"])
def customer_update(customer: str, name: str, phone: str | None = None, organization: str | None = None,
					tags: str | list | None = None) -> dict:
	from korkem_manufacturing.services import mdf_customers

	return mdf_customers.update(customer, name, phone, organization, tags)


@frappe.whitelist(methods=["POST"])
def customer_remove(customer: str) -> dict:
	from korkem_manufacturing.services import mdf_customers

	return mdf_customers.remove(customer)


@frappe.whitelist(methods=["GET"])
def last_head() -> dict:
	return service.last_head()


@frappe.whitelist(methods=["GET"])
def stages_for(finish: str | None = None) -> list[str]:
	return service.stages_for(finish)


@frappe.whitelist(methods=["POST"])
def add_payment(order: str, amount: float | str, method: str = "Перевод", paid_on: str | None = None,
				idempotency_key: str | None = None, bank: str | None = None) -> dict:
	"""Оплата по заказу: сумма, способ (и банк перевода или карты), дата."""
	from korkem_manufacturing.services import facade_prices, payments

	facade_prices.ensure_editor()
	method, bank = _method_bank(method, bank)
	doc = service._accepted(order)
	payments.record_payment(
		sales_order=doc.name,
		amount=amount,
		payment_type="Deposit" if not service._debt(doc) or float(doc.advance_paid or 0) == 0 else "Final",
		mode_of_payment=method,
		bank=bank,
		paid_on=paid_on,
		idempotency_key=idempotency_key,
	)
	from korkem_manufacturing.services import mdf_payments

	doc.add_comment("Comment", f"Оплата: {mdf_payments._words(float(amount), method, bank)}.")
	return service.card(doc.name)


@frappe.whitelist(methods=["POST"])
def fix_payment(order: str, entry: str, reason: str, amount: float | str, method: str,
				bank: str | None = None) -> dict:
	"""A payment entered wrong: cancelled and entered again (owner, 09.11.2026)."""
	from korkem_manufacturing.services import facade_prices, mdf_payments

	facade_prices.ensure_editor()
	reason = service._reason(reason, "Укажите, почему оплата исправляется.")
	method, bank = _method_bank(method, bank)
	doc = service._accepted(order)
	mdf_payments.fix(doc, entry, reason=reason, amount=amount, method=method, bank=bank)
	return service.card(doc.name)


@frappe.whitelist(methods=["POST"])
def delete_payment(order: str, entry: str, reason: str) -> dict:
	from korkem_manufacturing.services import facade_prices, mdf_payments

	facade_prices.ensure_editor()
	reason = service._reason(reason, "Укажите, почему оплата удаляется.")
	doc = service._accepted(order)
	mdf_payments.delete(doc, entry, reason=reason)
	return service.card(doc.name)


def _method_bank(method: str, bank: str | None) -> tuple[str, str | None]:
	"""One of the three methods, and the bank from the «Банк» list for a transfer or a card."""
	from korkem_manufacturing.services import facade_spec
	from korkem_manufacturing.services.scope import current_company

	if method in LEGACY_METHODS:
		method, bank = LEGACY_METHODS[method][0], bank or LEGACY_METHODS[method][1]
	if method not in PAYMENT_METHODS:
		frappe.throw(f"Способ оплаты — один из: {', '.join(PAYMENT_METHODS)}.")
	bank = facade_spec._text(bank) if method in WITH_BANK else None
	if bank:
		banks = facade_spec._values("Банк", current_company())
		if banks and bank not in banks and bank not in {b for _, b in LEGACY_METHODS.values()}:
			frappe.throw(f"Банка «{bank}» нет в справочнике «Банк».")
	_ensure_mode(method)
	return method, bank


def _ensure_mode(method: str) -> None:
	if frappe.db.exists("Mode of Payment", method):
		return
	frappe.get_doc(
		{"doctype": "Mode of Payment", "mode_of_payment": method, "type": "Cash" if method == "Наличные" else "Bank",
		 "enabled": 1}
	).insert(ignore_permissions=True)
