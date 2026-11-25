# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""«Утренняя сводка» (owner, 25.11.2026): what to hand over, what is due
and late, who owes the most, what is short."""

from __future__ import annotations

import uuid

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, nowdate

from korkem_manufacturing.services import facade_prices, mdf_customers, mdf_orders, morning_brief

COMPANY = "KORKEM"
MANAGER = "brief.manager@example.com"
FLAT = "МДФ Тест Сводка 90°"
PVC = facade_prices.PVC


class TestMorningBrief(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		facade_prices.seed_company(COMPANY)
		if not frappe.db.exists("User", MANAGER):
			frappe.get_doc({"doctype": "User", "email": MANAGER, "first_name": "brief", "send_welcome_email": 0,
							"roles": [{"role": "Sales User"}]}).insert(ignore_permissions=True)
		frappe.defaults.set_user_default("Company", COMPANY, user=MANAGER)

	def setUp(self):
		frappe.set_user("Administrator")
		facade_prices.set_price(FLAT, PVC, 10_000)
		tail = uuid.uuid4().int % 10_000_000
		frappe.set_user(MANAGER)
		try:
			self.customer = mdf_customers.add(f"Сводка Тест {tail}", f"8 708 {tail:07d}")["name"]
		finally:
			frappe.set_user("Administrator")

	def tearDown(self):
		frappe.set_user("Administrator")

	def _order(self, qty: int = 2) -> str:
		frappe.set_user(MANAGER)
		try:
			card = mdf_orders.save_draft(
				customer=self.customer, delivery_date=add_days(nowdate(), 7),
				head={"finish": PVC, "thickness_mm": 16},
				lines=[{"height_mm": 1000, "width_mm": 500, "qty": qty, "milling": FLAT}],
			)
			return mdf_orders.accept(card["name"])["name"]
		finally:
			frappe.set_user("Administrator")

	def test_the_morning_names_what_to_hand_over_what_is_due_and_late_and_who_owes(self):
		ready, today, late = self._order(), self._order(), self._order(4000)  # the last owes 20 000 000
		frappe.db.set_value("Sales Order", ready, "korkem_ready_on", nowdate())
		frappe.db.set_value("Sales Order", today, "delivery_date", nowdate())
		frappe.db.set_value("Sales Order", late, "delivery_date", add_days(nowdate(), -3))
		b = morning_brief.collect(COMPANY, staff=False)
		self.assertIn(ready, [x["order"] for x in b["ready"]])
		self.assertIn(today, [x["order"] for x in b["due_today"]])
		self.assertEqual(next(x for x in b["late"] if x["order"] == late)["days"], 3)
		self.assertEqual(b["debtors"][0]["customer"], self.customer)
		self.assertEqual(b["debtors"][0]["debt"], 20_020_000)
		text = morning_brief.text(b, COMPANY)
		self.assertIn("Готово, можно выдавать", text)
		self.assertIn("Срок сегодня", text)
		self.assertIn("— на 3 дн.", text)
		self.assertIn("Больше всех", text)

	def test_a_part_with_nothing_is_left_out_and_an_empty_morning_says_nothing(self):
		empty = {"day": nowdate(), "ready": [], "due_today": [], "late": [], "owed": 0, "debtors": [], "film": [],
				 "paint": [], "reorder": {"films": [], "glue": []}}
		self.assertIsNone(morning_brief.text(empty, COMPANY))
		short = morning_brief.text({**empty, "film": [{"title": "Белый Матовый", "short": 12.5, "unit": "м",
													  "orders": 3}],
									"paint": [{"title": "RAL 9003", "short": 3.2}]}, COMPANY)
		self.assertIn("плёнка Белый Матовый — 12,5 м (3 зак.)", short)
		self.assertIn("краска RAL 9003 — 3,2 кг", short)
		self.assertNotIn("Опаздывают", short)
		many = [{"order": f"SO-{i}", "number": i, "customer": "К", "debt": 0} for i in range(8)]
		self.assertIn("и ещё 3", morning_brief.text({**empty, "ready": many}, COMPANY))
