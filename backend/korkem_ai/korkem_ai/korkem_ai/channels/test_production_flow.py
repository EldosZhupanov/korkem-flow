# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""What has to hold when a real provider is on the other end.

A provider retries. A provider goes down. A model goes down. A person presses a
button twice because the first press did not visibly do anything. None of those
may produce two ERPNext documents, and none of them may lose the one that was
already written.

The rule these tests exist to hold: **one provider message id → one inbound
message → one turn → one proposal → one confirmation → one ERPNext write.**
Idempotency is decided on the provider's own identifier and never on the text,
because two people saying "готово" are two events and one webhook delivered
twice is one.
"""

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai.channels import confirmation, gateway
from korkem_ai.korkem_ai.doctype.channel_event import channel_event as audit
from korkem_ai.korkem_ai.doctype.channel_identity import channel_identity as identities
from korkem_ai.korkem_ai.doctype.work_instruction import work_instruction as instructions
from korkem_ai.korkem_ai.integrations import telegram, whatsapp
from korkem_ai.korkem_ai.orchestrator.protocol import AIToolCall

PLANNER = "korkem.planner@example.com"
MANAGER = "korkem.manager@example.com"
IVAN = "korkem.ivan@example.com"


def _message(channel=gateway.TELEGRAM, external_id="301001", text="Что на производстве?", message_id="p-1"):
	return gateway.InboundMessage(
		channel=channel,
		external_id=external_id,
		chat_id=external_id,
		text=text,
		message_id=message_id,
		sender_name="Иван",
	)


class _FlowTestCase(IntegrationTestCase):
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
			),
		)
		patcher.start()
		self.addCleanup(patcher.stop)
		self.addCleanup(self._clean)
		self.addCleanup(frappe.set_user, "Administrator")

	def _clean(self):
		frappe.set_user("Administrator")
		for doctype in (
			"Channel Event",
			"Pending Action",
			"Work Instruction",
			"Agent Conversation Message",
			"Agent Conversation",
			"Channel Identity",
		):
			for name in frappe.get_all(doctype, pluck="name"):
				frappe.delete_doc(doctype, name, force=1, ignore_permissions=True)
		frappe.db.commit()

	def link(self, external_id="301001", user=PLANNER, channel=gateway.TELEGRAM):
		identity = identities.observe(channel, external_id, "Иван")
		identity.db_set("user", user)
		return identity

	def proposing(self, tool="manufacturing.stop_production", arguments=None):
		"""A turn that proposes one write and nothing else."""

		class _Result:
			status = "needs_confirmation"
			text = "Остановить производство?"
			pending = (
				AIToolCall(
					id="provider-id-we-do-not-use",
					name=tool,
					arguments=arguments or {"sales_order": "SAL-ORD-X", "action": "останови"},
				),
			)

		return _Result()


class TestOneProviderMessageIsOneOfEverything(_FlowTestCase):
	def test_a_redelivered_webhook_runs_no_second_turn(self):
		self.link()

		with patch("frappe.enqueue") as enqueued:
			first = gateway.accept(_message(message_id="dup-1"))
			second = gateway.accept(_message(message_id="dup-1"))

		self.assertEqual(first["status"], "queued")
		self.assertEqual(second["status"], "duplicate")
		self.assertEqual(enqueued.call_count, 1)

	def test_the_drop_is_recorded_so_somebody_can_see_it_happened(self):
		self.link()

		with patch("frappe.enqueue"):
			gateway.accept(_message(message_id="dup-2"))
			gateway.accept(_message(message_id="dup-2"))

		events = frappe.get_all(
			"Channel Event",
			filters={"event": audit.DUPLICATE, "provider_message_id": "dup-2"},
			pluck="name",
		)
		self.assertEqual(len(events), 1)

	def test_the_same_words_twice_are_two_messages(self):
		"""Idempotency is on the provider's id. Two people can both say готово,
		and one person can say it twice about two different things."""
		self.link()

		with patch("frappe.enqueue") as enqueued:
			gateway.accept(_message(message_id="a-1", text="готово"))
			gateway.accept(_message(message_id="a-2", text="готово"))

		self.assertEqual(enqueued.call_count, 2)

	def test_a_redelivered_button_press_is_the_same_press(self):
		"""Telegram keys a press on the callback id, so a retry is recognised."""
		self.link()
		payload = {
			"callback_query": {
				"id": "cb-dup",
				"data": "confirm:abc",
				"from": {"id": 301001},
				"message": {"chat": {"id": 301001}},
			}
		}
		parsed = telegram.parse_update(payload)

		with patch("frappe.enqueue") as enqueued:
			gateway.accept(
				gateway.InboundMessage(
					channel=gateway.TELEGRAM,
					external_id=parsed["external_id"],
					chat_id=parsed["chat_id"],
					text=parsed["text"],
					message_id=parsed["message_id"],
				)
			)
			gateway.accept(
				gateway.InboundMessage(
					channel=gateway.TELEGRAM,
					external_id=parsed["external_id"],
					chat_id=parsed["chat_id"],
					text=parsed["text"],
					message_id=parsed["message_id"],
				)
			)

		self.assertEqual(enqueued.call_count, 1)

	def test_one_turn_writes_one_proposal(self):
		self.link()

		with patch(
			"korkem_ai.korkem_ai.agent.loop.run_turn", return_value=self.proposing()
		), patch("korkem_ai.korkem_ai.orchestrator.llm.resolve", return_value=None):
			conversation = gateway.conversation_for(_message(), PLANNER)
			gateway.run_turn_job(conversation.name, PLANNER, "останови", gateway.TELEGRAM, "301001")

		self.assertEqual(
			frappe.db.count("Pending Action", {"conversation": conversation.name}), 1
		)

	def test_confirming_twice_executes_once(self):
		self.link()
		frappe.set_user("Administrator")
		action = frappe.get_doc(
			{
				"doctype": "Pending Action",
				"tool": "profile.current_user",
				"action_data": "{}",
				"status": "Pending",
				"owner": PLANNER,
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


class TestAProviderThatIsDownLosesNothing(_FlowTestCase):
	def test_a_failed_send_does_not_undo_the_proposal(self):
		"""The turn happened and the row exists. Retrying the *job* would run the
		turn again and write a second proposal, so the failure is recorded
		instead — the person can ask again, and nothing is duplicated."""
		self.link()
		patcher = patch(
			"korkem_ai.korkem_ai.channels.gateway.deliver",
			side_effect=telegram.TelegramError("Bad Gateway", code="provider_unavailable"),
		)
		patcher.start()
		self.addCleanup(patcher.stop)

		with patch(
			"korkem_ai.korkem_ai.agent.loop.run_turn", return_value=self.proposing()
		), patch("korkem_ai.korkem_ai.orchestrator.llm.resolve", return_value=None):
			conversation = gateway.conversation_for(_message(), PLANNER)
			gateway.run_turn_job(conversation.name, PLANNER, "останови", gateway.TELEGRAM, "301001")

		self.assertEqual(
			frappe.db.count("Pending Action", {"conversation": conversation.name}), 1
		)
		self.assertTrue(
			frappe.db.exists("Channel Event", {"event": audit.FAILED, "status": "delivery_failed"})
		)

	def test_a_failed_send_records_the_reason_and_not_the_credential(self):
		self.link()
		patcher = patch(
			"korkem_ai.korkem_ai.channels.gateway.deliver",
			side_effect=telegram.TelegramError(
				"Unauthorized", code="invalid_credentials"
			),
		)
		patcher.start()
		self.addCleanup(patcher.stop)

		with patch(
			"korkem_ai.korkem_ai.agent.loop.run_turn", return_value=self.proposing()
		), patch("korkem_ai.korkem_ai.orchestrator.llm.resolve", return_value=None):
			conversation = gateway.conversation_for(_message(), PLANNER)
			gateway.run_turn_job(conversation.name, PLANNER, "останови", gateway.TELEGRAM, "301001")

		detail = frappe.db.get_value(
			"Channel Event", {"event": audit.FAILED, "status": "delivery_failed"}, "detail"
		)
		self.assertIn("invalid_credentials", detail)

	def test_a_model_that_is_down_answers_rather_than_going_silent(self):
		self.link()

		with patch(
			"korkem_ai.korkem_ai.agent.loop.run_turn", side_effect=RuntimeError("gemini is down")
		), patch("korkem_ai.korkem_ai.orchestrator.llm.resolve", return_value=None):
			conversation = gateway.conversation_for(_message(), PLANNER)
			gateway.run_turn_job(conversation.name, PLANNER, "что там", gateway.TELEGRAM, "301001")

		self.assertTrue(self.sent, "the person was left with nothing")
		self.assertTrue(frappe.db.exists("Channel Event", {"event": audit.FAILED}))

	def test_a_failing_turn_writes_no_pending_action(self):
		"""Nothing half-written: a turn that died proposed nothing."""
		self.link()

		with patch(
			"korkem_ai.korkem_ai.agent.loop.run_turn", side_effect=RuntimeError("boom")
		), patch("korkem_ai.korkem_ai.orchestrator.llm.resolve", return_value=None):
			conversation = gateway.conversation_for(_message(), PLANNER)
			gateway.run_turn_job(conversation.name, PLANNER, "останови", gateway.TELEGRAM, "301001")

		self.assertEqual(frappe.db.count("Pending Action"), 0)


class TestTheAuditTrailFollowsOneMessage(_FlowTestCase):
	def test_receiving_identifying_proposing_and_sending_are_all_recorded(self):
		self.link()

		with patch("frappe.enqueue"):
			gateway.accept(_message(message_id="trace-1"))

		with patch(
			"korkem_ai.korkem_ai.agent.loop.run_turn", return_value=self.proposing()
		), patch("korkem_ai.korkem_ai.orchestrator.llm.resolve", return_value=None):
			conversation = gateway.conversation_for(_message(message_id="trace-1"), PLANNER)
			gateway.run_turn_job(conversation.name, PLANNER, "останови", gateway.TELEGRAM, "301001")

		events = frappe.get_all(
			"Channel Event",
			filters={"conversation": conversation.name},
			fields=["event", "user", "tool", "provider_message_id"],
		)
		kinds = {row["event"] for row in events}
		self.assertIn(audit.IDENTIFIED, kinds)
		self.assertIn(audit.PROPOSED, kinds)
		self.assertIn(audit.SENT, kinds)
		self.assertTrue(any(row["tool"] == "manufacturing.stop_production" for row in events))
		self.assertTrue(any(row["provider_message_id"] == "trace-1" for row in events))

	def test_no_event_carries_a_credential(self):
		"""The whole point of an audit table that a wider group can read."""
		frappe.db.set_single_value("Telegram Settings", "enabled", 1)
		self.link()
		token = frappe.get_single("Telegram Settings").get_password(
			"bot_token", raise_exception=False
		)

		with patch(
			"korkem_ai.korkem_ai.agent.loop.run_turn", side_effect=RuntimeError("boom")
		), patch("korkem_ai.korkem_ai.orchestrator.llm.resolve", return_value=None):
			conversation = gateway.conversation_for(_message(), PLANNER)
			gateway.run_turn_job(conversation.name, PLANNER, "что там", gateway.TELEGRAM, "301001")

		rows = frappe.as_json(
			frappe.get_all("Channel Event", fields=["event", "status", "detail"])
		)
		self.assertNotIn("Authorization", rows)
		if token:
			self.assertNotIn(token, rows)

	def test_the_transcript_is_not_copied_into_the_audit(self):
		"""A customer's words live under the conversation's permission, not this
		table's."""
		self.link()

		with patch("frappe.enqueue"):
			gateway.accept(_message(message_id="trace-2", text="секретная цена 999"))

		rows = frappe.as_json(frappe.get_all("Channel Event", fields=["detail", "status"]))
		self.assertNotIn("999", rows)


