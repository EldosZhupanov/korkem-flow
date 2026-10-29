# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""PIN sign-in: only on a registered tablet, only what the administrator set."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.services import pin_login as service

COMPANY = "KORKEM"
CUTTER = "pin.cutter@example.com"
OWNER = "pin.owner@example.com"
SELLER = "pin.seller@example.com"


def _user(email: str, roles: tuple[str, ...]) -> str:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0].replace(".", " "),
			 "send_welcome_email": 0, "roles": [{"role": r} for r in roles]}
		).insert(ignore_permissions=True)
	if not frappe.db.exists("User Permission", {"user": email, "allow": "Company", "for_value": COMPANY}):
		frappe.get_doc(
			{"doctype": "User Permission", "user": email, "allow": "Company", "for_value": COMPANY}
		).insert(ignore_permissions=True)
	return email


class TestPinLogin(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		_user(CUTTER, ("Manufacturing User",))
		_user(OWNER, ("System Manager",))
		_user(SELLER, ("Sales User",))

	def setUp(self):
		frappe.set_user("Administrator")
		frappe.cache.delete_keys("korkem_pin_failures::")
		self.token = service.register_device("Цех, раскрой")["device_token"]
		service.set_pin(CUTTER, "4821")

	def tearDown(self):
		frappe.set_user("Administrator")

	def _login(self, pin: str, user: str = CUTTER, token: str | None = None):
		frappe.set_user("Guest")
		try:
			return service.login(token or self.token, user, pin)
		finally:
			frappe.set_user("Administrator")

	def test_the_right_pin_on_a_registered_tablet_signs_in(self):
		self.assertEqual(self._login("4821")["status"], "signed_in")

	def test_the_pin_is_stored_hashed_not_readable(self):
		# `__Auth` is a table, not a DocType: read it the way Frappe's own
		# password module does.
		rows = frappe.db.sql(
			"select `password` from `__Auth` where `doctype`=%s and `name`=%s and `fieldname`='pin'",
			(service.PIN_DOCTYPE, CUTTER),
		)
		stored = rows[0][0] if rows else None
		self.assertTrue(stored)
		self.assertNotIn("4821", stored)

	def test_a_wrong_pin_is_refused_without_saying_why(self):
		with self.assertRaises(frappe.AuthenticationError) as caught:
			self._login("0000")
		self.assertEqual(str(caught.exception), service.WRONG)

	def test_a_person_without_a_pin_reads_like_a_wrong_pin(self):
		with self.assertRaises(frappe.AuthenticationError) as caught:
			self._login("4821", user=SELLER)
		self.assertEqual(str(caught.exception), service.WRONG)

	def test_without_the_tablets_token_a_pin_opens_nothing(self):
		with self.assertRaises(frappe.AuthenticationError):
			self._login("4821", token="guessed-token")

	def test_a_revoked_tablet_opens_nothing(self):
		device = frappe.db.get_value(service.DEVICE_DOCTYPE, {"token_hash": service._hash(self.token)}, "name")
		service.revoke_device(device)
		with self.assertRaises(frappe.AuthenticationError):
			self._login("4821")

	def test_five_wrong_pins_lock_the_person_even_against_the_right_one(self):
		for _ in range(service.MAX_USER_FAILURES):
			with self.assertRaises(frappe.AuthenticationError):
				self._login("1111")
		with self.assertRaises(service.PinLocked):
			self._login("4821")

	def test_too_many_failures_lock_the_tablet(self):
		frappe.cache.set_value(
			service._device_key(frappe.db.get_value(service.DEVICE_DOCTYPE, {"token_hash": service._hash(self.token)}, "name")),
			service.MAX_DEVICE_FAILURES_PER_HOUR,
		)
		with self.assertRaises(service.PinLocked):
			self._login("4821")

	def test_an_administrator_gets_no_pin(self):
		with self.assertRaises(frappe.ValidationError):
			service.set_pin(OWNER, "1234")

	def test_a_pin_stops_working_once_its_owner_becomes_an_administrator(self):
		"""Four digits must never open an administrator's account, however it got one."""
		user = frappe.get_doc("User", CUTTER)
		user.append("roles", {"role": "System Manager"})
		user.save(ignore_permissions=True)
		try:
			with self.assertRaises(frappe.AuthenticationError) as caught:
				self._login("4821")
			self.assertEqual(str(caught.exception), service.WRONG)
		finally:
			user.reload()
			user.set("roles", [r for r in user.roles if r.role != "System Manager"])
			user.save(ignore_permissions=True)

	def test_only_digits_four_to_six(self):
		for bad in ("12", "1234567", "12ab"):
			with self.assertRaises(frappe.ValidationError, msg=bad):
				service.set_pin(CUTTER, bad)

	def test_only_the_administrator_sets_pins_or_tablets(self):
		frappe.set_user(SELLER)
		with self.assertRaises(frappe.PermissionError):
			service.set_pin(CUTTER, "5555")
		with self.assertRaises(frappe.PermissionError):
			service.register_device("Мой телефон")

	def test_the_tablet_lists_names_only(self):
		frappe.set_user("Guest")
		people = service.device_people(self.token)["people"]
		frappe.set_user("Administrator")
		row = next(p for p in people if p["user"] == CUTTER)
		self.assertEqual(set(row), {"user", "full_name"})

	def test_clearing_a_pin_closes_that_door(self):
		service.clear_pin(CUTTER)
		with self.assertRaises(frappe.AuthenticationError):
			self._login("4821")

	def test_attempts_are_audited(self):
		with self.assertRaises(frappe.AuthenticationError):
			self._login("0000")
		self._login("4821")
		for action in ("auth.pin_login_wrong", "auth.pin_login_ok"):
			self.assertTrue(frappe.db.exists("Domain Audit Event", {"action": action}), action)

	def test_the_token_is_kept_only_as_a_hash(self):
		self.assertFalse(frappe.db.exists(service.DEVICE_DOCTYPE, {"token_hash": self.token}))
