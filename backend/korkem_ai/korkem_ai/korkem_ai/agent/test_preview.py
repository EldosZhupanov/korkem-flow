# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Человек видит, что произойдёт, а не имя функции."""

from __future__ import annotations

from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai.agent import preview


class TestTheOwnerSeesTheInvoiceNotTheFunction(IntegrationTestCase):
	"""Согласие на непонятную строку ничего не стоит.

	Экран показывал `crm.create_deal · CRM Deal Заказ кухни для Ерлана`. Для
	действия с деньгами этого мало: владелец, подтверждающий счёт, должен
	видеть счёт.
	"""

	def test_an_invoice_is_shown_as_an_invoice(self):
		shown = preview.build(
			"sales.create_invoice",
			{"customer": "Ерлан Сериков", "amount": 650000, "due_date": "2026-09-17"},
		)

		self.assertEqual(shown["title"], "Будет создан счёт")
		self.assertIn({"label": "Клиент", "value": "Ерлан Сериков"}, shown["fields"])
		self.assertIn({"label": "Сумма", "value": "650000"}, shown["fields"])
		self.assertIn({"label": "Срок", "value": "2026-09-17"}, shown["fields"])

	def test_labels_are_the_words_of_an_invoice_not_of_a_developer(self):
		shown = preview.build("sales.create_order", {"delivery_date": "2026-09-17"})

		self.assertEqual(shown["fields"][0]["label"], "Срок")

	def test_an_unknown_argument_is_shown_as_it_is(self):
		"""Показать сырое имя честнее, чем спрятать значение."""
		shown = preview.build("crm.create_lead", {"weird_field": "значение"})

		self.assertEqual(shown["fields"][0]["label"], "weird_field")
		self.assertEqual(shown["fields"][0]["value"], "значение")


class TestNothingIsInvented(IntegrationTestCase):
	"""Человек, увидевший выдуманное поле, перестаёт верить и остальным."""

	def test_an_empty_value_produces_no_row(self):
		shown = preview.build(
			"sales.create_invoice", {"customer": "Ерлан", "amount": None, "note": ""}
		)

		labels = [f["label"] for f in shown["fields"]]
		self.assertEqual(labels, ["Клиент"])

	def test_an_action_with_nothing_to_show_gets_no_preview(self):
		"""Отсутствие описания — законный ответ, а не повод спрятать кнопку."""
		self.assertIsNone(preview.build("manufacturing.stop_production", {}))
		self.assertIsNone(preview.build("manufacturing.stop_production", None))

	def test_a_nested_list_is_counted_not_unfolded(self):
		"""«[{'item': ...}]» человеку не говорит ничего.

		Разворачивать вложенное в накладную значит рисовать накладную — этим
		занимается экран заказа, а не карточка согласования.
		"""
		shown = preview.build(
			"sales.create_order",
			{"customer": "Ерлан", "items": [{"item": "фасад"}, {"item": "корпус"}]},
		)

		values = {f["value"] for f in shown["fields"]}
		self.assertIn("2 шт.", values)
		self.assertNotIn("фасад", str(values))


class TestTheTitleSaysWhatWillHappen(IntegrationTestCase):
	"""Глагол в будущем: человек читает про то, чего ещё не случилось."""

	def test_the_title_agrees_in_gender(self):
		"""«Будет создан задача» на экране подтверждения денег подрывает доверие.

		Человек видит, что писали небрежно, и переносит это на суть: если тут
		не выверили слово, то и сумму, может быть, тоже.
		"""
		cases = {
			"sales.create_invoice": "Будет создан счёт",
			"crm.create_task": "Будет создана задача",
			"crm.create_capture": "Будет создано обращение",
			"chain.record_measurement": "Будет записан замер",
			"sales.create_delivery": "Будет создана отгрузка",
		}
		for tool, expected in cases.items():
			with self.subTest(tool=tool):
				shown = preview.build(tool, {"customer": "Ерлан"})
				self.assertEqual(shown["title"], expected)

	def test_an_unknown_action_is_named_rather_than_invented(self):
		"""Честнее назвать инструмент, чем сочинить фразу про него."""
		shown = preview.build("custom.frobnicate", {"customer": "Ерлан"})

		self.assertIn("custom.frobnicate", shown["title"])
