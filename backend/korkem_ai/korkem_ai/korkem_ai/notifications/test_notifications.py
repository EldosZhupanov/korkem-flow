# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Sending a person a message the system decided to send.

Three claims, and the third is the one that would hurt most if it were wrong.

**Nobody is told by accident.** A recipient is a `User` a document named. A
customer hears about their own order and nothing else — not another customer's,
not the factory's shelf, not a work order number.

**Nothing is said twice.** One business event, one recipient, one channel is one
row for ever, enforced by a unique key built from the document rather than from
the words.

**A dead provider costs a message, not a transaction.** The business document is
already written; a delivery that fails is retried on its own schedule, a bounded
number of times, and never for a failure that retrying cannot fix.
"""

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_to_date, now_datetime

from korkem_ai.korkem_ai.doctype.channel_identity import channel_identity as identities
from korkem_ai.korkem_ai.doctype.notification_delivery import notification_delivery as delivery
from korkem_ai.korkem_ai.integrations.telegram import TelegramError
from korkem_ai.korkem_ai.notifications import events, recipients, service

PLANNER = "korkem.planner@example.com"
MANAGER = "korkem.manager@example.com"
IVAN = "korkem.ivan@example.com"
CLIENT = "korkem.client@example.com"
MINE = "Мебель Астана"
THEIRS = "Караганда Мебель"


class _NotificationTestCase(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		from korkem_manufacturing import seed_demo

		seed_demo.seed_users()
		self._clean()
		self.sent = []
		patcher = patch(
			"korkem_ai.korkem_ai.channels.gateway.deliver",
			side_effect=lambda channel, chat_id, text, confirm_for=None, ask=False: self.sent.append(
				{"channel": channel, "chat_id": chat_id, "text": text, "confirm_for": confirm_for, "ask": ask}
			)
			or {"message_id": 4242},
		)
		patcher.start()
		self.addCleanup(patcher.stop)
		self.addCleanup(self._clean)
		self.addCleanup(frappe.set_user, "Administrator")

	def _clean(self):
		frappe.set_user("Administrator")
		for doctype in ("Notification Delivery", "Channel Event"):
			for name in frappe.get_all(doctype, pluck="name"):
				frappe.delete_doc(doctype, name, force=1, ignore_permissions=True)
		for name in frappe.get_all(
			"Channel Identity", filters={"external_id": ["like", "31%"]}, pluck="name"
		):
			frappe.delete_doc("Channel Identity", name, force=1, ignore_permissions=True)
		frappe.db.commit()

	def link(self, user, external_id, channel="Telegram", priority=0):
		identity = identities.observe(channel, external_id, "тест")
		identity.db_set({"user": user, "priority": priority})
		return identity

	def order_of(self, customer):
		return frappe.get_all(
			"Sales Order", filters={"customer": customer, "docstatus": 1}, pluck="name"
		)[0]

	def deliveries(self, **filters):
		return frappe.get_all(
			"Notification Delivery",
			filters=filters,
			fields=["name", "event", "recipient_user", "status", "channel", "attempt_count", "body"],
		)


class TestNobodyIsToldByAccident(_NotificationTestCase):
	def test_a_message_goes_to_the_person_a_document_named(self):
		self.link(IVAN, "310001")

		service.send_to_user("test.event", IVAN, "привет")

		self.assertEqual(len(self.sent), 1)
		self.assertEqual(self.sent[0]["chat_id"], "310001")

	def test_somebody_with_no_channel_is_recorded_and_not_invented(self):
		"""There was nobody to send to. That is a fact, not an error, and it is
		certainly not a reason to look for a phone number that resembles them."""
		created = service.send_to_user("test.event", IVAN, "привет")

		self.assertEqual(self.sent, [])
		self.assertEqual(
			frappe.db.get_value("Notification Delivery", created[0], "status"),
			delivery.SUPPRESSED,
		)

	def test_the_administrator_account_is_never_a_recipient(self):
		self.assertEqual(service.send_to_user("test.event", "Administrator", "привет"), [])

	def test_a_customers_own_order_reaches_that_customers_portal_user(self):
		from korkem_ai.korkem_ai import customer_access

		self._ensure_client()
		customer_access.link(CLIENT, MINE)
		self.addCleanup(customer_access.unlink, CLIENT, MINE)
		self.link(CLIENT, "310002")

		service.send_to_customer("order.test", self.order_of(MINE), "ваш заказ принят")

		self.assertEqual(len(self.sent), 1)
		self.assertEqual(self.sent[0]["chat_id"], "310002")

	def test_another_customers_order_reaches_them_not_at_all(self):
		"""The whole isolation claim, from the sending side."""
		from korkem_ai.korkem_ai import customer_access

		self._ensure_client()
		customer_access.link(CLIENT, MINE)
		self.addCleanup(customer_access.unlink, CLIENT, MINE)
		self.link(CLIENT, "310003")

		service.send_to_customer("order.test", self.order_of(THEIRS), "чужой заказ")

		self.assertEqual(self.sent, [])

	def test_a_customer_is_not_a_staff_recipient_of_their_own_order(self):
		"""An order placed through the assistant is *owned* by the customer, so
		the naive answer to "who is staff on this order" is the customer."""
		from korkem_ai.korkem_ai import customer_access

		self._ensure_client()
		customer_access.link(CLIENT, MINE)
		self.addCleanup(customer_access.unlink, CLIENT, MINE)
		order = self.order_of(MINE)
		frappe.db.set_value("Sales Order", order, "owner", CLIENT, update_modified=False)

		self.assertNotIn(CLIENT, recipients.staff_for_sales_order(order))

	def test_an_identity_speaking_for_nobody_reaches_nobody(self):
		identity = identities.observe("Telegram", "310004", "чужой")

		self.assertEqual(service.send_to_channel_identity("test.event", identity.name, "привет"), [])

	def _ensure_client(self):
		if not frappe.db.exists("User", CLIENT):
			frappe.get_doc(
				{
					"doctype": "User",
					"email": CLIENT,
					"first_name": "Клиент",
					"send_welcome_email": 0,
				}
			).insert(ignore_permissions=True)


class TestChannelPreference(_NotificationTestCase):
	def test_telegram_is_tried_before_whatsapp_when_nothing_says_otherwise(self):
		self.link(IVAN, "310010", channel="WhatsApp")
		self.link(IVAN, "310011", channel="Telegram")

		service.send_to_user("test.event", IVAN, "привет")

		self.assertEqual(self.sent[0]["channel"], "Telegram")

	def test_an_explicit_priority_wins(self):
		self.link(IVAN, "310012", channel="WhatsApp", priority=-1)
		self.link(IVAN, "310013", channel="Telegram", priority=0)

		service.send_to_user("test.event", IVAN, "привет")

		self.assertEqual(self.sent[0]["channel"], "WhatsApp")

	def test_a_transient_failure_moves_to_the_other_channel(self):
		self.link(IVAN, "310014", channel="Telegram")
		self.link(IVAN, "310015", channel="WhatsApp")

		with patch(
			"korkem_ai.korkem_ai.channels.gateway.deliver",
			side_effect=TelegramError("Bad Gateway", code="provider_unavailable"),
		):
			created = service.send_to_user("test.event", IVAN, "привет")

		row = frappe.get_doc("Notification Delivery", created[0])
		self.assertEqual(row.status, delivery.RETRYING)
		self.assertEqual(row.channel, "WhatsApp")

	def test_a_permanent_failure_does_not_wander_to_another_channel(self):
		"""A rejected token is not fixed by trying a different bot."""
		self.link(IVAN, "310016", channel="Telegram")
		self.link(IVAN, "310017", channel="WhatsApp")

		with patch(
			"korkem_ai.korkem_ai.channels.gateway.deliver",
			side_effect=TelegramError("Unauthorized", code="invalid_credentials"),
		):
			created = service.send_to_user("test.event", IVAN, "привет")

		row = frappe.get_doc("Notification Delivery", created[0])
		self.assertEqual(row.status, delivery.FAILED)
		self.assertEqual(row.channel, "Telegram")


class TestNothingIsSaidTwice(_NotificationTestCase):
	def test_the_same_event_for_the_same_person_is_one_row(self):
		self.link(IVAN, "310020")

		first = service.emit(
			"test.event", recipients=[IVAN], body="привет", reference_doctype="User", reference_name=IVAN
		)
		second = service.emit(
			"test.event", recipients=[IVAN], body="привет", reference_doctype="User", reference_name=IVAN
		)

		self.assertEqual(first, second)
		self.assertEqual(len(self.sent), 1)

	def test_two_different_events_are_two_rows_even_with_the_same_words(self):
		self.link(IVAN, "310021")

		service.emit("event.one", recipients=[IVAN], body="одинаково", reference_name=IVAN)
		service.emit("event.two", recipients=[IVAN], body="одинаково", reference_name=IVAN)

		self.assertEqual(len(self.deliveries()), 2)

	def test_the_key_is_built_from_the_document_and_not_the_body(self):
		self.assertEqual(
			service.event_key("e", IVAN, "Work Order", "WO-1"),
			service.event_key("e", IVAN, "Work Order", "WO-1"),
		)
		self.assertNotEqual(
			service.event_key("e", IVAN, "Work Order", "WO-1"),
			service.event_key("e", IVAN, "Work Order", "WO-2"),
		)

	def test_two_recipients_of_one_event_are_two_rows(self):
		self.link(IVAN, "310022")
		self.link(MANAGER, "310023")

		service.emit("test.event", recipients=[IVAN, MANAGER], body="привет", reference_name="x")

		self.assertEqual(len(self.deliveries()), 2)

	def test_a_second_attempt_on_a_sent_row_sends_nothing(self):
		self.link(IVAN, "310024")
		created = service.send_to_user("test.event", IVAN, "привет")

		outcome = service.attempt(created[0])

		self.assertEqual(outcome, "already_in_flight")
		self.assertEqual(len(self.sent), 1)


class TestADeadProviderCostsAMessageNotATransaction(_NotificationTestCase):
	def test_a_transient_failure_is_scheduled_rather_than_lost(self):
		self.link(IVAN, "310030")

		with patch(
			"korkem_ai.korkem_ai.channels.gateway.deliver",
			side_effect=TelegramError("Bad Gateway", code="provider_unavailable"),
		):
			created = service.send_to_user("test.event", IVAN, "привет")

		row = frappe.get_doc("Notification Delivery", created[0])
		self.assertEqual(row.status, delivery.RETRYING)
		self.assertEqual(row.attempt_count, 1)
		self.assertIsNotNone(row.next_attempt_at)

	def test_retries_are_bounded_and_end_in_a_dead_letter(self):
		"""Not an infinite loop: four attempts, then it stops and stays visible."""
		self.link(IVAN, "310031")

		with patch(
			"korkem_ai.korkem_ai.channels.gateway.deliver",
			side_effect=TelegramError("Bad Gateway", code="provider_unavailable"),
		):
			created = service.send_to_user("test.event", IVAN, "привет")
			for _ in range(delivery.ATTEMPTS + 2):
				frappe.db.set_value(
					"Notification Delivery", created[0], "next_attempt_at", now_datetime()
				)
				service.attempt(created[0])

		row = frappe.get_doc("Notification Delivery", created[0])
		self.assertEqual(row.status, delivery.DEAD_LETTER)
		self.assertEqual(row.attempt_count, delivery.ATTEMPTS)

	def test_the_backoff_grows(self):
		self.link(IVAN, "310032")

		with patch(
			"korkem_ai.korkem_ai.channels.gateway.deliver",
			side_effect=TelegramError("Bad Gateway", code="provider_unavailable"),
		):
			created = service.send_to_user("test.event", IVAN, "привет")
			first = frappe.db.get_value("Notification Delivery", created[0], "next_attempt_at")
			frappe.db.set_value("Notification Delivery", created[0], "next_attempt_at", now_datetime())
			service.attempt(created[0])
			second = frappe.db.get_value("Notification Delivery", created[0], "next_attempt_at")

		self.assertGreater(second, first)

	def test_an_invalid_credential_is_never_retried(self):
		self.link(IVAN, "310033")

		with patch(
			"korkem_ai.korkem_ai.channels.gateway.deliver",
			side_effect=TelegramError("Unauthorized", code="invalid_credentials"),
		):
			created = service.send_to_user("test.event", IVAN, "привет")

		row = frappe.get_doc("Notification Delivery", created[0])
		self.assertEqual(row.status, delivery.FAILED)
		self.assertIsNone(row.next_attempt_at)

	def test_only_due_rows_are_picked_up(self):
		self.link(IVAN, "310034")

		with patch(
			"korkem_ai.korkem_ai.channels.gateway.deliver",
			side_effect=TelegramError("Bad Gateway", code="provider_unavailable"),
		):
			created = service.send_to_user("test.event", IVAN, "привет")

		frappe.db.set_value(
			"Notification Delivery", created[0], "next_attempt_at", add_to_date(now_datetime(), hours=1)
		)
		self.assertNotIn(created[0], delivery.due())

	def test_a_provider_failure_does_not_raise_into_the_caller(self):
		"""The business document is already written. A message that could not be
		sent must not turn a completed transaction into an exception."""
		self.link(IVAN, "310035")

		with patch(
			"korkem_ai.korkem_ai.channels.gateway.deliver",
			side_effect=RuntimeError("something unexpected"),
		):
			created = service.send_to_user("test.event", IVAN, "привет")

		self.assertTrue(created)

	def test_an_unlinked_identity_between_recording_and_sending_is_suppressed(self):
		identity = self.link(IVAN, "310036")
		created = service.emit("test.event", recipients=[IVAN], body="привет", key_suffix="later")
		frappe.db.set_value("Notification Delivery", created[0], "status", delivery.PENDING)
		identity.db_set("enabled", 0)

		outcome = service.attempt(created[0])

		self.assertEqual(outcome, delivery.SUPPRESSED)


class TestNoSecretReachesTheRecord(_NotificationTestCase):
	def test_a_provider_error_is_stored_as_words_not_as_a_traceback(self):
		self.link(IVAN, "310040")

		with patch(
			"korkem_ai.korkem_ai.channels.gateway.deliver",
			side_effect=TelegramError("Unauthorized", code="invalid_credentials"),
		):
			created = service.send_to_user("test.event", IVAN, "привет")

		error = frappe.db.get_value("Notification Delivery", created[0], "error")
		self.assertIn("Unauthorized", error)
		self.assertNotIn("api.telegram.org", error)

	def test_an_unexpected_exception_is_reduced_to_its_class(self):
		"""An arbitrary exception's text is exactly where a credential travels."""
		self.link(IVAN, "310041")

		with patch(
			"korkem_ai.korkem_ai.channels.gateway.deliver",
			side_effect=RuntimeError("token=123456:AAH-secret-looking-thing"),
		):
			created = service.send_to_user("test.event", IVAN, "привет")

		error = frappe.db.get_value("Notification Delivery", created[0], "error")
		self.assertNotIn("AAH-secret-looking-thing", error)
		self.assertIn("RuntimeError", error)

	def test_no_delivery_row_carries_a_stored_credential(self):
		self.link(IVAN, "310042")
		service.send_to_user("test.event", IVAN, "привет")

		blob = frappe.as_json(frappe.get_all("Notification Delivery", fields=["*"]))
		for doctype, field in (
			("Telegram Settings", "bot_token"),
			("WhatsApp Settings", "access_token"),
		):
			secret = frappe.get_single(doctype).get_password(field, raise_exception=False)
			if secret:
				self.assertNotIn(secret, blob)


