# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""A small, real furniture dataset for the KORKEM company.

## Why this exists

The bench arrives full of ERPNext's own fixtures — `_Test Company`, 209 `_Test`
BOMs, 41 draft Sales Orders belonging to none of it. None of that describes a
furniture factory, and the assistant cannot be shown answering a question about
production when there is no production to answer about: every Bin row for a real
item reads zero.

So this seeds one honest slice of a cabinet shop: two products, six items, real
stock, and three submitted orders — one running and short of board, one running
and overdue, one nobody has started. Small enough to read in one screen,
complete enough that "can we start this order?" has a real answer with a real
shortage in it, and that "what is happening in production?" has more than one
state to describe.

## What it is not

It is **demo data and says so** — every record carries `KORKEM demo` in its
description or title, and `remove()` deletes exactly what `seed()` created.
Nothing here is invented in the sense that matters: the schema, the field names
and the workflow are ERPNext's own, verified against this bench. Only the
*quantities* are chosen, and they are chosen to produce a shortage worth
looking at.

## Where it refuses to run

`remove()` cancels and deletes every Sales Order, Work Order and Stock Entry
belonging to the customers and products it knows about. On a developer's bench
that is a teardown; on a furniture business's real site it would be
indistinguishable from an attack, and nothing about the call would look
different.

So every entry point here — the ones that create as much as the ones that delete
— asks `environment.require_non_production` first, and a site labelled `pilot`
or `production` refuses. The import is deliberately a hard one: if `korkem_ai`
is missing, this module fails to load rather than seeding without a guard.

Run:
    bench --site korkem.localhost execute \
        korkem_manufacturing.seed_demo.seed
