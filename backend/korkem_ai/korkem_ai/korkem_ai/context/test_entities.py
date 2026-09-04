# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""«Этот заказ» должен указывать на тот заказ — или ни на какой."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai.context import entities

PERSON = "entity-test@korkem.kz"


def _person(email: str, *, employee: bool = False) -> str:
	"""Человек для проверки.

	`employee` — с ролью цеха. Без неё `policy.role_of` считает человека
	клиентом, а клиенту инструменты склада и продаж не положены: политика
	работает верно, и обходить её в тесте значило бы проверять не тот путь.
	"""
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": "Проверка", "send_welcome_email": 0}
		).insert(ignore_permissions=True)
	if employee:
		doc = frappe.get_doc("User", email)
		if "Manufacturing User" not in {r.role for r in doc.get("roles") or []}:
			doc.append("roles", {"role": "Manufacturing User"})
			doc.save(ignore_permissions=True)
	return email


class TestTheConversationKeepsItsSubject(IntegrationTestCase):
	def setUp(self):
		self.user = _person(PERSON)
		frappe.db.delete(entities.DOCTYPE, {"user": self.user})

	def tearDown(self):
		frappe.db.delete(entities.DOCTYPE, {"user": self.user})

	def test_this_order_points_at_the_order_just_found(self):
		entities.remember("order", "SAL-ORD-2026-00042", user=self.user)

		self.assertEqual(
			entities.current("order", user=self.user), "SAL-ORD-2026-00042"
		)

	def test_naming_another_one_replaces_it(self):
		"""«А теперь по заказу Асхата» — обычный ход разговора, не ошибка."""
		entities.remember("order", "SAL-ORD-00001", user=self.user)
		entities.remember("order", "SAL-ORD-00002", user=self.user)

		self.assertEqual(entities.current("order", user=self.user), "SAL-ORD-00002")

	def test_a_switch_is_visible_to_the_caller(self):
		entities.remember("order", "SAL-ORD-00001", user=self.user)

		self.assertTrue(entities.switched("order", "SAL-ORD-00002", user=self.user))
		self.assertFalse(entities.switched("order", "SAL-ORD-00001", user=self.user))

	def test_one_persons_conversation_is_not_anothers(self):
		other = _person("entity-other@korkem.kz")
		frappe.db.delete(entities.DOCTYPE, {"user": other})

		entities.remember("order", "SAL-ORD-00001", user=self.user)

		self.assertIsNone(entities.current("order", user=other))


class TestAStaleReferenceIsNotUsed(IntegrationTestCase):
	"""«Этот заказ» вчерашний и «этот заказ» минуту назад — разные вещи.

	Молча применить вчерашний к сегодняшнему «поменяй срок» значит поменять
	срок не тому заказу, и человек об этом не узнает.
	"""

	def setUp(self):
		self.user = _person(PERSON)
		frappe.db.delete(entities.DOCTYPE, {"user": self.user})

	def tearDown(self):
		frappe.db.delete(entities.DOCTYPE, {"user": self.user})

	def _age(self, minutes: int):
		import json

		raw = json.loads(frappe.db.get_value(entities.DOCTYPE, self.user, "entities"))
		raw["order"]["at"] = frappe.utils.add_to_date(
			frappe.utils.now_datetime(), minutes=-minutes
		).isoformat()
		frappe.db.set_value(entities.DOCTYPE, self.user, "entities", json.dumps(raw))

	def test_an_hour_old_reference_is_not_offered(self):
		entities.remember("order", "SAL-ORD-00001", user=self.user)
		self._age(60)

		self.assertIsNone(entities.current("order", user=self.user))

	def test_a_minute_old_reference_still_works(self):
		entities.remember("order", "SAL-ORD-00001", user=self.user)
		self._age(1)

		self.assertEqual(entities.current("order", user=self.user), "SAL-ORD-00001")

	def test_a_stale_reference_is_kept_but_not_shown_to_the_model(self):
		"""Запись остаётся ради вопроса «почему KORKEM переспросил»."""
		entities.remember("order", "SAL-ORD-00001", user=self.user)
		self._age(60)

		self.assertTrue(frappe.db.exists(entities.DOCTYPE, self.user))
		self.assertNotIn("SAL-ORD-00001", entities.described(user=self.user))