class TestBusinessEventsReachTheRightPeople(_NotificationTestCase):
	def job(self):
		name = frappe.get_all(
			"Work Order", filters={"docstatus": 1}, pluck="name", order_by="creation desc"
		)[0]
		frappe.db.set_value("Work Order", name, "owner", PLANNER, update_modified=False)
		return name

	def test_a_started_job_tells_whoever_started_it(self):
		self.link(PLANNER, "310050")

		events.production_started(self.job())

		self.assertTrue(any(row["chat_id"] == "310050" for row in self.sent))

	def test_a_started_job_tells_the_customer_about_their_own_order_only(self):
		from korkem_ai.korkem_ai import customer_access

		if not frappe.db.exists("User", CLIENT):
			frappe.get_doc(
				{"doctype": "User", "email": CLIENT, "first_name": "Клиент", "send_welcome_email": 0}
			).insert(ignore_permissions=True)
		customer_access.link(CLIENT, MINE)
		self.addCleanup(customer_access.unlink, CLIENT, MINE)
		self.link(CLIENT, "310051")
		job = self.job()
		order = frappe.db.get_value("Work Order", job, "sales_order")

		events.production_started(job)

		customer_messages = [row for row in self.sent if row["chat_id"] == "310051"]
		if frappe.db.get_value("Sales Order", order, "customer") == MINE:
			self.assertTrue(customer_messages)
			for row in customer_messages:
				self.assertNotIn(THEIRS, row["text"])
				self.assertNotIn("MFG-WO", row["text"])
		else:
			self.assertEqual(customer_messages, [])

	def test_a_customer_is_never_told_the_shortage_figure(self):
		"""Staff are told which board and how much. A customer is told their
		order is waiting — a shortage number is a fact about the shelf."""
		from korkem_ai.korkem_ai import customer_access

		if not frappe.db.exists("User", CLIENT):
			frappe.get_doc(
				{"doctype": "User", "email": CLIENT, "first_name": "Клиент", "send_welcome_email": 0}
			).insert(ignore_permissions=True)
		customer_access.link(CLIENT, MINE)
		self.addCleanup(customer_access.unlink, CLIENT, MINE)
		self.link(CLIENT, "310052")
		order = self.order_of(MINE)

		events.material_short(
			None,
			[{"item_code": "ДСП 16мм", "shortage_qty": 4.0, "uom": "Лист"}],
			sales_order=order,
		)

		for row in self.sent:
			if row["chat_id"] == "310052":
				self.assertNotIn("ДСП", row["text"])
				self.assertNotIn("4", row["text"].replace(order, ""))

	def test_stopping_and_resuming_are_two_events(self):
		self.link(PLANNER, "310053")
		job = self.job()

		events.production_stopped(job, resumed=False)
		events.production_stopped(job, resumed=True)

		kinds = {row["event"] for row in self.deliveries()}
		self.assertIn(events.PRODUCTION_STOPPED, kinds)
		self.assertIn(events.PRODUCTION_RESUMED, kinds)

	def test_the_same_stop_twice_is_one_message(self):
		self.link(PLANNER, "310054")
		job = self.job()

		events.production_stopped(job)
		events.production_stopped(job)

		self.assertEqual(
			len([row for row in self.deliveries() if row["event"] == events.PRODUCTION_STOPPED]), 1
		)

	def test_an_event_about_a_document_that_vanished_says_nothing(self):
		self.assertEqual(events.production_started("MFG-WO-does-not-exist"), [])
