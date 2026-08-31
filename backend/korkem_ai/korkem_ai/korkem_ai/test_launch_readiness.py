# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""What has to be true before a real bot is pointed at this.

Everything here is about the difference between "works on a bench" and "survives
the internet". A webhook URL is public: anybody who learns it can POST anything
to it, including nothing, including a megabyte, including a body that is not
JSON. A provider retries whatever it thinks failed. And an operator staring at a
status page has to be told the truth, including the awkward truth that the bot
is blocked or being rate limited.

The four things these tests hold were each a real defect found while preparing
for launch, not hypotheticals.
"""

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai import channels_api
from korkem_ai.korkem_ai.channels import gateway
from korkem_ai.korkem_ai.doctype.channel_identity import channel_identity as identities
from korkem_ai.korkem_ai.doctype.notification_delivery import notification_delivery as nd
from korkem_ai.korkem_ai.integrations import telegram, whatsapp
from korkem_ai.korkem_ai.notifications import service
from korkem_ai.korkem_ai.orchestrator.protocol import AIToolCall

PLANNER = "korkem.planner@example.com"
IVAN = "korkem.ivan@example.com"


class _LaunchTestCase(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		from korkem_manufacturing import seed_demo

		seed_demo.seed_users()
		# The health verdict is persisted on a real settings singleton, and
		# `send_test_message` below writes it. A test that leaves `connected`
		# behind makes the settings screen claim a working bot on a bench whose
		# credentials are placeholders — which is exactly the lie these tests
		# exist to catch, arriving by the back door.
		self._verdicts = {
			doctype: (
				frappe.get_single(doctype).last_status,
				frappe.get_single(doctype).last_error,
				frappe.get_single(doctype).enabled,
			)
			for doctype in ("Telegram Settings", "WhatsApp Settings")
		}
		self.addCleanup(self._restore_verdicts)
		self._clean()
		self.sent = []
		patcher = patch(
			"korkem_ai.korkem_ai.channels.gateway.deliver",
			side_effect=lambda channel, chat_id, text, confirm_for=None, ask=False: self.sent.append(
				{"channel": channel, "chat_id": chat_id, "text": text}
			)
			or {"message_id": 11},
		)
		patcher.start()
		self.addCleanup(patcher.stop)
		self.addCleanup(self._clean)
		self.addCleanup(frappe.set_user, "Administrator")

	def _restore_verdicts(self):
		frappe.set_user("Administrator")
		for doctype, (status, error, enabled) in self._verdicts.items():
			frappe.db.set_single_value(
				doctype, {"last_status": status, "last_error": error, "enabled": enabled}
			)
		frappe.db.commit()

	def _clean(self):
		frappe.set_user("Administrator")
		for doctype in (
			"Notification Delivery",
			"Channel Event",
			"Pending Action",
			"Agent Conversation Message",
			"Agent Conversation",
		):
			for name in frappe.get_all(doctype, pluck="name"):
				frappe.delete_doc(doctype, name, force=1, ignore_permissions=True)
		for name in frappe.get_all(
			"Channel Identity", filters={"external_id": ["like", "34%"]}, pluck="name"
		):
			frappe.delete_doc("Channel Identity", name, force=1, ignore_permissions=True)
		frappe.db.commit()

	def link(self, user, external_id, channel="Telegram"):
		identity = identities.observe(channel, external_id, "тест")
		identity.db_set("user", user)
		return identity


class TestAStatusPageThatCannotFlatter(_LaunchTestCase):
	"""Every verdict a provider can leave behind has to reach the screen.

	The defect: `rate_limited` and `forbidden` were not in the list the state
	function looked at, so a channel that had just been refused by Telegram
	displayed **READY** — the exact green light that means nothing, which this
	design is arranged against everywhere else.
	"""

	def test_every_verdict_a_provider_can_leave_is_shown(self):
		for verdict in channels_api.VERDICTS:
			with self.subTest(verdict=verdict):
				self.assertEqual(
					channels_api._state(True, {"a": True}, verdict),
					verdict,
					"a real provider verdict was rounded up to something else",
				)

	def test_a_blocked_bot_does_not_read_as_ready(self):
		state = channels_api._state(True, {"a": True}, channels_api.FORBIDDEN)

		self.assertEqual(state, channels_api.FORBIDDEN)
		self.assertNotEqual(state, channels_api.READY)

	def test_being_rate_limited_does_not_read_as_ready(self):
		state = channels_api._state(True, {"a": True}, channels_api.RATE_LIMITED)

		self.assertEqual(state, channels_api.RATE_LIMITED)

	def test_every_state_the_screen_can_show_has_words_and_a_verdict(self):
		for state in (*channels_api.VERDICTS, channels_api.NOT_CONFIGURED, channels_api.DISABLED, channels_api.READY):
			with self.subTest(state=state):
				self.assertIn(state, channels_api.HEALTH)

	def test_waiting_helps_for_a_rate_limit_and_not_for_a_block(self):
		self.assertTrue(channels_api.HEALTH[channels_api.RATE_LIMITED][1])
		self.assertFalse(channels_api.HEALTH[channels_api.FORBIDDEN][1])

	def test_a_missing_credential_still_outranks_a_stale_verdict(self):
		"""A channel that was connected yesterday and has lost its token today
		is not connected."""
		self.assertEqual(
			channels_api._state(True, {"token": False}, channels_api.CONNECTED),
			channels_api.NOT_CONFIGURED,
		)

	def test_both_classifiers_agree_about_what_is_worth_retrying(self):
		for status, code in ((401, "invalid_credentials"), (403, "forbidden"), (429, "rate_limited"), (503, "provider_unavailable")):
			with self.subTest(status=status):
				self.assertEqual(telegram.classify_status(status), code)
		self.assertIn("forbidden", nd.PERMANENT)
		self.assertNotIn("rate_limited", nd.PERMANENT)


class TestAPublicEndpointSurvivesWhatIsSentToIt(_LaunchTestCase):
	"""A webhook URL is public. Everything below arrived at one.

	The rule these tests hold is not "reject the bad ones" — it is *how*. A 500
	is what a provider retries, so answering a body we can never parse with a
	500 turns one bad update into an endless redelivery loop.
	"""

	def post(self, module, body: bytes, headers: dict | None = None):
		class _Request:
			method = "POST"

			def get_data(self):
				return body

		with patch.object(frappe.local, "request", _Request(), create=True), patch(
			"frappe.get_request_header", side_effect=lambda name: (headers or {}).get(name)
		):
			return module.webhook()

	def test_telegram_answers_unparseable_json_without_asking_for_a_retry(self):
		frappe.db.set_single_value("Telegram Settings", "enabled", 1)
		self.addCleanup(frappe.db.set_single_value, "Telegram Settings", "enabled", 0)
		secret = frappe.get_single("Telegram Settings").get_password(
			"webhook_secret", raise_exception=False
		)
		if not secret:
			self.skipTest("no webhook secret stored on this bench")

		response = self.post(
			telegram, b"{not json at all", {"X-Telegram-Bot-Api-Secret-Token": secret}
		)

		self.assertEqual(response.status_code, 200)

	def test_telegram_drops_an_oversized_body_rather_than_reading_it_all(self):
		frappe.db.set_single_value("Telegram Settings", "enabled", 1)
		self.addCleanup(frappe.db.set_single_value, "Telegram Settings", "enabled", 0)
		secret = frappe.get_single("Telegram Settings").get_password(
			"webhook_secret", raise_exception=False
		)
		if not secret:
			self.skipTest("no webhook secret stored on this bench")

		response = self.post(
			telegram,
			b"x" * (telegram.MAX_UPDATE_BYTES + 1),
			{"X-Telegram-Bot-Api-Secret-Token": secret},
		)

		self.assertEqual(response.status_code, 200)

	def test_telegram_refuses_a_forged_secret_before_reading_anything(self):
		frappe.db.set_single_value("Telegram Settings", "enabled", 1)
		self.addCleanup(frappe.db.set_single_value, "Telegram Settings", "enabled", 0)

		response = self.post(
			telegram, b'{"message": {}}', {"X-Telegram-Bot-Api-Secret-Token": "forged"}
		)

		self.assertEqual(response.status_code, 401)

	def test_an_update_type_we_do_not_answer_is_skipped_not_half_handled(self):
		self.assertIsNone(telegram.parse_update({"poll_answer": {"poll_id": "1"}}))
		self.assertIsNone(telegram.parse_update({}))

	def test_whatsapp_answers_unparseable_json_without_asking_for_a_retry(self):
		import hashlib
		import hmac

		frappe.db.set_single_value("WhatsApp Settings", "enabled", 1)
		self.addCleanup(frappe.db.set_single_value, "WhatsApp Settings", "enabled", 0)
		app_secret = frappe.get_single("WhatsApp Settings").get_password(
			"app_secret", raise_exception=False
		)
		if not app_secret:
			self.skipTest("no app secret stored on this bench")

		body = b"{not json at all"
		digest = hmac.new(app_secret.encode(), body, hashlib.sha256).hexdigest()

		response = self.post(whatsapp, body, {"X-Hub-Signature-256": f"sha256={digest}"})

		self.assertEqual(response.status_code, 200)

	def test_whatsapp_drops_an_oversized_body_before_hashing_it(self):
		"""Hashing a megabyte is work an unauthenticated caller would otherwise
		be choosing for us."""
		frappe.db.set_single_value("WhatsApp Settings", "enabled", 1)
		self.addCleanup(frappe.db.set_single_value, "WhatsApp Settings", "enabled", 0)

		response = self.post(
			whatsapp, b"x" * (whatsapp.MAX_PAYLOAD_BYTES + 1), {"X-Hub-Signature-256": "sha256=x"}
		)

		self.assertEqual(response.status_code, 200)

	def test_whatsapp_refuses_a_body_somebody_edited_in_flight(self):
		import hashlib
		import hmac

		signed = b'{"entry": []}'
		digest = hmac.new(b"secret", signed, hashlib.sha256).hexdigest()

		self.assertFalse(
			whatsapp.verify_webhook_signature(b'{"entry": [{"changed": true}]}', f"sha256={digest}", "secret")
		)

	def test_a_payload_that_is_not_an_object_is_ignored(self):
		self.assertEqual(whatsapp.parse_inbound_messages({}), [])


class TestOneMessageCanBeFollowedEndToEnd(_LaunchTestCase):
	"""§15's chain, which an incident is followed along.

	The defect: `turn_id` on a proposal was the *conversation's* name, so every
	proposal in a thread shared one id and the chain could not distinguish two
	messages from the same person.
	"""

	def run_turn(self, tool="manufacturing.stop_production"):
		class _Result:
			status = "needs_confirmation"
			text = "Остановить производство?"
			pending = (
				AIToolCall(id="provider-id", name=tool, arguments={"sales_order": "X"}),
			)

		self.link(PLANNER, "340001")
		message = gateway.InboundMessage(
			channel=gateway.TELEGRAM,
			external_id="340001",
			chat_id="340001",
			text="останови",
			message_id="tg:34001",
		)
		with patch("frappe.enqueue"):
			gateway.accept(message)
		conversation = gateway.conversation_for(message, PLANNER)
		with patch(
			"korkem_ai.korkem_ai.agent.loop.run_turn", return_value=_Result()
		), patch("korkem_ai.korkem_ai.orchestrator.llm.resolve", return_value=None):
			gateway.run_turn_job(
				conversation.name, PLANNER, "останови", gateway.TELEGRAM, "340001"
			)
		return conversation

	def test_the_proposal_carries_the_turn_and_not_the_conversation(self):
		conversation = self.run_turn()

		turn = frappe.get_all(
			"Pending Action", filters={"conversation": conversation.name}, pluck="turn_id"
		)[0]
		self.assertTrue(turn)
		self.assertNotEqual(turn, conversation.name)

	def test_two_messages_in_one_conversation_are_two_turns(self):
		conversation = self.run_turn()
		first = frappe.get_all(
			"Pending Action", filters={"conversation": conversation.name}, pluck="turn_id"
		)[0]

		class _Result:
			status = "needs_confirmation"
			text = "И это тоже?"
			pending = (
				AIToolCall(
					id="provider-id-2",
					name="manufacturing.stop_production",
					arguments={"sales_order": "Y"},
				),
			)

		with patch(
			"korkem_ai.korkem_ai.agent.loop.run_turn", return_value=_Result()
		), patch("korkem_ai.korkem_ai.orchestrator.llm.resolve", return_value=None):
			gateway.run_turn_job(
				conversation.name, PLANNER, "и это", gateway.TELEGRAM, "340001"
			)

		turns = set(
			frappe.get_all(
				"Pending Action", filters={"conversation": conversation.name}, pluck="turn_id"
			)
		)
		self.assertEqual(len(turns), 2)
		self.assertIn(first, turns)

	def test_the_audit_rows_of_one_turn_share_its_id(self):
		conversation = self.run_turn()

		turn = frappe.get_all(
			"Pending Action", filters={"conversation": conversation.name}, pluck="turn_id"
		)[0]
		events = frappe.get_all(
			"Channel Event", filters={"turn_id": turn}, fields=["event", "tool", "pending_action"]
		)
		self.assertTrue(events, "no audit row carries the turn id")
		self.assertTrue(any(row["pending_action"] for row in events))

	def test_a_notification_raised_during_a_turn_carries_it(self):
		self.link(IVAN, "340002")
		self.link(PLANNER, "340003")
		frappe.flags[gateway.TURN_FLAG] = "turn-under-test"
		try:
			created = service.send_to_user("test.event", IVAN, "привет")
		finally:
			frappe.flags.pop(gateway.TURN_FLAG, None)

		self.assertEqual(
			frappe.db.get_value("Notification Delivery", created[0], "turn_id"),
			"turn-under-test",
		)

	def test_a_notification_from_a_scheduled_job_has_no_turn_and_says_so(self):
		"""Not every message belongs to a turn, and inventing one would make the
		chain lie about where it started."""
		self.link(IVAN, "340004")

		created = service.send_to_user("test.event", IVAN, "привет", key_suffix="scheduled")

		self.assertIsNone(
			frappe.db.get_value("Notification Delivery", created[0], "turn_id")
		)


class TestTheOperatorsTestMessage(_LaunchTestCase):
	"""§18: a real provider call that touches nothing else."""

	def test_it_is_recorded_where_every_other_outbound_message_is(self):
		identity = self.link("Administrator", "340010")

		result = channels_api.send_test_message("Telegram", identity=identity.name)

		self.assertTrue(result["ok"], result)
		row = frappe.get_doc("Notification Delivery", result["delivery"])
		self.assertEqual(row.event, "channel.test")
		self.assertEqual(row.status, nd.SENT)

	def test_it_is_visible_in_the_delivery_centre(self):
		identity = self.link("Administrator", "340011")
		channels_api.send_test_message("Telegram", identity=identity.name)

		events = channels_api.list_deliveries()["deliveries"]

		self.assertTrue(any(row["event"] == "channel.test" for row in events))

	def test_it_runs_no_model_and_writes_no_business_document(self):
		identity = self.link("Administrator", "340012")
		before = (
			frappe.db.count("Pending Action"),
			frappe.db.count("Sales Order"),
			frappe.db.count("Work Order"),
		)

		with patch("korkem_ai.korkem_ai.agent.loop.run_turn") as ran:
			channels_api.send_test_message("Telegram", identity=identity.name)

		ran.assert_not_called()
		self.assertEqual(
			before,
			(
				frappe.db.count("Pending Action"),
				frappe.db.count("Sales Order"),
				frappe.db.count("Work Order"),
			),
		)

	def test_a_failure_is_recorded_as_a_failed_delivery_and_not_lost(self):
		identity = self.link("Administrator", "340013")

		with patch(
			"korkem_ai.korkem_ai.channels.gateway.deliver",
			side_effect=telegram.TelegramError("Forbidden: bot was blocked", code="forbidden"),
		):
			result = channels_api.send_test_message("Telegram", identity=identity.name)

		self.assertFalse(result["ok"])
		row = frappe.get_doc("Notification Delivery", result["delivery"])
		self.assertEqual(row.status, nd.FAILED)
		self.assertIn("blocked", row.error)

	def test_the_message_says_what_it_is(self):
		"""Somebody receiving it must be able to tell at a glance that an
		administrator was testing a bot, not that something happened."""
		identity = self.link("Administrator", "340014")

		channels_api.send_test_message("Telegram", identity=identity.name)

		self.assertIn("тестовое", self.sent[-1]["text"])