class TestAnUnknownOrDisabledSenderReachesNothing(_FlowTestCase):
	def test_an_unlinked_sender_never_reaches_the_assistant(self):
		with patch("frappe.enqueue") as enqueued, patch(
			"frappe.db.get_single_value", return_value=1
		):
			result = gateway.accept(_message(message_id="stranger-1"))

		self.assertEqual(result["status"], "unlinked")
		self.assertNotIn(
			"korkem_ai.korkem_ai.channels.gateway.run_turn_job",
			[call.args[0] for call in enqueued.call_args_list],
		)

	def test_an_identity_an_administrator_disabled_speaks_for_nobody(self):
		identity = self.link()
		identity.db_set("enabled", 0)

		with patch("frappe.enqueue") as enqueued:
			result = gateway.accept(_message(message_id="disabled-1"))

		self.assertEqual(result["status"], "unlinked")
		# The sales router may still be queued — an unknown number is usually a
		# customer. What must never be is the assistant, which would run with no
		# user and therefore no company.
		self.assertNotIn(
			"korkem_ai.korkem_ai.channels.gateway.run_turn_job",
			[call.args[0] for call in enqueued.call_args_list],
		)

	def test_a_deleted_identity_speaks_for_nobody(self):
		self.link()
		frappe.set_user("Administrator")
		for name in frappe.get_all("Channel Identity", filters={"external_id": "301001"}, pluck="name"):
			frappe.delete_doc("Channel Identity", name, force=1, ignore_permissions=True)
		frappe.db.commit()

		with patch("frappe.enqueue") as enqueued:
			result = gateway.accept(_message(message_id="deleted-1"))

		self.assertEqual(result["status"], "unlinked")
		self.assertNotIn(
			"korkem_ai.korkem_ai.channels.gateway.run_turn_job",
			[call.args[0] for call in enqueued.call_args_list],
		)


