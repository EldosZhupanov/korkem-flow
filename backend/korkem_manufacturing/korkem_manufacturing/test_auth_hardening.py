# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Regression tests for the guest-facing onboarding doors.

Each test is one way a stranger got in before 2026-10-26, written as the attack:

* the published code ``1234`` verified any phone on a pilot site, and the
  server handed the code back in its own response;
* registering under an existing company's name made the caller its owner;
* accepting an invitation with somebody else's email reset that person's
  password and replaced their phone;
* an invitation addressed to one phone worked for any phone;
* analytics stored full phone numbers in the Activity Log.
"""

from __future__ import annotations

from unittest import mock

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils.password import check_password, update_password

from korkem_ai.korkem_ai import environment, onboarding
from korkem_manufacturing.services import analytics, auth_otp, invitations, registration

COMPANY = "Цех Проверки Входа"
OWNER = "owner.authcheck@test.korkem"


def _drop_user(email: str) -> None:
	if not frappe.db.exists("User", email):
		return
	frappe.db.set_value("User", email, "enabled", 0, update_modified=False)
	for name in frappe.get_all("User Permission", filters={"user": email}, pluck="name"):
		frappe.delete_doc("User Permission", name, force=True, ignore_permissions=True)
	for name in frappe.get_all("Contact", filters={"user": email}, pluck="name"):
		frappe.delete_doc("Contact", name, force=True, ignore_permissions=True)
	frappe.delete_doc("User", email, force=True, ignore_permissions=True)
	frappe.db.commit()


class _OnAPilotSite:
	"""Make this process behave as a `pilot` site outside the test runner."""

	def __enter__(self):
		self._in_test = frappe.flags.in_test
		frappe.flags.in_test = False
		self._patch = mock.patch.object(environment, "current", return_value=environment.PILOT)
		self._patch.start()
		return self

	def __exit__(self, *exc):
		self._patch.stop()
		frappe.flags.in_test = self._in_test
		return False


class TestTheFixedCodeIsForDevelopmentOnly(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		self.phone = "+7705" + "".join(str(int(c, 16) % 10) for c in frappe.generate_hash(length=7))

	def tearDown(self):
		frappe.cache.delete_value(f"otp_rate:{self.phone}")
		frappe.cache.delete_value(f"otp_code:{self.phone}")

	def test_a_pilot_never_returns_the_code(self):
		with _OnAPilotSite():
			result = auth_otp.request_otp(self.phone)
		self.assertIsNone(result["dev_code"])
		code = frappe.cache.get_value(f"otp_code:{self.phone}")["code"]
		self.assertNotIn(code, result["message"])

	def test_a_pilot_refuses_the_published_code(self):
		# Pin the random code away from 1234, so the test cannot pass by luck.
		with _OnAPilotSite(), mock.patch.object(auth_otp.secrets, "randbelow", return_value=4321 - 1000):
			auth_otp.request_otp(self.phone)
			with self.assertRaises(frappe.ValidationError):
				auth_otp.verify_otp(self.phone, auth_otp.DEV_DEFAULT_CODE)

	def test_a_pilot_refuses_the_published_code_even_without_a_request(self):
		with _OnAPilotSite(), self.assertRaises(frappe.ValidationError):
			auth_otp.verify_otp(self.phone, auth_otp.DEV_DEFAULT_CODE)

	def test_a_pilot_accepts_the_code_it_actually_issued(self):
		with _OnAPilotSite(), mock.patch.object(auth_otp.secrets, "randbelow", return_value=4321 - 1000):
			auth_otp.request_otp(self.phone)
			result = auth_otp.verify_otp(self.phone, "4321")
		self.assertTrue(result["verified"])

	def test_development_still_works_without_an_sms_gateway(self):
		result = auth_otp.request_otp(self.phone)
		self.assertEqual(result["dev_code"], auth_otp.DEV_DEFAULT_CODE)
		self.assertTrue(auth_otp.verify_otp(self.phone, result["dev_code"])["verified"])


class TestRegistrationCannotJoinAnExistingCompany(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		self.company = f"Чужой Цех {frappe.generate_hash(length=6)}"
		self.owner = f"owner.{frappe.generate_hash(length=6)}@test.korkem"
		self.stranger = f"stranger.{frappe.generate_hash(length=6)}@test.korkem"

	def tearDown(self):
		frappe.set_user("Administrator")
		for email in (self.stranger, self.owner):
			_drop_user(email)
		if frappe.db.exists("Company", self.company):
			frappe.delete_doc("Company", self.company, force=True, ignore_permissions=True)
		frappe.db.commit()

	def test_a_second_registration_under_the_same_name_is_refused(self):
		registration.register_company(company_name=self.company, owner_name="Настоящий Владелец", email=self.owner)

		with self.assertRaises(registration.AlreadyRegistered):
			registration.register_company(company_name=self.company, owner_name="Посторонний", email=self.stranger)

		self.assertFalse(frappe.db.exists("User", self.stranger))
		self.assertFalse(
			frappe.db.exists("User Permission", {"user": self.stranger, "allow": "Company", "for_value": self.company})
		)


class TestAnInvitationCannotTakeOverAnAccount(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		if not frappe.db.exists("Company", COMPANY):
			frappe.get_doc(
				{
					"doctype": "Company",
					"company_name": COMPANY,
					"abbr": "ЦПВ",
					"default_currency": "KZT",
					"country": "Kazakhstan",
				}
			).insert(ignore_permissions=True)
		onboarding.create_owner(OWNER, "Owner Authcheck", COMPANY)
		frappe.db.commit()

	@classmethod
	def tearDownClass(cls):
		frappe.set_user("Administrator")
		frappe.db.rollback()
		_drop_user(OWNER)
		if frappe.db.exists("Company", COMPANY):
			frappe.delete_doc("Company", COMPANY, force=True, ignore_permissions=True)
		frappe.db.commit()
		super().tearDownClass()

	def setUp(self):
		frappe.set_user("Administrator")
		self.victim = f"victim.{frappe.generate_hash(length=6)}@test.korkem"
		self.newcomer = None
		frappe.get_doc(
			{
				"doctype": "User",
				"email": self.victim,
				"first_name": "Жертва",
				"mobile_no": "+77010000001",
				"enabled": 1,
				"send_welcome_email": 0,
			}
		).insert(ignore_permissions=True)
		update_password(self.victim, "Victim-Original-1")
		frappe.db.commit()
		self.invites = []

	def tearDown(self):
		frappe.set_user("Administrator")
		for email in (self.victim, self.newcomer):
			if email:
				_drop_user(email)
		for name in self.invites:
			if frappe.db.exists("Company Invitation", name):
				frappe.delete_doc("Company Invitation", name, force=True, ignore_permissions=True)
		frappe.db.commit()

	def _invite(self, phone: str = "") -> str:
		frappe.set_user(OWNER)
		invite = invitations.create_invitation(role_name="CUTTING_OPERATOR", phone=phone, company=COMPANY)
		frappe.set_user("Guest")
		self.invites.append(invite["invitation_id"])
		return invite["token"]

	def test_somebody_elses_email_is_refused_and_their_password_survives(self):
		token = self._invite()
		with self.assertRaises(frappe.PermissionError):
			invitations.accept_invitation(
				token=token,
				phone="+77019998877",
				full_name="Посторонний Человек",
				email=self.victim,
				password="Attacker-Chosen-1",
			)
		frappe.set_user("Administrator")
		self.assertEqual(check_password(self.victim, "Victim-Original-1", delete_tracker_cache=False), self.victim)
		self.assertEqual(frappe.db.get_value("User", self.victim, "mobile_no"), "+77010000001")

	def test_the_same_person_on_the_same_phone_joins_without_a_new_password(self):
		token = self._invite()
		result = invitations.accept_invitation(
			token=token,
			phone="+77010000001",
			full_name="Жертва Тот же",
			email=self.victim,
			password="Some-Other-Pass-1",
		)
		self.assertEqual(result["user"], self.victim)
		frappe.set_user("Administrator")
		self.assertEqual(check_password(self.victim, "Victim-Original-1", delete_tracker_cache=False), self.victim)

	def test_an_invitation_for_one_phone_is_refused_on_another(self):
		token = self._invite(phone="+7 (701) 555-44-33")
		with self.assertRaises(frappe.PermissionError):
			invitations.accept_invitation(token=token, phone="+77016667788", full_name="Не Тот Номер")

	def test_an_invitation_for_one_phone_is_accepted_on_that_phone(self):
		token = self._invite(phone="+7 (701) 555-44-33")
		result = invitations.accept_invitation(token=token, phone="87015554433", full_name="Тот Самый Номер")
		self.newcomer = result["user"]
		self.assertEqual(result["status"], "ok")


class TestAnalyticsDoesNotKeepPhoneNumbers(IntegrationTestCase):
	def test_a_phone_is_masked(self):
		cleaned = analytics.sanitize_properties({"phone": "+77011234567", "role": "OWNER"})
		self.assertEqual(cleaned["phone"], "***67")
		self.assertEqual(cleaned["role"], "OWNER")
