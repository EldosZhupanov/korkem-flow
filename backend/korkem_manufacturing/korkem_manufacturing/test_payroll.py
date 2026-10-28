# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""The pay sheet: crews share a facade, bonuses follow thresholds, fines and
advances are entered by one person and approved by another."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, flt, get_first_day, get_last_day, nowdate

from korkem_manufacturing.services import (
	facade_jobs,
	facade_order,
	facade_prices,
	payroll,
	piece_rates,
	piece_work,
)

COMPANY = "KORKEM"
CHIEF = "pay.chief@example.com"
DEPUTY = "pay.deputy@example.com"
ANNA = "pay.anna@example.com"
BORIS = "pay.boris@example.com"
SELLER = "pay.seller@example.com"
BOOKKEEPER = "pay.bookkeeper@example.com"
STRANGER = "pay.stranger@example.com"


def _user(email: str, role: str, company: str = COMPANY) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", company, user=email)
	# Company membership is ERPNext's User Permission — what onboarding creates.
	if not frappe.db.exists("User Permission", {"user": email, "allow": "Company", "for_value": company}):
		frappe.get_doc(
			{"doctype": "User Permission", "user": email, "allow": "Company", "for_value": company,
			 "apply_to_all_doctypes": 1}
		).insert(ignore_permissions=True)


