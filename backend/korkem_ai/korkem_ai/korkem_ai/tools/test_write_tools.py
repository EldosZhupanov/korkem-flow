# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""The first tool that changes anything, and everything that must stop it.

`crm.create_lead` is the whole safety chain made real: propose → persist →
confirm → execute exactly what was recorded → audit. Most of this file is
therefore about refusal — the interesting failures of a write tool are all the
ways it must decline to run.

No provider is contacted. The model is scripted, because a real one would
propose something different each run and the test would assert nothing.
"""

import json
from dataclasses import replace
from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai import chat
from korkem_ai.korkem_ai.orchestrator.protocol import AIResponse, AIToolCall
from korkem_ai.korkem_ai.tools import catalog, registry
from korkem_ai.korkem_ai.tools.registry import Risk

TOOL = "crm.create_lead"
MARK = "ZzTestLead"


class _Proposer:
	"""Proposes the write, then summarises — with a *different* provider call id
	each time, which is what Anthropic and OpenAI really do."""

	streams_natively = False
	model = "scripted-1"

	def __init__(self, arguments=None):
		self.arguments = arguments or {"first_name": MARK, "organization": "Zz LLC"}
		self.asks = 0

	def chat(self, system, messages, tools=()):
		if any(message.role == "tool" for message in messages):
			return AIResponse(text="Done.")
		self.asks += 1
		return AIResponse(
			text="I can do that.",
			tool_calls=(
				AIToolCall(
					id=f"provider-{self.asks}", name=TOOL, arguments=self.arguments
				),
			),
		)


class _WriteToolTestCase(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		self.previous_settings = {
			field: frappe.db.get_single_value("AI Settings", field)
			for field in ("enabled", "provider", "model")
		}
		# Direct confirmation validates the persisted configuration before the
		# scripted provider is patched in. Anthropic needs no stored test secret.
		frappe.db.set_single_value(
			"AI Settings", {"enabled": 1, "provider": "Anthropic", "model": "test-model"}
		)
		self.created_referral = not frappe.db.exists("CRM Lead Source", "Referral")
		if self.created_referral:
			frappe.get_doc(
				{"doctype": "CRM Lead Source", "source_name": "Referral"}
			).insert(ignore_permissions=True)
		self.created_new_lead = not frappe.db.exists("CRM Lead Status", "New Lead")
		if self.created_new_lead:
			frappe.get_doc(
				{"doctype": "CRM Lead Status", "lead_status": "New Lead"}
			).insert(ignore_permissions=True)
		self._clean()

	def tearDown(self):
		frappe.set_user("Administrator")
		frappe.db.rollback()
		self._clean()
		frappe.db.set_single_value("AI Settings", self.previous_settings)
		if self.created_referral and frappe.db.exists("CRM Lead Source", "Referral"):
			frappe.delete_doc(
				"CRM Lead Source", "Referral", force=True, ignore_permissions=True
			)
		if self.created_new_lead and frappe.db.exists("CRM Lead Status", "New Lead"):
			frappe.delete_doc(
				"CRM Lead Status", "New Lead", force=True, ignore_permissions=True
			)
		frappe.db.commit()

	def _clean(self):
		frappe.db.delete("CRM Lead", {"first_name": ("like", f"{MARK}%")})
		frappe.db.delete("Pending Action", {"tool": TOOL})
		frappe.db.commit()

	def leads(self):
		return frappe.db.count("CRM Lead", {"first_name": ("like", f"{MARK}%")})

	def run_turn(self, provider, approved=None):
		published = []

		def record(event, payload=None, user=None, **kwargs):
			if event == chat.STREAM_EVENT:
				published.append(payload)

		with (
			patch("korkem_ai.korkem_ai.chat.frappe.publish_realtime", side_effect=record),
			patch.object(chat.llm, "resolve", return_value=provider),
		):
			chat.run_turn_job(
				user=frappe.session.user,
				turn_id="t1",
				message=f"create a lead for {MARK}",
				history=[],
				approved_calls=approved or [],
			)
		return published

	def propose(self, provider=None):
		published = self.run_turn(provider or _Proposer())
		self.assertEqual(published[-1]["type"], "needs_confirmation")
		return published[-1]["calls"][0]


class TestNothingHappensUntilAHumanAgrees(_WriteToolTestCase):
	def test_the_tool_is_declared_as_a_write(self):
		spec = registry.get(TOOL)

		self.assertIs(spec.risk, Risk.WRITE)
		self.assertTrue(spec.requires_confirmation)
		self.assertEqual(spec.audit_category, "crm")

	def test_proposing_creates_no_lead(self):
		"""The assertion that matters: on the *database*, not on the report."""
		self.propose()

		self.assertEqual(self.leads(), 0, "a write ran before anyone approved it")

	def test_the_proposal_records_what_will_run_and_who_proposed_it(self):
		call = self.propose()
		action = frappe.get_doc("Pending Action", call["id"])

		self.assertEqual(action.tool, TOOL)
		self.assertEqual(action.status, "Pending")
		self.assertEqual(action.provider, "Anthropic")
		self.assertEqual(action.model, "scripted-1")
		self.assertEqual(frappe.parse_json(action.action_data)["first_name"], MARK)

	def test_confirming_creates_exactly_one_lead(self):
		provider = _Proposer()
		call = self.propose(provider)

		self.run_turn(provider, approved=[call["id"]])

		self.assertEqual(self.leads(), 1)
		row = frappe.get_last_doc("CRM Lead", filters={"first_name": MARK})
		self.assertEqual(row.organization, "Zz LLC")
		self.assertEqual(row.lead_owner, frappe.session.user)

	def test_the_model_is_not_asked_to_propose_again(self):
		provider = _Proposer()
		call = self.propose(provider)

		self.run_turn(provider, approved=[call["id"]])

		self.assertEqual(provider.asks, 1, "the model re-proposed after approval")


class TestReplayCannotCreateASecondLead(_WriteToolTestCase):
	"""The success criterion: one Pending Action, one CRM record, whatever the
	client sends afterwards."""

	def test_a_repeated_confirmation_is_refused_and_writes_nothing(self):
		provider = _Proposer()
		call = self.propose(provider)
		self.run_turn(provider, approved=[call["id"]])

		with self.assertRaises(frappe.ValidationError):
			chat.confirm(turn_id="t1", call_ids=[call["id"]], message="again")

		self.assertEqual(self.leads(), 1, "a replayed confirmation created a second lead")

	def test_two_simultaneous_claims_admit_exactly_one_winner(self):
		"""The race a plain status check cannot survive: two confirmations that
		both read `Pending` before either writes. Mutation-checked — replacing
		the conditional UPDATE with check-then-act makes both return True."""
		call = self.propose()

		first = frappe.get_doc("Pending Action", call["id"])
		second = frappe.get_doc("Pending Action", call["id"])

		self.assertEqual([first.claim(), second.claim()], [True, False])

	def test_approving_twice_directly_is_refused(self):
		provider = _Proposer()
		call = self.propose(provider)
		self.run_turn(provider, approved=[call["id"]])

		with self.assertRaises(frappe.ValidationError):
			frappe.get_doc("Pending Action", call["id"]).approve()

		self.assertEqual(self.leads(), 1)


class TestTheServerDecidesWhatRuns(_WriteToolTestCase):
	"""Nothing the client says about *what* to execute is trusted: it sends an
	id, and the server reads the tool and arguments off its own row."""

	def test_arguments_come_from_the_row_not_the_request(self):
		provider = _Proposer()
		call = self.propose(provider)

		# A client trying to substitute different arguments has nowhere to put
		# them — `confirm` takes ids only.
		chat.confirm(turn_id="t1", call_ids=[call["id"]], message="yes")
		frappe.db.rollback()

		action = frappe.get_doc("Pending Action", call["id"])
		self.assertEqual(frappe.parse_json(action.action_data)["first_name"], MARK)

	def test_another_users_confirmation_is_refused(self):
		call = self.propose()
		user = frappe.db.get_value(
			"User", {"name": ("not in", ("Administrator", "Guest")), "enabled": 1}, "name"
		)
		self.assertTrue(user, "the site needs a second user for this test")
		frappe.set_user(user)

		with self.assertRaises(frappe.ValidationError):
			chat.confirm(turn_id="t1", call_ids=[call["id"]], message="yes")

		self.assertEqual(self.leads(), 0)

	def test_an_invented_call_id_writes_nothing(self):
		with self.assertRaises(frappe.ValidationError):
			chat.confirm(turn_id="t1", call_ids=["made-up"], message="yes")

		self.assertEqual(self.leads(), 0)

	def test_an_expired_proposal_cannot_be_approved(self):
		call = self.propose()
		frappe.db.set_value(
			"Pending Action", call["id"], "expires_at", frappe.utils.add_to_date(None, hours=-1)
		)

		with self.assertRaises(frappe.ValidationError):
			frappe.get_doc("Pending Action", call["id"]).approve()

		self.assertEqual(self.leads(), 0)

	def test_a_rejected_proposal_cannot_then_be_approved(self):
		call = self.propose()
		chat.reject(call_ids=[call["id"]])

		with self.assertRaises(frappe.ValidationError):
			chat.confirm(turn_id="t1", call_ids=[call["id"]], message="yes")

		self.assertEqual(self.leads(), 0)


class TestPermissionFollowsRisk(_WriteToolTestCase):
	def test_a_write_needs_create_permission_not_merely_read(self):
		"""Every tool used to be checked against `read`. That was invisible
		while the catalogue was read-only, and would have let anyone who could
		*see* a lead have the assistant create one."""
		self.assertEqual(Risk.READ.permission_type, "read")
		self.assertEqual(Risk.WRITE.permission_type, "create")
		self.assertEqual(Risk.DESTRUCTIVE.permission_type, "delete")

	def test_a_user_without_create_permission_is_refused(self):
		with patch.object(
			registry.frappe, "has_permission", return_value=False
		):
			outcome = registry.execute(TOOL, {"first_name": MARK})

		self.assertFalse(outcome["ok"])
		self.assertEqual(outcome["error"]["code"], "permission_denied")
		self.assertIn("create", outcome["error"]["message"])
		self.assertEqual(self.leads(), 0)


class TestArgumentsAreValidatedBeforeAnythingRuns(_WriteToolTestCase):
	def test_a_missing_required_field_is_reported_not_guessed(self):
		outcome = registry.execute(TOOL, {"organization": "Zz LLC"})

		self.assertFalse(outcome["ok"])
		self.assertEqual(outcome["error"]["code"], "invalid_arguments")
		self.assertEqual(self.leads(), 0)

	def test_a_wrong_type_is_refused(self):
		outcome = registry.execute(TOOL, {"first_name": 42})

		self.assertEqual(outcome["error"]["code"], "invalid_arguments")

	def test_an_unknown_argument_is_refused_rather_than_ignored(self):
		"""Silently dropping it would let a model believe it set something it
		did not — and hide a schema drift from whoever added the field."""
		outcome = registry.execute(TOOL, {"first_name": MARK, "salary": 100})

		self.assertEqual(outcome["error"]["code"], "invalid_arguments")
		self.assertEqual(self.leads(), 0)

	def test_a_lead_cannot_be_opened_in_an_outcome_status(self):
		"""`Converted` is where a lead ends, not where it starts. An assistant
		opening one there would corrupt every funnel report in the product."""
		outcome = registry.execute(TOOL, {"first_name": MARK, "status": "Converted"})

		self.assertEqual(outcome["error"]["code"], "invalid_arguments")
		self.assertEqual(self.leads(), 0)

	def test_an_unknown_source_is_a_sentence_not_a_link_error(self):
		outcome = registry.execute(
			TOOL, {"first_name": MARK, "source": "Telepathy"}
		)

		self.assertFalse(outcome["ok"])
		self.assertIn("Telepathy", outcome["error"]["message"])
		self.assertEqual(self.leads(), 0)

	def test_a_valid_call_creates_the_lead_and_returns_its_id(self):
		outcome = registry.execute(
			TOOL, {"first_name": MARK, "organization": "Zz LLC", "source": "Referral"}
		)

		self.assertTrue(outcome["ok"])
		self.assertTrue(outcome["data"]["lead_id"])
		self.assertEqual(outcome["data"]["status"], "New Lead")


class TestFailuresAreRecordedNotHidden(_WriteToolTestCase):
	def test_a_failing_write_is_recorded_as_a_failure_not_a_success(self):
		"""A tool reports failure as *data* rather than by raising, so this
		path returns normally. Recording that as a clean success would leave an
		audit row reading "Approved" with nothing to say the CRM refused."""
		call = self.propose()
		action = frappe.get_doc("Pending Action", call["id"])

		# `ToolSpec` is frozen and the registry holds a direct reference to the
		# handler, so neither the spec nor the module attribute can be patched.
		# The whole entry is swapped for the duration instead.
		def _refuse(**kwargs):
			frappe.throw("CRM refused that", exc=registry.ToolError)

		original = registry._REGISTRY[TOOL]
		registry._REGISTRY[TOOL] = replace(original, handler=_refuse)
		try:
			result = action.approve()
		finally:
			registry._REGISTRY[TOOL] = original

		self.assertFalse(result["ok"])
		action.reload()
		self.assertEqual(action.status, "Approved", "a human did approve it")
		self.assertIn("refused", action.error)
		self.assertTrue(action.executed_at)
		self.assertEqual(self.leads(), 0)

	def test_the_user_never_sees_a_traceback(self):
		class _Exploding:
			streams_natively = False
			model = "boom"

			def chat(self, *args, **kwargs):
				raise RuntimeError("secret internal detail")

		published = self.run_turn(_Exploding())

		self.assertEqual(published[-1]["type"], "error")
		self.assertNotIn("secret internal detail", published[-1]["message"])
		self.assertNotIn("Traceback", published[-1]["message"])


TASK_TOOL = "crm.create_task"
TASK_MARK = "ZzTestTask"


class _TaskProposer(_Proposer):
	"""Proposes a task rather than a lead, with a fresh provider id each ask."""

	def __init__(self, arguments=None):
		super().__init__(
			arguments or {"title": TASK_MARK, "priority": "High"}
		)

	def chat(self, system, messages, tools=()):
		if any(message.role == "tool" for message in messages):
			return AIResponse(text="Done.")
		self.asks += 1
		return AIResponse(
			text="I can do that.",
			tool_calls=(
				AIToolCall(
					id=f"provider-{self.asks}", name=TASK_TOOL, arguments=self.arguments
				),
			),
		)


class _TaskTestCase(_WriteToolTestCase):
	def _clean(self):
		super()._clean()
		frappe.db.delete("CRM Task", {"title": ("like", f"{TASK_MARK}%")})
		frappe.db.delete("Pending Action", {"tool": TASK_TOOL})
		frappe.db.commit()

	def tasks(self):
		return frappe.db.count("CRM Task", {"title": ("like", f"{TASK_MARK}%")})

	def a_deal(self):
		return frappe.get_all("CRM Deal", pluck="name", limit=1)[0]

	def propose_task(self, provider=None):
		published = self.run_turn(provider or _TaskProposer())
		self.assertEqual(published[-1]["type"], "needs_confirmation")
		return published[-1]["calls"][0]


class TestCreateTaskFollowsTheSameSafetyChain(_TaskTestCase):
	def test_it_is_a_write_that_needs_confirmation(self):
		spec = registry.get(TASK_TOOL)

		self.assertIs(spec.risk, Risk.WRITE)
		self.assertTrue(spec.requires_confirmation)
		self.assertEqual(spec.risk.permission_type, "create")

	def test_proposing_creates_no_task(self):
		self.propose_task()

		self.assertEqual(self.tasks(), 0, "a write ran before anyone approved it")

	def test_confirming_creates_exactly_one_task(self):
		provider = _TaskProposer()
		call = self.propose_task(provider)

		self.run_turn(provider, approved=[call["id"]])

		self.assertEqual(self.tasks(), 1)
		self.assertEqual(provider.asks, 1, "the model re-proposed after approval")

	def test_a_repeated_confirmation_creates_nothing_further(self):
		provider = _TaskProposer()
		call = self.propose_task(provider)
		self.run_turn(provider, approved=[call["id"]])

		with self.assertRaises(frappe.ValidationError):
			chat.confirm(turn_id="t1", call_ids=[call["id"]], message="again")

		self.assertEqual(self.tasks(), 1, "a replay created a second task")

	def test_two_simultaneous_claims_admit_exactly_one_winner(self):
		call = self.propose_task()
		first = frappe.get_doc("Pending Action", call["id"])
		second = frappe.get_doc("Pending Action", call["id"])

		self.assertEqual([first.claim(), second.claim()], [True, False])

	def test_a_foreign_users_confirmation_is_refused(self):
		call = self.propose_task()
		user = frappe.db.get_value(
			"User", {"name": ("not in", ("Administrator", "Guest")), "enabled": 1}, "name"
		)
		frappe.set_user(user)

		with self.assertRaises(frappe.ValidationError):
			chat.confirm(turn_id="t1", call_ids=[call["id"]], message="yes")

		self.assertEqual(self.tasks(), 0)

	def test_an_expired_proposal_cannot_be_approved(self):
		call = self.propose_task()
		frappe.db.set_value(
			"Pending Action", call["id"], "expires_at", frappe.utils.add_to_date(None, hours=-1)
		)

		with self.assertRaises(frappe.ValidationError):
			frappe.get_doc("Pending Action", call["id"]).approve()

		self.assertEqual(self.tasks(), 0)

	def test_a_rejected_proposal_cannot_then_be_approved(self):
		call = self.propose_task()
		chat.reject(call_ids=[call["id"]])

		with self.assertRaises(frappe.ValidationError):
			chat.confirm(turn_id="t1", call_ids=[call["id"]], message="yes")

		self.assertEqual(self.tasks(), 0)


class TestTaskArgumentsAreValidated(_TaskTestCase):
	def test_a_missing_title_is_refused(self):
		outcome = registry.execute(TASK_TOOL, {"priority": "High"})

		self.assertEqual(outcome["error"]["code"], "invalid_arguments")
		self.assertEqual(self.tasks(), 0)

	def test_a_wrong_type_is_refused(self):
		outcome = registry.execute(TASK_TOOL, {"title": 7})

		self.assertEqual(outcome["error"]["code"], "invalid_arguments")

	def test_an_unknown_argument_is_refused(self):
		outcome = registry.execute(
			TASK_TOOL, {"title": TASK_MARK, "assigned_to_team": "sales"}
		)

		self.assertEqual(outcome["error"]["code"], "invalid_arguments")
		self.assertEqual(self.tasks(), 0)

	def test_an_invalid_status_or_priority_is_refused(self):
		for arguments in (
			{"title": TASK_MARK, "status": "Blocked"},
			{"title": TASK_MARK, "priority": "Urgent"},
		):
			with self.subTest(arguments=arguments):
				outcome = registry.execute(TASK_TOOL, arguments)
				self.assertEqual(outcome["error"]["code"], "invalid_arguments")

		self.assertEqual(self.tasks(), 0)

	def test_an_unknown_assignee_is_named_not_silently_dropped(self):
		"""A task assigned to nobody still looks assigned to whoever asked."""
		outcome = registry.execute(
			TASK_TOOL, {"title": TASK_MARK, "assigned_to": "ghost@nowhere.invalid"}
		)

		self.assertFalse(outcome["ok"])
		self.assertIn("ghost@nowhere.invalid", outcome["error"]["message"])
		self.assertEqual(self.tasks(), 0)

	def test_an_unparseable_due_date_is_refused(self):
		outcome = registry.execute(
			TASK_TOOL, {"title": TASK_MARK, "due_date": "next Tuesday-ish"}
		)

		self.assertFalse(outcome["ok"])
		self.assertEqual(self.tasks(), 0)

	def test_a_valid_task_is_created_with_its_real_fields(self):
		deal = self.a_deal()
		outcome = registry.execute(
			TASK_TOOL,
			{
				"title": TASK_MARK,
				"priority": "High",
				"status": "Todo",
				"due_date": "2026-09-01 10:00:00",
				"reference_doctype": "CRM Deal",
				"reference_docname": deal,
			},
		)

		self.assertTrue(outcome["ok"], outcome)
		# `CRM Task` names itself with an autoincrementing integer.
		self.assertIsInstance(outcome["data"]["task_id"], int)
		self.assertEqual(outcome["data"]["reference_docname"], deal)
		self.assertEqual(outcome["data"]["priority"], "High")


class TestAReferenceCannotBeInvented(_TaskTestCase):
	"""`reference_doctype` is a Link to **DocType**. Unrestricted, the assistant
	could attach a task to anything on the site — including `User` or a settings
	singleton — or to a record it is not allowed to see."""

	def test_a_doctype_outside_the_allowlist_is_refused(self):
		for doctype in ("User", "AI Provider", "Pending Action", "DocType"):
			with self.subTest(doctype=doctype):
				outcome = registry.execute(
					TASK_TOOL,
					{
						"title": TASK_MARK,
						"reference_doctype": doctype,
						"reference_docname": "Administrator",
					},
				)
				self.assertFalse(outcome["ok"])

		self.assertEqual(self.tasks(), 0)

	def test_a_nonexistent_record_is_refused(self):
		outcome = registry.execute(
			TASK_TOOL,
			{
				"title": TASK_MARK,
				"reference_doctype": "CRM Deal",
				"reference_docname": "CRM-DEAL-9999-99999",
			},
		)

		self.assertFalse(outcome["ok"])
		self.assertIn("not found", outcome["error"]["message"])
		self.assertEqual(self.tasks(), 0)

	def test_half_a_reference_is_refused(self):
		for arguments in (
			{"title": TASK_MARK, "reference_doctype": "CRM Deal"},
			{"title": TASK_MARK, "reference_docname": "whatever"},
		):
			with self.subTest(arguments=arguments):
				outcome = registry.execute(TASK_TOOL, arguments)
				self.assertFalse(outcome["ok"])

		self.assertEqual(self.tasks(), 0)

	def test_an_unreadable_record_is_indistinguishable_from_a_missing_one(self):
		"""Otherwise "no such deal" versus "not found" tells an attacker which
		ids exist — an existence oracle over other people's records."""
		deal = self.a_deal()

		with patch.object(registry.frappe, "has_permission", return_value=False):
			outcome = registry.execute(
				TASK_TOOL,
				{
					"title": TASK_MARK,
					"reference_doctype": "CRM Deal",
					"reference_docname": deal,
				},
			)

		self.assertFalse(outcome["ok"])
		self.assertEqual(self.tasks(), 0)


class TestTaskTextSurvivesTheWholePath(_TaskTestCase):
	def test_cyrillic_and_kazakh_are_stored_unchanged(self):
		title = f"{TASK_MARK} Позвонить Айгүл — Мебель Астана"
		outcome = registry.execute(
			TASK_TOOL, {"title": title, "description": "Ә, Ө, Ұ, Ү, Һ, І"}
		)

		self.assertTrue(outcome["ok"], outcome)
		stored = frappe.get_doc("CRM Task", outcome["data"]["task_id"])
		self.assertEqual(stored.title, title)
		self.assertIn("Ү", stored.description)
