# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Push: адрес устройства, и обещание, что наружу не уходит работа завода."""

from __future__ import annotations

import json
from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai.channels import gateway
from korkem_ai.korkem_ai.integrations import push
from korkem_ai.korkem_ai.notifications import service as notifications

FAKE_ACCOUNT = {
	"type": "service_account",
	"project_id": "korkem-test",
	"client_email": "x@korkem-test.iam.gserviceaccount.com",
	"private_key": "-----BEGIN PRIVATE KEY-----\nnot-a-real-key\n-----END PRIVATE KEY-----\n",
}


class _Response:
	def __init__(self, status_code=200, text="{}"):
		self.status_code = status_code
		self.text = text


def _person(suffix: str) -> str:
	email = f"push-{suffix}-{frappe.generate_hash(length=6)}@example.com"
	frappe.get_doc(
		{"doctype": "User", "email": email, "first_name": "Push", "send_welcome_email": 0}
	).insert(ignore_permissions=True)
	return email


class TestRememberingATelephone(IntegrationTestCase):
	def tearDown(self):
		frappe.set_user("Administrator")

	def test_a_telephone_is_remembered_once_not_every_time_the_app_opens(self):
		"""Приложение сообщает адрес при каждом входе — записей должно быть одна.

		Иначе у человека копятся мёртвые устройства, и каждое уведомление уходит
		и в них тоже: сначала это лишние запросы, потом — уведомления на
		телефон, который давно у другого.
		"""
		user = _person("once")
		token = f"token-{frappe.generate_hash(length=10)}"

		first = push.register_device(token, user=user)
		second = push.register_device(token, user=user)

		self.assertTrue(first["created"])
		self.assertFalse(second["created"])
		self.assertEqual(first["identity"], second["identity"])
		self.assertEqual(
			frappe.db.count(
				push.IDENTITY_DOCTYPE, {"channel": push.CHANNEL, "external_id": token}
			),
			1,
		)

	def test_a_telephone_that_changed_hands_stops_reaching_the_previous_owner(self):
		"""В цехе телефон переходит к другому человеку. Уведомления — нет."""
		before = _person("before")
		after = _person("after")
		token = f"token-{frappe.generate_hash(length=10)}"

		push.register_device(token, user=before)
		push.register_device(token, user=after)

		identity = frappe.db.get_value(
			push.IDENTITY_DOCTYPE,
			{"channel": push.CHANNEL, "external_id": token},
			["user", "enabled"],
			as_dict=True,
		)
		self.assertEqual(identity.user, after)
		self.assertTrue(identity.enabled)

	def test_a_service_account_is_not_a_person_and_gets_no_notifications(self):
		for who in ("Guest", "Administrator"):
			with self.subTest(user=who):
				with self.assertRaises(frappe.ValidationError):
					push.register_device("token-x", user=who)

	def test_signing_out_stops_this_telephone_and_only_this_one(self):
		user = _person("out")
		mine = f"token-{frappe.generate_hash(length=10)}"
		theirs = f"token-{frappe.generate_hash(length=10)}"
		push.register_device(mine, user=user)
		push.register_device(theirs, user=_person("other"))

		push.forget_device(mine)

		self.assertFalse(
			frappe.db.get_value(
				push.IDENTITY_DOCTYPE,
				{"channel": push.CHANNEL, "external_id": mine},
				"enabled",
			)
		)
		self.assertTrue(
			frappe.db.get_value(
				push.IDENTITY_DOCTYPE,
				{"channel": push.CHANNEL, "external_id": theirs},
				"enabled",
			)
		)


