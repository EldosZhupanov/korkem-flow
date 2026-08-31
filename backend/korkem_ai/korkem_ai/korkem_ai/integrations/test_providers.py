# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Talking to the real Telegram and WhatsApp APIs, without leaking the keys to them.

These tests make no network call. What they hold is the part that cannot be
checked by sending a message and looking at a phone: that a credential never
reaches an exception, a log or a caller, that a webhook is trusted only when it
proves itself, and that every provider failure comes back as something a screen
can act on rather than a traceback.

The one behaviour they cannot cover is whether Telegram and Meta actually accept
these payloads. That needs a public HTTPS endpoint and real credentials, neither
of which exists in this environment — recorded as **REAL PROVIDER NOT VERIFIED**
rather than approximated with a fake server that would agree with whatever we
sent it.
"""

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai.integrations import telegram, whatsapp

#: Shaped like a Telegram token — `<digits>:<secret>` — because the redaction
#: under test is shape-based. Not a credential: it authenticates nothing.
TOKEN_SHAPED = "111222333:PLACEHOLDER-not-a-real-telegram-credential"


class _Response:
	def __init__(self, payload, status_code=200, text=""):
		self._payload = payload
		self.status_code = status_code
		self.text = text

	def json(self):
		if self._payload is None:
			raise ValueError("no json")
		return self._payload


class _TelegramTestCase(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		self.addCleanup(frappe.set_user, "Administrator")
		settings = frappe.get_single("Telegram Settings")
		# Everything this class touches is written down first, credentials
		# included. One of these tests *deletes* the stored token to prove
		# nothing is dialled without one, and a test that leaves a factory's bot
		# token deleted is worse than the test is worth.
		self._enabled = settings.enabled
		self._secrets = {
			field: settings.get_password(field, raise_exception=False)
			for field in ("bot_token", "webhook_secret")
		}
		settings.enabled = 1
		settings.bot_token = TOKEN_SHAPED
		settings.webhook_secret = "webhook-secret-placeholder"
		settings.save(ignore_permissions=True)
		frappe.db.commit()
		self.addCleanup(self._restore)

	def _restore(self):
		frappe.set_user("Administrator")
		settings = frappe.get_single("Telegram Settings")
		settings.enabled = self._enabled
		for field, value in self._secrets.items():
			if value:
				settings.set(field, value)
		settings.save(ignore_permissions=True)
		frappe.db.commit()


class TestTheTokenNeverEscapes(_TelegramTestCase):
	def test_a_transport_failure_does_not_carry_the_url(self):
		"""Telegram puts the token in the *path*, so `requests`' own message —
		"...for url: https://api.telegram.org/bot123:ABC/sendMessage" — is the
		credential. `frappe.log_error(get_traceback())` would then store it."""
		with patch(
			"korkem_ai.korkem_ai.integrations.telegram.requests.post",
			side_effect=OSError(
				f"HTTPSConnectionPool: Max retries exceeded with url: "
				f"/bot{TOKEN_SHAPED}/sendMessage"
			),
		):
			with self.assertRaises(telegram.TelegramError) as caught:
				telegram.send_message("1", "привет")

		self.assertNotIn(TOKEN_SHAPED, str(caught.exception))
		self.assertEqual(caught.exception.code, "provider_unavailable")

	def test_a_refusal_carries_telegrams_words_and_not_the_token(self):
		with patch(
			"korkem_ai.korkem_ai.integrations.telegram.requests.post",
			return_value=_Response({"ok": False, "description": "Unauthorized"}, 401),
		):
			with self.assertRaises(telegram.TelegramError) as caught:
				telegram.send_message("1", "привет")

		self.assertIn("Unauthorized", str(caught.exception))
		self.assertNotIn(TOKEN_SHAPED, str(caught.exception))
		self.assertEqual(caught.exception.code, "invalid_credentials")

	def test_redaction_catches_a_token_shape_it_was_never_given(self):
		"""Second line of defence: a message from a library we do not control."""
		leaked = f"connection to /bot{TOKEN_SHAPED}/getMe failed"

		self.assertNotIn(TOKEN_SHAPED, telegram.redact(leaked, None))

	def test_a_non_json_answer_is_reported_not_parsed(self):
		with patch(
			"korkem_ai.korkem_ai.integrations.telegram.requests.post",
			return_value=_Response(None, 502, text="<html>bad gateway</html>"),
		):
			with self.assertRaises(telegram.TelegramError) as caught:
				telegram.send_message("1", "привет")

		self.assertEqual(caught.exception.code, "provider_error")

	def test_no_token_is_a_refusal_before_any_call(self):
		frappe.db.sql(
			"delete from `__Auth` where doctype='Telegram Settings' and fieldname='bot_token'"
		)
		frappe.clear_cache()

		with patch("korkem_ai.korkem_ai.integrations.telegram.requests.post") as called:
			with self.assertRaises(telegram.TelegramError) as caught:
				telegram.send_message("1", "привет")

		self.assertEqual(caught.exception.code, "not_configured")
		called.assert_not_called()

	def test_a_disabled_channel_sends_nothing(self):
		frappe.db.set_single_value("Telegram Settings", "enabled", 0)

		with patch("korkem_ai.korkem_ai.integrations.telegram.requests.post") as called:
			with self.assertRaises(telegram.TelegramError) as caught:
				telegram.send_message("1", "привет")

		self.assertEqual(caught.exception.code, "disabled")
		called.assert_not_called()


class TestWebhookManagement(_TelegramTestCase):
	def test_setting_it_sends_the_secret_and_only_the_updates_we_handle(self):
		with patch(
			"korkem_ai.korkem_ai.integrations.telegram.requests.post",
			return_value=_Response({"ok": True, "result": True}),
		) as called:
			telegram.set_webhook("https://korkem.example/api/method/…webhook")

		body = called.call_args.kwargs["json"]
		self.assertEqual(body["url"], "https://korkem.example/api/method/…webhook")
		self.assertEqual(body["secret_token"], "webhook-secret-placeholder")
		self.assertEqual(body["allowed_updates"], telegram.ALLOWED_UPDATES)

	def test_setting_it_never_drops_what_people_already_sent(self):
		with patch(
			"korkem_ai.korkem_ai.integrations.telegram.requests.post",
			return_value=_Response({"ok": True, "result": True}),
		) as called:
			telegram.set_webhook("https://korkem.example/hook")

		self.assertFalse(called.call_args.kwargs["json"]["drop_pending_updates"])

	def test_removing_it_keeps_the_queue_unless_asked(self):
		with patch(
			"korkem_ai.korkem_ai.integrations.telegram.requests.post",
			return_value=_Response({"ok": True, "result": True}),
		) as called:
			telegram.delete_webhook()

		self.assertFalse(called.call_args.kwargs["json"]["drop_pending_updates"])

	def test_webhook_info_reports_what_telegram_has_seen(self):
		with patch(
			"korkem_ai.korkem_ai.integrations.telegram.requests.get",
			return_value=_Response(
				{
					"ok": True,
					"result": {
						"url": "https://korkem.example/hook",
						"pending_update_count": 3,
						"last_error_message": "SSL error",
					},
				}
			),
		):
			info = telegram.get_webhook_info()

		self.assertEqual(info["pending_update_count"], 3)
		self.assertEqual(info["last_error_message"], "SSL error")


class TestTelegramTrustsOnlyWhatItCanCheck(IntegrationTestCase):
	def test_a_request_without_the_secret_is_not_telegram(self):
		self.assertFalse(telegram.verify_secret(None, "expected"))

	def test_a_wrong_secret_is_not_telegram(self):
		self.assertFalse(telegram.verify_secret("wrong", "expected"))

	def test_a_bot_configured_without_a_secret_does_not_fail_open(self):
		"""A public URL and no secret is an open endpoint. Refused."""
		self.assertFalse(telegram.verify_secret("anything", None))

	def test_the_right_secret_is_accepted(self):
		self.assertTrue(telegram.verify_secret("expected", "expected"))


class TestTelegramUpdatesAreParsedForWhatWeAnswer(IntegrationTestCase):
	def test_a_press_becomes_the_text_protocol(self):
		parsed = telegram.parse_update(
			{
				"callback_query": {
					"id": "cb1",
					"data": "confirm:abc123",
					"from": {"id": 7, "first_name": "Иван"},
					"message": {"chat": {"id": 7}},
				}
			}
		)

		self.assertEqual(parsed["text"], "CONFIRM abc123")
		self.assertEqual(parsed["message_id"], "cb:cb1")

	def test_the_third_button_becomes_a_question(self):
		parsed = telegram.parse_update(
			{
				"callback_query": {
					"id": "cb2",
					"data": "ask:abc123",
					"from": {"id": 7},
					"message": {"chat": {"id": 7}},
				}
			}
		)

		self.assertEqual(parsed["text"], "ASK abc123")

	def test_a_press_is_keyed_on_the_callback_so_a_redelivery_is_the_same_press(self):
		payload = {
			"callback_query": {
				"id": "cb3",
				"data": "confirm:abc",
				"from": {"id": 7},
				"message": {"chat": {"id": 7}},
			}
		}

		self.assertEqual(
			telegram.parse_update(payload)["message_id"],
			telegram.parse_update(payload)["message_id"],
		)

	def test_a_sticker_is_not_something_to_answer(self):
		self.assertIsNone(
			telegram.parse_update({"message": {"chat": {"id": 1}, "from": {"id": 1}, "sticker": {}}})
		)

	def test_an_unknown_callback_is_ignored_rather_than_guessed(self):
		self.assertIsNone(
			telegram.parse_update(
				{
					"callback_query": {
						"id": "cb4",
						"data": "something:else",
						"from": {"id": 7},
						"message": {"chat": {"id": 7}},
					}
				}
			)
		)

	def test_two_messages_with_the_same_text_are_two_messages(self):
		"""Idempotency is on the provider's id, never on what was written."""
		first = telegram.parse_update(
			{"message": {"message_id": 1, "chat": {"id": 5}, "from": {"id": 5}, "text": "готово"}}
		)
		second = telegram.parse_update(
			{"message": {"message_id": 2, "chat": {"id": 5}, "from": {"id": 5}, "text": "готово"}}
		)

		self.assertNotEqual(first["message_id"], second["message_id"])


