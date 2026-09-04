# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Лента событий: что в неё попадает и что из неё не пропадает.

Два теста здесь важнее остальных.

`test_a_started_order_is_not_reported_as_unstarted` — потому что лента, зовущая
сделать сделанное, перестаёт читаться, и вместе с шумом проезжает настоящая
тревога.

`test_hiding_is_for_a_day_not_forever` — потому что скрытый просроченный заказ
остаётся просроченным, а кнопка, убирающая тревогу насовсем, однажды уберёт ту
единственную, ради которой всё это писалось.
"""

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai import events_api
from korkem_ai.korkem_ai.events import detectors
from korkem_ai.korkem_ai.tools import scope

COMPANY = "KORKEM"


class _EventTestCase(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		from korkem_manufacturing import seed_demo

		seed_demo.seed_users()
		frappe.db.delete(events_api.DOCTYPE, {"user": "Administrator"})

	def borrow_order(self, **changes):
		"""Одолжить заказ из демо-набора и вернуть его как было.

		Откат транзакции здесь не защита: `seed_users()` в setUp фиксирует
		транзакцию, и что именно переживёт тест, зависит от порядка вызовов, а
		не от намерения. Однажды это уже стоило десяти чужих падений — на стенде
		остались заказы со сроком «пять дней назад» и статусом «Закрыт», и
		падали проверки закупок, которым этот срок был нужен настоящим.

		Поэтому — явное восстановление, а не надежда на откат.
		"""
		name = self.any_order()
		before = frappe.db.get_value("Sales Order", name, list(changes), as_dict=True)
		self.addCleanup(frappe.db.set_value, "Sales Order", name, dict(before))
		frappe.db.set_value("Sales Order", name, changes)
		return name

	def any_order(self):
		rows = frappe.get_all(
			"Sales Order",
			filters={
				"company": COMPANY,
				"docstatus": 1,
				# Закрытый заказ не просрочен — он сделан, и детектор его не
				# вернёт. Брать такой в фикстуру значит проверять не то.
				"status": ["not in", detectors.LIVE],
			},
			pluck="name",
			limit=1,
		)
		if not rows:
			self.skipTest("на стенде нет живых проведённых заказов КОРКЕМ")
		return rows[0]


class TestWhatTheFactoryNotices(_EventTestCase):
	def test_an_overdue_order_is_reported_with_the_day_it_became_overdue(self):
		"""«С каких пор» выводится из данных, а не из момента, когда мы
		посмотрели: иначе это не «заметил», а «взглянул»."""
		order = self.borrow_order(
			delivery_date=frappe.utils.add_days(frappe.utils.nowdate(), -5)
		)

		found = [e for e in detectors.overdue_orders(COMPANY) if e["subject"]["name"] == order]

		self.assertTrue(found, "просроченный заказ должен попасть в ленту")
		self.assertEqual(found[0]["noticed_at"], str(frappe.db.get_value("Sales Order", order, "delivery_date")))
		self.assertEqual(found[0]["severity"], detectors.HIGH)

	def test_a_started_order_is_not_reported_as_unstarted(self):
		"""Лента, зовущая сделать сделанное, перестаёт читаться."""
		started = frappe.get_all(
			"Work Order",
			filters={"docstatus": ["<", 2], "sales_order": ["is", "set"]},
			fields=["sales_order"],
			limit=1,
		)
		if not started:
			self.skipTest("на стенде нет заказов с производственным заданием")
		order = started[0].sales_order
		before = frappe.db.get_value("Sales Order", order, "delivery_date")
		self.addCleanup(frappe.db.set_value, "Sales Order", order, "delivery_date", before)
		frappe.db.set_value(
			"Sales Order", order, "delivery_date", frappe.utils.add_days(frappe.utils.nowdate(), 1)
		)

		at_risk = [e["subject"]["name"] for e in detectors.deadlines_at_risk(COMPANY)]

		self.assertNotIn(order, at_risk)

	def test_a_closed_order_is_not_overdue_it_is_done(self):
		order = self.borrow_order(
			delivery_date=frappe.utils.add_days(frappe.utils.nowdate(), -5),
			status="Closed",
		)

		names = [e["subject"]["name"] for e in detectors.overdue_orders(COMPANY)]

		self.assertNotIn(order, names)

	def test_a_broken_detector_does_not_take_the_whole_feed_with_it(self):
		"""Человек скорее останется без одной строки, чем без всех."""
		from unittest.mock import patch

		with patch.object(detectors, "overdue_orders", side_effect=RuntimeError("boom")):
			events = detectors.all_for(COMPANY)

		self.assertIsInstance(events, list)

	def test_the_urgent_comes_first(self):
		events = detectors.all_for(COMPANY)
		severities = [e["severity"] for e in events]
		rank = {detectors.HIGH: 0, detectors.MEDIUM: 1, detectors.LOW: 2}
		self.assertEqual(severities, sorted(severities, key=lambda s: rank[s]))


class TestHiding(_EventTestCase):
	def test_hiding_removes_it_from_this_persons_feed(self):
		order = self.borrow_order(
			delivery_date=frappe.utils.add_days(frappe.utils.nowdate(), -5)
		)
		event_id = f"overdue_order:{order}"
		self.assertIn(event_id, [e["id"] for e in events_api.pending()["events"]])

		events_api.dismiss(event_id)

		self.assertNotIn(event_id, [e["id"] for e in events_api.pending()["events"]])

	def test_hiding_is_for_a_day_not_forever(self):
		"""Скрытый просроченный заказ остаётся просроченным."""
		order = self.borrow_order(
			delivery_date=frappe.utils.add_days(frappe.utils.nowdate(), -5)
		)
		event_id = f"overdue_order:{order}"
		events_api.dismiss(event_id)

		name = frappe.db.get_value(
			events_api.DOCTYPE, {"user": "Administrator", "event_id": event_id}, "name"
		)
		frappe.db.set_value(
			events_api.DOCTYPE, name, "hidden_until", frappe.utils.add_to_date(
				frappe.utils.now_datetime(), hours=-1
			)
		)

		self.assertIn(event_id, [e["id"] for e in events_api.pending()["events"]])

	def test_hiding_twice_does_not_leave_two_rows(self):
		events_api.dismiss("overdue_order:whatever")
		events_api.dismiss("overdue_order:whatever")

		self.assertEqual(
			frappe.db.count(
				events_api.DOCTYPE,
				{"user": "Administrator", "event_id": "overdue_order:whatever"},
			),
			1,
		)

	def test_one_persons_hiding_is_not_anothers(self):
		"""Мастер, отложивший своё, не убирает тревогу у владельца."""
		order = self.borrow_order(
			delivery_date=frappe.utils.add_days(frappe.utils.nowdate(), -5)
		)
		event_id = f"overdue_order:{order}"
		events_api.dismiss(event_id)

		frappe.set_user("korkem.planner@example.com")
		try:
			if scope.current_company() != COMPANY:
				self.skipTest("планировщик не в КОРКЕМ на этом стенде")
			self.assertIn(event_id, [e["id"] for e in events_api.pending()["events"]])
		finally:
			frappe.set_user("Administrator")

	def test_hiding_nothing_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			events_api.dismiss("")
