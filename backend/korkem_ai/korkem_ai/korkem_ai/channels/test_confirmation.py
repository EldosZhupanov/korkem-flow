# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Approving a write from a chat app.

The row being approved is the same `Pending Action` the app approves, by the
same method. What is new is resolving a chat reply to it, and refusing when it
is not this person's to approve — so that is what these tests are about, plus
the one thing that must never happen: a write running before somebody said yes.
"""

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase
from frappe.utils import add_to_date, now_datetime

from korkem_ai.korkem_ai.channels import confirmation, gateway
from korkem_ai.korkem_ai.doctype.channel_identity import channel_identity as identities
from korkem_ai.korkem_ai.tools import catalog, registry  # noqa: F401

PLANNER = "korkem.planner@example.com"
VIEWER = "korkem.viewer@example.com"
STOP = "manufacturing.stop_production"


class _ConfirmationTestCase(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		from korkem_manufacturing import seed_demo

		seed_demo.seed_users()
		self.job = frappe.get_all(
			"Work Order", filters={"company": "KORKEM", "docstatus": 1}, pluck="name"
		)[0]
		self._clean()
		self.sent = []
		patcher = patch(
			"korkem_ai.korkem_ai.channels.gateway.deliver",
			side_effect=lambda channel, chat_id, text, confirm_for=None, ask=False: self.sent.append(
				text
			),
		)
		patcher.start()
		self.addCleanup(patcher.stop)
		self.addCleanup(self._restart)
		self.addCleanup(self._clean)

	def _restart(self):
		frappe.set_user("Administrator")
		if frappe.db.get_value("Work Order", self.job, "status") == "Stopped":
			from erpnext.manufacturing.doctype.work_order.work_order import stop_unstop

			stop_unstop(self.job, "Resumed")
		frappe.db.commit()

	def _clean(self):
		frappe.set_user("Administrator")
		for doctype in ("Pending Action", "Agent Conversation Message", "Agent Conversation", "Channel Identity"):
			for name in frappe.get_all(doctype, pluck="name"):
				frappe.delete_doc(doctype, name, force=1, ignore_permissions=True)
		frappe.db.commit()

	def conversation(self, user=PLANNER, chat="777001"):
		message = gateway.InboundMessage(
			channel=gateway.TELEGRAM, external_id=chat, chat_id=chat, text="—", message_id=f"m-{chat}"
		)
		return gateway.conversation_for(message, user)

	def propose(self, user=PLANNER, conversation=None, action="останови"):
		"""A real proposal for a real tool, written the way the loop writes it."""
		frappe.set_user(user)
		doc = frappe.get_doc(
			{
				"doctype": "Pending Action",
				"conversation": conversation,
				"tool": STOP,
				"action_data": frappe.as_json({"work_order": self.job, "action": action}),
				"display_data": frappe.as_json({"summary": f"Остановить производство {self.job}"}),
				"status": "Pending",
				"expires_at": add_to_date(now_datetime(), hours=1),
			}
		)
		doc.insert(ignore_permissions=True)
		frappe.set_user("Administrator")
		return doc

	def status(self):
		frappe.set_user("Administrator")
		return frappe.db.get_value("Work Order", self.job, "status")

	def reply(self, conversation, text, user=PLANNER):
		"""Answer as the person answering.

		`handle` refuses to run as anybody other than the confirmer, so a test
		that helpfully switched back to Administrator to read a value has to
		switch back again — which is the point of the guard.
		"""
		frappe.set_user(user)
		try:
			return confirmation.handle(user, conversation, text)
		finally:
			frappe.set_user("Administrator")


class TestNothingRunsBeforeSomebodySaysYes(_ConfirmationTestCase):
	def test_a_proposal_changes_nothing(self):
		before = self.status()

		self.propose()

		self.assertEqual(self.status(), before)

	def test_the_person_is_asked_in_words_they_can_answer(self):
		action = self.propose()

		text = confirmation.describe(frappe.get_doc("Pending Action", action.name))

		self.assertIn("Подтвердить?", text)
		self.assertIn(action.name, text)

	def test_the_tools_internal_name_is_not_shown(self):
		action = self.propose()

		text = confirmation.describe(frappe.get_doc("Pending Action", action.name))

		self.assertNotIn(STOP, text)


class TestConfirmingFromAChat(_ConfirmationTestCase):
	def test_a_bare_yes_approves_the_one_waiting_action(self):
		conversation = self.conversation()
		action = self.propose(conversation=conversation.name)

		result = self.reply(conversation.name, "подтверждаю")

		self.assertEqual(result["status"], "approved")
		self.assertEqual(result["action"], action.name)
		self.assertEqual(self.status(), "Stopped")

	def test_an_explicit_reference_approves_it(self):
		conversation = self.conversation()
		action = self.propose(conversation=conversation.name)

		result = self.reply(conversation.name, f"CONFIRM {action.name}")

		self.assertEqual(result["status"], "approved")
		self.assertEqual(self.status(), "Stopped")

	def test_cancelling_runs_nothing(self):
		conversation = self.conversation()
		action = self.propose(conversation=conversation.name)
		before = self.status()

		result = self.reply(conversation.name, "отмена")

		self.assertEqual(result["status"], "cancelled")
		self.assertEqual(self.status(), before)
		frappe.set_user("Administrator")
		self.assertEqual(frappe.db.get_value("Pending Action", action.name, "status"), "Rejected")

	def test_an_ordinary_message_is_not_a_confirmation(self):
		conversation = self.conversation()
		self.propose(conversation=conversation.name)

		self.assertIsNone(self.reply(conversation.name, "Что на производстве?"))

	def test_with_nothing_waiting_a_yes_does_nothing(self):
		conversation = self.conversation()

		result = self.reply(conversation.name, "да")

		self.assertEqual(result["status"], "nothing_pending")


class TestAmbiguityIsRefused(_ConfirmationTestCase):
	def test_a_bare_yes_with_two_waiting_actions_refuses(self):
		"""Guessing here runs a write nobody asked for."""
		conversation = self.conversation()
		first = self.propose(conversation=conversation.name)
		second = self.propose(conversation=conversation.name)
		before = self.status()

		result = self.reply(conversation.name, "да")

		self.assertEqual(result["status"], "ambiguous")
		self.assertIn(first.name, result["reply"])
		self.assertIn(second.name, result["reply"])
		self.assertEqual(self.status(), before)

	def test_naming_one_of_them_resolves_it(self):
		conversation = self.conversation()
		first = self.propose(conversation=conversation.name)
		self.propose(conversation=conversation.name)

		result = self.reply(conversation.name, f"CONFIRM {first.name}")

		self.assertEqual(result["status"], "approved")
		frappe.set_user("Administrator")
		self.assertEqual(frappe.db.get_value("Pending Action", first.name, "status"), "Approved")


class TestItMustBeYourOwnAction(_ConfirmationTestCase):
	def test_another_persons_action_cannot_be_confirmed(self):
		conversation = self.conversation()
		action = self.propose(user=VIEWER, conversation=conversation.name)
		before = self.status()

		result = self.reply(conversation.name, f"CONFIRM {action.name}")

		self.assertEqual(result["status"], "unknown")
		self.assertEqual(self.status(), before)
		frappe.set_user("Administrator")
		self.assertEqual(frappe.db.get_value("Pending Action", action.name, "status"), "Pending")

	def test_it_is_refused_in_the_same_words_as_a_name_that_does_not_exist(self):
		"""Confirming that somebody else has an action pending is worth nothing
		to them and something to whoever is asking."""
		conversation = self.conversation()
		theirs = self.propose(user=VIEWER, conversation=conversation.name)

		mine = self.reply(conversation.name, f"CONFIRM {theirs.name}")
		nonsense = self.reply(conversation.name, "CONFIRM does-not-exist")

		self.assertEqual(mine["reply"], nonsense["reply"])

	def test_a_bare_yes_never_reaches_another_persons_action(self):
		conversation = self.conversation()
		self.propose(user=VIEWER, conversation=conversation.name)

		result = self.reply(conversation.name, "да")

		self.assertEqual(result["status"], "nothing_pending")


class TestTheAuditRecordsWhoActuallyApproved(_ConfirmationTestCase):
	def test_approving_is_stamped_with_the_person_who_did_it(self):
		"""`claim` stamps `resolved_by` from the session while ownership is
		checked against the caller's argument. A row recording one person
		approving another's action is a false audit trail."""
		conversation = self.conversation()
		action = self.propose(conversation=conversation.name)

		frappe.set_user(PLANNER)
		self.reply(conversation.name, "подтверждаю")

		frappe.set_user("Administrator")
		self.assertEqual(
			frappe.db.get_value("Pending Action", action.name, "resolved_by"), PLANNER
		)

	def test_handling_as_somebody_else_is_refused_outright(self):
		conversation = self.conversation()
		self.propose(conversation=conversation.name)
		frappe.set_user("Administrator")

		with self.assertRaises(frappe.ValidationError):
			confirmation.handle(PLANNER, conversation.name, "подтверждаю")