class TestWhatsAppTrustsOnlyWhatItCanCheck(IntegrationTestCase):
	def test_a_missing_app_secret_is_a_refusal_and_not_a_crash(self):
		"""It used to be `AttributeError` on `None.encode`, so a half-configured
		site answered Meta with a 500 — which is the code a caller retries."""
		self.assertFalse(whatsapp.verify_webhook_signature(b"{}", "sha256=abc", None))

	def test_a_missing_signature_is_refused(self):
		self.assertFalse(whatsapp.verify_webhook_signature(b"{}", None, "secret"))

	def test_a_wrong_signature_is_refused(self):
		self.assertFalse(whatsapp.verify_webhook_signature(b"{}", "sha256=deadbeef", "secret"))

	def test_a_correct_signature_is_accepted(self):
		import hashlib
		import hmac

		body = b'{"entry": []}'
		digest = hmac.new(b"secret", body, hashlib.sha256).hexdigest()

		self.assertTrue(whatsapp.verify_webhook_signature(body, f"sha256={digest}", "secret"))

	def test_the_verification_handshake_answers_only_its_own_token(self):
		self.assertEqual(
			whatsapp.check_verification_request("subscribe", "right", "42", "right", True),
			(200, "42"),
		)
		self.assertEqual(
			whatsapp.check_verification_request("subscribe", "wrong", "42", "right", True),
			(403, "Forbidden"),
		)

	def test_a_disabled_channel_does_not_complete_the_handshake(self):
		self.assertEqual(
			whatsapp.check_verification_request("subscribe", "right", "42", "right", False),
			(403, "Forbidden"),
		)


