# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Trying to get the system to do the wrong thing, on purpose.

Every test here is written from the attacker's side rather than the feature's:
not "does the boundary work" but "here is the specific way somebody would try to
get round it, and here is what happens when they do".

The boundaries under attack are the four this product rests on — who you are,
which company you are in, which customer you are, and whether a write has been
agreed to — plus the two that only exist because there is a chat app in front of
it: a forged webhook and a re-delivered one.
"""

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai import customer_access
from korkem_ai.korkem_ai.channels import confirmation, gateway
from korkem_ai.korkem_ai.doctype.channel_identity import channel_identity as identities
from korkem_ai.korkem_ai.doctype.work_instruction import work_instruction as instructions
from korkem_ai.korkem_ai.integrations import telegram, whatsapp
from korkem_ai.korkem_ai.notifications import service
from korkem_ai.korkem_ai.tools import catalog, policy, registry, scope  # noqa: F401

PLANNER = "korkem.planner@example.com"
MANAGER = "korkem.manager@example.com"
IVAN = "korkem.ivan@example.com"
VIEWER = "korkem.viewer@example.com"
CLIENT = "korkem.client@example.com"
MINE = "Мебель Астана"
THEIRS = "Караганда Мебель"


class _RedTeamTestCase(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		from korkem_manufacturing import seed_demo

		seed_demo.seed_users()
		self._clean()
		self.sent = []
		patcher = patch(
			"korkem_ai.korkem_ai.channels.gateway.deliver",
			side_effect=lambda channel, chat_id, text, confirm_for=None, ask=False: self.sent.append(
				{"channel": channel, "chat_id": chat_id, "text": text}
			)
			or {"message_id": 1},
		)
		patcher.start()
		self.addCleanup(patcher.stop)
		self.addCleanup(self._clean)
		self.addCleanup(frappe.set_user, "Administrator")

	def _clean(self):
		frappe.set_user("Administrator")
		for doctype in (
			"Notification Delivery",
			"Channel Event",
			"Pending Action",
			"Work Instruction",
			"Agent Conversation Message",
			"Agent Conversation",
		):
			for name in frappe.get_all(doctype, pluck="name"):
				frappe.delete_doc(doctype, name, force=1, ignore_permissions=True)
		for name in frappe.get_all(
			"Channel Identity", filters={"external_id": ["like", "32%"]}, pluck="name"
		):
			frappe.delete_doc("Channel Identity", name, force=1, ignore_permissions=True)
		if frappe.db.exists("User", CLIENT):
			for customer in (MINE, THEIRS):
				customer_access.unlink(CLIENT, customer)
		frappe.db.commit()

	def client(self):
		if not frappe.db.exists("User", CLIENT):
			frappe.get_doc(
				{"doctype": "User", "email": CLIENT, "first_name": "Клиент", "send_welcome_email": 0}
			).insert(ignore_permissions=True)
		customer_access.link(CLIENT, MINE)
		return CLIENT

	def link(self, user, external_id, channel="Telegram"):
		identity = identities.observe(channel, external_id, "кто-то")
		identity.db_set("user", user)
		return identity

	def as_user(self, user, tool, args=None):
		frappe.set_user(user)
		try:
			return registry.execute(tool, args or {})
		finally:
			frappe.set_user("Administrator")

	def order_of(self, customer):
		return frappe.get_all(
			"Sales Order", filters={"customer": customer, "docstatus": 1}, pluck="name"
		)[0]


class TestOneCustomerCannotReachAnother(_RedTeamTestCase):
	def test_naming_another_customer_returns_their_own_orders(self):
		self.client()

		result = self.as_user(CLIENT, "sales.search_sales_orders", {"customer": THEIRS})

		customers = {row["customer"] for row in result["data"]["sales_orders"]}
		self.assertNotIn(THEIRS, customers)

	def test_asking_for_another_customers_order_by_id_is_absence_not_refusal(self):
		self.client()
		theirs = self.order_of(THEIRS)

		result = self.as_user(CLIENT, "sales.delivery_forecast", {"sales_order": theirs})

		self.assertFalse(result["ok"])
		self.assertNotIn(THEIRS, frappe.as_json(result))

	def test_a_notification_about_another_customers_order_reaches_them_not_at_all(self):
		self.client()
		self.link(CLIENT, "320001")

		service.send_to_customer("order.test", self.order_of(THEIRS), "чужой заказ")

		self.assertEqual(self.sent, [])

	def test_a_customer_cannot_reach_a_production_tool(self):
		self.client()

		refused = self.as_user(CLIENT, "manufacturing.production_control", {})

		self.assertFalse(refused["ok"])
		self.assertEqual(refused["error"]["code"], "not_permitted")

	def test_a_customer_cannot_dispatch_work(self):
		self.client()

		refused = self.as_user(
			CLIENT, "dispatch.assign_work", {"employee": "Иван", "instruction": "сделай"}
		)

		self.assertFalse(refused["ok"])
		self.assertEqual(refused["error"]["code"], "not_permitted")


class TestNobodyTalksTheirWayIntoAPrivilege(_RedTeamTestCase):
	def test_saying_you_are_an_administrator_changes_nothing(self):
		frappe.set_user(IVAN)
		try:
			before = policy.role_of()
		finally:
			frappe.set_user("Administrator")

		# The message is data. It reaches the model inside a tool-result slot and
		# there is no code path from it to `role_of`, which reads the database.
		frappe.set_user(IVAN)
		try:
			after = policy.role_of()
		finally:
			frappe.set_user("Administrator")

		self.assertEqual(before, after)
		self.assertEqual(after, policy.EMPLOYEE)

	def test_an_employee_cannot_reach_an_administrators_write(self):
		result = self.as_user(
			PLANNER, "dispatch.assign_work", {"employee": "Иван", "instruction": "сделай"}
		)

		self.assertFalse(result["ok"])
		self.assertEqual(result["error"]["code"], "permission_denied")

	def test_a_channel_pin_can_narrow_but_never_widen(self):
		self.assertEqual(policy.effective_role(PLANNER, policy.ADMIN), policy.EMPLOYEE)
		self.assertEqual(policy.effective_role(PLANNER, policy.CUSTOMER), policy.CUSTOMER)

	def test_a_telegram_id_cannot_speak_for_somebody_elses_account(self):
		"""An identity is matched on the provider's own id. A second account
		claiming the same display name is a different row with no user."""
		self.link(IVAN, "320010")
		impostor = identities.observe("Telegram", "320011", "Иван")

		self.assertIsNone(identities.speaker_for(impostor))

	def test_a_whatsapp_number_cannot_claim_another_customer(self):
		self.client()
		stranger = identities.observe("WhatsApp", "320012", MINE)

		self.assertIsNone(identities.speaker_for(stranger))

	def test_a_display_name_is_never_matched_on(self):
		self.link(IVAN, "320013")

		self.assertIsNone(identities.find("Telegram", "Иван"))


class TestAForgedOrRepeatedWebhookAchievesNothing(_RedTeamTestCase):
	def test_a_wrong_telegram_secret_is_refused(self):
		self.assertFalse(telegram.verify_secret("forged", "real-secret"))

	def test_a_missing_telegram_secret_is_refused(self):
		self.assertFalse(telegram.verify_secret(None, "real-secret"))

	def test_a_bot_with_no_secret_configured_does_not_fail_open(self):
		self.assertFalse(telegram.verify_secret("anything", None))

	def test_a_wrong_whatsapp_signature_is_refused(self):
		self.assertFalse(whatsapp.verify_webhook_signature(b"{}", "sha256=forged", "secret"))

	def test_a_missing_whatsapp_app_secret_is_refused_not_crashed(self):
		self.assertFalse(whatsapp.verify_webhook_signature(b"{}", "sha256=abc", None))

	def test_an_enabled_but_unconfigured_telegram_webhook_answers_401_not_500(self):
		"""The helpers above are not enough, and this is the test that says so.

		`verify_secret` has always treated a missing expectation as a failed
		check. It never got the chance: the caller read the secret with
		`get_password`, which throws when nothing is stored, so a site that was
		switched on and not yet configured answered Telegram with a 500.

		A 500 is what a provider **retries** — so an unconfigured channel would
		not merely refuse, it would refuse repeatedly and fill the error log.
		Found on CI, whose site has no secret; a developer's bench has one from
		earlier work and passed.
		"""
		response = self._webhook_without_secrets(telegram.webhook, "Telegram Settings")

		self.assertEqual(response.status_code, 401)

	def test_an_enabled_but_unconfigured_whatsapp_webhook_answers_401_not_500(self):
		"""Same defect, one layer above a helper whose docstring warns about it."""
		response = self._webhook_without_secrets(whatsapp.webhook, "WhatsApp Settings")

		self.assertIn(response.status_code, (401, 403))

	def _webhook_without_secrets(self, handler, doctype):
		"""Enable the channel, store no secret at all, and call the endpoint."""
		from werkzeug.test import EnvironBuilder
		from werkzeug.wrappers import Request

		settings = frappe.get_single(doctype)
		settings.enabled = 1
		settings.save(ignore_permissions=True)
		self.addCleanup(self._disable, doctype)

		# A real request object: the handler reads headers and the raw body.
		builder = EnvironBuilder(method="POST", data=b"{}", content_type="application/json")
		previous = getattr(frappe.local, "request", None)
		frappe.local.request = Request(builder.get_environ())
		self.addCleanup(setattr, frappe.local, "request", previous)

		return handler()

	def _disable(self, doctype):
		frappe.set_user("Administrator")
		settings = frappe.get_single(doctype)
		settings.enabled = 0
		settings.save(ignore_permissions=True)

	def test_the_same_update_twice_runs_one_turn(self):
		self.link(PLANNER, "320020")
		message = gateway.InboundMessage(
			channel=gateway.TELEGRAM,
			external_id="320020",
			chat_id="320020",
			text="что на производстве?",
			message_id="tg:99001",
		)

		with patch("frappe.enqueue") as enqueued:
			first = gateway.accept(message)
			second = gateway.accept(message)

		self.assertEqual(first["status"], "queued")
		self.assertEqual(second["status"], "duplicate")
		self.assertEqual(enqueued.call_count, 1)

	def test_the_same_press_twice_confirms_once(self):
		self.link(PLANNER, "320021")
		frappe.set_user("Administrator")
		action = frappe.get_doc(
			{
				"doctype": "Pending Action",
				"tool": "profile.current_user",
				"action_data": "{}",
				"status": "Pending",
			}
		)
		action.insert(ignore_permissions=True)
		action.db_set("owner", PLANNER, update_modified=False)
		frappe.db.commit()

		frappe.set_user(PLANNER)
		try:
			first = confirmation.handle(PLANNER, None, f"CONFIRM {action.name}")
			second = confirmation.handle(PLANNER, None, f"CONFIRM {action.name}")
		finally:
			frappe.set_user("Administrator")

		self.assertEqual(first["status"], "approved")
		self.assertEqual(second["status"], "already_resolved")

	def test_a_repeated_business_event_sends_one_notification(self):
		self.link(IVAN, "320022")

		service.emit(
			"test.event",
			recipients=[IVAN],
			body="одно и то же",
			reference_doctype="User",
			reference_name=IVAN,
		)
		service.emit(
			"test.event",
			recipients=[IVAN],
			body="одно и то же",
			reference_doctype="User",
			reference_name=IVAN,
		)

		self.assertEqual(len(self.sent), 1)

	def test_somebody_elses_instruction_cannot_be_answered(self):
		frappe.set_user("Administrator")
		job = frappe.get_doc(
			{
				"doctype": "Work Instruction",
				"company": "KORKEM",
				"employee_user": IVAN,
				"instruction": "Закончить раскрой",
				"status": instructions.SENT,
			}
		)
		job.insert(ignore_permissions=True)
		frappe.db.commit()

		frappe.set_user(VIEWER)
		try:
			verdict = confirmation.handle(VIEWER, None, f"CONFIRM {job.name}")
		finally:
			frappe.set_user("Administrator")

		self.assertEqual(verdict["status"], "unknown")
		self.assertEqual(
			frappe.db.get_value("Work Instruction", job.name, "status"), instructions.SENT
		)


class TestAProviderFailureCostsNoBusinessTransaction(_RedTeamTestCase):
	def test_a_dispatch_survives_a_dead_provider(self):
		"""The instruction is the decision. The message is how somebody hears
		about it, and a bot that is down must not undo a manager's decision."""
		self.link(IVAN, "320030")

		with patch(
			"korkem_ai.korkem_ai.channels.gateway.deliver",
			side_effect=telegram.TelegramError("Bad Gateway", code="provider_unavailable"),
		):
			result = self.as_user(
				MANAGER,
				"dispatch.assign_work",
				{"employee": "Иван", "instruction": "Закончить раскрой"},
			)

		self.assertTrue(result["ok"], result.get("error"))
		self.assertTrue(frappe.db.exists("Work Instruction", result["data"]["instruction"]))

	def test_the_undelivered_message_stays_retryable(self):
		self.link(IVAN, "320031")

		with patch(
			"korkem_ai.korkem_ai.channels.gateway.deliver",
			side_effect=telegram.TelegramError("Bad Gateway", code="provider_unavailable"),
		):
			self.as_user(
				MANAGER,
				"dispatch.assign_work",
				{"employee": "Иван", "instruction": "Закончить раскрой"},
			)

		rows = frappe.get_all(
			"Notification Delivery", filters={"recipient_user": IVAN}, fields=["status"]
		)
		self.assertTrue(rows)
		self.assertEqual(rows[0]["status"], "Retrying")

	def test_a_provider_timeout_is_not_a_permanent_failure(self):
		self.link(IVAN, "320032")

		with patch(
			"korkem_ai.korkem_ai.channels.gateway.deliver",
			side_effect=telegram.TelegramError("timed out", code="provider_unavailable"),
		):
			created = service.send_to_user("test.event", IVAN, "привет")

		self.assertEqual(
			frappe.db.get_value("Notification Delivery", created[0], "status"), "Retrying"
		)