class TestConfirmingTwiceRunsOnce(_ConfirmationTestCase):
	def test_the_second_confirmation_executes_nothing(self):
		conversation = self.conversation()
		action = self.propose(conversation=conversation.name)
		self.reply(conversation.name, "подтверждаю")

		again = self.reply(conversation.name, f"CONFIRM {action.name}")

		self.assertEqual(again["status"], "already_resolved")
		self.assertIn("уже выполнено", again["reply"])

	def test_the_work_order_is_stopped_once_not_twice(self):
		conversation = self.conversation()
		action = self.propose(conversation=conversation.name)
		self.reply(conversation.name, "подтверждаю")
		frappe.set_user("Administrator")
		resolved_at = frappe.db.get_value("Pending Action", action.name, "resolved_at")

		self.reply(conversation.name, f"CONFIRM {action.name}")

		frappe.set_user("Administrator")
		self.assertEqual(self.status(), "Stopped")
		self.assertEqual(
			frappe.db.get_value("Pending Action", action.name, "resolved_at"), resolved_at
		)

	def test_confirming_after_a_cancel_runs_nothing(self):
		conversation = self.conversation()
		action = self.propose(conversation=conversation.name)
		self.reply(conversation.name, "отмена")
		before = self.status()

		result = self.reply(conversation.name, f"CONFIRM {action.name}")

		self.assertEqual(result["status"], "already_resolved")
		self.assertEqual(self.status(), before)

	def test_an_expired_action_is_refused(self):
		conversation = self.conversation()
		action = self.propose(conversation=conversation.name)
		frappe.set_user("Administrator")
		frappe.db.set_value(
			"Pending Action", action.name, "expires_at", add_to_date(now_datetime(), hours=-1)
		)
		before = self.status()

		result = self.reply(conversation.name, f"CONFIRM {action.name}")

		self.assertIn(result["status"], ("refused", "already_resolved"))
		self.assertEqual(self.status(), before)

	def test_an_expired_action_does_not_make_a_bare_yes_ambiguous(self):
		conversation = self.conversation()
		live = self.propose(conversation=conversation.name)
		stale = self.propose(conversation=conversation.name)
		frappe.set_user("Administrator")
		frappe.db.set_value(
			"Pending Action", stale.name, "expires_at", add_to_date(now_datetime(), hours=-1)
		)

		result = self.reply(conversation.name, "да")

		self.assertEqual(result["status"], "approved")
		self.assertEqual(result["action"], live.name)


