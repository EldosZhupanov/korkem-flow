# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Расходы цеха — статьи затрат, счета за месяц, расходники и «Куда идут
деньги». Тонкая обёртка над services/cost_items, cost_bills, consumables,
money_flow."""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import consumables, cost_bills, cost_items, money_flow


@frappe.whitelist(methods=["GET"])
def items(search: str | None = None, archived: int | str = 0) -> dict:
	"""Статьи затрат по группам; archived=1 — и архивные."""
	return cost_items.listing(search, archived)


@frappe.whitelist(methods=["POST"])
def add_item(title: str, group: str, mode: str = "other", behaviour: str = "variable", area: str | None = None,
			 unit: str | None = None, monthly_limit: float | str | None = None) -> dict:
	"""Новая статья. mode: bill (счёт за месяц), stock (расходник на складе), other (по факту)."""
	return cost_items.add(title, group, mode, behaviour, area, unit, monthly_limit)


@frappe.whitelist(methods=["POST"])
def quick_add(title: str, unit: str | None = None) -> dict:
	"""Расходник, которого нет в списке, — с цеха; помечается новым."""
	return cost_items.quick_add(title, unit)


@frappe.whitelist(methods=["POST"])
def edit_item(name: str, title: str | None = None, group: str | None = None, mode: str | None = None,
			  behaviour: str | None = None, area: str | None = None, unit: str | None = None,
			  monthly_limit: float | str | None = None) -> dict:
	"""Переименовать, перенести, поменять лимит."""
	changes = {k: v for k, v in {"title": title, "group": group, "mode": mode, "behaviour": behaviour, "area": area,
								 "unit": unit, "monthly_limit": monthly_limit}.items() if v is not None}
	return cost_items.edit(name, **changes)


@frappe.whitelist(methods=["POST"])
def archive_item(name: str, archived: int | str = 1) -> dict:
	"""В архив (история остаётся) или обратно."""
	return cost_items.archive(name, archived)


@frappe.whitelist(methods=["POST"])
def merge_items(source: str, target: str) -> dict:
	"""Две одинаковые статьи — в одну, с историей."""
	return cost_items.merge(source, target)


@frappe.whitelist(methods=["GET"])
def bills(month: str | None = None) -> dict:
	"""Счета за месяц; незаполненные — с суммой прошлого месяца рядом."""
	return cost_bills.month(month)


@frappe.whitelist(methods=["POST"])
def put_bill(item: str, month: str, amount: float | str, meter_from: float | str | None = None,
			 meter_to: float | str | None = None, note: str | None = None) -> dict:
	"""Внести или поправить счёт за месяц."""
	return cost_bills.put(item, month, amount, meter_from, meter_to, note)


@frappe.whitelist(methods=["GET"])
def consumable_list() -> dict:
	"""Расходники: сколько на полке, минимум, сколько взяли за месяц."""
	return consumables.listing()


@frappe.whitelist(methods=["POST"])
def take(item: str, qty: float | str, note: str | None = None) -> dict:
	"""Взял со склада."""
	return consumables.take(item, qty, note)


@frappe.whitelist(methods=["POST"])
def receive(item: str, qty: float | str, price: float | str, supplier: str | None = None) -> dict:
	"""Купили — на склад по цене."""
	return consumables.receive(item, qty, price, supplier)


@frappe.whitelist(methods=["POST"])
def set_minimum(item: str, minimum: float | str) -> dict:
	"""Минимум: ниже — пора покупать."""
	return consumables.set_minimum(item, minimum)


@frappe.whitelist(methods=["GET"])
def money(month: str | None = None) -> dict:
	"""Куда идут деньги за месяц: группы, статьи, участки, 1 м², безубыточность, план-факт."""
	return money_flow.month(month)