class TestPayroll(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		_user(CHIEF, "Manufacturing Manager")
		_user(DEPUTY, "Manufacturing Manager")
		_user(ANNA, "Manufacturing User")
		_user(BORIS, "Manufacturing User")
		_user(SELLER, "Sales User")
		_user(BOOKKEEPER, "Accounts User")
		other = frappe.db.get_value("Company", {"name": ["!=", COMPANY]}, "name")
		_user(STRANGER, "Manufacturing User", other or COMPANY)
		cls.stranger_elsewhere = bool(other)
		facade_prices.seed_company(COMPANY)

	def setUp(self):
		frappe.set_user("Administrator")
		frappe.db.delete("Piece Work Rules", {"company": COMPANY})
		piece_rates.set_rate(piece_rates.FACADE_OPERATION, piece_rates.PER_M2, 2_000)
		self.customer = frappe.db.get_value("Customer", {"disabled": 0}, "name")

	def tearDown(self):
		frappe.set_user("Administrator")

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	def _accrue(self, worker: str, amount: float, approve: bool = True):
		entry = piece_work.record_piece_work(
			company=COMPANY, employee=worker, operation="Раскрой", rate_type="KZT_PER_PART",
			quantity=1, rate=amount, idempotency_key=f"pay-test:{frappe.generate_hash(length=10)}",
		)
		if approve:
			piece_work.approve_piece_work(entry.name, approved_by=CHIEF)
		return entry

	def _row(self, worker: str, **period) -> dict:
		rows = self._as(CHIEF, payroll.statement, **period)["rows"]
		return next((r for r in rows if r["employee"] == worker), None)

	def _facade_line(self) -> tuple[str, str]:
		order = self._as(
			SELLER,
			facade_order.create_order,
			customer=self.customer,
			delivery_date=add_days(nowdate(), 10),
			lines=[{"width_mm": 500, "height_mm": 400, "qty": 10, "milling": "Квадро", "finish": facade_prices.PVC}],
		)["sales_order"]
		line = frappe.db.get_value("Sales Order Item", {"parent": order, "korkem_width_mm": [">", 0]}, "name")
		return order, line

	# --- crews ---------------------------------------------------------------

	def test_a_crew_shares_a_facade_equally_unless_told_otherwise(self):
		_, line = self._facade_line()  # 2 m² at 2 000 ₸ = 4 000 ₸
		self._as(ANNA, facade_jobs.set_status, line, facade_jobs.DONE, crew=[{"user": ANNA}, {"user": BORIS}])
		paid = {
			e.employee: flt(e.amount)
			for e in frappe.get_all("Piece Work Entry", filters={"idempotency_key": ["like", f"facade:{line}:%"]},
									fields=["employee", "amount"])
		}
		self.assertEqual(paid, {ANNA: 2_000, BORIS: 2_000})

	def test_a_crew_can_split_by_share(self):
		_, line = self._facade_line()
		self._as(ANNA, facade_jobs.set_status, line, facade_jobs.DONE,
				 crew=[{"user": ANNA, "share": 70}, {"user": BORIS, "share": 30}])
		paid = {
			e.employee: flt(e.amount)
			for e in frappe.get_all("Piece Work Entry", filters={"idempotency_key": ["like", f"facade:{line}:%"]},
									fields=["employee", "amount"])
		}
		self.assertEqual(paid, {ANNA: 2_800, BORIS: 1_200})

	def test_shares_must_add_up_and_the_crew_must_work_here(self):
		_, line = self._facade_line()
		with self.assertRaises(frappe.ValidationError):
			self._as(ANNA, facade_jobs.set_status, line, facade_jobs.DONE,
					 crew=[{"user": ANNA, "share": 70}, {"user": BORIS, "share": 20}])
		# Refused before anything was written: the facade is not «Готово».
		self.assertNotEqual(
			frappe.db.get_value("Sales Order Item", line, "korkem_facade_status"), facade_jobs.DONE
		)
		if self.stranger_elsewhere:
			with self.assertRaises(frappe.DoesNotExistError):
				self._as(ANNA, facade_jobs.set_status, line, facade_jobs.DONE,
						 crew=[{"user": ANNA}, {"user": STRANGER}])

	def test_taking_a_crew_s_facade_back_reverses_everyone_s_share(self):
		_, line = self._facade_line()
		self._as(ANNA, facade_jobs.set_status, line, facade_jobs.DONE, crew=[{"user": ANNA}, {"user": BORIS}])
		self._as(ANNA, facade_jobs.set_status, line, facade_jobs.IN_WORK)
		live = frappe.get_all(
			"Piece Work Entry",
			filters={"idempotency_key": ["like", f"facade:{line}:%"], "status": ["!=", "Reversed"],
					 "reversed_entry": ["is", "not set"]},
		)
		self.assertEqual(live, [])

	# --- adjustments ------------------------------------------------------------

	def test_an_advance_is_approved_by_someone_else(self):
		advance = self._as(CHIEF, payroll.add_adjustment, ANNA, payroll.ADVANCE, 10_000, "Аванс за неделю")
		with self.assertRaises(frappe.PermissionError):
			self._as(CHIEF, payroll.approve_adjustment, advance["adjustment"])
		approved = self._as(DEPUTY, payroll.approve_adjustment, advance["adjustment"])
		self.assertEqual(approved["status"], "Approved")

	def test_the_floor_cannot_fine_or_read_the_sheet(self):
		with self.assertRaises(frappe.PermissionError):
			self._as(ANNA, payroll.add_adjustment, BORIS, payroll.FINE, 5_000, "Брак")
		with self.assertRaises(frappe.PermissionError):
			self._as(ANNA, payroll.statement)
		self.assertIsNotNone(self._as(BOOKKEEPER, payroll.statement))

	def test_a_wrong_fine_is_reversed_with_a_reason_not_deleted(self):
		fine = self._as(CHIEF, payroll.add_adjustment, BORIS, payroll.FINE, 3_000, "Скол на фасаде")
		with self.assertRaises(frappe.ValidationError):
			self._as(DEPUTY, payroll.reverse_adjustment, fine["adjustment"], "")
		reversed_ = self._as(DEPUTY, payroll.reverse_adjustment, fine["adjustment"], "Скол был до нас")
		self.assertEqual(reversed_["status"], "Reversed")
		self.assertTrue(frappe.db.exists("Pay Adjustment", fine["adjustment"]))

	# --- the statement -------------------------------------------------------------

	def test_the_sheet_adds_up_and_leaves_unchecked_work_out(self):
		self._accrue(ANNA, 20_000)
		self._accrue(ANNA, 5_000, approve=False)
		for kind, amount in ((payroll.ADVANCE, 8_000), (payroll.FINE, 1_500), (payroll.BONUS, 3_000)):
			adj = self._as(CHIEF, payroll.add_adjustment, ANNA, kind, amount, f"{kind} для теста")
			self._as(DEPUTY, payroll.approve_adjustment, adj["adjustment"])
		row = self._row(ANNA)
		self.assertGreaterEqual(row["piece"], 20_000)
		self.assertGreaterEqual(row["pending"], 5_000)
		self.assertEqual(
			row["to_pay"],
			round(row["piece"] + row["daily_bonus"] + row["monthly_bonus"] + row["bonus"] - row["fine"] - row["advance"], 2),
		)
		self.assertGreaterEqual(row["advance"], 8_000)

	def test_a_day_over_the_threshold_earns_the_daily_bonus(self):
		piece_rates.save_rules(daily_bonus_threshold=1, daily_bonus=2_500)
		self._accrue(BORIS, 10_000)
		today = str(frappe.utils.getdate(nowdate()))
		self.assertEqual(self._row(BORIS, from_date=today, to_date=today)["daily_bonus"], 2_500)

	def test_a_month_earns_its_bonus_only_in_a_sheet_that_covers_it(self):
		piece_rates.save_rules(monthly_bonus_threshold=1, monthly_bonus=20_000)
		self._accrue(BORIS, 10_000)
		today = frappe.utils.getdate(nowdate())
		whole = self._row(BORIS, from_date=str(get_first_day(today)), to_date=str(get_last_day(today)))
		self.assertEqual(whole["monthly_bonus"], 20_000)
		part = self._row(BORIS, from_date=str(today), to_date=str(today))
		self.assertEqual(part["monthly_bonus"], 0)

	def test_a_worker_sees_how_far_the_bonus_is(self):
		piece_rates.save_rules(daily_bonus_threshold=1_000_000, daily_bonus=5_000)
		self._accrue(ANNA, 1_000)
		progress = self._as(ANNA, payroll.my_progress)
		self.assertFalse(progress["today"]["reached"])
		self.assertEqual(progress["today"]["left"], round(1_000_000 - progress["today"]["earned"], 2))
		self.assertIsNone(progress["month"])

	def test_the_sheet_exports_for_accounting(self):
		self._accrue(ANNA, 1_000)
		text = self._as(BOOKKEEPER, payroll.statement_csv)
		self.assertIn("К выплате", text.splitlines()[0])
		self.assertTrue(text.strip().splitlines()[-1].startswith("Итого"))

	def test_a_worker_may_see_who_works_here_by_name_only(self):
		people = self._as(ANNA, payroll.workers)
		users = {p["user"] for p in people}
		self.assertIn(BORIS, users)
		self.assertEqual(set(people[0]), {"user", "name"})
		if self.stranger_elsewhere:
			self.assertNotIn(STRANGER, users)
