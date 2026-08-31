# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Configuring the bots from the app, without ever handing it a token.

The rule under test is blunt: no response from this module contains a
credential, and no green light is shown for a connection nobody has made.
"""

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai import channels_api

PLANNER = "korkem.planner@example.com"
#: Deliberately *not* shaped like a real credential. What these tests assert is
#: that whatever is stored never comes back out, and any distinctive string
#: proves that — while a realistic-looking token in a test file is the thing the
#: secret scan exists to catch, and making a scanner judge intent is how a real
#: one eventually slips through.
TOKEN = "telegram-bot-token-placeholder-for-tests"
WHATSAPP_TOKEN = "whatsapp-access-token-placeholder-for-tests"


class _ChannelsApiTestCase(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		from korkem_manufacturing import seed_demo

		seed_demo.seed_users()
		telegram = frappe.get_single("Telegram Settings")
		whatsapp = frappe.get_single("WhatsApp Settings")
		self._before = {
			"telegram": telegram.as_dict(),
			"whatsapp": whatsapp.as_dict(),
			# Credentials as well as flags: one test deletes the stored bot
			# token to prove nothing is dialled without one, and leaving it
			# deleted takes a configured bot offline.
			"secrets": {
				("Telegram Settings", "bot_token"): telegram.get_password(
					"bot_token", raise_exception=False
				),
				("Telegram Settings", "webhook_secret"): telegram.get_password(
					"webhook_secret", raise_exception=False
				),
				("WhatsApp Settings", "access_token"): whatsapp.get_password(
					"access_token", raise_exception=False
				),
				("WhatsApp Settings", "app_secret"): whatsapp.get_password(
					"app_secret", raise_exception=False
				),
				("WhatsApp Settings", "webhook_verify_token"): whatsapp.get_password(
					"webhook_verify_token", raise_exception=False
				),
			},
		}
		self.addCleanup(self._restore)
		self.addCleanup(frappe.set_user, "Administrator")

	def _restore(self):
		frappe.set_user("Administrator")
		for doctype, saved in (
			("Telegram Settings", self._before["telegram"]),
			("WhatsApp Settings", self._before["whatsapp"]),
		):
			doc = frappe.get_single(doctype)
			doc.enabled = saved.get("enabled") or 0
			doc.last_status = saved.get("last_status")
			doc.last_error = saved.get("last_error")
			for (owner, field), value in self._before["secrets"].items():
				if owner == doctype and value:
					doc.set(field, value)
			doc.save(ignore_permissions=True)
		frappe.db.commit()


class TestSecretsGoInAndNeverComeOut(_ChannelsApiTestCase):
	def test_saving_a_token_does_not_return_it(self):
		result = channels_api.save_telegram(bot_token=TOKEN, enabled=1)

		self.assertNotIn(TOKEN, frappe.as_json(result))
		self.assertTrue(result["configured"]["bot_token"])

	def test_the_status_says_configured_never_what_with(self):
		channels_api.save_telegram(bot_token=TOKEN, webhook_secret="s3cret", enabled=1)
		channels_api.save_whatsapp(
			access_token=WHATSAPP_TOKEN, phone_number_id="123", webhook_verify_token="v"
		)

		status = frappe.as_json(channels_api.channel_status())

		self.assertNotIn(TOKEN, status)
		self.assertNotIn(WHATSAPP_TOKEN, status)
		self.assertNotIn("s3cret", status)

	def test_an_empty_field_does_not_wipe_a_working_credential(self):
		"""The failure this prevents is a factory's bots going offline because
		somebody toggled a checkbox on a screen that sent every field."""
		channels_api.save_telegram(bot_token=TOKEN, enabled=1)

		channels_api.save_telegram(enabled=0)

		self.assertTrue(channels_api.channel_status()["telegram"]["configured"]["bot_token"])

	def test_only_an_administrator_may_look(self):
		frappe.set_user(PLANNER)
		try:
			with self.assertRaises(frappe.PermissionError):
				channels_api.channel_status()
		finally:
			frappe.set_user("Administrator")

	def test_only_an_administrator_may_configure(self):
		frappe.set_user(PLANNER)
		try:
			with self.assertRaises(frappe.PermissionError):
				channels_api.save_telegram(bot_token="hijack")
		finally:
			frappe.set_user("Administrator")


class TestConnectedMeansSomebodyAsked(_ChannelsApiTestCase):
	def test_a_token_alone_is_never_connected(self):
		channels_api.save_telegram(bot_token=TOKEN, webhook_secret="s", enabled=1)
		frappe.db.set_single_value("Telegram Settings", "last_status", None)

		state = channels_api.channel_status()["telegram"]["state"]

		self.assertEqual(state, channels_api.READY)
		self.assertNotEqual(state, channels_api.CONNECTED)

	def test_a_missing_credential_is_reported_as_such(self):
		frappe.set_user("Administrator")
		settings = frappe.get_single("WhatsApp Settings")
		settings.phone_number_id = None
		settings.save(ignore_permissions=True)

		self.assertEqual(
			channels_api.channel_status()["whatsapp"]["state"], channels_api.NOT_CONFIGURED
		)

	def test_testing_without_a_token_says_so_rather_than_calling_out(self):
		frappe.db.sql(
			"delete from `__Auth` where doctype='Telegram Settings' and fieldname='bot_token'"
		)
		frappe.clear_cache()

		# Patched at the adapter, which is where the HTTP call now lives — the
		# assertion is unchanged: nothing is dialled without a token.
		with patch("korkem_ai.korkem_ai.integrations.telegram.requests.get") as called:
			result = channels_api.test_telegram()

		self.assertFalse(result["ok"])
		self.assertEqual(result["code"], channels_api.NOT_CONFIGURED)
		called.assert_not_called()

	def test_a_real_call_that_fails_reports_the_real_reason(self):
		"""Including "this container cannot reach the internet", which is the
		truth in a Docker bench and more useful than a red light."""
		channels_api.save_telegram(bot_token=TOKEN, enabled=1)

		with patch(
			"korkem_ai.korkem_ai.integrations.telegram.requests.get",
			side_effect=OSError("Network is unreachable"),
		):
			result = channels_api.test_telegram()

		self.assertFalse(result["ok"])
		self.assertEqual(result["code"], channels_api.PROVIDER_UNAVAILABLE)
		self.assertIn("unreachable", result["error"])

	def test_a_provider_rejection_is_not_dressed_up_as_success(self):
		channels_api.save_telegram(bot_token=TOKEN, enabled=1)

		class _Response:
			status_code = 401

			def json(self):
				return {"ok": False, "description": "Unauthorized"}

		with patch(
			"korkem_ai.korkem_ai.integrations.telegram.requests.get", return_value=_Response()
		):
			result = channels_api.test_telegram()

		self.assertFalse(result["ok"])
		self.assertEqual(result["code"], channels_api.INVALID_CREDENTIALS)

	def test_a_successful_check_names_the_bot_it_reached(self):
		channels_api.save_telegram(bot_token=TOKEN, enabled=1)

		class _Response:
			status_code = 200

			def json(self):
				return {"ok": True, "result": {"id": 42, "username": "korkem_bot"}}

		with patch(
			"korkem_ai.korkem_ai.integrations.telegram.requests.get", return_value=_Response()
		):
			result = channels_api.test_telegram()

		self.assertTrue(result["ok"])
		self.assertEqual(result["bot_username"], "korkem_bot")
		self.assertEqual(
			frappe.get_single("Telegram Settings").last_status, channels_api.CONNECTED
		)


class TestSayingWhoIsOnTheOtherEnd(_ChannelsApiTestCase):
	def setUp(self):
		super().setUp()
		self._clean()
		self.addCleanup(self._clean)

	def _clean(self):
		frappe.set_user("Administrator")
		for name in frappe.get_all(
			"Channel Identity", filters={"external_id": ["like", "2999%"]}, pluck="name"
		):
			frappe.delete_doc("Channel Identity", name, force=True, ignore_permissions=True)
		frappe.db.commit()

	def test_linking_binds_a_sender_to_a_user(self):
		result = channels_api.link_identity("Telegram", "29990001", PLANNER)

		self.assertEqual(result["user"], PLANNER)
		self.assertTrue(result["enabled"])

	def test_linking_twice_is_the_same_link(self):
		first = channels_api.link_identity("Telegram", "29990002", PLANNER)
		second = channels_api.link_identity("Telegram", "29990002", PLANNER)

		self.assertEqual(first["name"], second["name"])
		self.assertEqual(
			frappe.db.count("Channel Identity", {"external_id": "29990002"}), 1
		)

	def test_a_channel_role_may_be_pinned_when_linking(self):
		result = channels_api.link_identity("WhatsApp", "29990003", PLANNER, role="customer")

		self.assertEqual(result["role"], "customer")

	def test_an_unknown_user_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			channels_api.link_identity("Telegram", "29990004", "nobody@example.com")

	def test_unlinking_keeps_the_row_and_takes_the_person_away(self):
		linked = channels_api.link_identity("Telegram", "29990005", PLANNER)

		channels_api.unlink_identity(linked["name"])

		row = frappe.get_doc("Channel Identity", linked["name"])
		self.assertIsNone(row.user)
		self.assertFalse(row.enabled)

	def test_the_list_shows_who_each_sender_is(self):
		channels_api.link_identity("Telegram", "29990006", PLANNER)

		listed = channels_api.list_identities("Telegram")["identities"]

		self.assertIn("29990006", [row["external_id"] for row in listed])

	def test_only_an_administrator_may_link(self):
		frappe.set_user(PLANNER)
		try:
			with self.assertRaises(frappe.PermissionError):
				channels_api.link_identity("Telegram", "29990007", PLANNER)
		finally:
			frappe.set_user("Administrator")
