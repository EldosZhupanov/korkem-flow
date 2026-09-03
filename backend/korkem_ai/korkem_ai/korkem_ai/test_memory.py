# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Память помнит устойчивое и отказывается помнить изменяемое."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai import memory


class TestWhatMemoryRefusesToKeep(IntegrationTestCase):
	"""Главная проверка модуля: память не источник правды.

	Остаток «ЛДСП 40 листов», записанный сюда, к вечеру станет ложью — и
	ассистент назовёт это число уверенно. Ошибётся при этом тот, кто спрашивал:
	он поверит. Поэтому отказ, а не предупреждение: предупреждение читают один
	раз и обходят.
	"""

	def tearDown(self):
		frappe.db.delete(memory.DOCTYPE)

	def _write(self, **kwargs):
		base = {
			"scope": memory.COMPANY,
			"category": "process",
			"subject": "склад",
			"predicate": "состояние",
			"value": "что-то",
		}
		base.update(kwargs)
		return memory.remember(**base)

	def test_a_stock_level_is_refused(self):
		with self.assertRaises(frappe.ValidationError) as refusal:
			self._write(value="ЛДСП на складе 40 листов")

		self.assertIn("ERPNext", str(refusal.exception))

	def test_a_price_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			self._write(subject="кухня", predicate="цена", value="650000")

	def test_an_order_status_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			self._write(subject="заказ 142", predicate="статус заказа", value="готов")

	def test_a_secret_is_refused_whatever_it_is_called(self):
		"""Память уходит в модель. Ключ, сохранённый как «предпочтение», уедет."""
		with self.assertRaises(frappe.ValidationError) as refusal:
			self._write(category="preference", subject="вход", predicate="пароль", value="1234")

		self.assertIn("секрет", str(refusal.exception).lower())

	def test_terminology_may_mention_prices_because_it_is_the_rule_not_the_number(self):
		"""«Цены храним без НДС» — это способ считать, а не сама цена."""
		name = self._write(
			category="terminology",
			subject="цены",
			predicate="правило",
			value="цены храним без НДС",
		)

		self.assertTrue(frappe.db.exists(memory.DOCTYPE, name))


class TestAFactCanStopBeingTrue(IntegrationTestCase):
	"""«Нурлан основной оператор ЧПУ» верно сегодня и неверно, когда он ушёл."""

	def tearDown(self):
		frappe.db.delete(memory.DOCTYPE)

	def test_a_new_fact_supersedes_the_old_one_instead_of_erasing_it(self):
		first = memory.remember(
			scope=memory.COMPANY,
			category="role",
			subject="Нурлан",
			predicate="должность",
			value="оператор ЧПУ",
		)
		second = memory.remember(
			scope=memory.COMPANY,
			category="role",
			subject="Нурлан",
			predicate="должность",
			value="начальник цеха",
		)

		old = frappe.db.get_value(
			memory.DOCTYPE, first, ["is_active", "superseded_by"], as_dict=True
		)
		self.assertFalse(old.is_active)
		self.assertEqual(
			old.superseded_by,
			second,
			"история нужна на вопрос «почему KORKEM так думает»",
		)

	def test_only_the_current_fact_reaches_the_context(self):
		memory.remember(
			scope=memory.COMPANY, category="role", subject="Нурлан",
			predicate="должность", value="оператор ЧПУ",
		)
		memory.remember(
			scope=memory.COMPANY, category="role", subject="Нурлан",
			predicate="должность", value="начальник цеха",
		)

		values = [row["value"] for row in memory.recall(scope=memory.COMPANY)]

		self.assertEqual(values, ["начальник цеха"])

	def test_an_expired_fact_is_not_offered(self):
		memory.remember(
			scope=memory.COMPANY, category="process", subject="смена",
			predicate="график", value="в две смены",
			expires_at=frappe.utils.add_days(frappe.utils.now_datetime(), -1),
		)

		self.assertEqual(memory.recall(scope=memory.COMPANY), [])

	def test_forgetting_leaves_the_row_but_takes_it_out_of_context(self):
		name = memory.remember(
			scope=memory.COMPANY, category="rule", subject="кромка",
			predicate="единица", value="метры",
		)

		memory.forget(name)

		self.assertTrue(frappe.db.exists(memory.DOCTYPE, name), "строка остаётся")
		self.assertEqual(memory.recall(scope=memory.COMPANY), [])


