# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

from types import SimpleNamespace
from unittest.mock import patch

from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai import cache
from korkem_ai.korkem_ai.agent.loop import TurnResult
from korkem_ai.korkem_ai.orchestrator.protocol import AIToolCall


class TestSemanticCache(IntegrationTestCase):
	def setUp(self):
		cache.clear_cache()

	def tearDown(self):
		cache.clear_cache()

	def test_normalization_strips_punctuation_fillers_and_spaces(self):
		q1 = "Подскажи пожалуйста, сколько ЛДСП на складе???"
		q2 = "сколько ЛДСП на складе?"
		q3 = "Сколько   ЛДСП на складе"
		self.assertEqual(cache.normalize(q1), "сколько лдсп на складе")
		self.assertEqual(cache.normalize(q1), cache.normalize(q2))
		self.assertEqual(cache.normalize(q2), cache.normalize(q3))

	def test_kazakh_queries_normalize_cleanly(self):
		q1 = "Айтшы, қоймада қанша ЛДСП қалды?"
		q2 = "Қоймада қанша ЛДСП қалды"
		self.assertEqual(cache.normalize(q1), cache.normalize(q2))

	def test_greeting_detection(self):
		self.assertTrue(cache.is_greeting("Привет"))
		self.assertTrue(cache.is_greeting("Сәлем!"))
		self.assertTrue(cache.is_greeting("Добрый день, кто ты?"))
		self.assertFalse(cache.is_greeting("Где заказ 104?"))
		self.assertFalse(cache.is_greeting("Сколько ЛДСП на складе?"))

	def test_put_and_get_roundtrip(self):
		q = "где заказ 104?"
		cache.put(q, "Заказ 104 находится на этапе распила.", company="TestCo", role="Owner")

		hit = cache.get(q, company="TestCo", role="Owner")
		self.assertIsNotNone(hit)
		self.assertEqual(hit["text"], "Заказ 104 находится на этапе распила.")

		# Normalized variation hits the exact same cache
		hit2 = cache.get("Подскажи пожалуйста, где заказ 104???", company="TestCo", role="Owner")
		self.assertIsNotNone(hit2)
		self.assertEqual(hit2["text"], "Заказ 104 находится на этапе распила.")

	def test_multi_tenant_isolation(self):
		q = "сколько ЛДСП на складе?"
		cache.put(q, "У Компании А осталось 40 листов.", company="CompanyA", role="Owner")

		hit_a = cache.get(q, company="CompanyA", role="Owner")
		hit_b = cache.get(q, company="CompanyB", role="Owner")

		self.assertIsNotNone(hit_a)
		self.assertIsNone(hit_b, "Другая компания никогда не должна видеть чужой кэш")

	def test_role_isolation(self):
		q = "покажи финансовую сводку"
		cache.put(q, "Маржа 35%, чистая прибыль 1.2M", company="CompanyA", role="Owner")

		hit_owner = cache.get(q, company="CompanyA", role="Owner")
		hit_measurer = cache.get(q, company="CompanyA", role="Measurer")

		self.assertIsNotNone(hit_owner)
		self.assertIsNone(hit_measurer, "Другая роль не должна видеть чужой финансовый ответ")

	def test_writes_and_pending_actions_are_never_cached(self):
		# Turn with pending proposals must not be cached
		res_pending = TurnResult(
			status="needs_confirmation",
			text="Создать заказ?",
			pending=(AIToolCall(id="call_1", name="sales.create_sales_order", arguments={}),),
		)
		self.assertFalse(cache.is_cacheable(res_pending))

		# Turn that executed a write tool must not be cached
		res_write = TurnResult(
			status="answered",
			text="Заказ создан",
			executed=[{"tool": "sales.create_sales_order", "ok": True}],
		)
		self.assertFalse(cache.is_cacheable(res_write))

		# Read-only answered turn is safe to cache
		res_read = TurnResult(
			status="answered",
			text="На складе 45 листов ЛДСП Дуб Сонома",
			executed=[{"tool": "inventory.get_stock", "ok": True}],
		)
		self.assertTrue(cache.is_cacheable(res_read))