class TestBeingGivenWorkHasThreeAnswers(_FlowTestCase):
	def open_job(self, employee=IVAN):
		frappe.set_user("Administrator")
		doc = frappe.get_doc(
			{
				"doctype": "Work Instruction",
				"company": "KORKEM",
				"employee_user": employee,
				"instruction": "Закончить раскрой",
				"status": instructions.SENT,
			}
		)
		doc.insert(ignore_permissions=True)
		doc.db_set("owner", MANAGER, update_modified=False)
		frappe.db.commit()
		return doc.reload()

	def answer(self, text, user=IVAN):
		frappe.set_user(user)
		try:
			return confirmation.handle(user, None, text)
		finally:
			frappe.set_user("Administrator")

	def test_a_question_resolves_nothing_and_reaches_the_person_who_asked(self):
		job = self.open_job()
		self.link(external_id="301099", user=MANAGER)

		verdict = self.answer(f"ASK {job.name}")

		self.assertEqual(verdict["status"], "asked")
		# Still open — a question settles nothing — but no longer
		# indistinguishable from silence, which is a different problem for
		# whoever is waiting.
		status = frappe.db.get_value("Work Instruction", job.name, "status")
		self.assertEqual(status, instructions.CLARIFICATION)
		self.assertIn(status, instructions.OPEN)
		self.assertTrue(self.sent, "the question did not reach anybody")
		self.assertEqual(self.sent[-1]["chat_id"], "301099")

	def test_a_question_can_be_asked_twice_because_it_settles_nothing(self):
		job = self.open_job()

		self.answer(f"ASK {job.name}")
		verdict = self.answer(f"ASK {job.name}")

		self.assertEqual(verdict["status"], "asked")

	def test_accepting_tells_the_person_who_gave_it(self):
		job = self.open_job()
		self.link(external_id="301099", user=MANAGER)

		self.answer("Принял")

		self.assertEqual(
			frappe.db.get_value("Work Instruction", job.name, "status"),
			instructions.ACKNOWLEDGED,
		)
		self.assertIn("принял", self.sent[-1]["text"].lower())

	def test_refusing_carries_the_employees_own_words_back(self):
		self.open_job()
		self.link(external_id="301099", user=MANAGER)

		self.answer("Не могу")

		self.assertIn("Не могу", self.sent[-1]["text"])

	def test_an_unlinked_manager_still_gets_the_answer_recorded(self):
		"""Nobody to send it to is not a reason to lose it."""
		job = self.open_job()

		verdict = self.answer("Принял")

		self.assertEqual(verdict["status"], "acknowledged")
		self.assertEqual(
			frappe.db.get_value("Work Instruction", job.name, "status"),
			instructions.ACKNOWLEDGED,
		)

	def test_a_question_about_a_write_is_refused_rather_than_approving_it(self):
		"""The dangerous half of a third button: `ASK` pointed at a proposal must
		not fall through to approval."""
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
		action.db_set("owner", IVAN, update_modified=False)
		frappe.db.commit()

		verdict = self.answer(f"ASK {action.name}")

		self.assertEqual(verdict["status"], "not_askable")
		self.assertEqual(
			frappe.db.get_value("Pending Action", action.name, "status"), "Pending"
		)

	def test_somebody_elses_job_cannot_be_asked_about_either(self):
		job = self.open_job(employee=PLANNER)

		verdict = self.answer(f"ASK {job.name}", user=IVAN)

		self.assertEqual(verdict["status"], "unknown")


class TestWhatsAppTravelsTheSamePath(_FlowTestCase):
	def test_a_button_press_from_whatsapp_confirms_the_same_row(self):
		self.link(external_id="77009990001", user=PLANNER, channel=gateway.WHATSAPP)
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

		parsed = whatsapp.parse_inbound_messages(
			{
				"entry": [
					{
						"changes": [
							{
								"value": {
									"messages": [
										{
											"from": "77009990001",
											"id": "wamid.press",
											"type": "interactive",
											"interactive": {
												"button_reply": {
													"id": f"confirm:{action.name}",
													"title": "Подтвердить",
												}
											},
										}
									]
								}
							}
						]
					}
				]
			}
		)[0]

		frappe.set_user(PLANNER)
		try:
			verdict = confirmation.handle(PLANNER, None, parsed["text"])
		finally:
			frappe.set_user("Administrator")

		self.assertEqual(verdict["status"], "approved")
		self.assertEqual(
			frappe.db.get_value("Pending Action", action.name, "status"), "Approved"
		)
