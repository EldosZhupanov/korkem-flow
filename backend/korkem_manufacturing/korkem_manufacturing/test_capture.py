# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Catching what was said — the feature the product now rests on.

Every test here is written against one sentence from the interview that
produced this feature: the owner is at the machine, the customer calls, and the
order is late because nobody was told. So the tests care about two things above
all — that the sentence survives, and that somebody is told.
"""

from __future__ import annotations

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.api import capture as api
from korkem_manufacturing.services import capture as service


class TestRecordingWhatWasSaid(IntegrationTestCase):
	def tearDown(self):
		frappe.set_user("Administrator")

	def test_a_sentence_is_recorded_with_no_model_at_all(self):
		"""The point of the whole feature: it must not need an LLM.

		The notepad this replaces works when the internet is down and when
		nobody has paid for a model. If ours does not, it is worse than the
		notepad and nobody will use it twice.
		"""
		result = service.record(text="Айгуль, кухня, замер в четверг")

		self.assertEqual(result["status"], "Recorded")
		self.assertEqual(result["understood"], {})
		stored = frappe.get_doc("Capture", result["capture"])
		self.assertEqual(stored.spoken_text, "Айгуль, кухня, замер в четверг")
		self.assertTrue(stored.company)

	def test_what_the_model_understood_is_stored_beside_the_sentence(self):
		result = service.record(
			text="Айгуль, кухня три двести на шестьсот, ЛДСП белый глянец",
			understood={
				"customer_hint": "Айгуль",
				"product_hint": "Кухня",
				"size_hint": "3200x600",
				"material_hint": "ЛДСП белый глянец",
			},
		)

		self.assertEqual(result["status"], "Understood")
		self.assertEqual(result["understood"]["customer_hint"], "Айгуль")
		stored = frappe.get_doc("Capture", result["capture"])
		# The sentence is kept verbatim even when the model read it well: what
		# the person actually said is the record, the interpretation is a guess.
		self.assertIn("три двести", stored.spoken_text)

	def test_an_empty_capture_is_refused_rather_than_stored(self):
		with self.assertRaises(frappe.ValidationError):
			service.record(text="   ")

	def test_a_nonsense_understood_payload_never_costs_the_sentence(self):
		"""A client that garbles its JSON still said something worth keeping."""
		result = api.record(text="Позвонить Серику про фасады", understood="{not json")

		self.assertEqual(result["status"], "Recorded")
		stored = frappe.get_doc("Capture", result["capture"])
		self.assertEqual(stored.spoken_text, "Позвонить Серику про фасады")


class TestHandingItToSomebody(IntegrationTestCase):
	"""The half a notepad cannot do, and the half the order was late for."""

	def tearDown(self):
		frappe.set_user("Administrator")

	def test_a_task_is_created_and_points_back_at_what_was_said(self):
		result = service.record(
			text="Замерить кухню у Айгуль, Абая 12",
			assign_to="Administrator",
			due_on=frappe.utils.add_days(frappe.utils.nowdate(), 2),
		)

		self.assertIsNotNone(result["task"])
		task = frappe.get_doc("CRM Task", result["task"])
		self.assertEqual(task.assigned_to, "Administrator")
		self.assertEqual(task.reference_doctype, "Capture")
		self.assertEqual(task.reference_docname, result["capture"])
		# The title carries the sentence: somebody opening their task list must
		# know what it is about without a second tap.
		self.assertIn("Айгуль", task.title)

	def test_the_due_date_falls_back_to_what_the_model_heard(self):
		wanted = frappe.utils.add_days(frappe.utils.nowdate(), 3)
		result = service.record(
			text="Замер в четверг",
			understood={"due_hint": wanted},
			assign_to="Administrator",
		)

		task = frappe.get_doc("CRM Task", result["task"])
		# Compared as dates, not as strings: CRM Task stores this as a datetime,
		# so "2026-09-06" comes back as "2026-09-06 00:00:00".
		self.assertEqual(frappe.utils.getdate(task.due_date), frappe.utils.getdate(wanted))

	def test_without_an_assignee_the_capture_still_survives(self):
		"""Nobody to hand it to is not a reason to lose the sentence."""
		result = service.record(text="Уточнить цвет у Марата")

		self.assertIsNone(result["task"])
		self.assertTrue(frappe.db.exists("Capture", result["capture"]))


class TestTheNumbersThatAnswerTheOwner(IntegrationTestCase):
	"""«Могу ли я не нанимать администратора» — вопрос про числа, не про мнение."""

	def tearDown(self):
		frappe.set_user("Administrator")

	def test_stats_count_caught_handed_over_and_stale(self):
		service.record(text="Один", assign_to="Administrator")
		service.record(text="Два")

		result = service.stats(days=1)

		self.assertGreaterEqual(result["caught"], 2)
		self.assertGreaterEqual(result["handed_over"], 1)
		self.assertEqual(result["days"], 1)

	def test_a_fresh_capture_is_not_yet_stale(self):
		"""Stale means forgotten, and nothing is forgotten in its first hour."""
		service.record(text="Только что сказано")
		self.assertEqual(service.stats(days=1)["stale"], 0)

	def test_something_left_unassigned_overnight_counts_as_stale(self):
		result = service.record(text="Забытое вчера")
		frappe.db.set_value(
			"Capture",
			result["capture"],
			"creation",
			frappe.utils.add_days(frappe.utils.now_datetime(), -2),
			update_modified=False,
		)

		self.assertGreaterEqual(service.stats(days=7)["stale"], 1)

	def test_the_window_cannot_be_stretched_without_limit(self):
		with patch.object(service, "_count", return_value=0):
			self.assertEqual(service.stats(days=100000)["days"], 365)
			self.assertEqual(service.stats(days=0)["days"], 30)


class TestCompanyScope(IntegrationTestCase):
	"""A capture belongs to one factory, decided server-side."""

	def test_company_is_not_a_caller_argument(self):
		import inspect

		self.assertNotIn("company", inspect.signature(service.record).parameters)
		self.assertNotIn("company", inspect.signature(api.record).parameters)

	def test_a_capture_without_a_company_in_scope_is_refused(self):
		with patch.object(service, "scoped", return_value={}):
			with self.assertRaises(frappe.ValidationError):
				service.record(text="Ничей")
