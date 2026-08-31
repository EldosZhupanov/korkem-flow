# Copyright (c) 2026, KORKEM and Contributors
# See license.txt

import hashlib
import hmac
import json
from unittest.mock import MagicMock, patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai.integrations import whatsapp
from korkem_ai.korkem_ai.integrations.whatsapp import (
	check_verification_request,
	parse_inbound_messages,
	queue_send_message,
	send_message,
	verify_webhook_signature,
)


class TestWhatsAppSignatureVerification(IntegrationTestCase):
	def test_valid_signature_accepted(self):
		secret = "test-app-secret"
		body = b'{"hello":"world"}'
		signature = "sha256=" + hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()

		self.assertTrue(verify_webhook_signature(body, signature, secret))

	def test_tampered_body_rejected(self):
		secret = "test-app-secret"
		body = b'{"hello":"world"}'
		signature = "sha256=" + hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()

		tampered_body = b'{"hello":"world!"}'
		self.assertFalse(verify_webhook_signature(tampered_body, signature, secret))

	def test_wrong_secret_rejected(self):
		body = b'{"hello":"world"}'
		signature = "sha256=" + hmac.new(b"correct-secret", body, hashlib.sha256).hexdigest()

		self.assertFalse(verify_webhook_signature(body, signature, "wrong-secret"))

	def test_missing_signature_rejected(self):
		self.assertFalse(verify_webhook_signature(b"{}", None, "any-secret"))

	def test_malformed_signature_header_rejected(self):
		self.assertFalse(verify_webhook_signature(b"{}", "not-a-real-header", "any-secret"))


class TestWhatsAppPayloadParsing(IntegrationTestCase):
	def test_parses_single_text_message(self):
		payload = {
			"entry": [
				{
					"changes": [
						{
							"value": {
								"messages": [
									{
										"from": "77011234567",
										"id": "wamid.abc123",
										"timestamp": "1732000000",
										"type": "text",
										"text": {"body": "Hi, I need a kitchen facade quote"},
									}
								]
							}
						}
					]
				}
			]
		}

		messages = parse_inbound_messages(payload)

		self.assertEqual(len(messages), 1)
		self.assertEqual(messages[0]["from"], "77011234567")
		self.assertEqual(messages[0]["text"], "Hi, I need a kitchen facade quote")
		self.assertEqual(messages[0]["message_id"], "wamid.abc123")

	def test_ignores_non_text_messages(self):
		payload = {
			"entry": [
				{
					"changes": [
						{
							"value": {
								"messages": [
									{"from": "77011234567", "id": "wamid.1", "type": "image"},
									{
										"from": "77011234567",
										"id": "wamid.2",
										"type": "text",
										"text": {"body": "actual text message"},
									},
								]
							}
						}
					]
				}
			]
		}

		messages = parse_inbound_messages(payload)

		self.assertEqual(len(messages), 1)
		self.assertEqual(messages[0]["message_id"], "wamid.2")

	def test_handles_status_update_payload_with_no_messages(self):
		"""Meta also posts delivery/read status updates to the same webhook -- these
		have no 'messages' key and must not raise."""
		payload = {"entry": [{"changes": [{"value": {"statuses": [{"status": "delivered"}]}}]}]}

		self.assertEqual(parse_inbound_messages(payload), [])

	def test_handles_empty_payload(self):
		self.assertEqual(parse_inbound_messages({}), [])


class TestWhatsAppVerificationHandshake(IntegrationTestCase):
	def test_correct_token_returns_challenge(self):
		status, body = check_verification_request(
			mode="subscribe",
			token="correct-token",
			challenge="12345",
			expected_token="correct-token",
			enabled=True,
		)
		self.assertEqual(status, 200)
		self.assertEqual(body, "12345")

	def test_wrong_token_rejected(self):
		status, body = check_verification_request(
			mode="subscribe",
			token="wrong-token",
			challenge="12345",
			expected_token="correct-token",
			enabled=True,
		)
		self.assertEqual(status, 403)

	def test_wrong_mode_rejected(self):
		status, _ = check_verification_request(
			mode="unsubscribe",
			token="correct-token",
			challenge="12345",
			expected_token="correct-token",
			enabled=True,
		)
		self.assertEqual(status, 403)

	def test_disabled_integration_rejected_even_with_correct_token(self):
		status, _ = check_verification_request(
			mode="subscribe",
			token="correct-token",
			challenge="12345",
			expected_token="correct-token",
			enabled=False,
		)
		self.assertEqual(status, 403)


