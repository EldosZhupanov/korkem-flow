# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Piece-rate pay follows what was booked — never what the worker typed."""

from __future__ import annotations

from datetime import datetime

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, flt, nowdate

from korkem_manufacturing.services import facade_jobs, facade_order, facade_prices, piece_rates

COMPANY = "KORKEM"
CUTTER = "rates.cutter@example.com"
CHIEF = "rates.chief@example.com"
SELLER = "rates.seller@example.com"

#: A Wednesday at 10:00, a Wednesday at 20:00, a Sunday at 10:00.
WEEKDAY = datetime(2026, 10, 28, 10, 0)
EVENING = datetime(2026, 10, 28, 20, 0)
SUNDAY = datetime(2026, 11, 1, 10, 0)


def _user(email: str, role: str) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)


def _stage(**overrides) -> dict:
	# A real job card: the entry links to it, and Frappe checks the link.
	card = frappe.db.get_value("Job Card", {"company": COMPANY}, "name")
	return {
		"status": "completed", "operation": "Раскрой", "job_card": card,
		"work_order": None, "booked_now": 4, "good_qty": 4, **overrides,
	}


class TestPieceRates(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		_user(CUTTER, "Manufacturing User")
		_user(CHIEF, "Manufacturing Manager")
		_user(SELLER, "Sales User")
		facade_prices.seed_company(COMPANY)

	def setUp(self):
		frappe.set_user("Administrator")
		frappe.db.delete("Piece Work Rules", {"company": COMPANY})
		self.assertTrue(frappe.db.exists("Job Card", {"company": COMPANY}), "seeded site has job cards")
		frappe.db.delete("Piece Work Entry", {"idempotency_key": ["like", "stage:%"]})
		piece_rates.set_rate("Раскрой", piece_rates.PER_PART, 150)
		piece_rates.set_rate(piece_rates.FACADE_OPERATION, piece_rates.PER_M2, 2_000)

	def tearDown(self):
		frappe.set_user("Administrator")

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	# --- what a stage pays ------------------------------------------------

	def test_a_finished_stage_pays_the_booked_pieces_at_the_rate(self):
		entry = self._as(CUTTER, piece_rates.accrue_stage, _stage(), WEEKDAY)
		self.assertEqual((entry.employee, flt(entry.quantity), flt(entry.amount)), (CUTTER, 4, 600))
		self.assertEqual(entry.status, "Pending Approval")

	def test_the_same_booking_replayed_pays_once(self):
		first = self._as(CUTTER, piece_rates.accrue_stage, _stage(), WEEKDAY)
		second = self._as(CUTTER, piece_rates.accrue_stage, _stage(), WEEKDAY)
		self.assertEqual(first.name, second.name)

	def test_nothing_booked_pays_nothing(self):
		self.assertIsNone(self._as(CUTTER, piece_rates.accrue_stage, _stage(booked_now=0), WEEKDAY))
		self.assertIsNone(self._as(CUTTER, piece_rates.accrue_stage, _stage(status="already_complete"), WEEKDAY))

	def test_an_operation_without_a_rate_pays_nothing_rather_than_a_guess(self):
		self.assertIsNone(self._as(CUTTER, piece_rates.accrue_stage, _stage(operation="Покраска"), WEEKDAY))

	# --- coefficients, from the clock and the admin's rules ----------------

	def test_no_rules_means_ordinary_pay_even_in_the_evening(self):
		self.assertEqual(piece_rates.shift_of(EVENING, COMPANY), (piece_rates.NORMAL, 1.0))

	def test_overtime_after_the_shift_ends(self):
		piece_rates.save_rules(shift_end="18:00:00", overtime_factor=1.5)
		entry = self._as(CUTTER, piece_rates.accrue_stage, _stage(), EVENING)
		self.assertEqual((entry.shift_kind, flt(entry.amount)), (piece_rates.OVERTIME, 900))

	def test_a_day_off_pays_the_weekend_factor(self):
		piece_rates.save_rules(weekend_factor=2)
		entry = self._as(CUTTER, piece_rates.accrue_stage, _stage(), SUNDAY)
		self.assertEqual((entry.shift_kind, flt(entry.amount)), (piece_rates.WEEKEND, 1_200))

	def test_saturday_is_a_working_day_unless_the_admin_says_otherwise(self):
		saturday = datetime(2026, 10, 31, 10, 0)
		piece_rates.save_rules(weekend_factor=2)
		self.assertEqual(piece_rates.shift_of(saturday, COMPANY)[0], piece_rates.NORMAL)
		piece_rates.save_rules(saturday_is_weekend=1)
		self.assertEqual(piece_rates.shift_of(saturday, COMPANY)[0], piece_rates.WEEKEND)

	def test_impossible_rules_are_refused(self):
		with self.assertRaises(frappe.ValidationError):
			piece_rates.save_rules(overtime_factor=1.5)  # no shift end
		with self.assertRaises(frappe.ValidationError):
			piece_rates.save_rules(weekend_factor=0.5)

	# --- approval -----------------------------------------------------------

	def test_the_chief_approves_and_the_worker_sees_it(self):
		entry = self._as(CUTTER, piece_rates.accrue_stage, _stage(), WEEKDAY)
		self._as(CHIEF, piece_rates.approve, entry.name)
		mine = self._as(CUTTER, piece_rates.my_work)
		self.assertGreaterEqual(mine["totals"]["approved"], 600)

	def test_nobody_approves_their_own_pay(self):
		entry = self._as(CHIEF, piece_rates.accrue_stage, _stage(good_qty=99), WEEKDAY)
		with self.assertRaises(frappe.PermissionError):
			self._as(CHIEF, piece_rates.approve, entry.name)

	def test_a_worker_cannot_approve(self):
		entry = self._as(CUTTER, piece_rates.accrue_stage, _stage(), WEEKDAY)
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, piece_rates.approve, entry.name)

	def test_a_rejection_needs_a_reason_and_cancels_the_pay(self):
		entry = self._as(CUTTER, piece_rates.accrue_stage, _stage(), WEEKDAY)
		with self.assertRaises(frappe.ValidationError):
			self._as(CHIEF, piece_rates.reject, entry.name, "")
		self._as(CHIEF, piece_rates.reject, entry.name, "Брак не засчитан")
		mine = self._as(CUTTER, piece_rates.my_work)
		reversed_ = [e for e in mine["entries"] if e["entry"] == entry.name]
		self.assertEqual(reversed_[0]["status"], "Reversed")

	def test_rates_are_set_by_the_admin_or_the_chief_only(self):
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, piece_rates.set_rate, "Раскрой", piece_rates.PER_PART, 1_000)
		with self.assertRaises(frappe.PermissionError):
			self._as(SELLER, piece_rates.save_rules, weekend_factor=3)
		self._as(CHIEF, piece_rates.set_rate, "Кромка", piece_rates.PER_PART, 80)

	# --- facades ------------------------------------------------------------

	def _facade_line(self) -> tuple[str, str]:
		customer = frappe.db.get_value("Customer", {"disabled": 0}, "name")
		order = facade_order.create_order(
			customer=customer,
			delivery_date=add_days(nowdate(), 10),
			lines=[{"width_mm": 500, "height_mm": 400, "qty": 2, "milling": "Квадро", "finish": facade_prices.PVC}],
		)["sales_order"]
		line = frappe.db.get_value("Sales Order Item", {"parent": order, "korkem_width_mm": [">", 0]}, "name")
		return order, line

	def test_a_finished_facade_pays_its_area(self):
		_, line = self._facade_line()
		self._as(CUTTER, facade_jobs.set_status, line, facade_jobs.DONE)
		entries = frappe.get_all(
			"Piece Work Entry", filters={"idempotency_key": ["like", f"facade:{line}:%"]}, fields=["amount", "employee"]
		)
		# 0.4 m² × 2 000 ₸, before any coefficient the clock may add.
		self.assertEqual(len(entries), 1)
		self.assertEqual(entries[0].employee, CUTTER)
		self.assertGreaterEqual(flt(entries[0].amount), 800)

	def test_taking_a_facade_back_from_done_reverses_the_pay(self):
		_, line = self._facade_line()
		self._as(CUTTER, facade_jobs.set_status, line, facade_jobs.DONE)
		self._as(CUTTER, facade_jobs.set_status, line, facade_jobs.IN_WORK)
		live = frappe.get_all(
			"Piece Work Entry",
			filters={"idempotency_key": ["like", f"facade:{line}:%"], "status": "Pending Approval"},
		)
		self.assertEqual(live, [])
