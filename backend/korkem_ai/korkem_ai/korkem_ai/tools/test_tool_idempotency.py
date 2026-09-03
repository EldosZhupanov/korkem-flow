# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Пишущий инструмент выполняется один раз за ход. Даже когда ответ потерян."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai.tools import registry

RUN = "turn-under-test"


def _spec(name: str, risk: registry.Risk, handler) -> registry.ToolSpec:
	spec = registry.ToolSpec(
		name=name,
		description="проверка",
		input_schema={"type": "object", "properties": {}},
		risk=risk,
		handler=handler,
	)
	registry._REGISTRY[name] = spec
	return spec


class TestAWriteHappensOnce(IntegrationTestCase):
	"""Сценарий, который порядок в цикле агента не закрывает.

	Раньше от повтора защищало одно: инструмент выполнился, результат лёг в
	историю, следующая модель его не повторила. Это верно ровно для случая,
	когда результат вернулся.

	Не закрывалось это:

	    crm.create_order()  →  заказ создан
	                        →  процесс упал до записи результата
	                        →  ход перезапустили
	                        →  модель просит то же самое

	Истории нет, модель не знает, что заказ уже есть, заказов становится два.
	"""

	def setUp(self):
		self.calls = []
		self.names = []

	def tearDown(self):
		for name in self.names:
			registry._REGISTRY.pop(name, None)
		frappe.set_user("Administrator")

	def _register(self, name, risk):
		self.names.append(name)

		def handler(**kwargs):
			self.calls.append(kwargs)
			return {"order": f"SAL-{len(self.calls)}"}

		_spec(name, risk, handler)
		return name

	def test_the_same_call_repeated_after_a_lost_answer_creates_nothing_new(self):
		"""Ход перезапущен, инструмент вызван снова — заказ остаётся один."""
		tool = self._register(f"test.write.{frappe.generate_hash(length=6)}", registry.Risk.WRITE)

		first = registry.execute(tool, {"item": "кухня"}, run_id=RUN)
		second = registry.execute(tool, {"item": "кухня"}, run_id=RUN)

		self.assertTrue(first["ok"] and second["ok"])
		self.assertEqual(len(self.calls), 1, "побочный эффект выполнился дважды")
		self.assertEqual(
			second["data"],
			first["data"],
			"повтор обязан вернуть сохранённый ответ первого вызова",
		)

	def test_the_same_tool_with_other_arguments_is_another_intent(self):
		"""Два задания за один ход — это две записи, а не одна потерянная."""
		tool = self._register(f"test.write.{frappe.generate_hash(length=6)}", registry.Risk.WRITE)

		registry.execute(tool, {"item": "кухня"}, run_id=RUN)
		registry.execute(tool, {"item": "шкаф"}, run_id=RUN)

		self.assertEqual(len(self.calls), 2)

	def test_another_turn_asking_the_same_thing_is_a_new_order(self):
		"""Клиент заказал такую же кухню завтра — это новый заказ, а не повтор."""
		tool = self._register(f"test.write.{frappe.generate_hash(length=6)}", registry.Risk.WRITE)

		registry.execute(tool, {"item": "кухня"}, run_id="turn-one")
		registry.execute(tool, {"item": "кухня"}, run_id="turn-two")

		self.assertEqual(len(self.calls), 2)

	def test_a_destructive_tool_is_protected_too(self):
		tool = self._register(
			f"test.destroy.{frappe.generate_hash(length=6)}", registry.Risk.DESTRUCTIVE
		)

		registry.execute(tool, {"name": "x"}, run_id=RUN)
		registry.execute(tool, {"name": "x"}, run_id=RUN)

		self.assertEqual(len(self.calls), 1)

	def test_a_read_leaves_no_record_behind(self):
		"""Запись о каждом чтении — мусор в таблице и лишняя строка на запрос."""
		tool = self._register(f"test.read.{frappe.generate_hash(length=6)}", registry.Risk.READ)

		registry.execute(tool, {"q": "склад"}, run_id=RUN)
		registry.execute(tool, {"q": "склад"}, run_id=RUN)

		self.assertEqual(len(self.calls), 2, "чтение не обязано повторять сохранённое")
		self.assertFalse(
			frappe.get_all(
				"Idempotency Record", filters={"action": f"ai_tool:{tool}"}, limit=1
			),
			"на читающий инструмент записей быть не должно",
		)

	def test_without_a_run_id_there_is_no_protection_and_that_is_visible(self):
		"""Явно закреплено: вызывающий без хода платит дубликатом.

		Проверка существует не чтобы разрешить это, а чтобы никто не считал,
		будто защита появляется сама.
		"""
		tool = self._register(f"test.write.{frappe.generate_hash(length=6)}", registry.Risk.WRITE)

		registry.execute(tool, {"item": "кухня"})
		registry.execute(tool, {"item": "кухня"})

		self.assertEqual(len(self.calls), 2)


class TestTheRecordSurvivesTheAnswerBeingLost(IntegrationTestCase):
	"""Запись о выполнении и сам эффект коммитятся одной транзакцией."""

	def tearDown(self):
		for name in getattr(self, "names", []):
			registry._REGISTRY.pop(name, None)

	def test_a_completed_record_exists_after_a_write(self):
		self.names = [f"test.write.{frappe.generate_hash(length=6)}"]
		_spec(self.names[0], registry.Risk.WRITE, lambda **kw: {"order": "SAL-1"})

		registry.execute(self.names[0], {"item": "кухня"}, run_id=RUN)

		rows = frappe.get_all(
			"Idempotency Record",
			filters={"action": f"ai_tool:{self.names[0]}"},
			fields=["status"],
		)
		self.assertEqual([r["status"] for r in rows], ["Completed"])

	def test_a_failing_write_leaves_no_completed_record(self):
		"""Иначе повтор вернул бы «успешно» для того, чего не произошло."""
		self.names = [f"test.write.{frappe.generate_hash(length=6)}"]

		def explode(**kwargs):
			raise frappe.ValidationError("склад отказал")

		_spec(self.names[0], registry.Risk.WRITE, explode)

		result = registry.execute(self.names[0], {"item": "кухня"}, run_id=RUN)

		self.assertFalse(result["ok"])
		self.assertFalse(
			frappe.get_all(
				"Idempotency Record",
				filters={"action": f"ai_tool:{self.names[0]}", "status": "Completed"},
				limit=1,
			)
		)