class TestMoneyNeverUsesAPronoun(IntegrationTestCase):
	"""Счёт, оплата, договор, списание.

	Цена ошибки — чужие деньги, и она не отыгрывается назад. Переспросить
	дешевле, чем выставить счёт не тому.
	"""

	def setUp(self):
		self.user = _person(PERSON)
		frappe.db.delete(entities.DOCTYPE, {"user": self.user})
		entities.remember("order", "SAL-ORD-00001", user=self.user)

	def tearDown(self):
		frappe.db.delete(entities.DOCTYPE, {"user": self.user})

	def test_a_risky_action_gets_nothing_even_from_a_fresh_reference(self):
		self.assertEqual(entities.current("order", user=self.user), "SAL-ORD-00001")
		self.assertIsNone(
			entities.current("order", user=self.user, for_risky=True),
			"для денег ссылка не подставляется даже свежая",
		)

	def test_the_model_is_told_to_ask_instead_of_assuming(self):
		text = entities.described(user=self.user)

		self.assertIn("money", text)
		self.assertIn("ask which one", text)


class TestTheToolsAreWhatFillTheContext(IntegrationTestCase):
	"""Предмет разговора берётся из найденного, а не из сказанного.

	Человек мог сказать «заказ Ерлана», а найтись мог заказ Ерлана Сериковича —
	и «этот заказ» должно указывать на найденное.
	"""

	def setUp(self):
		self.user = _person("entity-tools@korkem.kz", employee=True)
		frappe.db.delete(entities.DOCTYPE, {"user": self.user})
		frappe.set_user(self.user)
		self.names = []

	def tearDown(self):
		from korkem_ai.korkem_ai.tools import registry

		frappe.set_user("Administrator")
		for name in self.names:
			registry._REGISTRY.pop(name, None)
		frappe.db.delete(entities.DOCTYPE, {"user": self.user})

	def _tool(self, payload):
		from korkem_ai.korkem_ai.tools import registry

		name = f"sales.find_{frappe.generate_hash(length=6)}"
		self.names.append(name)
		registry._REGISTRY[name] = registry.ToolSpec(
			name=name,
			description="проверка",
			input_schema={"type": "object", "properties": {}},
			risk=registry.Risk.READ,
			handler=lambda **kw: payload,
		)
		return name

	def test_a_found_order_becomes_this_order(self):
		from korkem_ai.korkem_ai.tools import registry

		tool = self._tool({"sales_order": "SAL-ORD-2026-00042", "total": 650000})

		result = registry.execute(tool, {})

		self.assertTrue(result["ok"], result)
		self.assertEqual(
			entities.current("order", user=self.user), "SAL-ORD-2026-00042"
		)

	def test_a_result_without_a_subject_changes_nothing(self):
		from korkem_ai.korkem_ai.tools import registry

		entities.remember("order", "SAL-ORD-00001", user=self.user)
		registry.execute(self._tool({"count": 3, "total": 12}), {})

		self.assertEqual(entities.current("order", user=self.user), "SAL-ORD-00001")

	def test_a_broken_context_never_breaks_the_tool(self):
		"""Контекст, уронивший ход, хуже отсутствующего контекста."""
		from unittest.mock import patch

		from korkem_ai.korkem_ai.tools import registry

		tool = self._tool({"sales_order": "SAL-ORD-00003"})
		with patch.object(entities, "remember", side_effect=RuntimeError("база упала")):
			result = registry.execute(tool, {})

		self.assertTrue(result["ok"])