class TestWhatsAppMessagesAreParsedForWhatWeAnswer(IntegrationTestCase):
	def envelope(self, message):
		return {"entry": [{"changes": [{"value": {"messages": [message]}}]}]}

	def test_text_arrives_with_its_provider_id(self):
		parsed = whatsapp.parse_inbound_messages(
			self.envelope(
				{"from": "77001234567", "id": "wamid.1", "type": "text", "text": {"body": "привет"}}
			)
		)

		self.assertEqual(parsed[0]["message_id"], "wamid.1")
		self.assertEqual(parsed[0]["text"], "привет")

	def test_a_button_reply_becomes_the_text_protocol(self):
		parsed = whatsapp.parse_inbound_messages(
			self.envelope(
				{
					"from": "77001234567",
					"id": "wamid.2",
					"type": "interactive",
					"interactive": {"button_reply": {"id": "confirm:abc", "title": "Подтвердить"}},
				}
			)
		)

		self.assertEqual(parsed[0]["text"], "CONFIRM abc")

	def test_the_third_button_becomes_a_question(self):
		parsed = whatsapp.parse_inbound_messages(
			self.envelope(
				{
					"from": "7700",
					"id": "wamid.3",
					"type": "interactive",
					"interactive": {"button_reply": {"id": "ask:abc", "title": "Уточнить"}},
				}
			)
		)

		self.assertEqual(parsed[0]["text"], "ASK abc")

	def test_an_image_is_not_something_to_answer(self):
		self.assertEqual(
			whatsapp.parse_inbound_messages(
				self.envelope({"from": "7700", "id": "wamid.4", "type": "image"})
			),
			[],
		)

	def test_a_status_callback_carries_no_message(self):
		"""Meta sends delivery receipts through the same webhook."""
		self.assertEqual(
			whatsapp.parse_inbound_messages(
				{"entry": [{"changes": [{"value": {"statuses": [{"status": "delivered"}]}}]}]},
			),
			[],
		)