class TestWhatsAppSendMessage(IntegrationTestCase):
	"""The outbound HTTP call itself is mocked -- these tests verify we build the
	correct request, not that Meta's real API is reachable (no real credentials
	exist in this environment; see the module docstring).
	"""

	def setUp(self):
		frappe.db.set_single_value("WhatsApp Settings", "enabled", 1)
		frappe.db.set_single_value("WhatsApp Settings", "phone_number_id", "1234567890")
		frappe.db.set_single_value("WhatsApp Settings", "api_version", "v21.0")
		settings = frappe.get_single("WhatsApp Settings")
		settings.access_token = "test-access-token"
		settings.save()

	def tearDown(self):
		frappe.db.set_single_value("WhatsApp Settings", "enabled", 0)
		frappe.db.rollback()

	@patch("korkem_ai.korkem_ai.integrations.whatsapp.requests.post")
	def test_send_message_calls_correct_url_and_payload(self, mock_post):
		mock_response = MagicMock()
		# A real status code, because the adapter now reads one: an error from
		# Meta arrives as a 4xx with a body, not as an exception, and that is
		# what lets a settings screen say *which* thing is wrong.
		mock_response.status_code = 200
		mock_response.json.return_value = {"messages": [{"id": "wamid.sent"}]}
		mock_post.return_value = mock_response

		result = send_message("77011234567", "Your order is ready!")

		mock_post.assert_called_once()
		args, kwargs = mock_post.call_args
		self.assertEqual(args[0], "https://graph.facebook.com/v21.0/1234567890/messages")
		self.assertEqual(kwargs["headers"]["Authorization"], "Bearer test-access-token")
		body = kwargs["json"]
		self.assertEqual(body["to"], "77011234567")
		self.assertEqual(body["text"]["body"], "Your order is ready!")
		self.assertEqual(result["messages"][0]["id"], "wamid.sent")

	def test_send_message_raises_when_disabled(self):
		frappe.db.set_single_value("WhatsApp Settings", "enabled", 0)

		with self.assertRaises(frappe.ValidationError):
			send_message("77011234567", "Should not send")

	@patch("korkem_ai.korkem_ai.integrations.whatsapp.frappe.enqueue")
	def test_queue_send_message_enqueues_with_correct_args(self, mock_enqueue):
		queue_send_message("77011234567", "Queued message")

		mock_enqueue.assert_called_once_with(
			"korkem_ai.korkem_ai.integrations.whatsapp.send_message",
			queue="short",
			to="77011234567",
			body="Queued message",
		)


class TestWhatsAppInboundDispatch(IntegrationTestCase):
	def tearDown(self):
		frappe.db.rollback()

	def test_dispatch_creates_conversation_and_message(self):
		from korkem_ai.korkem_ai.integrations.whatsapp import _dispatch_inbound_message

		_dispatch_inbound_message(
			{"from": "77019876543", "message_id": "wamid.x", "timestamp": "1732000000", "text": "Hello!"}
		)

		conversation = frappe.get_all(
			"Agent Conversation",
			filters={"contact_phone": "77019876543", "channel": "WhatsApp"},
		)
		self.assertEqual(len(conversation), 1)

		messages = frappe.get_all(
			"Agent Conversation Message",
			filters={"conversation": conversation[0].name},
			fields=["content", "sender"],
		)
		self.assertEqual(len(messages), 1)
		self.assertEqual(messages[0].content, "Hello!")
		self.assertEqual(messages[0].sender, "User")


class TestWhatsAppConfirmationButtons(IntegrationTestCase):
	def test_a_proposal_is_sent_as_an_interactive_message(self):
		payload = whatsapp.confirmation_buttons("Остановить?", "abc123")

		self.assertEqual(payload["type"], "interactive")
		buttons = payload["interactive"]["action"]["buttons"]
		self.assertEqual(buttons[0]["reply"]["id"], "confirm:abc123")
		self.assertEqual(buttons[1]["reply"]["id"], "cancel:abc123")

	def test_the_labels_fit_metas_twenty_character_cap(self):
		payload = whatsapp.confirmation_buttons("x", "abc123")

		for button in payload["interactive"]["action"]["buttons"]:
			self.assertLessEqual(len(button["reply"]["title"]), 20)

	def test_a_button_press_becomes_the_text_protocol(self):
		"""So a press and a typed reply travel the same path."""
		payload = {
			"entry": [
				{
					"changes": [
						{
							"value": {
								"messages": [
									{
										"from": "77001234567",
										"id": "wamid.btn",
										"timestamp": "1780000000",
										"type": "interactive",
										"interactive": {
											"type": "button_reply",
											"button_reply": {"id": "confirm:abc123", "title": "Подтвердить"},
										},
									}
								]
							}
						}
					]
				}
			]
		}

		messages = whatsapp.parse_inbound_messages(payload)

		self.assertEqual(len(messages), 1)
		self.assertEqual(messages[0]["text"], "CONFIRM abc123")
		self.assertEqual(messages[0]["message_id"], "wamid.btn")

	def test_an_unrecognised_interactive_reply_is_skipped(self):
		payload = {
			"entry": [
				{
					"changes": [
						{
							"value": {
								"messages": [
									{
										"from": "7700",
										"id": "wamid.x",
										"type": "interactive",
										"interactive": {
											"type": "list_reply",
											"list_reply": {"id": "menu:1"},
										},
									}
								]
							}
						}
					]
				}
			]
		}

		self.assertEqual(whatsapp.parse_inbound_messages(payload), [])