"""

from __future__ import annotations

import frappe
from frappe.utils import add_days, flt, nowdate

from korkem_ai.korkem_ai import environment

COMPANY = "KORKEM"
ABBR = "KRK"
STORES = f"Stores - {ABBR}"
WIP = f"Work In Progress - {ABBR}"
FINISHED = f"Finished Goods - {ABBR}"

MARKER = "KORKEM demo"
ITEM_GROUP = "KORKEM Demo"

#: The Sprint 1 sample product from `setup.py`. Its item and BOM are still used
#: by the end-to-end test; a work order for it is not part of this factory.
LEGACY_ITEM = "Kitchen Facade"

#: Sheets are cut, so a cabinet consumes part of one.
#:
#: ERPNext refuses a fractional quantity on `Nos`, which is marked "must be a
#: whole number" — a real constraint, and the right one for hinges. Board is
#: not counted that way on a shop floor, so it gets a unit that can hold 4.2.
SHEET_UOM = "Лист"

#: The cabinet, and what one of it takes.
#:
#: 4.2 sheets per cabinet is deliberate: ten cabinets need 42 and the shop has
#: 38, so the readiness answer has a real shortage in it rather than a tidy
#: "everything is fine" that would prove nothing.
PRODUCT = "Шкаф Астана"
MATERIALS = [
	# (item_code, uom, per cabinet, on hand)
	("ДСП 16мм", SHEET_UOM, 4.2, 38),
	("Кромка 2мм", "Meter", 18.0, 240),
	("Петля", "Nos", 4.0, 52),
]

ORDER_QTY = 10
PRODUCED_QTY = 6

CUSTOMER = "Мебель Астана"

#: A second product, deliberately well stocked and on *different* materials.
#:
#: The point of the extra orders is to give the production overview more than
#: one state to describe. Putting them on the same board would change what is
#: reserved against it, and the four-sheet shortage that the whole procurement
#: slice is built on would quietly become some other number.
PRODUCT_B = "Тумба Караганда"
MATERIALS_B = [
	("ЛДСП 18мм", SHEET_UOM, 2.0, 200),
	("Ручка", "Nos", 2.0, 300),
]

#: One order per production situation worth reporting on.
#:
#: `produced` of `None` means no work order at all — an order nobody has
#: started, which is a different answer to "what is happening in production"
#: than one that is running.
LINES = (
	# product, materials, customer, qty, produced, delivery in N days
	(PRODUCT, MATERIALS, CUSTOMER, ORDER_QTY, PRODUCED_QTY, 14),
	(PRODUCT_B, MATERIALS_B, "Караганда Мебель", 20, 5, -3),
	(PRODUCT_B, MATERIALS_B, "Павлодар Уют", 5, None, 21),
)


#: The shop floor, in the order a cabinet moves through it.
#:
#: Seven operations, four workstations. Times are per unit and are the numbers
#: this factory would quote: twelve minutes on the saw, eight on the edgebander,
#: fifteen on the CNC. They are chosen, like every quantity here — but they are
#: internally consistent, so «какая загрузка цеха» and «что запускать первым»
#: have arithmetic to work with rather than placeholders.
#:
#: Workstations carry ERPNext's own capacity mechanics: working hours, hourly
#: rate, and how many jobs run at once. Nothing here is a second scheduler.
WORKSTATIONS = {
	# name: (labour rate KZT/hour, jobs in parallel, hours per day)
	"Раскрой": (4500, 1, 8),
	"Кромка и сверловка": (3800, 2, 8),
	"ЧПУ": (7200, 1, 8),
	"Покраска и сборка": (3200, 2, 8),
}

#: (operation, workstation, minutes per unit) — the order a cabinet moves in.
ROUTING_STEPS = [
	("Раскрой", "Раскрой", 12),
	("Кромление", "Кромка и сверловка", 8),
	("ЧПУ обработка", "ЧПУ", 15),
	("Сверление", "Кромка и сверловка", 6),
	("Покраска", "Покраска и сборка", 20),
	("Сборка", "Покраска и сборка", 25),
	("ОТК", "Покраска и сборка", 5),
]

ROUTING_NAME = "KORKEM Мебельный цех"

#: The one operation the shop actually inspects. ОТК is the quality department
#: — it is the step that exists to check the work, so it is the step ERPNext is
#: told to gate on.
INSPECTED_STEP = "ОТК"

#: Where a spoiled piece goes when it can be saved.
#:
#: Marked `is_corrective_operation`, which is what ERPNext requires of a rework
#: step: its job cards carry the cost of poor quality and never production
#: quantity. It is deliberately **not** in `ROUTING_STEPS` — rework is not a
#: stage every cabinet passes through, it is what happens when one fails.
CORRECTIVE_STEP = "Исправление брака"
CORRECTIVE_WORKSTATION = "Покраска и сборка"


#: What the hourly rate is booked against. One component is enough for a shop
#: this size; ERPNext allows several (labour, electricity, rent) and sums them.
COST_COMPONENT = "Работа"


def _cost_component() -> str:
	if not frappe.db.exists("Workstation Operating Component", COST_COMPONENT):
		doc = frappe.new_doc("Workstation Operating Component")
		doc.component_name = COST_COMPONENT
		doc.insert(ignore_permissions=True)
	return COST_COMPONENT


def _valuation_account():
	"""Where the routing's operating cost lands when goods are manufactured.

	A Manufacture entry carries the work order's operating cost — real money,
	because Phase 18 gave the workstations real hourly rates — as an additional
	cost row, and ERPNext requires an account for it. `KORKEM` was created
	without one, so every Manufacture failed with a bare "Account is required"
	*after* the stock ledger had already posted.

	The account exists in the chart of accounts with the right type; it was
	simply never assigned to the company. This is ordinary ERPNext setup for a
	manufacturer running perpetual inventory, not a workaround.
	"""
	account = frappe.db.get_value(
		"Account",
		{"company": COMPANY, "account_type": "Expenses Included In Valuation", "is_group": 0},
		"name",
	)
	if not account:
		return

	if not frappe.db.get_value("Company", COMPANY, "default_operating_cost_account"):
		frappe.db.set_value(
			"Company", COMPANY, "default_operating_cost_account", account, update_modified=False
		)

	# The cost component itself carries the account in ERPNext 17, and the one
	# created with the workstations had none — which is the actual gap.
	if frappe.db.exists("Workstation Operating Component", COST_COMPONENT):
		component = frappe.get_doc("Workstation Operating Component", COST_COMPONENT)
		if not any(row.company == COMPANY for row in component.accounts):
			component.append("accounts", {"company": COMPANY, "expense_account": account})
			component.save(ignore_permissions=True)

	frappe.db.commit()


def seed_shop_floor():
	"""Operations, workstations and one routing. Safe to run twice."""
	environment.require_non_production("Seeding the demo shop floor")
	for name, (rate, capacity, hours) in WORKSTATIONS.items():
		if frappe.db.exists("Workstation", name):
			station = frappe.get_doc("Workstation", name)
		else:
			station = frappe.new_doc("Workstation")
			station.workstation_name = name
		# `hour_rate` is read-only and summed by ERPNext from the cost table —
		# assigning it writes nothing. The granular labour/electricity/rent
		# fields of older versions are gone too.
		station.set("workstation_costs", [])
		station.append(
			"workstation_costs",
			{"operating_component": _cost_component(), "operating_cost": rate},
		)
		station.production_capacity = capacity
		# ERPNext schedules job cards against these hours, which is why they are
		# real rather than left blank.
		station.set("working_hours", [])
		station.append(
			"working_hours",
			{"start_time": "08:00:00", "end_time": f"{8 + hours:02d}:00:00", "enabled": 1},
		)
		station.save(ignore_permissions=True)

	steps = [(op, ws) for op, ws, _m in ROUTING_STEPS]
	# The rework bench, outside the routing: a piece only goes there when one
	# fails, so it is not a stage every cabinet passes through.
	steps.append((CORRECTIVE_STEP, CORRECTIVE_WORKSTATION))
	for operation, workstation in steps:
		if frappe.db.exists("Operation", operation):
			doc = frappe.get_doc("Operation", operation)
		else:
			doc = frappe.new_doc("Operation")
			doc.__newname = operation
		doc.workstation = workstation
		doc.description = f"{MARKER} — {operation}"
		doc.is_corrective_operation = 1 if operation == CORRECTIVE_STEP else 0
		doc.save(ignore_permissions=True)

	if frappe.db.exists("Routing", ROUTING_NAME):
		routing = frappe.get_doc("Routing", ROUTING_NAME)
	else:
		routing = frappe.new_doc("Routing")
		routing.routing_name = ROUTING_NAME
	routing.disabled = 0
	routing.set("operations", [])
	for index, (operation, workstation, minutes) in enumerate(ROUTING_STEPS, start=1):
		routing.append(
			"operations",
			{
				"sequence_id": index,
				"operation": operation,
				"workstation": workstation,
				"time_in_mins": minutes,
				"hour_rate": WORKSTATIONS[workstation][0],
			},
		)
	routing.save(ignore_permissions=True)

	frappe.db.commit()
	return {"workstations": sorted(WORKSTATIONS), "routing": ROUTING_NAME}


def remove_shop_floor():
	environment.require_non_production("Deleting the demo shop floor")
	if frappe.db.exists("Routing", ROUTING_NAME):
		frappe.delete_doc("Routing", ROUTING_NAME, force=True, ignore_permissions=True)
	for operation in [op for op, *_ in ROUTING_STEPS] + [CORRECTIVE_STEP]:
		if frappe.db.exists("Operation", operation):
			frappe.delete_doc("Operation", operation, force=True, ignore_permissions=True)
	for name in WORKSTATIONS:
		if frappe.db.exists("Workstation", name):
			frappe.delete_doc("Workstation", name, force=True, ignore_permissions=True)
	frappe.db.commit()


#: Who sells the shop its material.
#:
#: The bench arrives with ten suppliers, every one of them `_Test`, and not one
#: item pointing at any of them. Procurement cannot be demonstrated against
#: that: the supplier lookup correctly refuses, every time, for the right
#: reason. So two real-shaped suppliers, and the material split between them.
SUPPLIERS = {
	"Мебельная база Астана": ("ДСП 16мм", "ЛДСП 18мм"),
	"Фурнитура KZ": ("Петля", "Ручка", "Кромка 2мм"),
}

#: The company's currency is KZT and the stock `Standard Buying` list is in INR,
#: so a buying list has to exist before any purchase order can carry a price.
BUYING_LIST = "KORKEM Buying"

#: What the shop sells, and the list a customer's own order is priced from.
#:
#: It exists for the same reason the buying list does: `set_missing_values` has
#: to have somewhere real to read a rate from. Without it a customer placing an
#: order through the assistant would get a Sales Order with a rate of zero, and
#: the intake tool correctly refuses to write one — so the demo would have no
#: order to place. The rate is the one the seeded orders already carry.
SELLING_LIST = "KORKEM Selling"

SELLING_PRICES = {
	PRODUCT: 120000,
	PRODUCT_B: 120000,
}

#: What the shop pays. Chosen, like every other quantity here, and labelled as
#: demo data — but a real number in a real price list, so `set_missing_values`
#: resolves it the way it would for a customer.
PRICES = {
	"ДСП 16мм": 9800,
	"ЛДСП 18мм": 12400,
	"Кромка 2мм": 145,
	"Петля": 320,
	"Ручка": 890,
}


def seed_selling():
	"""A selling price list and the price of what the factory makes.

	Safe to run twice. Set as the company's `default_selling_list` so the
	customer intake tool, ERPNext's `set_missing_values` and the desk all read
	the same number.
	"""
	environment.require_non_production("Seeding the demo selling price list")
	if not frappe.db.exists("Price List", SELLING_LIST):
		frappe.get_doc(
			{
				"doctype": "Price List",
				"price_list_name": SELLING_LIST,
				"currency": "KZT",
				"buying": 0,
				"selling": 1,
				"enabled": 1,
			}
		).insert(ignore_permissions=True)

	for code, rate in SELLING_PRICES.items():
		if not frappe.db.exists("Item", code):
			continue
		if not frappe.db.exists("Item Price", {"item_code": code, "price_list": SELLING_LIST}):
			frappe.get_doc(
				{
					"doctype": "Item Price",
					"item_code": code,
					"price_list": SELLING_LIST,
					"selling": 1,
					"currency": "KZT",
					"price_list_rate": rate,
				}
			).insert(ignore_permissions=True)

	# ERPNext resolves a selling price list from the customer, then their
	# customer group, then Selling Settings — `accounts/party.get_default_price_list`
	# is the function that does it. The site default is set here so a customer
	# with no list of their own still prices correctly; the seeded customers get
	# it explicitly for the same reason the suppliers do.
	settings = frappe.get_single("Selling Settings")
	settings.selling_price_list = SELLING_LIST
	settings.save(ignore_permissions=True)

	frappe.db.commit()
	return SELLING_LIST


def remove_selling():
	environment.require_non_production("Deleting the demo selling price list")
	for customer in {customer for _p, _m, customer, *_rest in LINES}:
		if frappe.db.exists("Customer", customer):
			frappe.db.set_value("Customer", customer, "default_price_list", None, update_modified=False)
	settings = frappe.get_single("Selling Settings")
	if settings.selling_price_list == SELLING_LIST:
		settings.selling_price_list = None
		settings.save(ignore_permissions=True)
	for name in frappe.get_all("Item Price", filters={"price_list": SELLING_LIST}, pluck="name"):
		frappe.delete_doc("Item Price", name, force=True, ignore_permissions=True)
	if frappe.db.exists("Price List", SELLING_LIST):
		frappe.delete_doc("Price List", SELLING_LIST, force=True, ignore_permissions=True)
	frappe.db.commit()


def seed_buying():
	"""Suppliers, a buying price list and prices. Safe to run twice."""
	environment.require_non_production("Seeding demo suppliers")
	group = frappe.db.get_value("Supplier Group", {"is_group": 0, "name": "Local"}) or frappe.db.get_value(
		"Supplier Group", {"is_group": 0}, "name"
	)
	if not frappe.db.exists("Price List", BUYING_LIST):
		frappe.get_doc(
			{
				"doctype": "Price List",
				"price_list_name": BUYING_LIST,
				"currency": "KZT",
				"buying": 1,
				"selling": 0,
				"enabled": 1,
			}
		).insert(ignore_permissions=True)

	# The supplier's own price list, which is how ERPNext decides what a
	# purchase order costs. Without it the order inherits Buying Settings'
	# `Standard Buying`, which is in INR on this bench against a KZT company —
	# so every rate resolves to zero and the tool correctly refuses to send an
	# order with no price on it.
	for supplier in SUPPLIERS:
		if not frappe.db.exists("Supplier", supplier):
			frappe.get_doc(
				{
					"doctype": "Supplier",
					"supplier_name": supplier,
					"supplier_type": "Company",
					"supplier_group": group,
					"supplier_details": MARKER,
				}
			).insert(ignore_permissions=True)
		frappe.db.set_value(
			"Supplier",
			supplier,
			{"default_price_list": BUYING_LIST, "default_currency": "KZT"},
			update_modified=False,
		)

	for supplier, codes in SUPPLIERS.items():
		for code in codes:
			if not frappe.db.exists("Item", code):
				continue
			item = frappe.get_doc("Item", code)
			for default in item.item_defaults:
				default.default_supplier = supplier
			if not any(row.supplier == supplier for row in item.supplier_items):
				item.append("supplier_items", {"supplier": supplier})
			item.save(ignore_permissions=True)

			rate = PRICES.get(code)
			if rate and not frappe.db.exists(
				"Item Price", {"item_code": code, "price_list": BUYING_LIST}
			):
				frappe.get_doc(
					{
						"doctype": "Item Price",
						"item_code": code,
						"price_list": BUYING_LIST,
						"buying": 1,
						"currency": "KZT",
						"price_list_rate": rate,
					}
				).insert(ignore_permissions=True)

	frappe.db.commit()
	return sorted(SUPPLIERS)


def remove_buying():
	environment.require_non_production("Deleting demo suppliers")
	for supplier in SUPPLIERS:
		for name in frappe.get_all("Purchase Order", filters={"supplier": supplier}, pluck="name"):
			doc = frappe.get_doc("Purchase Order", name)
			if doc.docstatus == 1:
				doc.cancel()
			frappe.delete_doc("Purchase Order", name, force=True, ignore_permissions=True)
		if frappe.db.exists("Supplier", supplier):
			frappe.delete_doc("Supplier", supplier, force=True, ignore_permissions=True)
	for name in frappe.get_all("Item Price", filters={"price_list": BUYING_LIST}, pluck="name"):
		frappe.delete_doc("Item Price", name, force=True, ignore_permissions=True)
	if frappe.db.exists("Price List", BUYING_LIST):
		frappe.delete_doc("Price List", BUYING_LIST, force=True, ignore_permissions=True)
	frappe.db.commit()


#: Two people, because "least privilege" is a claim that needs someone to test
#: it on. Both are ordinary System Users built from **stock ERPNext roles** —
#: no custom role, no permission tweak — so what they can and cannot do is
#: ERPNext's answer rather than ours.
#:
#: The planner can run the whole procurement workflow. The viewer can read the
#: same production data and cannot raise a request: `Sales User` grants no
#: Material Request permission at all, which is what makes the negative test
#: meaningful instead of decorative.
USERS = {
	# `Purchase User` is the third role, and it is a deliberate widening rather
	# than an oversight: placing the order is the other half of noticing the
	# shortage, and in a shop this size the same person does both. It is still a
	# stock ERPNext role, and the viewer below does not have it — which is what
	# keeps the negative test meaningful.
	#
	# `Quality Manager` is the fourth, and it is ERPNext's own role for the one
	# thing it grants: creating and submitting a Quality Inspection. The ОТК
	# step is the planner's in a shop this size, and without the role the
	# verdict cannot be recorded at all. The viewer below still does not have
	# it, which is what keeps the negative test meaningful.
	"korkem.planner@example.com": (
		"Planner",
		("Manufacturing User", "Stock User", "Purchase User", "Quality Manager"),
	),
	"korkem.viewer@example.com": ("Viewer", ("Manufacturing User", "Sales User")),
	# The person who hands work out. `Manufacturing Manager` is ERPNext's own
	# role for running production, and it is what the Work Instruction doctype
	# grants `create` to — so "who may dispatch" is an ERPNext permission
	# rather than a second opinion in our policy file. The planner deliberately
	# does not have it, which is what makes the negative test mean something.
	"korkem.manager@example.com": (
		"Менеджер",
		("Manufacturing Manager", "Manufacturing User", "Stock Manager", "Sales Manager"),
	),
	# The person work is handed to. Same roles as the planner — this is a
	# second pair of hands on the floor, not a second privilege level — and a
	# Russian first name because that is what an administrator types when they
	# say «передай Ивану».
	"korkem.ivan@example.com": (
		"Иван",
		("Manufacturing User", "Stock User", "Quality Manager"),
	),
}

#: Development only, and enforced below rather than promised in a comment.
#:
#: A known password in source is only acceptable because these accounts cannot
#: come into existence anywhere it would matter: `seed_users` refuses to run
#: unless the site is in developer mode. Without that guard this constant would
#: be a credential in git, which is the one thing it must never become.
DEMO_PASSWORD = "KorkemE2E!2026"


def seed_users():
	"""Create the demo staff. Safe to run twice. Developer-mode benches only."""
	environment.require_non_production("Creating demo user accounts")
	if not frappe.conf.get("developer_mode"):
		frappe.throw(
			"seed_users creates accounts with a password that is published in "
			"source, so it only runs on a developer-mode bench."
		)

	for email, (first_name, roles) in USERS.items():
		if frappe.db.exists("User", email):
			user = frappe.get_doc("User", email)
		else:
			user = frappe.new_doc("User")
			user.update({"email": email, "first_name": first_name, "send_welcome_email": 0})

		user.user_type = "System User"
		user.enabled = 1
		# Roles are reset rather than appended to, so re-running narrows a user
		# that has drifted instead of quietly accumulating privilege.
		user.set("roles", [])
		for role in roles:
			user.append("roles", {"role": role})
		user.new_password = DEMO_PASSWORD
		user.save(ignore_permissions=True)
		_bind_to_company(email)

	_administrator_means_korkem()
	frappe.db.commit()
	return sorted(USERS)


def _bind_to_company(email: str):
	"""Привязать демо-сотрудника к КОРКЕМ через User Permission.

	Без этого компания сотрудника — умолчание сайта, а умолчание сайта меняется
	от чужой руки: достаточно зарегистрировать в приложении вторую компанию, и
	она становится ответом на вопрос «чья это смена». Тесты цеха продолжали
	брать заказы КОРКЕМ, а инструменты отвечали уже про другую компанию и
	сообщали «заказ не найден» — тридцать семь тестов, и ни один из них не
	показывал на настоящую причину.

	Это же и правильный способ по ERPNext: User Permission — единственная
	привязка, которую `get_list` учитывает сам.
	"""
	if frappe.db.exists(
		"User Permission", {"user": email, "allow": "Company", "for_value": COMPANY}
	):
		return
	frappe.get_doc(
		{
			"doctype": "User Permission",
			"user": email,
			"allow": "Company",
			"for_value": COMPANY,
			"apply_to_all_doctypes": 1,
		}
	).insert(ignore_permissions=True)


def _administrator_means_korkem():
	"""Демо-завод принадлежит КОРКЕМ, и умолчание сайта должно это говорить.

	Почти весь набор тестов цеха ходит по этому заводу от лица Administrator.
	Своей компании у Administrator нет, поэтому «какая компания» уходит к
	умолчанию сайта — а умолчание сайта меняется от чужой руки: достаточно
	завести в приложении вторую компанию, и семьдесят один тест начинает падать
	с «заказ не найден», не показывая ни одного пальца в сторону причины.

	Умолчание пользователя тут не годится, и это проверено, а не предположено:
	строка `company` у Administrator стояла на КОРКЕМ, а
	`frappe.defaults.get_user_default("Company")` продолжал отвечать умолчанием
	сайта. Поэтому — сайт.

	Владельца это не задевает: у каждого, кто зашёл через приложение, есть свой
	User Permission на свою компанию, и он читается раньше умолчания.
	"""
	frappe.db.set_single_value("Global Defaults", "default_company", COMPANY)
	# И отдельно — глобальное умолчание `company`. Это **не** то же самое поле:
	# `Global Defaults.default_company` живёт в `tabSingles`, а отвечает на
	# вопрос «какая компания» строка `company` в `tabDefaultValue` с родителем
	# `__default`, которую пишет `on_update` документа. `set_single_value`
	# документ не открывает, поэтому одна строка менялась, а вторая оставалась
	# от прежней компании — и `scope.current_company()` продолжал отвечать ею,
	# хотя в настройках сайта уже стояло КОРКЕМ. Час на этом потерян.
	frappe.defaults.set_global_default("company", COMPANY)
	frappe.defaults.clear_defaults_cache()


def remove_users():
	environment.require_non_production("Deleting demo user accounts")
	for email in USERS:
		if frappe.db.exists("User", email):
			frappe.delete_doc("User", email, force=True, ignore_permissions=True)
	frappe.db.commit()


def seed():
	"""Create the dataset. Safe to run twice."""
	environment.require_non_production("Seeding the demo factory")
	_administrator_means_korkem()
	_sheet_uom()
	_item_group()
	seed_shop_floor()
	_valuation_account()
	_retire_legacy_work_orders()

	# Materials are shared between lines, so items and opening stock are
	# created once from the union — seeding them per line would put the same
	# board on the shelf twice and make every availability figure wrong.
	materials = {}
	for _product, line_materials, *_rest in LINES:
		for code, uom, _per, on_hand in line_materials:
			materials[code] = (code, uom, on_hand)
	for code, uom, _on_hand in materials.values():
		_item(code, uom, is_stock=True)
	_stock(list(materials.values()))

	# The products have to exist before they can be priced, and priced before
	# an order can resolve a rate — so the catalogue is created first and the
	# selling list right after it.
	for product, *_rest in LINES:
		_item(product, "Nos", is_stock=True)
	seed_selling()

	created = []
	for product, line_materials, customer, qty, produced, due_in in LINES:
		bom = _bom(product, line_materials)
		order = _sales_order(_customer(customer), product, qty, due_in)
		work_order = None if produced is None else _work_order(bom, order, product, qty)
		# The finished units are built, not declared. Producing six cabinets
		# consumes 25.2 of the 38 sheets on the shelf and leaves the remaining
		# four needing 16.8 against 12.8 — the same four-sheet shortage the
		# procurement story has always been about, now arrived at physically.
		if work_order and produced:
			_produce(work_order, produced)
		created.append(
			{
				"customer": customer,
				"product": product,
				"bom": bom,
				"sales_order": order,
				"work_order": work_order,
			}
		)

	frappe.db.commit()
	return {
		"item_group": ITEM_GROUP,
		"lines": created,
		"users": seed_users(),
		"suppliers": seed_buying(),
		"selling_price_list": SELLING_LIST,
		"shop_floor": {"workstations": sorted(WORKSTATIONS), "routing": ROUTING_NAME},
	}


def remove():
	"""Delete everything `seed` created, newest dependency first."""
	environment.require_non_production("Deleting the demo factory")
	remove_buying()
	remove_selling()
	products = sorted({product for product, *_ in LINES})
	customers = sorted({customer for _p, _m, customer, *_ in LINES})

	# Everything posted against a demo work order, whoever posted it.
	#
	# Matching on the seed's own remark is not enough and the difference is not
	# academic: the assistant's own tools post transfers and manufacturing
	# entries against these jobs, and those carry no remark of ours. Leaving
	# them behind makes the work order undeletable, `remove()` fails halfway,
	# and the next `seed()` finds the jobs still there and quietly builds on a
	# half-torn-down factory — which is exactly how a re-seed produced a work
	# order claiming 15 of 20 that nobody had ordered.
	jobs = frappe.get_all(
		"Work Order", filters={"production_item": ["in", products]}, pluck="name"
	)
	entries = ["in", jobs] if jobs else ["is", "set"]

	# Quality Inspections hang off the job cards and outlive them otherwise —
	# the job card is deleted with the work order, and the inspection is left
	# pointing at a document that no longer exists. They accumulated once
	# already, which is how a re-seeded bench came to hold fourteen inspections
	# for two work orders.
	cards = (
		frappe.get_all("Job Card", filters={"work_order": ["in", jobs]}, pluck="name") if jobs else []
	)
	stock_entries = (
		frappe.get_all("Stock Entry", filters={"work_order": ["in", jobs]}, pluck="name") if jobs else []
	)
	for name in (
		frappe.get_all(
			"Quality Inspection",
			filters={"reference_name": ["in", cards + stock_entries]},
			pluck="name",
		)
		if (cards or stock_entries)
		else []
	):
		doc = frappe.get_doc("Quality Inspection", name)
		if doc.docstatus == 1:
			doc.cancel()
		frappe.delete_doc("Quality Inspection", name, force=True, ignore_permissions=True)

	for doctype, filters, order_by in (
		# Newest first throughout. A work order cannot be cancelled while a
		# Manufacture entry stands against it, and the opening stock cannot be
		# reversed before the entries that consumed it — undoing in anything
		# other than reverse chronological order walks the ledger negative and
		# ERPNext refuses, rightly.
		("Delivery Note", {"customer": ["in", customers]}, "creation desc"),
		*(
			[("Stock Entry", {"work_order": entries}, "creation desc")] if jobs else []
		),
		# Job cards outlive the work order they belong to — Phase 17 found the
		# same thing — and a re-seeded bench had collected twenty-one of them
		# for a job with seven operations. They come *after* the stock entries:
		# ERPNext refuses to cancel a card that a Manufacturing Entry was costed
		# from, and says so.
		*([("Job Card", {"work_order": ["in", jobs]}, "creation desc")] if jobs else []),
		("Work Order", {"production_item": ["in", products]}, "creation desc"),
		("Stock Entry", {"remarks": ["like", f"%{MARKER}%"]}, "creation desc"),
		("Sales Order", {"customer": ["in", customers]}, "creation desc"),
		("BOM", {"item": ["in", products]}, "creation desc"),
	):
		for name in frappe.get_all(doctype, filters=filters, pluck="name", order_by=order_by):
			doc = frappe.get_doc(doctype, name)
			if doc.docstatus == 1:
				doc.cancel()
			frappe.delete_doc(doctype, name, force=True, ignore_permissions=True)

	# The shop floor goes last. Operations and workstations are what a work
	# order's rows point at, and deleting the masters first makes cancelling the
	# job fail with "Could not find Operation: Раскрой" — the job cannot be
	# taken apart once the things it references are gone.
	remove_shop_floor()

	materials = {code for _p, line, *_ in LINES for code, *_rest in line}
	for code in sorted(materials | set(products)):
		if frappe.db.exists("Item", code):
			frappe.delete_doc("Item", code, force=True, ignore_permissions=True)
	for customer in customers:
		if frappe.db.exists("Customer", customer):
			frappe.delete_doc("Customer", customer, force=True, ignore_permissions=True)

	frappe.db.commit()


def _sheet_uom():
	if not frappe.db.exists("UOM", SHEET_UOM):
		frappe.get_doc(
			{
				"doctype": "UOM",
				"uom_name": SHEET_UOM,
				"must_be_whole_number": 0,
			}
		).insert(ignore_permissions=True)


def _item_group():
	if not frappe.db.exists("Item Group", ITEM_GROUP):
		frappe.get_doc(
			{
				"doctype": "Item Group",
				"item_group_name": ITEM_GROUP,
				"parent_item_group": "All Item Groups",
				"is_group": 0,
			}
		).insert(ignore_permissions=True)


def _item(code: str, uom: str, is_stock: bool):
	if frappe.db.exists("Item", code):
		return code
	frappe.get_doc(
		{
			"doctype": "Item",
			"item_code": code,
			"item_name": code,
			"item_group": ITEM_GROUP,
			"stock_uom": uom,
			"is_stock_item": 1 if is_stock else 0,
			"description": f"{MARKER} — {code}",
			"item_defaults": [{"company": COMPANY, "default_warehouse": STORES}],
		}
	).insert(ignore_permissions=True)
	return code


def _bom(product: str, materials: list) -> str:
	existing = frappe.get_all(
		"BOM", filters={"item": product, "docstatus": 1}, pluck="name"
	)
	if existing:
		return existing[0]

	bom = frappe.get_doc(
		{
			"doctype": "BOM",
			"item": product,
			"company": COMPANY,
			"quantity": 1,
			"is_active": 1,
			"is_default": 1,
			# The routing is what gives a Work Order its operations, and
			# operations are what give it Job Cards. Without this the shop floor
			# has no stages and «на каком этапе заказ» has no answer.
			"with_operations": 1,
			"routing": ROUTING_NAME,
			# ERPNext gates an operation on quality only when *both* the bill of
			# materials asks for inspection and the operation does. One
			# operation here does: ОТК is the inspection step, and marking every
			# stage would put a quality gate in front of every cut.
			"inspection_required": 1,
			"operations": [
				{
					"sequence_id": index,
					"operation": operation,
					"workstation": workstation,
					"time_in_mins": minutes,
					"hour_rate": WORKSTATIONS[workstation][0],
					"quality_inspection_required": 1 if operation == INSPECTED_STEP else 0,
				}
				for index, (operation, workstation, minutes) in enumerate(
					ROUTING_STEPS, start=1
				)
			],
			"items": [
				{
					"item_code": code,
					"qty": per,
					"uom": uom,
					"rate": 1000,
					"source_warehouse": STORES,
				}
				for code, uom, per, _on_hand in materials
			],
		}
	)
	bom.insert(ignore_permissions=True)
	bom.submit()
	return bom.name


def _stock(materials: list):
	"""Put material on the shelf, through a real Stock Entry.

	Writing `Bin.actual_qty` directly would leave the ledger disagreeing with
	the stock — the number would look right and every valuation built on it
	would be wrong. A Material Receipt is how stock actually arrives.

	The board arrives **valued**. `allow_zero_valuation_rate` used to be set
	here alongside a rate of 1000, and the flag wins: ERPNext booked every sheet
	at nothing. That was invisible for as long as the seed only ever moved this
	stock around, and it stopped the moment the seed started manufacturing from
	it — a Manufacture entry values the finished cabinet from the material it
	consumed plus the routing's operating cost, and material that cost nothing
	gives a cabinet no value to post, so ERPNext refuses the entry outright.
	Board that costs nothing was never true anyway.
	"""
	if frappe.db.exists("Stock Entry", {"remarks": ["like", f"%{MARKER}%"]}):
		return

	entry = frappe.get_doc(
		{
			"doctype": "Stock Entry",
			"stock_entry_type": "Material Receipt",
			"company": COMPANY,
			"remarks": f"{MARKER} opening stock",
			"items": [
				{
					"item_code": code,
					"qty": on_hand,
					"uom": uom,
					"t_warehouse": STORES,
					"basic_rate": 1000,
				}
				for code, uom, on_hand in materials
			],
		}
	)
	entry.insert(ignore_permissions=True)
	entry.submit()


def _retire_legacy_work_orders():
	"""Take the Sprint 1 sample job out of the production views.

	`setup.py` provisions a `Kitchen Facade` item and BOM to prove the company
	can manufacture at all, and a work order for it was left behind on this
	bench by an early run — submitted, "In Process", no operations, no
	warehouse, produced nothing, and visible in every production answer the
	assistant gives as though a real job were sitting on the floor.

	The item and its BOM stay: `test_end_to_end.py` builds the whole
	deal → quote → production path on them. Only a stray job is retired, and
	only one that never moved any stock — anything with a transaction behind it
	is real by definition and is left alone with a note.
	"""
	stale = frappe.get_all(
		"Work Order",
		filters={"company": COMPANY, "production_item": LEGACY_ITEM, "docstatus": ["<", 2]},
		pluck="name",
	)
	skipped = []
	for name in stale:
		if frappe.db.exists("Stock Entry", {"work_order": name, "docstatus": 1}) or frappe.db.exists(
			"Job Card", {"work_order": name, "docstatus": ["<", 2]}
		):
			skipped.append(name)
			continue
		job = frappe.get_doc("Work Order", name)
		if job.docstatus == 1:
			job.cancel()
		frappe.delete_doc("Work Order", name, force=True, ignore_permissions=True)
	frappe.db.commit()
	return {"retired": [n for n in stale if n not in skipped], "kept_has_transactions": skipped}


def _produce(work_order: str, qty: float):
	"""Actually build `qty` units, the way the shop floor would.

	This replaces two lies at once. `produced_qty` used to be written straight
	onto the work order with `db_set`, and the finished units it claimed were
	put on the shelf by a Material Receipt labelled "opening stock" — a
	manufacturing transaction wearing a receipt's clothes. Neither survived
	contact with ERPNext: `produced_qty` is a **derived** field, recomputed from
	submitted Manufacture entries by `StatusService._update_qty_for_purpose`
	whenever a stock transaction touches the work order. One of the two seeded
	values had already been silently erased that way before anyone noticed.

	So the material moves into work-in-progress and comes back out as product,
	through ERPNext's own mapper. `produced_qty`, `status` and the stock ledger
	then agree because they are the same fact, not three copies of it.

	Idempotent: a work order that has already been produced against is left
	alone, so `seed()` can be re-run without building the cabinets twice.
	"""
	from erpnext.manufacturing.doctype.work_order.mapper import make_stock_entry

	if frappe.db.exists(
		"Stock Entry", {"work_order": work_order, "purpose": "Manufacture", "docstatus": 1}
	):
		return

	for purpose in ("Material Transfer for Manufacture", "Manufacture"):
		entry = frappe.get_doc(make_stock_entry(work_order, purpose, qty))
		entry.posting_date = nowdate()
		entry.remarks = f"{MARKER} — {purpose.lower()}"
		entry.insert(ignore_permissions=True)
		if entry.inspection_required:
			_pass_inspection(entry)
		entry.submit()


def _pass_inspection(entry) -> None:
	"""Sign off the finished goods on a draft Manufacture entry.

	The bill of materials is marked `inspection_required`, and in ERPNext that
	one switch gates two things: the ОТК job card, and the finished-item row of
	the Manufacture entry. So goods cannot reach the shelf without a verdict —
	and the seeded cabinets need a real one rather than the switch being turned
	off to make the fixture convenient.

	Recorded against the stock entry, which is what the desk does when goods are
	inspected as they are received. The seed never runs the shop floor, so there
	is no ОТК job card to hang it on — during real production `record_inspection`
	records the verdict there instead, and `complete_production` carries it onto
	this same row.

	Accepted, because these units are on the shelf in the story being told.
	"""
	verdicts = {}
	for row in entry.items:
		if not row.is_finished_item or row.quality_inspection:
			continue
		doc = frappe.get_doc(
			{
				"doctype": "Quality Inspection",
				"inspection_type": "In Process",
				"reference_type": "Stock Entry",
				"reference_name": entry.name,
				"item_code": row.item_code,
				"sample_size": flt(row.qty),
				"inspected_by": frappe.session.user,
				"status": "Accepted",
				"remarks": f"{MARKER} — ОТК",
				"company": COMPANY,
			}
		)
		doc.insert(ignore_permissions=True)
		doc.submit()
		verdicts[row.idx] = doc.name

	if not verdicts:
		return
	# Submitting an inspection writes back to the entry, so the copy in hand is
	# a version behind and saving it raises a timestamp mismatch. Re-read, then
	# attach.
	entry.reload()
	for row in entry.items:
		if row.idx in verdicts:
			row.quality_inspection = verdicts[row.idx]
	entry.save(ignore_permissions=True)


def _customer(name: str) -> str:
	if not frappe.db.exists("Customer", name):
		frappe.get_doc(
			{
				"doctype": "Customer",
				"customer_name": name,
				"customer_type": "Company",
				"customer_group": frappe.db.get_value("Customer Group", {"is_group": 0}, "name"),
				"territory": frappe.db.get_value("Territory", {"is_group": 0}, "name"),
			}
		).insert(ignore_permissions=True)
	# Their own selling list, the mirror of what `seed_buying` does for a
	# supplier. ERPNext reads this first when it prices an order.
	frappe.db.set_value(
		"Customer", name, "default_price_list", SELLING_LIST, update_modified=False
	)
	return name


def _sales_order(customer: str, product: str, qty: float, due_in: int) -> str:
	existing = frappe.get_all(
		"Sales Order", filters={"customer": customer, "docstatus": 1}, pluck="name"
	)
	if existing:
		return existing[0]

	order = frappe.get_doc(
		{
			"doctype": "Sales Order",
			"customer": customer,
			"company": COMPANY,
			"currency": "KZT",
			"conversion_rate": 1,
			"selling_price_list": SELLING_LIST,
			"price_list_currency": "KZT",
			"plc_conversion_rate": 1,
			# An overdue order is one placed a while ago, not one placed today
			# for yesterday: ERPNext refuses a delivery date before the order
			# date ("Expected Delivery Date should be after Sales Order Date").
			"transaction_date": add_days(nowdate(), min(0, due_in - 7)),
			"delivery_date": add_days(nowdate(), due_in),
			"order_type": "Sales",
			"items": [
				{
					"item_code": product,
					"qty": qty,
					# From SELLING_PRICES via the price list; stated here too
					# because `insert` does not run `set_missing_values` and a
					# seeded order with a zero rate would make every total wrong.
					"rate": SELLING_PRICES[product],
					"uom": "Nos",
					"conversion_factor": 1,
					"warehouse": FINISHED,
					"delivery_date": add_days(nowdate(), due_in),
				}
			],
		}
	)
	order.insert(ignore_permissions=True)
	order.submit()
	return order.name


def _work_order(bom: str, sales_order: str, product: str, qty: float) -> str:
	"""The job itself. What it has produced is decided by `_produce`, not here."""
	existing = frappe.get_all(
		"Work Order", filters={"sales_order": sales_order, "docstatus": 1}, pluck="name"
	)
	if existing:
		return existing[0]

	order = frappe.get_doc(
		{
			"doctype": "Work Order",
			"production_item": product,
			"bom_no": bom,
			"company": COMPANY,
			"qty": qty,
			"sales_order": sales_order,
			"wip_warehouse": WIP,
			"fg_warehouse": FINISHED,
			"source_warehouse": STORES,
			"planned_start_date": nowdate(),
		}
	)
	# Operations do not arrive on their own. ERPNext fills them from the BOM in
	# `set_work_order_operations`, which the desk form calls and `insert` does
	# not — so a work order created in code has no stages unless it is asked
	# for them, and «на каком этапе заказ» has no answer.
	order.set_work_order_operations()
	order.insert(ignore_permissions=True)
	order.submit()
	return order.name