class TestWhatsAppButtonsRespectMetasLimits(IntegrationTestCase):
	def test_a_title_fits_metas_twenty_characters(self):
		for buttons in (
			whatsapp.confirmation_buttons("body", "abc")["interactive"]["action"]["buttons"],
			whatsapp.confirmation_buttons("body", "abc", ask=True)["interactive"]["action"]["buttons"],
		):
			for button in buttons:
				self.assertLessEqual(len(button["reply"]["title"]), 20)

	def test_three_is_the_whole_budget(self):
		buttons = whatsapp.confirmation_buttons("body", "abc", ask=True)["interactive"]["action"][
			"buttons"
		]

		self.assertEqual(len(buttons), 3)

	def test_a_write_is_offered_two_answers_and_not_three(self):
		"""A proposal answered with "maybe" would sit unresolved for ever."""
		buttons = whatsapp.confirmation_buttons("body", "abc")["interactive"]["action"]["buttons"]

		self.assertEqual(len(buttons), 2)


class TestTelegramButtonsRespectTelegramsLimits(IntegrationTestCase):
	def test_callback_data_fits_sixty_four_bytes(self):
		markup = telegram.confirmation_markup("0123456789", ask=True)

		for button in markup["inline_keyboard"][0]:
			self.assertLessEqual(len(button["callback_data"].encode("utf-8")), 64)

	def test_a_write_is_offered_two_answers_and_not_three(self):
		markup = telegram.confirmation_markup("abc")

		self.assertEqual(len(markup["inline_keyboard"][0]), 2)
