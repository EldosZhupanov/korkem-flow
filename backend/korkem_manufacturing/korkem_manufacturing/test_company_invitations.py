# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Comprehensive test suite for Native Onboarding, Phone OTP, and Company Invitations.

Validates all 10 security and workflow invariants:
1. Valid invite flow works end-to-end
2. Expired invite rejected
3. Revoked invite rejected
4. Replayed/already used invite rejected
5. Token guessing fails
6. Cross-tenant isolation
7. Non-admin cannot generate invites
8. Role assignment matches invited role exactly
9. Phone OTP validation behaves correctly
10. Logo upload and graceful initials fallback
"""

from __future__ import annotations

import base64
import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, now_datetime

from korkem_ai.korkem_ai import onboarding
from korkem_manufacturing.services import auth_otp, invitations, registration

COMPANY_A = "Цех Алатау Тест"
COMPANY_B = "Цех Байтерек Тест"
OWNER_A = "owner.alatau@test.korkem"
OWNER_B = "owner.baiterek@test.korkem"


class TestCompanyInvitationsAndOnboarding(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		frappe.clear_cache()
		# Clean up any leftover test companies
		for comp in [COMPANY_A, COMPANY_B]:
			if not frappe.db.exists("Company", comp):
				letters = [c for c in comp.upper() if c.isalnum()]
				abbr = "".join(letters[:4]) or "TEST"
				frappe.get_doc({
					"doctype": "Company",
					"company_name": comp,
					"abbr": abbr,
					"default_currency": "KZT",
					"country": "Kazakhstan",
				}).insert(ignore_permissions=True)

		onboarding.create_owner(OWNER_A, "Owner Alatau", COMPANY_A)
		onboarding.create_owner(OWNER_B, "Owner Baiterek", COMPANY_B)
		frappe.db.commit()

	@classmethod
	def tearDownClass(cls):
		frappe.set_user("Administrator")
		frappe.db.rollback()
		for user in [OWNER_A, OWNER_B]:
			cls._drop_user(user)
		for comp in [COMPANY_A, COMPANY_B]:
			if frappe.db.exists("Company", comp):
				frappe.delete_doc("Company", comp, force=True, ignore_permissions=True)
		frappe.db.commit()
		super().tearDownClass()

	def setUp(self):
		frappe.set_user("Administrator")
		self.users_to_clean = []
		self.invites_to_clean = []

	def tearDown(self):
		frappe.set_user("Administrator")
		for email in reversed(self.users_to_clean):
			self._drop_user(email)
		for inv_id in self.invites_to_clean:
			if frappe.db.exists("Company Invitation", inv_id):
				frappe.delete_doc("Company Invitation", inv_id, force=True, ignore_permissions=True)
		frappe.db.commit()

	@staticmethod
	def _drop_user(email: str) -> None:
		if not frappe.db.exists("User", email):
			return
		frappe.db.set_value("User", email, "enabled", 0, update_modified=False)
		frappe.db.commit()
		for name in frappe.get_all("User Permission", filters={"user": email}, pluck="name"):
			frappe.delete_doc("User Permission", name, force=True, ignore_permissions=True)
		for name in frappe.get_all("Contact", filters={"user": email}, pluck="name"):
			frappe.delete_doc("Contact", name, force=True, ignore_permissions=True)
		frappe.db.commit()
		frappe.delete_doc("User", email, force=True, ignore_permissions=True)

	# 1. Valid invite flow works end-to-end
	def test_01_valid_invite_flow_end_to_end(self):
		frappe.set_user(OWNER_A)
		invite = invitations.create_invitation(
			role_name="CUTTING_OPERATOR",
			phone="+77011112233",
			company=COMPANY_A,
		)
		self.invites_to_clean.append(invite["invitation_id"])
		token = invite["token"]

		# Public query gets info
		frappe.set_user("Guest")
		info = invitations.get_invitation_info(token)
		self.assertTrue(info["valid"])
		self.assertEqual(info["company_name"], COMPANY_A)
		self.assertEqual(info["role_name"], "CUTTING_OPERATOR")
		self.assertEqual(info["landing_route"], "/workstations/Раскрой")

		# Accept invitation
		worker_email = "cutter.test.01@korkem.test"
		self.users_to_clean.append(worker_email)
		result = invitations.accept_invitation(
			token=token,
			phone="+77011112233",
			full_name="Раскройщик Нурлан",
			email=worker_email,
			password="Password123!",
		)
		self.assertEqual(result["status"], "ok")
		self.assertEqual(result["company"], COMPANY_A)
		self.assertEqual(result["landing_route"], "/workstations/Раскрой")

		# Check user created and bound to Company A
		self.assertTrue(frappe.db.exists("User", worker_email))
		bound_company = frappe.db.get_value(
			"User Permission",
			{"user": worker_email, "allow": "Company"},
			"for_value",
		)
		self.assertEqual(bound_company, COMPANY_A)

		# Invitation status is now ACCEPTED
		inv_status = frappe.db.get_value("Company Invitation", invite["invitation_id"], "status")
		self.assertEqual(inv_status, "ACCEPTED")

	# 2. Expired invite rejected
	def test_02_expired_invite_rejected(self):
		frappe.set_user(OWNER_A)
		invite = invitations.create_invitation(
			role_name="ASSEMBLER",
			company=COMPANY_A,
		)
		self.invites_to_clean.append(invite["invitation_id"])

		# Manually expire the invitation
		frappe.set_user("Administrator")
		past_time = add_days(now_datetime(), -2)
		frappe.db.set_value("Company Invitation", invite["invitation_id"], "expires_at", past_time)
		frappe.db.commit()

		frappe.set_user("Guest")
		info = invitations.get_invitation_info(invite["token"])
		self.assertFalse(info["valid"])
		self.assertEqual(info["status"], "EXPIRED")

		with self.assertRaises(frappe.ValidationError):
			invitations.accept_invitation(
				token=invite["token"],
				phone="+77012223344",
				full_name="Сборщик Марат",
			)

	# 3. Revoked invite rejected
	def test_03_revoked_invite_rejected(self):
		frappe.set_user(OWNER_A)
		invite = invitations.create_invitation(
			role_name="MEASURER",
			company=COMPANY_A,
		)
		self.invites_to_clean.append(invite["invitation_id"])

		# Owner revokes
		invitations.revoke_invitation(invite["invitation_id"])
		status = frappe.db.get_value("Company Invitation", invite["invitation_id"], "status")
		self.assertEqual(status, "REVOKED")

		frappe.set_user("Guest")
		info = invitations.get_invitation_info(invite["token"])
		self.assertFalse(info["valid"])
		self.assertEqual(info["status"], "REVOKED")

		with self.assertRaises(frappe.PermissionError):
			invitations.accept_invitation(
				token=invite["token"],
				phone="+77013334455",
				full_name="Замерщик Серик",
			)

	# 4. Replayed / already used invite rejected
	def test_04_replayed_invite_rejected(self):
		frappe.set_user(OWNER_A)
		invite = invitations.create_invitation(
			role_name="EDGEBANDING_OPERATOR",
			company=COMPANY_A,
		)
		self.invites_to_clean.append(invite["invitation_id"])
		token = invite["token"]

		frappe.set_user("Guest")
		email_1 = "worker1.replayed@test.korkem"
		self.users_to_clean.append(email_1)
		invitations.accept_invitation(
			token=token,
			phone="+77014445566",
			full_name="Кромщик Бауыржан",
			email=email_1,
		)

		# Second attempt must fail
		email_2 = "worker2.replayed@test.korkem"
		self.users_to_clean.append(email_2)
		with self.assertRaises(frappe.ValidationError):
			invitations.accept_invitation(
				token=token,
				phone="+77015556677",
				full_name="Второй Человек",
				email=email_2,
			)

	# 5. Token guessing fails
	def test_05_token_guessing_fails(self):
		frappe.set_user("Guest")
		fake_token = "random_invalid_token_1234567890abcdef"
		info = invitations.get_invitation_info(fake_token)
		self.assertFalse(info["valid"])

		with self.assertRaises(frappe.DoesNotExistError):
			invitations.accept_invitation(
				token=fake_token,
				phone="+77019999999",
				full_name="Злоумышленник",
			)

	# 6. Cross-tenant isolation
	def test_06_cross_tenant_isolation(self):
		# User invited to Company A cannot be bound to Company B
		frappe.set_user(OWNER_A)
		invite = invitations.create_invitation(
			role_name="CNC_OPERATOR",
			company=COMPANY_A,
		)
		self.invites_to_clean.append(invite["invitation_id"])

		frappe.set_user("Guest")
		worker_email = "cnc.isolated@test.korkem"
		self.users_to_clean.append(worker_email)
		invitations.accept_invitation(
			token=invite["token"],
			phone="+77016667788",
			full_name="ЧПУ Айдар",
			email=worker_email,
		)

		# Check user only has permission for Company A, NOT Company B
		perms = frappe.get_all(
			"User Permission",
			filters={"user": worker_email, "allow": "Company"},
			pluck="for_value",
		)
		self.assertIn(COMPANY_A, perms)
		self.assertNotIn(COMPANY_B, perms)

	# 7. Non-admin cannot generate invites
	def test_07_non_admin_cannot_generate_invites(self):
		# Create an employee without System Manager
		employee_email = "standard.worker@test.korkem"
		self.users_to_clean.append(employee_email)
		frappe.set_user("Administrator")
		onboarding.create_employee(
			email=employee_email,
			first_name="Обычный Работник",
			roles=["Manufacturing User"],
			company=COMPANY_A,
		)
		frappe.db.commit()

		frappe.set_user(employee_email)
		with self.assertRaises(frappe.PermissionError):
			invitations.create_invitation(
				role_name="ASSEMBLER",
				company=COMPANY_A,
			)

	# 8. Role assignment matches invited role exactly
	def test_08_role_assignment_matches_invited_role(self):
		frappe.set_user(OWNER_A)
		invite = invitations.create_invitation(
			role_name="ACCOUNTANT",
			company=COMPANY_A,
		)
		self.invites_to_clean.append(invite["invitation_id"])

		frappe.set_user("Guest")
		acct_email = "acct.test@test.korkem"
		self.users_to_clean.append(acct_email)
		invitations.accept_invitation(
			token=invite["token"],
			phone="+77017778899",
			full_name="Бухгалтер Алия",
			email=acct_email,
		)

		user_roles = set(frappe.get_roles(acct_email))
		self.assertIn("Accounts User", user_roles)
		self.assertNotIn("System Manager", user_roles)
		self.assertNotIn("Manufacturing Manager", user_roles)

	# 9. Phone OTP validation behaves correctly
	def test_09_phone_otp_validation(self):
		phone = "+7 (701) 999-12-34"
		# Request OTP
		req = auth_otp.request_otp(phone)
		self.assertEqual(req["status"], "ok")
		self.assertEqual(req["phone"], "+77019991234")

		# Invalid code fails
		with self.assertRaises(frappe.ValidationError):
			auth_otp.verify_otp("+77019991234", "99999")

		# Valid code passes
		verify = auth_otp.verify_otp("+77019991234", "1234")
		self.assertTrue(verify["verified"])
		self.assertTrue(bool(verify["verification_token"]))

	# 10. Logo upload and graceful initials fallback
	def test_10_logo_and_initials_fallback(self):
		# Initials fallback test
		self.assertEqual(registration.get_initials("Korkem Mebel"), "KM")
		self.assertEqual(registration.get_initials("Алатау"), "АЛ")
		self.assertEqual(registration.get_initials("Престиж Дизайн Астана"), "ПД")

		# Register with logo
		test_comp = "Новый Мебельный Цех 2026"
		test_email = "owner.new2026@test.korkem"
		self.users_to_clean.append(test_email)

		# 1x1 transparent PNG base64
		sample_png_b64 = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
		res = registration.register_company(
			company_name=test_comp,
			owner_name="Данияр Сериков",
			email=test_email,
			phone="+77028889900",
			logo_base64=sample_png_b64,
		)
		self.assertEqual(res["status"], "ok")
		self.assertEqual(res["company_initials"], "НМ")
		self.assertTrue(frappe.db.exists("Company", test_comp))

		# Clean up company
		frappe.delete_doc("Company", test_comp, force=True, ignore_permissions=True)
		frappe.db.commit()
