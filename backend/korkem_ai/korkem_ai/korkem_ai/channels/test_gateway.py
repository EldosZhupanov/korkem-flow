# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""One brain, several channels.

The claim under test is that a message arriving from Telegram or WhatsApp is
answered by the *same* assistant the app talks to — same tools, same company
scoping, same permissions — and that it can only do so once somebody has said
who is writing.
"""

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai.channels import confirmation, gateway
from korkem_ai.korkem_ai.doctype.channel_identity import channel_identity as identities

PLANNER = "korkem.planner@example.com"
VIEWER = "korkem.viewer@example.com"


def _message(channel=gateway.TELEGRAM, external_id="777001", text="Что на производстве?", message_id="m-1"):
	return gateway.InboundMessage(
		channel=channel,
		external_id=external_id,
		chat_id=external_id,
		text=text,
		message_id=message_id,
		sender_name="Иван",
	)


class _GatewayTestCase(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		from korkem_manufacturing import seed_demo

		seed_demo.seed_users()
		self._clean()
		self.sent = []
		patcher = patch(
			"korkem_ai.korkem_ai.channels.gateway.deliver",
			side_effect=lambda channel, chat_id, text, confirm_for=None, ask=False: self.sent.append(
				(channel, chat_id, text)
			),
		)
		patcher.start()
		self.addCleanup(patcher.stop)
		self.addCleanup(self._clean)

	def _clean(self):
		frappe.set_user("Administrator")
		for doctype in ("Agent Conversation Message", "Agent Conversation", "Channel Identity"):
			for name in frappe.get_all(doctype, pluck="name"):
				frappe.delete_doc(doctype, name, force=1, ignore_permissions=True)
		frappe.db.commit()

	def link(self, external_id="777001", user=PLANNER, channel=gateway.TELEGRAM):
		identity = identities.observe(channel, external_id, "Иван")
		identity.db_set("user", user)
		return identity


class TestAnUnknownSenderIsNotTrusted(_GatewayTestCase):
	def test_a_message_from_nobody_never_reaches_the_assistant(self):
		with patch("frappe.enqueue") as enqueued:
			result = gateway.accept(_message())

		self.assertEqual(result["status"], "unlinked")
		self.assertNotIn(
			"korkem_ai.korkem_ai.channels.gateway.run_turn_job",
			[call.args[0] for call in enqueued.call_args_list],
		)

	def test_the_sender_is_recorded_so_somebody_can_link_them(self):
		gateway.accept(_message())

		identity = identities.find(gateway.TELEGRAM, "777001")
		self.assertIsNotNone(identity)
		self.assertIsNone(identity.user, "an unknown sender was given a user")
		self.assertEqual(identity.display_name, "Иван")

	def test_a_linked_customer_now_reaches_the_assistant(self):
		"""Phase 29. Until every customer-reachable tool pinned its reads to the
		session's own customer, the safe answer for a customer on a channel was
		the sales router. Now they are answered by the same brain as everybody
		else — with three tools instead of thirty-nine."""
		from korkem_ai.korkem_ai import customer_access
		from korkem_ai.korkem_ai.tools import policy, registry

		email = "korkem.client@example.com"
		if not frappe.db.exists("User", email):
			frappe.get_doc(
				{"doctype": "User", "email": email, "first_name": "Клиент", "send_welcome_email": 0}
			).insert(ignore_permissions=True)
			self.addCleanup(
				lambda: frappe.delete_doc("User", email, force=True, ignore_permissions=True)
			)
		customer_access.link(email, "Мебель Астана")
		# The turn below leaves the session as the customer — that is what
		# running as a person means — and cleanups run last-registered-first, so
		# this one has to put the session back before the unlink needs it.
		self.addCleanup(customer_access.unlink, email, "Мебель Астана")
		self.addCleanup(frappe.set_user, "Administrator")
		self.link(external_id="777900", user=email)
		seen = {}

		def capture(history, provider=None, **kwargs):
			seen["user"] = frappe.session.user
			seen["role"] = policy.role_of()
			seen["tools"] = {spec.name for spec in registry.available_to()}

			class _Result:
				status = "ok"
				text = "Ваш заказ в работе."

			return _Result()

		with patch("korkem_ai.korkem_ai.agent.loop.run_turn", side_effect=capture), patch(
			"korkem_ai.korkem_ai.orchestrator.llm.resolve", return_value=None
		):
			message = _message(external_id="777900", text="Где мой заказ?")
			conversation = gateway.conversation_for(message, email)
			gateway.run_turn_job(
				conversation.name, email, message.text, gateway.TELEGRAM, "777900"
			)

		self.assertEqual(seen["user"], email)
		self.assertEqual(seen["role"], policy.CUSTOMER)
		self.assertTrue(seen["tools"] <= policy.CUSTOMER_ALLOWED)
		self.assertEqual(self.sent[-1][2], "Ваш заказ в работе.")

	def test_an_unknown_sender_goes_to_the_sales_path_not_the_assistant(self):
		"""An unknown number is usually a customer, and the sales path already
		knows what to do with one. The assistant must not run for them: with no
		user there is no company, and every tool would refuse."""
		with patch("frappe.enqueue") as enqueued, patch(
			"frappe.db.get_single_value", return_value=1
		):
			gateway.accept(_message())

		queued = [call.args[0] for call in enqueued.call_args_list]
		self.assertIn("korkem_ai.korkem_ai.orchestrator.router.handle_message", queued)
		self.assertNotIn("korkem_ai.korkem_ai.channels.gateway.run_turn_job", queued)

	def test_a_disabled_identity_speaks_for_nobody(self):
		identity = self.link()
		identity.db_set("enabled", 0)

		with patch("frappe.enqueue") as enqueued:
			result = gateway.accept(_message(message_id="m-2"))

		self.assertEqual(result["status"], "unlinked")
		self.assertNotIn(
			"korkem_ai.korkem_ai.channels.gateway.run_turn_job",
			[call.args[0] for call in enqueued.call_args_list],
		)

	def test_a_disabled_user_speaks_for_nobody(self):
		self.link()
		frappe.db.set_value("User", PLANNER, "enabled", 0)
		self.addCleanup(frappe.db.set_value, "User", PLANNER, "enabled", 1)

		self.assertIsNone(identities.speaker_for(identities.find(gateway.TELEGRAM, "777001")))


class TestALinkedSenderReachesTheAssistant(_GatewayTestCase):
	def test_the_turn_is_queued_as_that_user(self):
		self.link()

		with patch("frappe.enqueue") as enqueued:
			result = gateway.accept(_message())

		self.assertEqual(result["status"], "queued")
		self.assertEqual(result["user"], PLANNER)
		self.assertEqual(enqueued.call_args.kwargs["user"], PLANNER)
		self.assertEqual(
			enqueued.call_args.args[0], "korkem_ai.korkem_ai.channels.gateway.run_turn_job"
		)

	def test_the_message_is_written_down_before_anything_runs(self):
		self.link()

		with patch("frappe.enqueue"):
			result = gateway.accept(_message())

		rows = frappe.get_all(
			"Agent Conversation Message",
			filters={"conversation": result["conversation"]},
			fields=["sender", "content", "external_message_id"],
		)
		self.assertEqual(len(rows), 1)
		self.assertEqual(rows[0]["sender"], "User")
		self.assertEqual(rows[0]["external_message_id"], "m-1")

	def test_a_second_message_joins_the_same_conversation(self):
		self.link()

		with patch("frappe.enqueue"):
			first = gateway.accept(_message(message_id="m-1"))
			second = gateway.accept(_message(message_id="m-2", text="А сроки?"))

		self.assertEqual(first["conversation"], second["conversation"])

	def test_whatsapp_reaches_the_same_assistant_as_telegram(self):
		"""The point of the phase. Both channels queue the same job."""
		self.link(external_id="77001234567", channel=gateway.WHATSAPP)

		with patch("frappe.enqueue") as enqueued:
			gateway.accept(
				_message(channel=gateway.WHATSAPP, external_id="77001234567", message_id="w-1")
			)

		self.assertEqual(
			enqueued.call_args.args[0], "korkem_ai.korkem_ai.channels.gateway.run_turn_job"
		)


class TestARetriedWebhookIsDropped(_GatewayTestCase):
	def test_the_same_provider_message_runs_once(self):
		self.link()

		with patch("frappe.enqueue") as enqueued:
			first = gateway.accept(_message(message_id="m-dup"))
			second = gateway.accept(_message(message_id="m-dup"))

		self.assertEqual(first["status"], "queued")
		self.assertEqual(second["status"], "duplicate")
		self.assertEqual(enqueued.call_count, 1)

	def test_it_is_not_written_down_twice(self):
		self.link()

		with patch("frappe.enqueue"):
			gateway.accept(_message(message_id="m-dup"))
			gateway.accept(_message(message_id="m-dup"))

		self.assertEqual(
			frappe.db.count("Agent Conversation Message", {"external_message_id": "m-dup"}), 1
		)

	def test_the_same_id_on_another_channel_is_a_different_message(self):
		self.link()
		self.link(external_id="77001234567", channel=gateway.WHATSAPP)

		with patch("frappe.enqueue") as enqueued:
			gateway.accept(_message(message_id="shared"))
			gateway.accept(
				_message(channel=gateway.WHATSAPP, external_id="77001234567", message_id="shared")
			)

		self.assertEqual(enqueued.call_count, 2)


class TestTheTurnRunsAsThePerson(_GatewayTestCase):
	def test_the_tools_see_that_users_company_not_administrators(self):
		"""The keystone. A webhook is Guest, which resolves to no company at
		all — so the turn has to become somebody before the assistant runs."""
		self.link()
		seen = {}

		def capture(history, provider=None, **kwargs):
			from korkem_ai.korkem_ai.tools import scope

			seen["user"] = frappe.session.user
			seen["company"] = scope.current_company()

			class _Result:
				status = "ok"
				text = "готово"

			return _Result()

		with patch("korkem_ai.korkem_ai.agent.loop.run_turn", side_effect=capture), patch(
			"korkem_ai.korkem_ai.orchestrator.llm.resolve", return_value=None
		):
			conversation = gateway.conversation_for(_message(), PLANNER)
			gateway.run_turn_job(conversation.name, PLANNER, "текст", gateway.TELEGRAM, "777001")

		self.assertEqual(seen["user"], PLANNER)
		self.assertEqual(seen["company"], "KORKEM")

	def test_the_answer_goes_back_out_and_is_written_down(self):
		self.link()

		class _Result:
			status = "ok"
			text = "Шесть из десяти готово."

		with patch("korkem_ai.korkem_ai.agent.loop.run_turn", return_value=_Result()), patch(
			"korkem_ai.korkem_ai.orchestrator.llm.resolve", return_value=None
		):
			conversation = gateway.conversation_for(_message(), PLANNER)
			gateway.run_turn_job(conversation.name, PLANNER, "текст", gateway.TELEGRAM, "777001")

		self.assertEqual(self.sent[-1][2], "Шесть из десяти готово.")
		frappe.set_user("Administrator")
		last = frappe.get_all(
			"Agent Conversation Message",
			filters={"conversation": conversation.name, "sender": "Agent"},
			fields=["content"],
		)
		self.assertEqual(last[-1]["content"], "Шесть из десяти готово.")

	def test_a_write_is_not_performed_without_a_yes(self):
		"""A tool needing confirmation stops the turn and asks. Nothing runs
		until somebody answers — which they can now do here rather than having
		to open the app."""
		self.link()

		class _Result:
			status = "needs_confirmation"
			text = "Остановить производство?"
			pending = ()

		with patch("korkem_ai.korkem_ai.agent.loop.run_turn", return_value=_Result()), patch(
			"korkem_ai.korkem_ai.orchestrator.llm.resolve", return_value=None
		):
			conversation = gateway.conversation_for(_message(), PLANNER)
			gateway.run_turn_job(conversation.name, PLANNER, "останови", gateway.TELEGRAM, "777001")

		self.assertIn("Остановить производство?", self.sent[-1][2])

	def test_a_failed_turn_answers_rather_than_going_silent(self):
		self.link()

		with patch(
			"korkem_ai.korkem_ai.agent.loop.run_turn", side_effect=RuntimeError("boom")
		), patch("korkem_ai.korkem_ai.orchestrator.llm.resolve", return_value=None):
			conversation = gateway.conversation_for(_message(), PLANNER)
			gateway.run_turn_job(conversation.name, PLANNER, "текст", gateway.TELEGRAM, "777001")

		self.assertTrue(self.sent, "the person was left with no answer at all")


class TestAProposalIsWrittenDownOnAChannelToo(_GatewayTestCase):
	"""The defect this phase found: approval was implemented and tested, and
	*proposal* was not. A foreman was shown a sentence describing a write and
	given nothing to confirm, because the row the confirmation layer resolves
	against had never been written on this path."""

	def setUp(self):
		super().setUp()
		frappe.set_user("Administrator")
		for name in frappe.get_all("Pending Action", pluck="name"):
			frappe.delete_doc("Pending Action", name, force=True, ignore_permissions=True)
		frappe.db.commit()

	def _propose(self):
		from korkem_ai.korkem_ai.orchestrator.protocol import AIToolCall

		class _Result:
			status = "needs_confirmation"
			text = "Остановить производство?"
			pending = (
				AIToolCall(
					id="provider-made-this-up",
					name="manufacturing.stop_production",
					arguments={"sales_order": "SAL-ORD-2026-00001", "action": "остановить"},
				),
			)

		self.link()
		with patch(
			"korkem_ai.korkem_ai.agent.loop.run_turn", return_value=_Result()
		), patch("korkem_ai.korkem_ai.orchestrator.llm.resolve", return_value=None):
			conversation = gateway.conversation_for(_message(), PLANNER)
			gateway.run_turn_job(
				conversation.name, PLANNER, "останови", gateway.TELEGRAM, "777001"
			)
		return conversation

	def test_the_row_exists_and_belongs_to_the_person_who_asked(self):
		conversation = self._propose()

		rows = frappe.get_all(
			"Pending Action",
			filters={"conversation": conversation.name},
			fields=["name", "tool", "owner", "status"],
		)
		self.assertEqual(len(rows), 1)
		self.assertEqual(rows[0]["tool"], "manufacturing.stop_production")
		self.assertEqual(rows[0]["owner"], PLANNER)
		self.assertEqual(rows[0]["status"], "Pending")

	def test_the_name_is_ours_not_the_providers(self):
		"""Providers mint their own call ids and change them between requests."""
		conversation = self._propose()

		name = frappe.get_all(
			"Pending Action", filters={"conversation": conversation.name}, pluck="name"
		)[0]
		self.assertNotEqual(name, "provider-made-this-up")

	def test_the_person_is_given_something_they_can_actually_confirm(self):
		conversation = self._propose()

		name = frappe.get_all(
			"Pending Action", filters={"conversation": conversation.name}, pluck="name"
		)[0]
		frappe.set_user(PLANNER)
		try:
			waiting = confirmation.waiting_for(PLANNER, conversation.name)
		finally:
			frappe.set_user("Administrator")
		self.assertEqual([row["name"] for row in waiting], [name])

	def test_the_arguments_recorded_are_the_ones_proposed(self):
		conversation = self._propose()

		row = frappe.get_all(
			"Pending Action",
			filters={"conversation": conversation.name},
			fields=["action_data"],
		)[0]
		self.assertEqual(
			frappe.parse_json(row["action_data"])["sales_order"], "SAL-ORD-2026-00001"
		)


class TestAChannelMayNarrowARole(_GatewayTestCase):
	def test_an_identity_pinned_to_customer_reaches_a_customers_tools(self):
		"""The pin has to reach `role_of`, or it is a label on a report rather
		than a boundary — the registry, the scope and the system instruction all
		ask that function and none of them can see a gateway argument."""
		from korkem_ai.korkem_ai.tools import policy, registry

		self.link()
		seen = {}

		def capture(history, provider=None, **kwargs):
			seen["role"] = policy.role_of()
			seen["tools"] = {spec.name for spec in registry.available_to()}

			class _Result:
				status = "ok"
				text = "ок"

			return _Result()

		with patch("korkem_ai.korkem_ai.agent.loop.run_turn", side_effect=capture), patch(
			"korkem_ai.korkem_ai.orchestrator.llm.resolve", return_value=None
		):
			conversation = gateway.conversation_for(_message(), PLANNER)
			gateway.run_turn_job(
				conversation.name,
				PLANNER,
				"что на производстве?",
				gateway.TELEGRAM,
				"777001",
				channel_role=policy.CUSTOMER,
			)

		self.assertEqual(seen["role"], policy.CUSTOMER)
		self.assertNotIn("manufacturing.stop_production", seen["tools"])

	def test_a_pin_can_never_promote(self):
		from korkem_ai.korkem_ai.tools import policy

		self.assertEqual(policy.effective_role(PLANNER, policy.ADMIN), policy.EMPLOYEE)


class TestIdentityIsMatchedExactly(_GatewayTestCase):
	def test_two_channels_do_not_share_an_identity(self):
		self.link(external_id="777001", channel=gateway.TELEGRAM)

		self.assertIsNone(identities.find(gateway.WHATSAPP, "777001"))

	def test_the_same_identity_cannot_be_recorded_twice(self):
		identities.observe(gateway.TELEGRAM, "777001")

		with self.assertRaises(frappe.ValidationError):
			frappe.get_doc(
				{
					"doctype": "Channel Identity",
					"channel": gateway.TELEGRAM,
					"external_id": "777001",
				}
			).insert(ignore_permissions=True)

	def test_a_name_is_never_used_to_match(self):
		"""Display name is shown to an administrator and used for nothing else —
		anyone can set their own name in a chat app."""
		identities.observe(gateway.TELEGRAM, "777001", "Иван")

		self.assertIsNone(identities.find(gateway.TELEGRAM, "Иван"))