class TestNothingAboutTheFactoryLeavesTheBuilding(IntegrationTestCase):
	"""Главная проверка этого модуля.

	Push идёт через серверы Google. Обещание клиенту противоположное — заказы,
	цены, имена и суммы не покидают его здания (R6, политика приватности).
	Строку «Заказ Ерлана на 650 000 ₸ просрочен» в уведомление можно добавить
	одной правкой, и ничего не сломается: тесты пройдут, приложение заработает
	лучше, а обещание окажется нарушено молча.

	Поэтому здесь проверяется не то, что отправка работает, а **то, чего в ней
	нет**.
	"""

	def _send_and_capture(self, **kwargs) -> dict:
		sent = {}

		def fake_post(url, headers=None, json=None, timeout=None):
			sent["url"] = url
			sent["body"] = json
			return _Response()

		with (
			patch.object(push, "_credentials", return_value=("korkem-test", "access")),
			patch.object(push.requests, "post", fake_post),
		):
			push.send("device-address", **kwargs)
		return sent

	def test_the_payload_carries_a_kind_and_nothing_else(self):
		sent = self._send_and_capture()
		message = sent["body"]["message"]

		self.assertEqual(message["data"], {"kind": "attention"})
		self.assertEqual(
			set(message),
			{"token", "data"},
			"в сообщении не должно быть ни notification, ни заголовка, ни текста: "
			"всё это Google увидит",
		)

	def test_the_whole_request_contains_no_business_words(self):
		"""Грубо, зато поймает любую будущую правку, которая добавит текст."""
		sent = self._send_and_capture()
		flat = json.dumps(sent["body"], ensure_ascii=False).lower()

		for word in ("заказ", "клиент", "₸", "просроч", "notification", "title", "body"):
			self.assertNotIn(word, flat, f"наружу ушло слово «{word}»")

	def test_a_device_that_no_longer_exists_is_switched_off_rather_than_retried(self):
		user = _person("gone")
		token = f"token-{frappe.generate_hash(length=10)}"
		push.register_device(token, user=user)

		def fake_post(url, headers=None, json=None, timeout=None):
			return _Response(404, '{"error":{"status":"NOT_FOUND"}}')

		with (
			patch.object(push, "_credentials", return_value=("korkem-test", "access")),
			patch.object(push.requests, "post", fake_post),
		):
			result = push.send(token)

		self.assertEqual(result, {"ok": False, "reason": "device_gone"})
		self.assertFalse(
			frappe.db.get_value(
				push.IDENTITY_DOCTYPE,
				{"channel": push.CHANNEL, "external_id": token},
				"enabled",
			),
			"устройство, которого нет, обязано выключиться: иначе узел стучится "
			"в него до конца времён",
		)


class TestThePushChannelIsWiredIn(IntegrationTestCase):
	def test_push_is_a_channel_the_gateway_knows(self):
		self.assertEqual(gateway.PUSH, "Push")

	def test_push_is_offered_last(self):
		"""Мессенджер доносит новость, push только будит телефон."""
		self.assertEqual(notifications.CHANNEL_ORDER[-1], gateway.PUSH)

	def test_the_gateway_routes_push_without_the_message_text(self):
		with patch.object(push, "send", return_value={"ok": True}) as sender:
			gateway.deliver(gateway.PUSH, "device-address", "Заказ Ерлана просрочен")

		sender.assert_called_once_with("device-address")

	def test_an_unconfigured_node_refuses_in_words_rather_than_a_traceback(self):
		settings = frappe.get_single(push.SETTINGS_DOCTYPE)
		settings.enabled = 0
		settings.flags.ignore_permissions = True
		settings.save(ignore_permissions=True)

		with self.assertRaises(push.PushNotConfigured):
			push.send("device-address")


class TestTheKeyIsCheckedWhenItIsPastedNotWhenItIsUsed(IntegrationTestCase):
	"""Владелец вставляет ключ один раз и уходит. Ошибку он должен увидеть тогда."""

	def _settings(self):
		doc = frappe.get_single(push.SETTINGS_DOCTYPE)
		doc.flags.ignore_permissions = True
		return doc

	def tearDown(self):
		doc = self._settings()
		doc.enabled = 0
		doc.save(ignore_permissions=True)

	def test_google_services_json_is_the_other_file_and_is_refused_by_name(self):
		"""Их легко перепутать: оба JSON, оба из Firebase, оба выглядят верно."""
		doc = self._settings()
		doc.enabled = 1
		doc.service_account_json = json.dumps({"project_info": {"project_id": "x"}})

		with self.assertRaises(frappe.ValidationError) as refusal:
			doc.save(ignore_permissions=True)

		self.assertIn("google-services.json", str(refusal.exception))

	def test_something_that_is_not_json_at_all_is_refused(self):
		doc = self._settings()
		doc.enabled = 1
		doc.service_account_json = "тут был ключ"

		with self.assertRaises(frappe.ValidationError):
			doc.save(ignore_permissions=True)

	def test_a_real_looking_key_is_accepted(self):
		doc = self._settings()
		doc.enabled = 1
		doc.service_account_json = json.dumps(FAKE_ACCOUNT)
		doc.save(ignore_permissions=True)

		self.assertTrue(frappe.get_single(push.SETTINGS_DOCTYPE).enabled)