class TestTheArgumentsAreWhatWasProposed(_ConfirmationTestCase):
	def test_approving_runs_exactly_the_recorded_tool_and_arguments(self):
		conversation = self.conversation()
		action = self.propose(conversation=conversation.name)

		self.reply(conversation.name, "подтверждаю")

		frappe.set_user("Administrator")
		row = frappe.get_doc("Pending Action", action.name)
		self.assertEqual(row.tool, STOP)
		self.assertEqual(frappe.parse_json(row.action_data)["work_order"], self.job)
		self.assertEqual(row.status, "Approved")


class TestTheWholeTurnFromAChannel(_ConfirmationTestCase):
	"""Proposal and approval, through the gateway, as a person would."""

	def link(self, chat="777001", user=PLANNER):
		identity = identities.observe(gateway.TELEGRAM, chat, "Иван")
		identity.db_set("user", user)
		return identity

	def test_a_proposal_is_written_down_and_attached_to_the_conversation(self):
		"""Phase 29 changed what this asserts, and the change is the point.

		The turn used to be handed a row somebody else had written; nothing on
		this path ever wrote one, so a proposal from a channel could not be
		confirmed at all. The gateway now records it, through the same recorder
		the app uses, and attaches *that* row to the thread."""
		from korkem_ai.korkem_ai.orchestrator.protocol import AIToolCall

		self.link()
		conversation = self.conversation()

		class _Result:
			status = "needs_confirmation"
			text = "Нашёл заказ."
			pending = (
				AIToolCall(
					id="provider-made-this-up",
					name="manufacturing.stop_production",
					arguments={"sales_order": "SAL-ORD-2026-00001", "action": "останови"},
				),
			)

		with patch("korkem_ai.korkem_ai.agent.loop.run_turn", return_value=_Result()), patch(
			"korkem_ai.korkem_ai.orchestrator.llm.resolve", return_value=None
		):
			gateway.run_turn_job(conversation.name, PLANNER, "останови", gateway.TELEGRAM, "777001")

		frappe.set_user("Administrator")
		rows = frappe.get_all(
			"Pending Action",
			filters={"conversation": conversation.name},
			fields=["name", "tool", "owner"],
		)
		self.assertEqual(len(rows), 1)
		self.assertEqual(rows[0]["tool"], "manufacturing.stop_production")
		self.assertEqual(rows[0]["owner"], PLANNER)
		self.assertNotEqual(rows[0]["name"], "provider-made-this-up")
		self.assertIn("Подтвердить?", self.sent[-1])

	def test_the_next_message_approves_it_without_the_model(self):
		self.link()
		conversation = self.conversation()
		self.propose(conversation=conversation.name)

		with patch("korkem_ai.korkem_ai.agent.loop.run_turn") as ran:
			gateway.run_turn_job(
				conversation.name, PLANNER, "подтверждаю", gateway.TELEGRAM, "777001"
			)

		ran.assert_not_called()
		self.assertEqual(self.status(), "Stopped")
		self.assertIn("выполнено", self.sent[-1])