class TestCompanyAndPersonAreDifferentThings(IntegrationTestCase):
	def tearDown(self):
		frappe.db.delete(memory.DOCTYPE)
		frappe.set_user("Administrator")

	def test_a_company_fact_belongs_to_nobody_in_particular(self):
		with self.assertRaises(frappe.ValidationError):
			memory.remember(
				scope=memory.COMPANY, category="preference", subject="язык",
				predicate="рабочий", value="русский", owner="Administrator",
			)

	def test_a_persons_fact_is_not_offered_to_another_person(self):
		memory.remember(
			scope=memory.USER, category="preference", subject="язык",
			predicate="рабочий", value="казахский", owner="Administrator",
		)

		mine = memory.recall(scope=memory.USER, owner="Administrator")
		theirs = memory.recall(scope=memory.USER, owner="Guest")

		self.assertEqual(len(mine), 1)
		self.assertEqual(theirs, [], "чужая память — чужая")


class TestWhatTheOwnerConfirmedOutranksWhatWeGuessed(IntegrationTestCase):
	def tearDown(self):
		frappe.db.delete(memory.DOCTYPE)

	def test_a_confirmed_fact_comes_first(self):
		"""Человек знает свой цех лучше модели, которая его слушала."""
		guessed = memory.remember(
			scope=memory.COMPANY, category="process", subject="раскрой",
			predicate="порядок", value="сначала длинные детали",
			source_type="inferred", importance=0.9,
		)
		stated = memory.remember(
			scope=memory.COMPANY, category="rule", subject="кромка",
			predicate="единица", value="метры", importance=0.5,
		)
		memory.confirm(stated)

		order = [row["name"] for row in memory.recall(scope=memory.COMPANY)]

		self.assertEqual(order[0], stated)
		self.assertIn(guessed, order)

	def test_confirming_makes_it_certain_and_stated(self):
		name = memory.remember(
			scope=memory.COMPANY, category="process", subject="замер",
			predicate="срок", value="в течение двух дней",
			source_type="inferred", confidence=0.3,
		)

		memory.confirm(name)

		row = frappe.db.get_value(
			memory.DOCTYPE, name, ["confidence", "source_type", "confirmed_by"], as_dict=True
		)
		self.assertEqual(row.confidence, 1.0)
		self.assertEqual(row.source_type, "stated")
		self.assertTrue(row.confirmed_by)


class TestWhatThePersonSeesAndCanCorrect(IntegrationTestCase):
	"""Экран «Что KORKEM знает»: посмотреть, исправить, подтвердить, забыть."""

	def setUp(self):
		frappe.db.delete(memory.DOCTYPE)
		self.fact = memory.remember(
			scope=memory.COMPANY, category="terminology", subject="ЛДСП",
			predicate="единица измерения", value="квадратные метры",
			source_type="inferred", source_reference="разговор 2 сентября",
		)

	def tearDown(self):
		frappe.db.delete(memory.DOCTYPE)
		frappe.set_user("Administrator")

	def test_a_fact_arrives_as_a_sentence_with_its_origin(self):
		"""Человек, не видящий источника, не может решить, верить ли факту."""
		from korkem_ai.korkem_ai import memory_api

		shown = memory_api.list()["company"][0]

		self.assertIn("квадратные метры", shown["text"])
		self.assertIn("разговор 2 сентября", shown["source_label"])
		self.assertFalse(shown["confirmed"])

	def test_correcting_a_fact_makes_it_stated_and_certain(self):
		from korkem_ai.korkem_ai import memory_api

		memory_api.update(self.fact, "погонные метры")

		row = frappe.db.get_value(
			memory.DOCTYPE, self.fact, ["value", "source_type", "confidence"], as_dict=True
		)
		self.assertEqual(row.value, "погонные метры")
		self.assertEqual(row.source_type, "stated")
		self.assertEqual(row.confidence, 1.0)

	def test_an_empty_correction_is_not_a_way_to_delete(self):
		"""Иначе пустое поле стирало бы память случайным касанием."""
		from korkem_ai.korkem_ai import memory_api

		with self.assertRaises(frappe.ValidationError):
			memory_api.update(self.fact, "   ")

	def test_a_deleted_fact_leaves_the_screen(self):
		from korkem_ai.korkem_ai import memory_api

		memory_api.delete(self.fact)

		self.assertEqual(memory_api.list()["company"], [])

	def test_somebody_elses_fact_cannot_be_touched_by_knowing_its_id(self):
		"""Без этой проверки достаточно знать идентификатор."""
		from korkem_ai.korkem_ai import memory_api

		theirs = memory.remember(
			scope=memory.USER, category="preference", subject="язык",
			predicate="рабочий", value="казахский", owner="Administrator",
		)

		frappe.set_user("Guest")
		try:
			with self.assertRaises(frappe.PermissionError):
				memory_api.delete(theirs)
		finally:
			frappe.set_user("Administrator")
