# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Handing work to a person, and finding out whether they took it.

Two claims are under test. An instruction never crosses a company — not the
employee, not the order, not the job. And answering one is exactly once: a
double-tapped button, a re-delivered webhook and a second «принял» all leave the
same row in the same state.
"""

from unittest.mock import patch

import frappe

from korkem_ai.korkem_ai.tools import foreign_fixture
from frappe.tests import IntegrationTestCase
from frappe.utils import add_days, nowdate

from korkem_ai.korkem_ai.channels import confirmation
from korkem_ai.korkem_ai.doctype.work_instruction import work_instruction as instructions
from korkem_ai.korkem_ai.tools import catalog, dispatch, registry  # noqa: F401

MANAGER = "korkem.manager@example.com"
IVAN = "korkem.ivan@example.com"
PLANNER = "korkem.planner@example.com"
VIEWER = "korkem.viewer@example.com"


class _DispatchTestCase(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		from korkem_manufacturing import seed_demo

		seed_demo.seed_users()
		self._clean()
		self.sent = []
		patcher = patch(
			"korkem_ai.korkem_ai.channels.gateway.deliver",
			side_effect=lambda channel, chat_id, text, confirm_for=None, ask=False: self.sent.append(
				{
					"channel": channel,
					"chat_id": chat_id,
					"text": text,
					"confirm_for": confirm_for,
					"ask": ask,
				}
			),
		)
		patcher.start()
		self.addCleanup(patcher.stop)
		self.addCleanup(self._clean)
		self.addCleanup(frappe.set_user, "Administrator")

	def _clean(self):
		frappe.set_user("Administrator")
		for name in frappe.get_all("Work Instruction", pluck="name"):
			frappe.delete_doc("Work Instruction", name, force=True, ignore_permissions=True)
		for name in frappe.get_all(
			"Channel Identity", filters={"external_id": ["like", "29%"]}, pluck="name"
		):
			frappe.delete_doc("Channel Identity", name, force=True, ignore_permissions=True)
		frappe.db.commit()

	def order(self):
		"""A submitted order **of this company**.

		The company filter is not decoration. Without it this returned the
		first submitted order on the bench, whichever company it belonged to,
		and the moment a second company existed sixteen tests in this file
		started asserting against a document the dispatcher is supposed to
		refuse. They did not fail honestly either — they errored on the refusal,
		so the output pointed at the dispatcher instead of at the fixture."""
		return frappe.get_all(
			"Sales Order", filters={"docstatus": 1, "company": "KORKEM"}, pluck="name"
		)[0]

	def link_ivan(self, external_id="290001"):
		from korkem_ai.korkem_ai.doctype.channel_identity import channel_identity as identities

		identity = identities.observe("Telegram", external_id, "Иван")
		identity.db_set("user", IVAN)
		return identity

	def as_manager(self, tool, args):
		frappe.set_user(MANAGER)
		try:
			return registry.execute(tool, args)
		finally:
			frappe.set_user("Administrator")

	def assign(self, **kwargs):
		payload = {"employee": "Иван", "instruction": "Закончить раскрой"}
		payload.update(kwargs)
		return self.as_manager("dispatch.assign_work", payload)


class TestGivingSomebodyWork(foreign_fixture.UsesForeignCompany, _DispatchTestCase):
	def test_it_records_who_was_told_what(self):
		result = self.assign(sales_order=self.order(), due_date=add_days(nowdate(), 3))

		self.assertTrue(result["ok"], result.get("error"))
		doc = frappe.get_doc("Work Instruction", result["data"]["instruction"])
		self.assertEqual(doc.employee_user, IVAN)
		self.assertEqual(doc.company, "KORKEM")
		self.assertEqual(doc.owner, MANAGER)
		self.assertEqual(doc.instruction, "Закончить раскрой")

	def test_it_reaches_them_on_the_channel_they_are_linked_on(self):
		identity = self.link_ivan()

		result = self.assign(sales_order=self.order())

		self.assertTrue(self.sent, "nothing was sent")
		self.assertEqual(self.sent[-1]["channel"], "Telegram")
		self.assertEqual(self.sent[-1]["chat_id"], identity.external_id)
		self.assertEqual(result["data"]["delivery"]["delivered"], True)
		self.assertEqual(
			frappe.db.get_value("Work Instruction", result["data"]["instruction"], "status"),
			instructions.SENT,
		)

	def test_the_message_carries_the_buttons_that_answer_it(self):
		"""The same protocol a proposal uses — one set of buttons, two kinds of
		thing they can be about."""
		self.link_ivan()

		result = self.assign()

		self.assertEqual(self.sent[-1]["confirm_for"], result["data"]["instruction"])

	def test_being_given_work_offers_the_third_answer(self):
		"""A job can be answered with a question; a write cannot."""
		self.link_ivan()

		self.assign()

		self.assertTrue(self.sent[-1]["ask"])

	def test_it_names_the_order_and_the_customer_in_the_message(self):
		self.link_ivan()
		order = self.order()

		self.assign(sales_order=order)

		self.assertIn(order, self.sent[-1]["text"])
		self.assertIn(frappe.db.get_value("Sales Order", order, "customer"), self.sent[-1]["text"])

	def test_somebody_with_no_channel_is_still_recorded(self):
		"""The decision was made. That it could not be delivered is a fact about
		the delivery, not a reason to forget it."""
		result = self.assign()

		self.assertTrue(result["ok"])
		self.assertFalse(result["data"]["delivery"]["delivered"])
		self.assertEqual(
			frappe.db.get_value("Work Instruction", result["data"]["instruction"], "status"),
			instructions.DRAFT,
		)

	def test_an_unknown_employee_is_refused_with_the_real_ones_listed(self):
		result = self.assign(employee="Иванов Иван Иванович из Твери")

		self.assertEqual(result["data"]["status"], "not_found")
		self.assertTrue(result["data"]["candidates"])
		self.assertEqual(frappe.db.count("Work Instruction"), 0)

	def test_an_ambiguous_name_is_never_guessed(self):
		result = self.assign(employee="korkem")

		self.assertEqual(result["data"]["status"], "ambiguous")
		self.assertGreater(len(result["data"]["candidates"]), 1)
		self.assertEqual(frappe.db.count("Work Instruction"), 0)

	def test_an_order_from_another_company_is_not_found(self):
		frappe.set_user("Administrator")
		foreign = foreign_fixture.ensure()["sales_order"]

		result = self.assign(sales_order=foreign)

		self.assertFalse(result["ok"])
		self.assertEqual(frappe.db.count("Work Instruction"), 0)

	def test_a_second_instruction_updates_the_open_one(self):
		"""«Тогда сделай завтра до 12:00» is the same job with a new deadline.
		Two live cards for one piece of work is how it gets done twice."""
		first = self.assign(instruction="Закончить раскрой сегодня")

		second = self.assign(instruction="Тогда завтра до 12:00", due_date=add_days(nowdate(), 1))

		self.assertEqual(second["data"]["status"], "updated")
		self.assertEqual(second["data"]["instruction"], first["data"]["instruction"])
		self.assertEqual(frappe.db.count("Work Instruction"), 1)
		self.assertEqual(
			frappe.db.get_value("Work Instruction", first["data"]["instruction"], "instruction"),
			"Тогда завтра до 12:00",
		)

	def test_an_answered_instruction_is_never_rewritten(self):
		"""Changing what somebody already agreed to would rewrite their answer."""
		first = self.assign(instruction="Закончить раскрой")
		frappe.db.set_value(
			"Work Instruction", first["data"]["instruction"], "status", instructions.ACKNOWLEDGED
		)

		second = self.assign(instruction="Другое задание")

		self.assertEqual(second["data"]["status"], "assigned")
		self.assertNotEqual(second["data"]["instruction"], first["data"]["instruction"])

	def test_the_summary_says_who_and_what_before_anybody_agrees(self):
		frappe.set_user(MANAGER)
		try:
			summary = dispatch.summarise_assignment(
				employee="Иван", instruction="Закончить раскрой", sales_order=self.order()
			)
		finally:
			frappe.set_user("Administrator")

		self.assertIn("Иван", summary)
		self.assertIn("Закончить раскрой", summary)



class TestWhoMayDispatch(foreign_fixture.UsesForeignCompany, _DispatchTestCase):
	def test_a_shop_floor_user_may_not(self):
		"""ERPNext's own permission, not a second opinion in the policy file:
		`Work Instruction` grants create to Manufacturing Manager."""
		frappe.set_user(PLANNER)
		try:
			result = registry.execute(
				"dispatch.assign_work", {"employee": "Иван", "instruction": "сделай"}
			)
		finally:
			frappe.set_user("Administrator")

		self.assertFalse(result["ok"])
		self.assertEqual(result["error"]["code"], "permission_denied")
		self.assertEqual(frappe.db.count("Work Instruction"), 0)

	def test_an_employee_of_another_company_cannot_be_sent_work(self):
		"""Company membership is a `User Permission` on Company — ERPNext's own
		way of saying it, and the same one `scope.current_company` reads."""
		email = "korkem.elsewhere@example.com"
		other = foreign_fixture.ensure()["company"]
		if not frappe.db.exists("User", email):
			frappe.get_doc(
				{
					"doctype": "User",
					"email": email,
					"first_name": "Чужой",
					"send_welcome_email": 0,
					"roles": [{"role": "Manufacturing User"}],
				}
			).insert(ignore_permissions=True)
		permission = frappe.get_doc(
			{"doctype": "User Permission", "user": email, "allow": "Company", "for_value": other}
		).insert(ignore_permissions=True)
		self.addCleanup(
			lambda: frappe.delete_doc("User", email, force=True, ignore_permissions=True)
		)
		self.addCleanup(
			lambda: frappe.delete_doc(
				"User Permission", permission.name, force=True, ignore_permissions=True
			)
		)

		result = self.assign(employee="Чужой")

		self.assertEqual(result["data"]["status"], "not_found")
		self.assertEqual(frappe.db.count("Work Instruction"), 0)

	def test_saying_you_are_the_manager_does_not_make_you_one(self):
		from korkem_ai.korkem_ai.tools import policy

		frappe.set_user(PLANNER)
		try:
			self.assertEqual(policy.role_of(), policy.EMPLOYEE)
		finally:
			frappe.set_user("Administrator")


class TestAnsweringAnInstruction(_DispatchTestCase):
	def open_one(self):
		self.link_ivan()
		result = self.assign(sales_order=self.order())
		return result["data"]["instruction"]

	def as_ivan(self, text, conversation=None):
		frappe.set_user(IVAN)
		try:
			return confirmation.handle(IVAN, conversation, text)
		finally:
			frappe.set_user("Administrator")

	def test_a_bare_accept_takes_the_one_job_waiting(self):
		name = self.open_one()

		verdict = self.as_ivan("Принял")

		self.assertEqual(verdict["status"], "acknowledged")
		doc = frappe.get_doc("Work Instruction", name)
		self.assertEqual(doc.status, instructions.ACKNOWLEDGED)
		self.assertTrue(doc.acknowledged_at)

	def test_a_button_press_answers_the_job_it_names(self):
		name = self.open_one()

		verdict = self.as_ivan(f"CONFIRM {name}")

		self.assertEqual(verdict["status"], "acknowledged")

	def test_refusing_records_the_reason_in_their_own_words(self):
		name = self.open_one()

		verdict = self.as_ivan("Не могу")

		self.assertEqual(verdict["status"], "rejected")
		doc = frappe.get_doc("Work Instruction", name)
		self.assertEqual(doc.status, instructions.REJECTED)
		self.assertIn("Не могу", doc.response)

	def test_answering_twice_changes_nothing(self):
		name = self.open_one()
		self.as_ivan("Принял")
		first = frappe.db.get_value("Work Instruction", name, "acknowledged_at")

		verdict = self.as_ivan("Принял")

		self.assertEqual(verdict["status"], "already_answered")
		self.assertEqual(
			frappe.db.get_value("Work Instruction", name, "acknowledged_at"), first
		)

	def test_a_rejection_cannot_be_turned_into_an_acceptance(self):
		name = self.open_one()
		self.as_ivan("Не могу")

		verdict = self.as_ivan("Принял")

		self.assertEqual(verdict["status"], "already_answered")
		self.assertEqual(
			frappe.db.get_value("Work Instruction", name, "status"), instructions.REJECTED
		)

	def test_somebody_elses_job_is_refused_in_the_words_of_absence(self):
		name = self.open_one()

		frappe.set_user(VIEWER)
		try:
			verdict = confirmation.handle(VIEWER, None, f"CONFIRM {name}")
		finally:
			frappe.set_user("Administrator")

		self.assertEqual(verdict["status"], "unknown")
		self.assertEqual(
			frappe.db.get_value("Work Instruction", name, "status"), instructions.SENT
		)

	def test_two_open_jobs_are_never_chosen_between(self):
		self.open_one()
		self.assign(instruction="И упаковать")

		verdict = self.as_ivan("Принял")

		self.assertEqual(verdict["status"], "ambiguous")
		self.assertEqual(
			frappe.db.count("Work Instruction", {"status": instructions.ACKNOWLEDGED}), 0
		)

	def test_an_ordinary_message_is_not_an_answer(self):
		self.open_one()

		self.assertIsNone(self.as_ivan("а сколько там всего штук?"))

	def test_nothing_waiting_is_said_plainly(self):
		verdict = self.as_ivan("Принял")

		self.assertEqual(verdict["status"], "nothing_pending")

	def test_a_second_press_of_a_button_that_worked_says_so(self):
		"""Not "нечего подтверждать" — that reads as though the first press was
		lost, which is the one thing a person must not be told after it worked."""
		self.open_one()
		self.as_ivan("Принял")

		verdict = self.as_ivan("Принял")

		self.assertEqual(verdict["status"], "already_answered")
		self.assertIn("уже принято", verdict["reply"])


class TestAnsweringFromTheApp(_DispatchTestCase):
	"""The app has no accept button — it confirms proposals, and an instruction
	is not one — so the same answer arrives through a tool. What must be true is
	that it reaches the same state machine."""

	def open_one(self):
		return self.assign(sales_order=self.order())["data"]["instruction"]

	def as_ivan(self, args):
		frappe.set_user(IVAN)
		try:
			return registry.execute("dispatch.respond_to_instruction", args)
		finally:
			frappe.set_user("Administrator")

	def test_accepting_marks_the_same_row_a_button_would(self):
		name = self.open_one()

		result = self.as_ivan({"result": "Принял"})

		self.assertTrue(result["ok"], result.get("error"))
		self.assertEqual(result["data"]["status"], "acknowledged")
		self.assertEqual(
			frappe.db.get_value("Work Instruction", name, "status"),
			instructions.ACKNOWLEDGED,
		)

	def test_refusing_is_read_before_accepting(self):
		"""«не могу принять» contains «принять». Of the two ways to be wrong,
		only one leaves a job nobody is doing."""
		name = self.open_one()

		result = self.as_ivan({"result": "Не могу принять, станок сломан"})

		self.assertEqual(result["data"]["status"], "rejected")
		self.assertEqual(
			frappe.db.get_value("Work Instruction", name, "status"), instructions.REJECTED
		)

	def test_answering_twice_from_the_app_changes_nothing(self):
		name = self.open_one()
		self.as_ivan({"result": "Принял"})
		first = frappe.db.get_value("Work Instruction", name, "acknowledged_at")

		result = self.as_ivan({"result": "Принял"})

		self.assertEqual(result["data"]["status"], "already_answered")
		self.assertEqual(
			frappe.db.get_value("Work Instruction", name, "acknowledged_at"), first
		)

	def test_two_open_jobs_are_never_chosen_between(self):
		self.open_one()
		self.assign(instruction="И упаковать")

		result = self.as_ivan({"result": "Принял"})

		self.assertEqual(result["data"]["status"], "ambiguous")
		self.assertEqual(
			frappe.db.count("Work Instruction", {"status": instructions.ACKNOWLEDGED}), 0
		)

	def test_an_unreadable_answer_is_asked_about_rather_than_guessed(self):
		self.open_one()

		result = self.as_ivan({"result": "хм"})

		self.assertEqual(result["data"]["status"], "unclear")

	def test_somebody_elses_job_is_not_theirs_to_answer(self):
		name = self.open_one()

		frappe.set_user(VIEWER)
		try:
			result = registry.execute(
				"dispatch.respond_to_instruction", {"result": "Принял", "instruction": name}
			)
		finally:
			frappe.set_user("Administrator")

		self.assertFalse(result["ok"])
		self.assertEqual(
			frappe.db.get_value("Work Instruction", name, "status"), instructions.DRAFT
		)

	def test_it_needs_confirming_like_any_other_write(self):
		self.assertTrue(registry.get("dispatch.respond_to_instruction").requires_confirmation)


class TestWhatTheManagerCanSee(_DispatchTestCase):
	def test_it_reports_what_has_been_answered_and_what_has_not(self):
		self.link_ivan()
		accepted = self.assign(instruction="Первое")["data"]["instruction"]
		# A *second* person, because a second instruction to the same employee
		# while the first is still open now updates it rather than duplicating —
		# see `test_a_second_instruction_updates_the_open_one`.
		self.assign(employee="Viewer", instruction="Второе")
		frappe.set_user(IVAN)
		try:
			confirmation.handle(IVAN, None, f"CONFIRM {accepted}")
		finally:
			frappe.set_user("Administrator")

		result = self.as_manager("dispatch.list_instructions", {})

		summary = result["data"]["summary"]
		self.assertEqual(summary["total"], 2)
		self.assertEqual(summary["acknowledged"], 1)
		self.assertEqual(summary["awaiting_acknowledgement"], 1)

	def test_it_can_be_narrowed_to_one_person(self):
		self.assign(instruction="Первое")

		result = self.as_manager("dispatch.list_instructions", {"employee": "Иван"})

		self.assertTrue(result["ok"], result.get("error"))
		self.assertTrue(all(row["employee_user"] == IVAN for row in result["data"]["instructions"]))

	def test_an_employee_sees_their_own_work(self):
		self.assign(instruction="Первое")

		frappe.set_user(IVAN)
		try:
			result = registry.execute("dispatch.list_instructions", {})
		finally:
			frappe.set_user("Administrator")

		self.assertTrue(result["ok"], result.get("error"))
		self.assertEqual(result["data"]["count"], 1)

	def test_an_employee_sees_only_their_own_work(self):
		"""A shop floor user holds read on the doctype — ERPNext has no way to
		say "only the rows addressed to you", because the field that would say
		so is not `owner`. So the tool draws that line, using ERPNext's own
		answer to who hands work out."""
		self.assign(instruction="Ивану")
		self.assign(employee="Viewer", instruction="Другому")

		frappe.set_user(IVAN)
		try:
			result = registry.execute("dispatch.list_instructions", {})
		finally:
			frappe.set_user("Administrator")

		self.assertEqual(
			{row["employee_user"] for row in result["data"]["instructions"]}, {IVAN}
		)

	def test_an_employee_cannot_ask_about_somebody_else(self):
		self.assign(employee="Viewer", instruction="Другому")

		frappe.set_user(IVAN)
		try:
			result = registry.execute(
				"dispatch.list_instructions", {"employee": "Viewer"}
			)
		finally:
			frappe.set_user("Administrator")

		self.assertEqual(result["data"]["instructions"], [])
