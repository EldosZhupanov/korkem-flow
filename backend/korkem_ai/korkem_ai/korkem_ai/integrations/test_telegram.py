# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""The Telegram wire protocol, and only that.

No network is touched. What is worth testing here is the parsing and the secret
comparison — the two places where a wrong answer either drops a real message or
accepts a forged one.
"""

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai.integrations import telegram


def _update(text="Привет", chat_id=42, user_id=777, message_id=9):
	return {
		"update_id": 1,
		"message": {
			"message_id": message_id,
			"from": {"id": user_id, "first_name": "Иван", "last_name": "Петров"},
			"chat": {"id": chat_id, "type": "private"},
			"text": text,
		},
	}


class TestParsingAnUpdate(IntegrationTestCase):
	def test_a_text_message_is_read(self):
		parsed = telegram.parse_update(_update())

		self.assertEqual(parsed["external_id"], "777")
		self.assertEqual(parsed["chat_id"], "42")
		self.assertEqual(parsed["text"], "Привет")
		self.assertEqual(parsed["sender_name"], "Иван Петров")

	def test_the_message_id_is_unique_per_chat(self):
		"""Telegram numbers messages within a chat, not globally, so the chat
		has to be part of the key or two chats collide on message 1."""
		first = telegram.parse_update(_update(chat_id=1, message_id=1))
		second = telegram.parse_update(_update(chat_id=2, message_id=1))

		self.assertNotEqual(first["message_id"], second["message_id"])

	def test_an_edited_message_is_still_a_message(self):
		payload = {"edited_message": _update()["message"]}

		self.assertIsNotNone(telegram.parse_update(payload))

	def test_a_message_with_no_text_is_skipped(self):
		payload = _update()
		del payload["message"]["text"]

		self.assertIsNone(telegram.parse_update(payload))

	def test_something_that_is_not_a_message_is_skipped(self):
		self.assertIsNone(telegram.parse_update({"update_id": 1}))
		self.assertIsNone(telegram.parse_update({}))

	def test_a_sender_with_only_a_username_is_still_named(self):
		payload = _update()
		payload["message"]["from"] = {"id": 5, "username": "ivan"}

		self.assertEqual(telegram.parse_update(payload)["sender_name"], "ivan")


class TestTheWebhookSecret(IntegrationTestCase):
	def test_the_right_secret_is_accepted(self):
		self.assertTrue(telegram.verify_secret("s3cret", "s3cret"))

	def test_the_wrong_secret_is_refused(self):
		self.assertFalse(telegram.verify_secret("nope", "s3cret"))

	def test_a_missing_header_is_refused(self):
		self.assertFalse(telegram.verify_secret(None, "s3cret"))

	def test_an_unconfigured_secret_does_not_fail_open(self):
		"""The URL is public. Without a secret to compare, every caller is
		Telegram, which is the one outcome that must not happen."""
		self.assertFalse(telegram.verify_secret("anything", None))
		self.assertFalse(telegram.verify_secret("anything", ""))


class TestSending(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		self.settings = frappe.get_single("Telegram Settings")
		self.settings.enabled = 1
		self.settings.bot_token = "test-token"
		self.settings.save(ignore_permissions=True)
		self.addCleanup(self._disable)

	def _disable(self):
		frappe.set_user("Administrator")
		settings = frappe.get_single("Telegram Settings")
		settings.enabled = 0
		settings.save(ignore_permissions=True)

	def test_a_reply_is_posted_to_the_bot_api(self):
		with patch("korkem_ai.korkem_ai.integrations.telegram.requests.post") as post:
			post.return_value.json.return_value = {"ok": True}
			telegram.send_message("42", "готово")

		url, kwargs = post.call_args.args[0], post.call_args.kwargs
		self.assertIn("/sendMessage", url)
		self.assertEqual(kwargs["json"], {"chat_id": "42", "text": "готово"})

	def test_the_token_is_never_in_the_payload(self):
		"""It belongs in the path, and a token in a JSON body ends up in logs."""
		with patch("korkem_ai.korkem_ai.integrations.telegram.requests.post") as post:
			post.return_value.json.return_value = {"ok": True}
			telegram.send_message("42", "готово")

		self.assertNotIn("test-token", str(post.call_args.kwargs))

	def test_a_disabled_integration_sends_nothing(self):
		self._disable()

		with patch("korkem_ai.korkem_ai.integrations.telegram.requests.post") as post:
			with self.assertRaises(frappe.ValidationError):
				telegram.send_message("42", "готово")

		post.assert_not_called()


class TestConfirmationButtons(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		settings = frappe.get_single("Telegram Settings")
		settings.enabled = 1
		settings.bot_token = "test-token"
		settings.save(ignore_permissions=True)
		self.addCleanup(self._disable)

	def _disable(self):
		frappe.set_user("Administrator")
		settings = frappe.get_single("Telegram Settings")
		settings.enabled = 0
		settings.save(ignore_permissions=True)

	def test_a_proposal_is_sent_with_two_buttons(self):
		with patch("korkem_ai.korkem_ai.integrations.telegram.requests.post") as post:
			post.return_value.json.return_value = {"ok": True}
			telegram.send_message("42", "Остановить?", confirm_for="abc123")

		markup = post.call_args.kwargs["json"]["reply_markup"]
		buttons = markup["inline_keyboard"][0]
		self.assertEqual(len(buttons), 2)
		self.assertEqual(buttons[0]["callback_data"], "confirm:abc123")
		self.assertEqual(buttons[1]["callback_data"], "cancel:abc123")

	def test_an_ordinary_reply_carries_no_buttons(self):
		with patch("korkem_ai.korkem_ai.integrations.telegram.requests.post") as post:
			post.return_value.json.return_value = {"ok": True}
			telegram.send_message("42", "Шесть из десяти.")

		self.assertNotIn("reply_markup", post.call_args.kwargs["json"])

	def test_the_callback_payload_fits_telegrams_limit(self):
		"""64 bytes, and the action name is what has to fit."""
		markup = telegram.confirmation_markup("a" * 24)

		for button in markup["inline_keyboard"][0]:
			self.assertLessEqual(len(button["callback_data"].encode("utf-8")), 64)


class TestAButtonPressIsAConfirmation(IntegrationTestCase):
	def _press(self, data="confirm:abc123"):
		return {
			"update_id": 2,
			"callback_query": {
				"id": "cb-1",
				"from": {"id": 777, "first_name": "Иван"},
				"message": {"message_id": 9, "chat": {"id": 42}},
				"data": data,
			},
		}

	def test_a_confirm_press_becomes_the_text_protocol(self):
		"""So a press and a typed reply travel the same path and cannot drift."""
		parsed = telegram.parse_update(self._press())

		self.assertEqual(parsed["text"], "CONFIRM abc123")
		self.assertEqual(parsed["external_id"], "777")
		self.assertEqual(parsed["chat_id"], "42")

	def test_a_cancel_press_becomes_cancel(self):
		parsed = telegram.parse_update(self._press("cancel:abc123"))

		self.assertEqual(parsed["text"], "CANCEL abc123")

	def test_the_press_is_keyed_on_the_callback_id(self):
		"""Telegram re-delivers a press it gets no acknowledgement for."""
		parsed = telegram.parse_update(self._press())

		self.assertEqual(parsed["message_id"], "cb:cb-1")

	def test_an_unrecognised_callback_is_ignored(self):
		self.assertIsNone(telegram.parse_update(self._press("something-else")))

	def test_a_press_with_no_chat_is_ignored(self):
		payload = self._press()
		del payload["callback_query"]["message"]

		self.assertIsNone(telegram.parse_update(payload))
