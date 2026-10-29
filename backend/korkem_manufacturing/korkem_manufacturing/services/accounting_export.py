# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""«Обмен с 1С»: what the accountant loads into 1C, so nothing is typed twice.

Statutory accounting — taxes, reports, electronic invoices — stays in 1C, where
the accountant already keeps it. KORKEM does not become a second ledger; it
hands over, for a period, what happened here:

- **Реализация** — submitted sales invoices, one row per line;
- **Оплаты** — payments received and paid out;
- **Поступления** — goods received from suppliers, one row per line;
- **Ведомость** — the pay sheet (`services/payroll.py`);
- **Контрагенты** — the customers and suppliers in those documents, with БИН/ИИН,
  so 1C matches them instead of creating duplicates.

One direction, as files 1C's own «Загрузка данных из табличного документа»
reads: `;`-separated, dates `ДД.ММ.ГГГГ`, decimal comma, UTF-8 with a byte-order
mark so Excel opens it in Cyrillic. No live sync: it breaks on every 1C update,
and every client runs a different configuration. If the pilot shows a real need
for more, that is a decision for then.

**A switch, on by default** (`Accounting Export Settings.enabled`): a company
that does not keep 1C turns it off, and the screen and the endpoints say so.

Who: the administrator and accounting. The production floor sees none of it.
"""

from __future__ import annotations

import csv
import io
from datetime import date

import frappe
from frappe.utils import flt, getdate

from korkem_manufacturing.services import audit
from korkem_manufacturing.services.scope import current_company

SETTINGS = "Accounting Export Settings"
READERS = frozenset({"System Manager", "Accounts Manager", "Accounts User"})
EDITORS = frozenset({"System Manager", "Accounts Manager"})
MAX_DAYS = 93

SALES, PAYMENTS, PURCHASES, PAYROLL, PARTIES = "sales", "payments", "purchases", "payroll", "counterparties"
TABLES = {
	SALES: "Реализация",
	PAYMENTS: "Оплаты",
	PURCHASES: "Поступления",
	PAYROLL: "Ведомость",
	PARTIES: "Контрагенты",
}


def _ensure(roles: frozenset, message: str) -> None:
	if not roles.intersection(frappe.get_roles()):
		frappe.throw(message, frappe.PermissionError)


def settings() -> dict:
	_ensure(READERS, "Обмен с 1С — для администратора и бухгалтерии.")
	return {
		"enabled": _enabled(current_company()),
		"can_edit": bool(EDITORS.intersection(frappe.get_roles())),
		"tables": [{"table": key, "title": title} for key, title in TABLES.items()],
	}


def set_enabled(enabled) -> dict:
	_ensure(EDITORS, "Обмен с 1С включает и выключает администратор или главный бухгалтер.")
	company = current_company()
	enabled = bool(int(enabled)) if isinstance(enabled, str) else bool(enabled)
	doc = frappe.get_doc(SETTINGS, company) if frappe.db.exists(SETTINGS, company) else frappe.new_doc(SETTINGS)
	doc.company = company
	doc.enabled = 1 if enabled else 0
	doc.save(ignore_permissions=True)
	audit.record_audit(action="accounting.one_c_switched", entity_type=SETTINGS, entity_id=company, diff={"enabled": enabled})
	return settings()


def export(table: str, from_date: str | None = None, to_date: str | None = None) -> dict:
	"""One table for the period, as text 1C loads. Refused while the switch is off."""
	_ensure(READERS, "Обмен с 1С — для администратора и бухгалтерии.")
	company = current_company()
	if not _enabled(company):
		frappe.throw("Обмен с 1С выключен в настройках.")
	if table not in TABLES:
		frappe.throw(f"Таблица — одна из: {', '.join(TABLES)}.")
	start, end = _period(from_date, to_date)
	header, rows = _BUILDERS[table](company, start, end)
	audit.record_audit(
		action="accounting.one_c_exported",
		entity_type="Company",
		entity_id=company,
		diff={"table": table, "from_date": str(start), "to_date": str(end), "rows": len(rows)},
	)
	return {
		"table": table,
		"title": TABLES[table],
		"rows": len(rows),
		"filename": f"1c_{table}_{start:%Y%m%d}_{end:%Y%m%d}.csv",
		"csv": _csv(header, rows),
	}


# --------------------------------------------------------------------------
# Tables
# --------------------------------------------------------------------------


def _sales(company: str, start: date, end: date):
	header = ["Дата", "Номер", "Контрагент", "БИН/ИИН", "Номенклатура", "Код", "Ед.", "Количество", "Цена",
			  "Сумма", "Заказ", "Возврат"]
	invoices = _documents("Sales Invoice", company, start, end, ["customer", "customer_name", "is_return"])
	lines = _lines("Sales Invoice Item", [i.name for i in invoices], ["sales_order"])
	ids = _tax_ids("Customer", {i.customer for i in invoices})
	rows = []
	for inv in invoices:
		for line in lines.get(inv.name, []):
			rows.append([
				_day(inv.posting_date), inv.name, inv.customer_name or inv.customer, ids.get(inv.customer, ""),
				line.item_name or line.item_code, line.item_code, line.uom, _num(line.qty, 3), _num(line.rate),
				_num(line.amount), line.sales_order or "", "Да" if inv.is_return else "",
			])
	return header, rows


def _payments(company: str, start: date, end: date):
	header = ["Дата", "Номер", "Вид", "Контрагент", "БИН/ИИН", "Сумма", "Способ оплаты", "Номер платежа",
			  "Дата платежа", "Основание"]
	entries = frappe.get_all(
		"Payment Entry",
		filters={"company": company, "docstatus": 1, "posting_date": ["between", [start, end]],
				 "payment_type": ["in", ["Receive", "Pay"]]},
		fields=["name", "posting_date", "payment_type", "party_type", "party", "party_name", "paid_amount",
				"received_amount", "mode_of_payment", "reference_no", "reference_date"],
		order_by="posting_date asc, name asc",
		limit_page_length=0,
	)
	refs: dict[str, list[str]] = {}
	for r in frappe.get_all(
		"Payment Entry Reference",
		filters={"parent": ["in", [e.name for e in entries] or [""]], "parenttype": "Payment Entry"},
		fields=["parent", "reference_name"],
		limit_page_length=0,
	):
		refs.setdefault(r.parent, []).append(r.reference_name)
	ids = {
		**_tax_ids("Customer", {e.party for e in entries if e.party_type == "Customer"}),
		**_tax_ids("Supplier", {e.party for e in entries if e.party_type == "Supplier"}),
	}
	rows = [
		[
			_day(e.posting_date), e.name, "Поступление" if e.payment_type == "Receive" else "Выплата",
			e.party_name or e.party or "", ids.get(e.party, ""),
			_num(e.received_amount if e.payment_type == "Receive" else e.paid_amount),
			e.mode_of_payment or "", e.reference_no or "", _day(e.reference_date) if e.reference_date else "",
			", ".join(refs.get(e.name, [])),
		]
		for e in entries
	]
	return header, rows


def _purchases(company: str, start: date, end: date):
	header = ["Дата", "Номер", "Поставщик", "БИН/ИИН", "Номенклатура", "Код", "Ед.", "Количество", "Цена",
			  "Сумма", "Заказ поставщику"]
	receipts = _documents("Purchase Receipt", company, start, end, ["supplier", "supplier_name"])
	lines = _lines("Purchase Receipt Item", [r.name for r in receipts], ["purchase_order"])
	ids = _tax_ids("Supplier", {r.supplier for r in receipts})
	rows = []
	for rec in receipts:
		for line in lines.get(rec.name, []):
			rows.append([
				_day(rec.posting_date), rec.name, rec.supplier_name or rec.supplier, ids.get(rec.supplier, ""),
				line.item_name or line.item_code, line.item_code, line.uom, _num(line.qty, 3), _num(line.rate),
				_num(line.amount), line.purchase_order or "",
			])
	return header, rows


def _payroll(company: str, start: date, end: date):
	from korkem_manufacturing.services import payroll

	header = ["Сотрудник", "Сдельно", "Премии", "Штрафы", "Авансы", "К выплате", "Выплачено", "Остаток"]
	sheet = payroll.statement(str(start), str(end))
	rows = [
		[
			r["employee_name"], _num(r["piece"]), _num(r["daily_bonus"] + r["monthly_bonus"] + r["bonus"]),
			_num(r["fine"]), _num(r["advance"]), _num(r["to_pay"]), _num(r.get("paid", 0)), _num(r.get("left", r["to_pay"])),
		]
		for r in sheet["rows"]
	]
	return header, rows


def _parties(company: str, start: date, end: date):
	header = ["Вид", "Наименование", "БИН/ИИН", "Код в KORKEM"]
	customers = {i.customer for i in _documents("Sales Invoice", company, start, end, ["customer"])}
	suppliers = {r.supplier for r in _documents("Purchase Receipt", company, start, end, ["supplier"])}
	for e in frappe.get_all(
		"Payment Entry",
		filters={"company": company, "docstatus": 1, "posting_date": ["between", [start, end]]},
		fields=["party_type", "party"],
		limit_page_length=0,
	):
		if e.party_type == "Customer":
			customers.add(e.party)
		elif e.party_type == "Supplier":
			suppliers.add(e.party)
	rows = []
	for doctype, kind, names, name_field in (
		("Customer", "Покупатель", customers, "customer_name"),
		("Supplier", "Поставщик", suppliers, "supplier_name"),
	):
		for p in frappe.get_all(
			doctype,
			filters={"name": ["in", sorted(n for n in names if n) or [""]]},
			fields=["name", name_field, "tax_id"],
			order_by=f"{name_field} asc",
			limit_page_length=0,
		):
			rows.append([kind, p.get(name_field) or p.name, p.tax_id or "", p.name])
	return header, rows


_BUILDERS = {SALES: _sales, PAYMENTS: _payments, PURCHASES: _purchases, PAYROLL: _payroll, PARTIES: _parties}


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------


def _enabled(company: str) -> bool:
	value = frappe.db.get_value(SETTINGS, company, "enabled")
	return True if value is None else bool(value)


def _period(from_date, to_date) -> tuple[date, date]:
	from frappe.utils import get_first_day, nowdate

	end = getdate(to_date) if to_date else getdate(nowdate())
	start = getdate(from_date) if from_date else get_first_day(end)
	if start > end:
		frappe.throw("Начало периода позже конца.")
	if (end - start).days > MAX_DAYS:
		frappe.throw(f"Период — не длиннее {MAX_DAYS} дней.")
	return start, end


def _documents(doctype: str, company: str, start: date, end: date, fields: list[str]):
	return frappe.get_all(
		doctype,
		filters={"company": company, "docstatus": 1, "posting_date": ["between", [start, end]]},
		fields=["name", "posting_date", *fields],
		order_by="posting_date asc, name asc",
		limit_page_length=0,
	)


def _lines(doctype: str, parents: list[str], extra: list[str]) -> dict[str, list]:
	result: dict[str, list] = {}
	for line in frappe.get_all(
		doctype,
		filters={"parent": ["in", parents or [""]]},
		fields=["parent", "idx", "item_code", "item_name", "uom", "qty", "rate", "amount", *extra],
		order_by="parent asc, idx asc",
		limit_page_length=0,
	):
		result.setdefault(line.parent, []).append(line)
	return result


def _tax_ids(doctype: str, names: set) -> dict[str, str]:
	names = sorted(n for n in names if n)
	if not names:
		return {}
	return {
		r.name: r.tax_id or ""
		for r in frappe.get_all(doctype, filters={"name": ["in", names]}, fields=["name", "tax_id"], limit_page_length=0)
	}


def _day(value) -> str:
	return getdate(value).strftime("%d.%m.%Y") if value else ""


def _num(value, digits: int = 2) -> str:
	"""A number as 1C and Excel read it in Kazakhstan: decimal comma, no grouping."""
	return f"{flt(value):.{digits}f}".replace(".", ",")


def _csv(header: list[str], rows: list[list]) -> str:
	buffer = io.StringIO()
	writer = csv.writer(buffer, delimiter=";", lineterminator="\r\n")
	writer.writerow(header)
	writer.writerows(rows)
	return "﻿" + buffer.getvalue()
