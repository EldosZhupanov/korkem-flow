# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Ассистент должен доставать до цепочки, а не только до отчётов.

Найдено замером живого хода: в каталоге было 43 инструмента и ни одного для
того, ради чего продукт делается — записать сказанное. Владелец мог спросить
«сколько заказов», но не мог сказать «запиши: звонил Данияр, кухня, замерить».
"""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai.tools import catalog, registry  # noqa: F401
from korkem_ai.korkem_ai.tools.registry import Risk


class TestTheChainIsReachable(IntegrationTestCase):
	def test_the_owner_can_say_write_this_down(self):
		"""Тот самый вопрос, ради которого всё."""
		self.assertIsNotNone(registry.find("chain.record_capture"))

	def test_the_morning_question_has_a_tool(self):
		"""«Что застряло сегодня» — то, что владелец спрашивает голосом."""
		self.assertIsNotNone(registry.find("chain.what_needs_attention"))

	def test_writing_waits_for_a_person(self):
		"""R10: ассистент мог не расслышать имя клиента."""
		for name in (
			"chain.record_capture",
			"chain.convert_capture",
			"chain.record_measurement",
		):
			with self.subTest(tool=name):
				self.assertEqual(registry.get(name).risk, Risk.WRITE)

	def test_looking_does_not_wait(self):
		"""Спрашивать разрешение на взгляд — сделать взгляд дороже, чем он стоит."""
		for name in ("chain.what_needs_attention", "chain.contract_status"):
			with self.subTest(tool=name):
				self.assertEqual(registry.get(name).risk, Risk.READ)

	def test_recording_what_was_said_actually_records_it(self):
		said = f"Звонил клиент, кухня 3200. Проверка {frappe.generate_hash(length=6)}"
		result = registry.execute(
			"chain.record_capture",
			{"text": said, "customer_hint": "Данияр", "assign_to": "Administrator"},
		)

		self.assertTrue(result["ok"], result)
		capture = result["data"]["capture"]
		self.assertEqual(frappe.db.get_value("Capture", capture, "spoken_text"), said)
		# Задача замерщику ставится тем же действием — человек делает это одним.
		self.assertTrue(frappe.db.get_value("Capture", capture, "task"))

	def test_the_morning_question_answers_in_four_lists(self):
		result = registry.execute("chain.what_needs_attention", {})

		self.assertTrue(result["ok"], result)
		self.assertEqual(
			set(result["data"]),
			{
				"unassigned_captures",
				"overdue_tasks",
				"orders_without_design",
				"delivered_not_invoiced",
			},
		)

	def test_a_tool_holds_no_business_rule_of_its_own(self):
		"""R1: правило живёт в сервисе, инструмент только зовёт.

		Два места с одним правилом однажды разойдутся, и разойдутся молча.
		"""
		import inspect

		from korkem_ai.korkem_ai.tools import chain

		source = inspect.getsource(chain)
		for forbidden in ("frappe.throw", "frappe.get_list", "frappe.db."):
			self.assertNotIn(
				forbidden,
				source,
				f"{forbidden} в обёртке означает правило, продублированное мимо сервиса",
			)

	def test_converting_a_note_really_makes_an_enquiry(self):
		"""Проверять объявление инструмента мало: он должен работать.

		Первая версия этих тестов смотрела только на уровень риска — то есть
		прошла бы и на обёртке, которая ничего не вызывает.
		"""
		said = registry.execute(
			"chain.record_capture",
			{"text": "Шкаф-купе", "customer_hint": f"Клиент {frappe.generate_hash(length=6)}"},
		)["data"]["capture"]

		result = registry.execute("chain.convert_capture", {"capture": said})

		self.assertTrue(result["ok"], result)
		enquiry = result["data"]["enquiry"]
		self.assertTrue(frappe.db.exists("Opportunity", enquiry))

	def test_recording_a_measurement_puts_the_address_where_delivery_looks(self):
		said = registry.execute(
			"chain.record_capture",
			{"text": "Кухня", "customer_hint": f"Клиент {frappe.generate_hash(length=6)}"},
		)["data"]["capture"]
		enquiry = registry.execute("chain.convert_capture", {"capture": said})["data"][
			"enquiry"
		]

		result = registry.execute(
			"chain.record_measurement",
			{
				"enquiry": enquiry,
				"dimensions": "3200x600",
				"address_line": "проспект Абая 15",
				"city": "Астана",
			},
		)

		self.assertTrue(result["ok"], result)
		self.assertTrue(result["data"]["address"], "адрес не стал адресом")

	def test_a_refusal_from_the_service_reaches_the_assistant_as_a_refusal(self):
		"""Отказ сервиса не должен превращаться в «ок» по дороге."""
		result = registry.execute("chain.record_measurement", {"enquiry": "OPP-НЕТ-ТАКОЙ"})

		self.assertFalse(result["ok"], result)


class TestTheRestOfTheChainIsReachable(IntegrationTestCase):
	"""После замера ассистент немел. Здесь проверяется, что перестал.

	Проверяются не объявления, а вызовы — и в первую очередь **отказы**:
	правило, живущее в сервисе, должно доходить до ассистента отказом, а не
	теряться по дороге в бодрое «готово».
	"""

	def setUp(self):
		frappe.set_user("Administrator")

	def test_every_link_of_the_chain_has_a_tool(self):
		for name in (
			"chain.draft_proposal",
			"chain.accept_proposal",
			"chain.draft_contract",
			"chain.sign_contract",
			"chain.assign_design",
			"chain.deliver_design",
			"chain.schedule_installation",
			"chain.complete_installation",
			"chain.warranty_status",
			"chain.warranty_claim",
			"chain.draft_invoice",
			"chain.catalogue_items",
			"chain.create_item",
		):
			with self.subTest(tool=name):
				self.assertIsNotNone(registry.find(name), f"{name} нет в каталоге")

	def test_a_proposal_becomes_an_order_and_then_a_contract(self):
		enquiry, item = _an_enquiry_with_an_item()

		quoted = registry.execute(
			"chain.draft_proposal",
			{"enquiry": enquiry, "items": [{"item_code": item, "qty": 1}]},
		)
		self.assertTrue(quoted["ok"], quoted)
		quotation = quoted["data"]["quotation"]
		frappe.get_doc("Quotation", quotation).submit()

		accepted = registry.execute(
			"chain.accept_proposal",
			{
				"quotation": quotation,
				"deliver_on": frappe.utils.add_days(frappe.utils.nowdate(), 21),
			},
		)
		self.assertTrue(accepted["ok"], accepted)
		order = accepted["data"]["sales_order"]

		drafted = registry.execute("chain.draft_contract", {"sales_order": order})
		self.assertTrue(drafted["ok"], drafted)

		signed = registry.execute(
			"chain.sign_contract",
			{"contract": drafted["data"]["contract"], "signee": "Данияр Ахметов"},
		)
		self.assertTrue(signed["ok"], signed)
		self.assertEqual(signed["data"]["signee"], "Данияр Ахметов")

	def test_a_design_without_a_drawing_is_refused_to_the_assistant_too(self):
		"""«Готово» без чертежа — самая дорогая ложь в производстве."""
		order = _an_order()
		registry.execute(
			"chain.assign_design",
			{
				"sales_order": order,
				"designer": "Administrator",
				"due_on": frappe.utils.add_days(frappe.utils.nowdate(), 5),
			},
		)

		result = registry.execute("chain.deliver_design", {"sales_order": order})

		self.assertFalse(result["ok"], "дизайн принялся без чертежа")

	def test_installation_before_shipping_is_refused_to_the_assistant_too(self):
		"""Бригада без мебели теряет день, а клиент — доверие."""
		order = _an_order()

		result = registry.execute(
			"chain.schedule_installation",
			{
				"sales_order": order,
				"installer": "Administrator",
				"install_on": frappe.utils.nowdate(),
			},
		)

		self.assertFalse(result["ok"], "монтаж назначился до отгрузки")

	def test_an_invoice_for_nothing_shipped_is_refused_to_the_assistant_too(self):
		order = _an_order()
		frappe.get_doc("Sales Order", order).submit()

		result = registry.execute("chain.draft_invoice", {"sales_order": order})

		self.assertFalse(result["ok"], "счёт выставился за неотгруженное")

	def test_the_catalogue_offers_seven_units_not_two_hundred(self):
		result = registry.execute("chain.catalogue_units", {})

		self.assertTrue(result["ok"], result)
		units = result["data"]["units"]
		self.assertLessEqual(len(units), 7)
		self.assertEqual(units[0]["unit"], "Nos")

	def test_an_item_with_a_unit_nobody_offered_is_refused(self):
		result = registry.execute(
			"chain.create_item",
			{"name": f"Шкаф {frappe.generate_hash(length=6)}", "unit": "Acre"},
		)

		self.assertFalse(result["ok"], "позиция завелась в акрах")


def _an_enquiry_with_an_item() -> tuple[str, str]:
	from korkem_manufacturing.services import catalogue as catalogue_service

	item = f"Кухня {frappe.generate_hash(length=6)}"
	catalogue_service.create(name=item, unit="Nos", price=650000)

	said = registry.execute(
		"chain.record_capture",
		{"text": "Кухня", "customer_hint": f"Клиент {frappe.generate_hash(length=6)}"},
	)["data"]["capture"]
	enquiry = registry.execute("chain.convert_capture", {"capture": said})["data"]["enquiry"]
	return enquiry, item


def _an_order() -> str:
	from korkem_manufacturing.services import acceptance as acceptance_service
	from korkem_manufacturing.services import proposal as proposal_service

	enquiry, item = _an_enquiry_with_an_item()
	quotation = proposal_service.draft(
		enquiry=enquiry, items=[{"item_code": item, "qty": 1}]
	)["quotation"]
	frappe.db.set_value("Quotation", quotation, "docstatus", 1)
	return acceptance_service.accept(
		quotation=quotation,
		deliver_on=frappe.utils.add_days(frappe.utils.nowdate(), 21),
	)["sales_order"]
