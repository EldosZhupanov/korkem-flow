# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Отбор инструментов: вопрос про склад не должен нести схемы договоров."""

from __future__ import annotations

from dataclasses import dataclass

from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai.context import tools as ctx


@dataclass
class _Spec:
	name: str
	description: str = "проверка"
	input_schema: dict = None

	def __post_init__(self):
		if self.input_schema is None:
			self.input_schema = {"type": "object", "properties": {"x": {"type": "string"}}}


CATALOGUE = [
	_Spec("inventory.stock"),
	_Spec("inventory.reserve"),
	_Spec("manufacturing.start"),
	_Spec("manufacturing.complete"),
	_Spec("sales.invoice"),
	_Spec("crm.create_lead"),
	_Spec("dispatch.deliver"),
	_Spec("tasks.overdue"),
	_Spec("profile.current_user"),
]


class TestAQuestionBringsOnlyWhatItNeeds(IntegrationTestCase):
	"""Измерено 4 сентября: схемы 65 инструментов — 93% запроса.

	Девяносто три процента уходит на перечисление того, что ассистент умеет,
	ещё до того как человек что-то спросил. Вопрос про склад не нуждается в
	схемах отгрузки, договоров и рабочих мест.
	"""

	def test_a_stock_question_leaves_contracts_behind(self):
		kept, info = ctx.offered("есть ли ЛДСП на складе?", all_specs=CATALOGUE)
		names = {spec.name for spec in kept}

		self.assertIn("inventory.stock", names)
		self.assertNotIn("sales.invoice", names)
		self.assertNotIn("dispatch.deliver", names)
		self.assertFalse(info["unmatched"])

	def test_a_money_question_leaves_the_workshop_behind(self):
		kept, _ = ctx.offered("выстави счёт на 650000", all_specs=CATALOGUE)
		names = {spec.name for spec in kept}

		self.assertIn("sales.invoice", names)
		self.assertNotIn("manufacturing.start", names)

	def test_kazakh_is_understood_too(self):
		"""Половина цеха думает по-казахски и пишет так же."""
		kept, info = ctx.offered("қоймада ЛДСП бар ма?", all_specs=CATALOGUE)

		self.assertFalse(info["unmatched"])
		self.assertIn("inventory.stock", {spec.name for spec in kept})

	def test_who_am_i_is_always_available(self):
		"""Двадцать три токена, без которых модель не отвечает на «кто я»."""
		kept, _ = ctx.offered("есть ли ЛДСП на складе?", all_specs=CATALOGUE)

		self.assertIn("profile.current_user", {spec.name for spec in kept})


class TestAnUnrecognisedQuestionCostsWhatItAlwaysCost(IntegrationTestCase):
	"""Молчащий ассистент хуже дорогого.

	Соблазн — на незнакомый вопрос показать «самое частое». Тогда ассистент
	отвечает «не умею» на то, что умеет, и человек перестаёт спрашивать. Это
	дороже любых токенов.
	"""

	def test_nothing_recognised_means_everything_offered(self):
		kept, info = ctx.offered("расскажи анекдот", all_specs=CATALOGUE)

		self.assertEqual(len(kept), len(CATALOGUE))
		self.assertTrue(info["unmatched"])

	def test_the_miss_is_recorded_so_the_dictionary_can_be_widened(self):
		"""Без этого признака никто не узнает, что словарь отстал от цеха."""
		_, info = ctx.offered("сделай красиво", all_specs=CATALOGUE)

		self.assertTrue(info["unmatched"])
		self.assertEqual(info["tokens"], info["tokens_if_all"])

	def test_a_known_word_with_no_tools_behind_it_falls_back_to_everything(self):
		"""Словарь может разойтись с каталогом: область узнана, инструментов нет."""
		only_sales = [_Spec("sales.invoice")]

		kept, info = ctx.offered("что на складе?", all_specs=only_sales)

		self.assertEqual(len(kept), 1)
		self.assertTrue(info["unmatched"])


class TestTheSavingIsReal(IntegrationTestCase):
	def test_a_narrow_question_costs_a_fraction(self):
		_, info = ctx.offered("что просрочено?", all_specs=CATALOGUE)

		self.assertLess(
			info["tokens"] * 3,
			info["tokens_if_all"],
			"узкий вопрос обязан стоить заметно меньше полного каталога",
		)

	def test_the_report_says_what_was_offered_and_what_it_would_have_cost(self):
		"""Человек должен видеть не только сумму, но и от чего её избавили."""
		_, info = ctx.offered("есть ли ЛДСП на складе?", all_specs=CATALOGUE)

		self.assertLess(info["offered"], info["total"])
		self.assertLess(info["tokens"], info["tokens_if_all"])


class TestTheLoopFollowsThePerson(IntegrationTestCase):
	"""Отбор идёт по последнему вопросу, а не по началу разговора."""

	def test_the_last_question_is_the_one_that_chooses(self):
		"""Разговор начался со склада и перешёл к счетам — выбирают счета."""
		from korkem_ai.korkem_ai.agent import loop
		from korkem_ai.korkem_ai.orchestrator.protocol import AIMessage

		history = [
			AIMessage.user("что на складе?"),
			AIMessage.assistant(text="сорок листов"),
			AIMessage.user("выстави счёт на 650000"),
		]

		self.assertEqual(loop._last_question(history), "выстави счёт на 650000")

	def test_an_empty_history_chooses_nothing_and_that_means_everything(self):
		from korkem_ai.korkem_ai.agent import loop

		self.assertEqual(loop._last_question([]), "")
		_, info = ctx.offered("", all_specs=CATALOGUE)
		self.assertTrue(info["unmatched"], "пустой вопрос — это незнакомый вопрос")
