# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Ключи TrustMe и Kaspi: место есть, а наружу они не выходят."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.services import integration_settings as service


class TestIntegrationSettings(IntegrationTestCase):
	def tearDown(self):
		frappe.set_user("Administrator")

	def test_status_says_what_is_configured_without_saying_what(self):
		service.save(
			provider="kaspi",
			values={"merchant_id": "KZ-777", "api_key": "секрет-который-нельзя-показывать"},
		)

		state = service.status()
		self.assertEqual(state["kaspi"]["merchant_id"], "KZ-777")
		self.assertTrue(state["kaspi"]["configured"]["api_key"])

		body = frappe.as_json(state)
		self.assertNotIn("секрет-который-нельзя-показывать", body)

	def test_a_secret_never_comes_back_from_the_api(self):
		"""Поле `Password` Frappe не отдаёт — на этом всё и держится."""
		from korkem_manufacturing.api import integration_settings as api

		api.save(provider="trustme", values={"api_token": "трастми-токен-12345"})

		body = frappe.as_json(api.status())
		self.assertNotIn("трастми-токен-12345", body)

	def test_an_empty_field_does_not_erase_the_key(self):
		"""Владелец правит БИН и не должен вводить заново токен, которого не видит."""
		service.save(provider="trustme", values={"api_token": "первый-токен"})
		service.save(provider="trustme", values={"organization_bin": "123456789012"})

		state = service.status()["trustme"]
		self.assertEqual(state["organization_bin"], "123456789012")
		self.assertTrue(state["configured"]["api_token"])

	def test_clearing_a_key_is_a_separate_deliberate_action(self):
		"""Стереть ключ — значит отключить приём оплаты. Не по забывчивости."""
		service.save(provider="kaspi", values={"api_key": "ключ"})
		self.assertTrue(service.status()["kaspi"]["configured"]["api_key"])

		service.clear_secret(provider="kaspi", field="api_key")
		self.assertFalse(service.status()["kaspi"]["configured"]["api_key"])

	def test_clearing_something_that_is_not_a_secret_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			service.clear_secret(provider="kaspi", field="merchant_id")

	def test_an_unknown_integration_is_refused_by_name(self):
		with self.assertRaises(frappe.ValidationError):
			service.save(provider="paypal", values={})

	def test_an_employee_sees_none_of_this(self):
		"""Ключи оплаты и подписи — не то, что показывают замерщику."""
		from korkem_manufacturing.services import invitations

		email = f"zamer-{frappe.generate_hash(length=8)}@korkem.kz"
		invitations.invite_employee(email=email, position="shop_floor")

		frappe.set_user(email)
		with self.assertRaises(frappe.PermissionError):
			service.status()

	def test_the_secret_is_not_stored_in_the_document_table(self):
		"""Оно лежит в `__Auth`, зашифрованным, а не рядом с БИН в открытую."""
		service.save(provider="kaspi", values={"api_key": "проверяемый-ключ"})

		row = frappe.db.sql(
			"SELECT field, value FROM `tabSingles` WHERE doctype = %s", "Kaspi Settings"
		)
		stored = {field: value for field, value in row}
		self.assertNotIn("проверяемый-ключ", frappe.as_json(stored))
