# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Одна команда, которой проверяют живой узел после установки.

Тесты сюда не доедут: на рабочем сайте они выключены, и это правильно —
`allow_tests` на производстве означает, что кто-то может стереть данные завода
одной командой. Но убедиться, что цепочка жива, всё равно надо, и делать это
надо на том сайте, который отдали клиенту, а не на соседнем.

Отсюда и разница со всем остальным в этой папке: здесь **не проверка кода, а
проверка установки**. Все звенья по отдельности покрыты тестами; этот проход
отвечает на другой вопрос — собран ли узел так, что по нему можно пройти от
звонка клиента до счёта.

    bench --site <сайт> execute korkem_manufacturing.chain_smoke.run

**Он оставляет следы, и это осознанно.** Заказ, договор и счёт остаются в базе:
удалять их значило бы проверять не то, что произойдёт у клиента. Данные помечены
словом «Проверка» в имени клиента, чтобы их было видно и легко убрать руками.

**Останавливается на первом же звене, которое не сработало,** и называет его.
Пройти половину и сказать «в целом работает» — не проверка.
"""

from __future__ import annotations

import frappe

from korkem_manufacturing.services import acceptance as acceptance_service
from korkem_manufacturing.services import capture as capture_service
from korkem_manufacturing.services import catalogue as catalogue_service
from korkem_manufacturing.services import contract as contract_service
from korkem_manufacturing.services import design as design_service
from korkem_manufacturing.services import enquiry as enquiry_service
from korkem_manufacturing.services import measurement as measurement_service
from korkem_manufacturing.services import proposal as proposal_service


def run() -> None:
	"""Пройти цепочку целиком и рассказать, где остановились."""
	mark = frappe.generate_hash(length=6)
	customer = f"Проверка {mark}"
	item = f"Кухня проверка {mark}"

	_say("номенклатура", "позиция и цена")
	catalogue_service.create(name=item, unit="Nos", price=650000)

	_say("этап 1", "сказанное превращается в заявку с замерщиком")
	said = capture_service.record(
		text=f"Звонил клиент, кухня, замерить. {customer}",
		understood={"customer_hint": customer},
		assign_to=frappe.session.user,
		due_on=frappe.utils.add_days(frappe.utils.nowdate(), 2),
	)["capture"]
	asked = enquiry_service.convert(capture=said)["enquiry"]

	_say("этап 2", "замер с адресом закрывает задачу замерщика")
	measurement_service.record(
		enquiry=asked,
		dimensions="3200x600, высота 2100",
		address_line="проспект Абая 15",
		city="Астана",
	)

	_say("этап 3", "КП и заказ")
	quotation = proposal_service.draft(
		enquiry=asked, items=[{"item_code": item, "qty": 1}]
	)["quotation"]
	frappe.get_doc("Quotation", quotation).submit()
	order = acceptance_service.accept(
		quotation=quotation,
		deliver_on=frappe.utils.add_days(frappe.utils.nowdate(), 21),
	)["sales_order"]

	_say("этап 4", "договор и подпись")
	contract = contract_service.draft(sales_order=order)["contract"]
	contract_service.sign(contract=contract, signee=f"Проверка {mark}")
	signed = contract_service.status(sales_order=order)
	_assert(signed["signed"], "договор не отметился подписанным")

	_say("этап 5", "дизайн: «готово» требует чертежа")
	design_service.assign(
		sales_order=order,
		designer=frappe.session.user,
		due_on=frappe.utils.add_days(frappe.utils.nowdate(), 5),
	)
	_assert(
		_refuses(lambda: design_service.deliver(sales_order=order)),
		"дизайн принялся без единого приложенного файла — это дефект",
	)
	frappe.get_doc(
		{
			"doctype": "File",
			"file_name": f"чертёж-{mark}.txt",
			"attached_to_doctype": "Sales Order",
			"attached_to_name": order,
			"is_private": 1,
			"content": b"a drawing stands in for itself here",
		}
	).insert()
	design_service.deliver(sales_order=order)

	_say("этап 10", "монтаж не раньше отгрузки")
	from korkem_manufacturing.services import installation as installation_service

	_assert(
		_refuses(
			lambda: installation_service.schedule(
				sales_order=order,
				installer=frappe.session.user,
				install_on=frappe.utils.nowdate(),
			)
		),
		"монтаж назначился до отгрузки — это дефект",
	)

	_say("этап 12", "счёт только за отгруженное")
	from korkem_manufacturing.services import invoicing as invoicing_service

	frappe.get_doc("Sales Order", order).submit()
	_assert(
		_refuses(lambda: invoicing_service.draft(sales_order=order)),
		"счёт выставился за неотгруженное — это дефект",
	)

	_say("внимание", "экран «что застряло» отвечает")
	from korkem_manufacturing.services import attention as attention_service

	today = attention_service.today()
	_assert(
		set(today) == {
			"unassigned_captures",
			"overdue_tasks",
			"orders_without_design",
			"delivered_not_invoiced",
		},
		"ответ экрана внимания изменил форму",
	)

	print(f"\n\033[32mЦЕПОЧКА ЖИВА\033[0m — заказ {order}, договор {contract}")
	print(f"Следы проверки помечены словом «Проверка {mark}» — их можно убрать руками.")


def _say(stage: str, what: str) -> None:
	print(f"  {stage:<12} {what}")


def _assert(condition: bool, message: str) -> None:
	if not condition:
		frappe.throw(f"ЦЕПОЧКА ОБОРВАЛАСЬ: {message}")


def _refuses(action) -> bool:
	"""Отказ здесь — правильный ответ, а не ошибка проверки."""
	try:
		action()
	except frappe.ValidationError:
		return True
	return False
