# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Реквизиты компании — то, что печатается в договоре и в накладной.

Пункт плана «администрирование без админки»: сегодня завести БИН и счёт можно
только через панель ERPNext, а каждый раз, когда владелец её открывает, это
дефект продукта, а не особенность настройки.

**Ничего своего здесь не заводится.** ERPNext уже хранит всё это, просто
в четырёх местах, и в каждом — по делу:

* БИН — `Company.tax_id`. Это поле налогового номера, а БИН и есть налоговый
  номер юридического лица в Казахстане. Своё поле означало бы два места, где
  написан один номер, и печатные формы ERPNext знают только это.
* Телефон, почта, сайт — на самой `Company`.
* Адрес — `Address`, привязанный к компании. Туда же, куда ложится адрес
  клиента на замере, и по той же причине: адрес нужен документам, а не ленте.
* Банк — `Bank Account` с `iban` и `branch_code`. БИК живёт в `branch_code`,
  потому что это он и есть: код отделения банка.

**Счёт заводится как реквизит, а не как счёт в бухгалтерии.** У ERPNext признак
`is_company_account` требует счёта в плане счетов, потому что означает «по этому
счёту ведётся учёт»: с него пойдут проводки и сверки. Владельцу сейчас нужно
другое — чтобы номер напечатался в договоре. Включить учёт можно потом, одним
полем, и это отдельное решение с отдельными последствиями; делать его молча за
владельца, когда он вписал IBAN, нельзя.

**Неполное сохраняется.** Владелец заводит реквизиты по частям: сегодня адрес,
завтра, когда откроет счёт, — банк. Требовать всё сразу значит не дать записать
ничего.

**Но записанное проверяется.** БИН из одиннадцати цифр в договоре — это
переподписание, а не опечатка, и стоит оно дороже, чем отказ в форме.
"""

from __future__ import annotations

import re

import frappe

from korkem_manufacturing.services.scope import current_company

#: БИН и ИИН в Казахстане — ровно двенадцать цифр.
BIN_LENGTH = 12

#: IBAN Казахстана: KZ и ещё восемнадцать знаков. Это ранняя проверка формы, а
#: не последнее слово: контрольную сумму по mod-97 считает сам ERPNext при
#: сохранении `Bank Account`, и он в этом авторитет. Здесь она нужна затем, что
#: «KZ и 18 знаков» человек понимает, а «is not a valid IBAN» из ERPNext ничего
#: ему не говорит о том, что именно исправить.
IBAN_PATTERN = re.compile(r"^KZ[0-9A-Z]{18}$")


def read() -> dict:
	"""Что записано о компании сейчас."""
	company = frappe.get_doc("Company", current_company())
	address = _address_of(company.name)
	bank = _bank_account_of(company.name)

	return {
		"company": company.name,
		"name": company.company_name,
		"bin": company.tax_id,
		"phone": company.phone_no,
		"email": company.email,
		"website": company.website,
		"address": address.get("address_line1") if address else None,
		"city": address.get("city") if address else None,
		"bank_name": bank.get("bank") if bank else None,
		"bank_account": bank.get("iban") if bank else None,
		"bik": bank.get("branch_code") if bank else None,
	}


def save(
	*,
	bin: str | None = None,
	phone: str | None = None,
	email: str | None = None,
	website: str | None = None,
	address: str | None = None,
	city: str | None = None,
	bank_name: str | None = None,
	bank_account: str | None = None,
	bik: str | None = None,
) -> dict:
	"""Записать реквизиты. Пустое поле означает «пока не знаю», а не «стереть»."""
	frappe.only_for("System Manager")

	company = frappe.get_doc("Company", current_company())

	if bin:
		company.tax_id = _checked_bin(bin)
	if phone:
		company.phone_no = phone.strip()
	if email:
		company.email = email.strip()
	if website:
		company.website = website.strip()
	company.save()

	if address:
		_write_address(company, address, city)

	if bank_account or bank_name or bik:
		_write_bank_account(company, bank_name, bank_account, bik)

	return read()


def _checked_bin(value: str) -> str:
	digits = value.strip()
	if not digits.isdigit() or len(digits) != BIN_LENGTH:
		frappe.throw(
			f"БИН — это {BIN_LENGTH} цифр. Неверный БИН в договоре означает "
			"переподписание, а не опечатку."
		)
	return digits


def _checked_iban(value: str) -> str:
	iban = value.replace(" ", "").upper()
	if not IBAN_PATTERN.match(iban):
		frappe.throw(
			"Счёт не похож на казахстанский IBAN: KZ и ещё 18 знаков. "
			"Деньги по неверному счёту уходят не туда и возвращаются неделями."
		)
	return iban


def _address_of(company: str) -> dict | None:
	names = frappe.get_all(
		"Dynamic Link",
		filters={
			"link_doctype": "Company",
			"link_name": company,
			"parenttype": "Address",
		},
		parent_doctype="Address",
		pluck="parent",
	)
	if not names:
		return None
	rows = frappe.get_all(
		"Address",
		filters={"name": ["in", names]},
		fields=["name", "address_line1", "city"],
		order_by="modified desc",
		limit_page_length=1,
	)
	return rows[0] if rows else None


def _bank_account_of(company: str) -> dict | None:
	rows = frappe.get_all(
		"Bank Account",
		filters={"company": company, "party_type": ["is", "not set"]},
		fields=["name", "bank", "iban", "branch_code"],
		order_by="modified desc",
		limit_page_length=1,
	)
	return rows[0] if rows else None


def _write_address(company, line: str, city: str | None) -> None:
	existing = _address_of(company.name)
	if existing:
		doc = frappe.get_doc("Address", existing["name"])
	else:
		doc = frappe.get_doc(
			{
				"doctype": "Address",
				"address_title": company.company_name,
				"address_type": "Billing",
				"links": [{"link_doctype": "Company", "link_name": company.name}],
			}
		)
	doc.address_line1 = line.strip()
	if city:
		doc.city = city.strip()
	doc.save() if existing else doc.insert()


def _write_bank_account(company, bank_name, iban, bik) -> None:
	"""Счёт компании — один. Второй завёлся бы молча и попал бы в накладную."""
	existing = _bank_account_of(company.name)
	if existing:
		doc = frappe.get_doc("Bank Account", existing["name"])
	else:
		if not bank_name:
			frappe.throw("Назовите банк: счёт без банка в платёжку не поставить.")
		doc = frappe.get_doc(
			{
				"doctype": "Bank Account",
				"account_name": company.company_name,
				"company": company.name,
			}
		)

	if bank_name:
		doc.bank = _bank(bank_name)
	if iban:
		doc.iban = _checked_iban(iban)
	if bik:
		doc.branch_code = bik.strip()

	doc.flags.ignore_mandatory = True
	doc.save() if existing else doc.insert()


def _bank(name: str) -> str:
	"""Банк как справочник ERPNext — чтобы у трёх компаний он был один."""
	name = name.strip()
	if not frappe.db.exists("Bank", name):
		frappe.get_doc({"doctype": "Bank", "bank_name": name}).insert()
	return name
