# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Running the channels, rather than merely having them.

An administrator who is told "something is wrong with Telegram" needs four
things and none of them is a log file: what state it is in, whether that state
is worth waiting out, what the provider actually said, and what was not
delivered because of it. This module is the surface that answers those, and
these tests are about the answers being *true* — a green light that means "a
token is present" is the failure mode the whole design is arranged against.

The second half is the operations themselves. Retry has to be idempotent, a
dead letter must not resurrect itself, and two administrators tapping the same
button must produce one message.
"""

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai import channels_api
from korkem_ai.korkem_ai.doctype.channel_identity import channel_identity as identities
from korkem_ai.korkem_ai.doctype.notification_delivery import notification_delivery as nd
from korkem_ai.korkem_ai.integrations import telegram
from korkem_ai.korkem_ai.notifications import service

PLANNER = "korkem.planner@example.com"
IVAN = "korkem.ivan@example.com"


class _OperationsTestCase(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		from korkem_manufacturing import seed_demo

		seed_demo.seed_users()
		self._before = {}
		for doctype in ("Telegram Settings", "WhatsApp Settings"):
			doc = frappe.get_single(doctype)
			self._before[doctype] = {
				"enabled": doc.enabled,
				"last_status": doc.last_status,
				"secrets": {
					field: doc.get_password(field, raise_exception=False)
					for field in (
						("bot_token", "webhook_secret")
						if doctype == "Telegram Settings"
						else ("access_token", "app_secret", "webhook_verify_token")
					)
				},
			}
		self._clean()
		self.sent = []
		patcher = patch(
			"korkem_ai.korkem_ai.channels.gateway.deliver",
			side_effect=lambda channel, chat_id, text, confirm_for=None, ask=False: self.sent.append(
				{"channel": channel, "chat_id": chat_id, "text": text}
			)
			or {"message_id": 7},
		)
		patcher.start()
		self.addCleanup(patcher.stop)
		self.addCleanup(self._restore)
		self.addCleanup(self._clean)
		self.addCleanup(frappe.set_user, "Administrator")

	def _clean(self):
		frappe.set_user("Administrator")
		for name in frappe.get_all("Notification Delivery", pluck="name"):
			frappe.delete_doc("Notification Delivery", name, force=1, ignore_permissions=True)
		for name in frappe.get_all(
			"Channel Identity", filters={"external_id": ["like", "33%"]}, pluck="name"
		):
			frappe.delete_doc("Channel Identity", name, force=1, ignore_permissions=True)
		frappe.db.commit()

	def _restore(self):
		frappe.set_user("Administrator")
		for doctype, saved in self._before.items():
			doc = frappe.get_single(doctype)
			doc.enabled = saved["enabled"]
			doc.last_status = saved["last_status"]
			for field, value in saved["secrets"].items():
				if value:
					doc.set(field, value)
			doc.save(ignore_permissions=True)
		frappe.db.commit()

	def link(self, user, external_id, channel="Telegram"):
		identity = identities.observe(channel, external_id, "тест")
		identity.db_set("user", user)
		return identity

	def failed_delivery(self, code="provider_unavailable"):
		self.link(IVAN, "330001")
		with patch(
			"korkem_ai.korkem_ai.channels.gateway.deliver",
			side_effect=telegram.TelegramError("Bad Gateway", code=code),
		):
			created = service.send_to_user("test.event", IVAN, "привет")
		return created[0]


class TestHealthIsAnAnswerNotAColour(_OperationsTestCase):
	def test_every_state_has_a_sentence_and_a_verdict_on_waiting(self):
		"""A code to branch on, words to read, and whether trying again could
		plausibly help — the difference between "wait" and "go and fix it"."""
		for code, (message, retryable) in channels_api.HEALTH.items():
			with self.subTest(state=code):
				self.assertTrue(message)
				self.assertIsInstance(retryable, bool)

	def test_a_rejected_credential_is_not_worth_waiting_out(self):
		self.assertFalse(channels_api.HEALTH[channels_api.INVALID_CREDENTIALS][1])

	def test_an_unreachable_provider_is(self):
		self.assertTrue(channels_api.HEALTH[channels_api.PROVIDER_UNAVAILABLE][1])

	def test_the_status_carries_the_health_of_both_channels(self):
		status = channels_api.channel_status()

		for channel in ("telegram", "whatsapp"):
			health = status[channel]["health"]
			self.assertIn("code", health)
			self.assertIn("message", health)
			self.assertIn("retryable", health)
			self.assertIn("failed_deliveries", health)
			self.assertIn("pending_retries", health)

	def test_it_counts_what_could_not_be_delivered(self):
		self.failed_delivery()

		health = channels_api.channel_status()["telegram"]["health"]

		self.assertGreaterEqual(health["pending_retries"] + health["failed_deliveries"], 1)

	def test_ready_is_still_not_connected(self):
		channels_api.save_telegram(bot_token="placeholder-token-value", webhook_secret="s", enabled=1)
		frappe.db.set_single_value("Telegram Settings", "last_status", None)

		self.assertEqual(channels_api.channel_status()["telegram"]["state"], channels_api.READY)

	def test_traffic_is_read_from_what_already_happened(self):
		status = channels_api.channel_status()

		self.assertIn("last_inbound_at", status["telegram"])
		self.assertIn("last_outbound_at", status["telegram"])


class TestProviderRefusalsAreToldApart(_OperationsTestCase):
	def test_a_rejected_token_is_permanent(self):
		self.assertEqual(telegram.classify_status(401), "invalid_credentials")
		self.assertIn("invalid_credentials", nd.PERMANENT)

	def test_a_blocked_chat_is_permanent_and_a_different_fix(self):
		self.assertEqual(telegram.classify_status(403), "forbidden")
		self.assertIn("forbidden", nd.PERMANENT)

	def test_a_rate_limit_is_exactly_what_retrying_is_for(self):
		self.assertEqual(telegram.classify_status(429), "rate_limited")
		self.assertNotIn("rate_limited", nd.PERMANENT)

	def test_a_provider_having_a_bad_day_is_retryable(self):
		self.assertEqual(telegram.classify_status(503), "provider_unavailable")
		self.assertNotIn("provider_unavailable", nd.PERMANENT)

	def test_a_rate_limited_message_is_scheduled_rather_than_abandoned(self):
		name = self.failed_delivery(code="rate_limited")

		self.assertEqual(frappe.db.get_value("Notification Delivery", name, "status"), nd.RETRYING)

	def test_a_blocked_chat_is_not_retried_at_all(self):
		name = self.failed_delivery(code="forbidden")

		row = frappe.get_doc("Notification Delivery", name)
		self.assertEqual(row.status, nd.FAILED)
		self.assertIsNone(row.next_attempt_at)


class TestRetryingByHand(_OperationsTestCase):
	def test_an_administrator_can_try_again(self):
		name = self.failed_delivery()

		result = channels_api.retry_delivery(name)

		self.assertTrue(result["ok"], result)
		self.assertEqual(frappe.db.get_value("Notification Delivery", name, "status"), nd.SENT)

	def test_a_dead_letter_needs_asking_and_does_not_resurrect_itself(self):
		name = self.failed_delivery()
		frappe.db.set_value("Notification Delivery", name, "status", nd.DEAD_LETTER)

		# The scheduler sweeps `Retrying` only. A dead letter stays where it is
		# until somebody decides otherwise.
		self.assertNotIn(name, nd.due())

		self.assertTrue(channels_api.retry_delivery(name)["ok"])

	def test_retrying_twice_sends_once(self):
		"""Two administrators, one button, one message."""
		name = self.failed_delivery()

		first = channels_api.retry_delivery(name)
		second = channels_api.retry_delivery(name)

		self.assertTrue(first["ok"])
		self.assertFalse(second["ok"])
		self.assertEqual(second["reason"], "not_retryable")
		self.assertEqual(len(self.sent), 1)

	def test_a_delivered_message_is_never_re_sent(self):
		self.link(IVAN, "330002")
		created = service.send_to_user("test.event", IVAN, "привет")
		self.sent.clear()

		result = channels_api.retry_delivery(created[0])

		self.assertFalse(result["ok"])
		self.assertEqual(self.sent, [])

	def test_cancelling_stops_the_attempts(self):
		name = self.failed_delivery()

		result = channels_api.cancel_delivery(name)

		self.assertTrue(result["ok"])
		row = frappe.get_doc("Notification Delivery", name)
		self.assertEqual(row.status, nd.CANCELLED)
		self.assertIsNone(row.next_attempt_at)
		self.assertNotIn(name, nd.due())

	def test_a_cancelled_message_is_not_swept_up_by_retry_all(self):
		name = self.failed_delivery()
		channels_api.cancel_delivery(name)
		self.sent.clear()

		channels_api.retry_all_deliveries()

		self.assertEqual(self.sent, [])

	def test_retry_all_takes_the_ones_an_administrator_could_take_one_by_one(self):
		self.failed_delivery()
		self.link(IVAN, "330003", channel="WhatsApp")
		with patch(
			"korkem_ai.korkem_ai.channels.gateway.deliver",
			side_effect=telegram.TelegramError("Bad Gateway", code="provider_unavailable"),
		):
			service.emit("test.other", recipients=[IVAN], body="ещё", key_suffix="second")
		self.sent.clear()

		result = channels_api.retry_all_deliveries()

		self.assertGreaterEqual(result["attempted"], 2)
		self.assertEqual(result["sent"], len(self.sent))

	def test_a_suppressed_message_is_not_retried_because_there_was_nobody(self):
		created = service.send_to_user("test.event", PLANNER, "привет")
		self.sent.clear()

		channels_api.retry_all_deliveries()

		self.assertEqual(
			frappe.db.get_value("Notification Delivery", created[0], "status"), nd.SUPPRESSED
		)
		self.assertEqual(self.sent, [])

	def test_retrying_something_that_does_not_exist_says_so(self):
		self.assertEqual(channels_api.retry_delivery("no-such-row")["reason"], "not_found")

	def test_only_an_administrator_may_retry(self):
		name = self.failed_delivery()
		frappe.set_user(PLANNER)
		try:
			with self.assertRaises(frappe.PermissionError):
				channels_api.retry_delivery(name)
		finally:
			frappe.set_user("Administrator")


class TestTheDeliveryBoard(_OperationsTestCase):
	def test_it_lists_what_was_tried_and_summarises_by_state(self):
		self.failed_delivery()

		board = channels_api.list_deliveries()

		self.assertTrue(board["deliveries"])
		self.assertTrue(board["summary"])

	def test_it_can_be_narrowed_to_one_state_or_one_channel(self):
		self.failed_delivery()

		self.assertTrue(channels_api.list_deliveries(status=nd.RETRYING)["deliveries"])
		self.assertEqual(channels_api.list_deliveries(status=nd.SENT)["count"], 0)
		self.assertTrue(channels_api.list_deliveries(channel="Telegram")["deliveries"])

	def test_it_carries_no_credential(self):
		self.failed_delivery()

		blob = frappe.as_json(channels_api.list_deliveries())

		self.assertNotIn("Authorization", blob)
		for doctype, field in (
			("Telegram Settings", "bot_token"),
			("WhatsApp Settings", "access_token"),
		):
			secret = frappe.get_single(doctype).get_password(field, raise_exception=False)
			if secret and len(secret) >= 8:
				self.assertNotIn(secret, blob)

	def test_only_an_administrator_may_read_it(self):
		frappe.set_user(PLANNER)
		try:
			with self.assertRaises(frappe.PermissionError):
				channels_api.list_deliveries()
		finally:
			frappe.set_user("Administrator")


class TestSendingATestMessage(_OperationsTestCase):
	def test_it_goes_to_a_linked_identity_and_never_to_a_typed_number(self):
		"""A settings screen that can message arbitrary numbers is a settings
		screen that can be used to message anybody."""
		identity = self.link("Administrator", "330010")

		result = channels_api.send_test_message("Telegram", identity=identity.name)

		self.assertTrue(result["ok"], result)
		self.assertEqual(self.sent[-1]["chat_id"], "330010")

	def test_without_a_linked_identity_it_says_so_rather_than_guessing(self):
		result = channels_api.send_test_message("WhatsApp")

		self.assertFalse(result["ok"])
		self.assertEqual(result["code"], "no_identity")
		self.assertEqual(self.sent, [])

	def test_an_identity_on_another_channel_is_refused(self):
		identity = self.link("Administrator", "330011", channel="WhatsApp")

		result = channels_api.send_test_message("Telegram", identity=identity.name)

		self.assertFalse(result["ok"])
		self.assertEqual(result["code"], "wrong_channel")

	def test_a_failure_is_recorded_as_the_channels_health(self):
		identity = self.link("Administrator", "330012")

		with patch(
			"korkem_ai.korkem_ai.channels.gateway.deliver",
			side_effect=telegram.TelegramError("Unauthorized", code="invalid_credentials"),
		):
			result = channels_api.send_test_message("Telegram", identity=identity.name)

		self.assertFalse(result["ok"])
		self.assertEqual(
			frappe.get_single("Telegram Settings").last_status, channels_api.INVALID_CREDENTIALS
		)

	def test_only_an_administrator_may_send_one(self):
		frappe.set_user(PLANNER)
		try:
			with self.assertRaises(frappe.PermissionError):
				channels_api.send_test_message("Telegram")
		finally:
			frappe.set_user("Administrator")


class TestDisconnecting(_OperationsTestCase):
	def test_it_switches_the_channel_off(self):
		channels_api.save_telegram(bot_token="placeholder-token-value", enabled=1)

		with patch(
			"korkem_ai.korkem_ai.integrations.telegram.delete_webhook",
			return_value={"result": True},
		):
			result = channels_api.disconnect_channel("Telegram")

		self.assertTrue(result["ok"])
		self.assertFalse(frappe.get_single("Telegram Settings").enabled)

	def test_it_does_not_forget_the_credentials(self):
		""""Turn it off for now" and "forget my bot token" are different
		intentions, and conflating them makes the destructive one the easy one."""
		channels_api.save_telegram(bot_token="placeholder-token-value", enabled=1)

		with patch(
			"korkem_ai.korkem_ai.integrations.telegram.delete_webhook",
			return_value={"result": True},
		):
			channels_api.disconnect_channel("Telegram")

		self.assertTrue(channels_api.channel_status()["telegram"]["configured"]["bot_token"])


class TestIdentityManagement(_OperationsTestCase):
	def test_an_address_is_recognisable_but_not_transcribable(self):
		self.link(IVAN, "330020")

		row = next(
			r
			for r in channels_api.list_identities("Telegram")["identities"]
			if r["external_id"] == "330020"
		)

		self.assertTrue(row["external_id_masked"].endswith("0020"))
		self.assertNotEqual(row["external_id_masked"], "330020")

	def test_priority_decides_which_way_is_tried_first(self):
		telegram_identity = self.link(IVAN, "330021", channel="Telegram")
		whatsapp_identity = self.link(IVAN, "330022", channel="WhatsApp")

		channels_api.set_identity_priority(whatsapp_identity.name, -1)

		self.assertEqual(service.identities_for(IVAN)[0]["name"], whatsapp_identity.name)
		self.assertNotEqual(service.identities_for(IVAN)[0]["name"], telegram_identity.name)

	def test_only_an_administrator_may_reorder_them(self):
		identity = self.link(IVAN, "330023")
		frappe.set_user(PLANNER)
		try:
			with self.assertRaises(frappe.PermissionError):
				channels_api.set_identity_priority(identity.name, 5)
		finally:
			frappe.set_user("Administrator")


class TestTheDispatchBoard(_OperationsTestCase):
	def test_it_reports_how_long_somebody_took_to_answer(self):
		frappe.set_user("Administrator")
		doc = frappe.get_doc(
			{
				"doctype": "Work Instruction",
				"company": "KORKEM",
				"employee_user": IVAN,
				"instruction": "Закончить раскрой",
				"status": "Sent",
			}
		)
		doc.insert(ignore_permissions=True)
		doc.acknowledge("принял")
		self.addCleanup(
			frappe.delete_doc, "Work Instruction", doc.name, force=True, ignore_permissions=True
		)

		board = channels_api.list_work_instructions()

		row = next(r for r in board["instructions"] if r["name"] == doc.name)
		self.assertIsNotNone(row["response_seconds"])
		self.assertEqual(row["response"], "принял")

	def test_it_grants_nothing_beyond_what_erpnext_allows(self):
		"""Read through `get_list`, so this endpoint is a view and not a door."""
		frappe.set_user(IVAN)
		try:
			board = channels_api.list_work_instructions()
		finally:
			frappe.set_user("Administrator")

		self.assertIn("instructions", board)