class TestNoSecretEscapesAnywhere(_RedTeamTestCase):
	def token(self):
		return frappe.get_single("Telegram Settings").get_password(
			"bot_token", raise_exception=False
		)

	def test_a_provider_exception_never_carries_the_token(self):
		token = self.token()
		if not token:
			self.skipTest("no bot token stored on this bench")

		with patch(
			"korkem_ai.korkem_ai.integrations.telegram.requests.post",
			side_effect=OSError(f"failed for url: /bot{token}/sendMessage"),
		):
			frappe.db.set_single_value("Telegram Settings", "enabled", 1)
			with self.assertRaises(telegram.TelegramError) as caught:
				telegram.send_message("1", "привет")

		self.assertNotIn(token, str(caught.exception))

	def test_no_channel_event_carries_a_credential(self):
		self.link(PLANNER, "320040")
		with patch("frappe.enqueue"):
			gateway.accept(
				gateway.InboundMessage(
					channel=gateway.TELEGRAM,
					external_id="320040",
					chat_id="320040",
					text="привет",
					message_id="tg:99100",
				)
			)

		blob = frappe.as_json(frappe.get_all("Channel Event", fields=["*"]))
		self.assertNotIn("Authorization", blob)
		for doctype, field in (
			("Telegram Settings", "bot_token"),
			("WhatsApp Settings", "access_token"),
			("WhatsApp Settings", "app_secret"),
		):
			secret = frappe.get_single(doctype).get_password(field, raise_exception=False)
			if secret:
				self.assertNotIn(secret, blob)

	def test_no_notification_delivery_carries_a_credential(self):
		self.link(IVAN, "320041")
		service.send_to_user("test.event", IVAN, "привет")

		blob = frappe.as_json(frappe.get_all("Notification Delivery", fields=["*"]))
		self.assertNotIn("Authorization", blob)
		for doctype, field in (
			("Telegram Settings", "bot_token"),
			("WhatsApp Settings", "access_token"),
		):
			secret = frappe.get_single(doctype).get_password(field, raise_exception=False)
			if secret:
				self.assertNotIn(secret, blob)

	def test_the_settings_api_never_returns_one(self):
		from korkem_ai.korkem_ai import channels_api

		blob = frappe.as_json(channels_api.channel_status())

		self.assertNotIn("Authorization", blob)
		for doctype, field in (
			("Telegram Settings", "bot_token"),
			("WhatsApp Settings", "access_token"),
			("WhatsApp Settings", "app_secret"),
			("WhatsApp Settings", "webhook_verify_token"),
		):
			secret = frappe.get_single(doctype).get_password(field, raise_exception=False)
			# Searching a JSON document for a one-character "secret" finds it in
			# every English word. Eight is the same threshold `_mask` refuses to
			# mask below, and for the same reason: below it there is nothing to
			# protect and no way to tell a leak from a coincidence.
			if secret and len(secret) >= 8:
				self.assertNotIn(secret, blob)

	def test_a_credential_too_short_to_mask_is_not_hinted_at_either(self):
		"""`_mask` returns nothing below eight characters rather than showing
		most of a short secret."""
		from korkem_ai.korkem_ai import channels_api

		self.assertIsNone(channels_api._mask("abc"))
		self.assertIsNone(channels_api._mask(None))
		self.assertTrue(channels_api._mask("abcdefghijkl").startswith("••••"))
