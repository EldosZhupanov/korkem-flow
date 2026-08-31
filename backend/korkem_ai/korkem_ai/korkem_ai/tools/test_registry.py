# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""The boundary between a language model and the factory's database.

Two kinds of test here, and both matter:

* **Contract** — a model may call only what is registered, with arguments that
  validate. Most of these assert something is *refused*.
* **Real** — the read tools run against the actual site with the actual
  doctypes. A tool that queries a field which does not exist fails while a user
  is watching; a tool that queries the wrong field succeeds and lies. Mocking
  Frappe here would test the mock.
"""

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai.tools import catalog, registry  # noqa: F401 - registers the tools
from korkem_ai.korkem_ai.tools import schema as schema_validator
from korkem_ai.korkem_ai.tools.registry import Risk


class TestSchemaValidation(IntegrationTestCase):
	SCHEMA = {
		"type": "object",
		"properties": {
			"status": {"type": "string", "enum": ["Todo", "Done"]},
			"limit": {"type": "integer", "minimum": 1, "maximum": 50},
			"overdue": {"type": "boolean"},
		},
		"required": ["status"],
	}

	def test_a_valid_call_has_no_problems(self):
		self.assertEqual(schema_validator.validate({"status": "Todo", "limit": 5}, self.SCHEMA), [])

	def test_missing_required_argument_is_reported(self):
		problems = schema_validator.validate({"limit": 5}, self.SCHEMA)
		self.assertTrue(any("status is required" in p for p in problems))

	def test_a_value_outside_the_enum_is_refused(self):
		problems = schema_validator.validate({"status": "Elsewhere"}, self.SCHEMA)
		self.assertTrue(any("must be one of" in p for p in problems))

	def test_an_invented_argument_is_refused_not_ignored(self):
		"""A model adding `delete: true` to a search must be told no, not
		quietly obeyed on the arguments it did get right."""
		problems = schema_validator.validate({"status": "Todo", "delete": True}, self.SCHEMA)
		self.assertTrue(any("not a known argument" in p for p in problems))

	def test_a_bool_is_not_an_integer(self):
		"""`True` is an `int` in Python. It is not a limit."""
		problems = schema_validator.validate({"status": "Todo", "limit": True}, self.SCHEMA)
		self.assertTrue(any("must be integer" in p for p in problems))

	def test_numeric_bounds_are_enforced(self):
		self.assertTrue(schema_validator.validate({"status": "Todo", "limit": 9999}, self.SCHEMA))
		self.assertTrue(schema_validator.validate({"status": "Todo", "limit": 0}, self.SCHEMA))


class TestRegistryContract(IntegrationTestCase):
	def test_there_is_no_general_purpose_escape_hatch(self):
		"""The single most important assertion in this file. A model that can
		issue arbitrary requests has whatever access the process has, and no
		permission or audit layer downstream can narrow it again."""
		# Mechanism words, not domain words. `request` used to be on this list
		# and had to come off: ERPNext calls a purchase requisition a "Material
		# Request", so `inventory.create_material_request` tripped a guard
		# aimed at `http_request`. The generic-transport half of that name is
		# `http`/`api`/`url`, all still forbidden, so nothing is given up —
		# a tool that could really issue arbitrary calls has to say so in one
		# of the words below.
		forbidden = (
			"http",
			"api",
			"url",
			"sql",
			"query",
			"execute",
			"eval",
			"shell",
			"run_doc",
			"raw",
		)
		for spec in registry.all_specs():
			for word in forbidden:
				self.assertNotIn(
					word,
					spec.name.lower(),
					f"{spec.name} looks like a generic escape hatch",
				)

	def test_no_destructive_tool_exists_yet(self):
		"""Deletes are the one class of tool this product has not earned. The
		safety policy in `docs/ai_phase5_safe_write.md` allows them; nothing
		implements one, and this test is what keeps that deliberate."""
		for spec in registry.all_specs():
			self.assertIsNot(spec.risk, Risk.DESTRUCTIVE, f"{spec.name} is destructive")

	def test_every_write_tool_requires_confirmation_and_create_permission(self):
		"""The policy, enforced rather than documented: a tool that changes data
		may never run unattended, and may never be gated on mere read access."""
		for spec in registry.all_specs():
			if spec.risk is Risk.READ:
				self.assertFalse(spec.requires_confirmation, spec.name)
				self.assertEqual(spec.risk.permission_type, "read", spec.name)
			else:
				self.assertTrue(spec.requires_confirmation, spec.name)
				self.assertNotEqual(spec.risk.permission_type, "read", spec.name)
				self.assertTrue(spec.doctypes, f"{spec.name} names no doctype to check")

	def test_risk_decides_confirmation(self):
		self.assertFalse(Risk.READ.requires_confirmation)
		self.assertTrue(Risk.WRITE.requires_confirmation)
		self.assertTrue(Risk.DESTRUCTIVE.requires_confirmation)

	def test_every_tool_declares_an_object_schema(self):
		for spec in registry.all_specs():
			self.assertEqual(spec.input_schema.get("type"), "object", spec.name)

	def test_an_unknown_tool_is_refused_and_names_the_real_ones(self):
		result = registry.execute("crm.delete_everything", {})

		self.assertFalse(result["ok"])
		self.assertEqual(result["error"]["code"], "unknown_tool")
		self.assertIn("crm.search_deals", result["error"]["message"])

	def test_invalid_arguments_are_refused_before_the_handler_runs(self):
		result = registry.execute("tasks.list", {"status": "Whenever"})

		self.assertFalse(result["ok"])
		self.assertEqual(result["error"]["code"], "invalid_arguments")

	def test_a_failure_is_data_not_an_exception(self):
		"""One bad call must not end the conversation — the model is told what
		went wrong so it can correct itself."""
		result = registry.execute("crm.get_deal", {})

		self.assertFalse(result["ok"])
		self.assertIn("required", result["error"]["message"])

	def test_registering_a_duplicate_name_is_a_programming_error(self):
		spec = registry.all_specs()[0]
		with self.assertRaises(ValueError):
			registry.register(spec)


class TestReadToolsAgainstTheRealSite(IntegrationTestCase):
	"""These run real queries. If a fieldname here is wrong, this fails."""

	def test_search_deals_returns_real_columns(self):
		result = registry.execute("crm.search_deals", {"limit": 3})

		self.assertTrue(result["ok"], result)
		self.assertIn("deals", result["data"])
		self.assertLessEqual(len(result["data"]["deals"]), 3)

	def test_list_tasks_runs_and_stringifies_its_integer_id(self):
		"""`CRM Task.name` is an autoincrement integer on this backend."""
		result = registry.execute("tasks.list", {"limit": 3})

		self.assertTrue(result["ok"], result)
		for row in result["data"]["tasks"]:
			self.assertIsInstance(row["name"], str)

	def test_overdue_excludes_finished_tasks(self):
		"""Without this, a task completed last month still matches "due before
		today" and the answer is confidently wrong."""
		result = registry.execute("tasks.list", {"overdue": True, "limit": 50})

		self.assertTrue(result["ok"], result)
		for row in result["data"]["tasks"]:
			self.assertIn(row["status"], catalog.OPEN_TASK_STATUSES)

	def test_work_orders_expose_the_link_back_to_the_deal(self):
		"""Calls the function directly: the tool is no longer registered, but
		`production_readiness` still uses it and the deal link is what ties a
		work order back to the sale it came from."""
		result = catalog.list_work_orders(limit=3)

		for row in result["work_orders"]:
			self.assertIn("originating_deal", row)

	def test_only_one_work_order_tool_is_offered(self):
		"""Two tools over one doctype is not redundancy, it is confusion — a
		model called both in a single turn before this was narrowed."""
		names = {spec.name for spec in registry.all_specs()}

		self.assertIn("manufacturing.search_work_orders", names)
		self.assertNotIn("production.list_work_orders", names)

	def test_organizations_and_leads_run(self):
		for tool in ("crm.search_organizations", "crm.search_leads"):
			with self.subTest(tool=tool):
				self.assertTrue(registry.execute(tool, {"limit": 2})["ok"])

	def test_current_user_reports_the_session_not_a_service_account(self):
		result = registry.execute("profile.current_user", {})

		self.assertTrue(result["ok"])
		self.assertEqual(result["data"]["user"], frappe.session.user)

	def test_the_row_limit_is_a_ceiling_the_model_cannot_raise(self):
		"""A thousand-row blob is mostly tokens the model cannot use, and it
		buries the rows that matter."""
		result = registry.execute("crm.search_deals", {"limit": catalog.MAX_LIMIT})
		self.assertTrue(result["ok"])

		refused = registry.execute("crm.search_deals", {"limit": catalog.MAX_LIMIT + 1})
		self.assertFalse(refused["ok"])
		self.assertEqual(refused["error"]["code"], "invalid_arguments")


class TestPermissionsBoundTheModel(IntegrationTestCase):
	"""AI permission <= ERP permission, by construction rather than diligence."""

	def tearDown(self):
		frappe.set_user("Administrator")
		frappe.db.rollback()

	def test_tools_are_hidden_from_a_user_who_cannot_read_their_doctype(self):
		offered = {spec.name for spec in registry.available_to("Guest")}
		everything = {spec.name for spec in registry.all_specs()}

		self.assertNotEqual(offered, everything)
		self.assertNotIn("crm.search_deals", offered)

	def test_a_tool_offered_to_administrator_covers_the_catalogue(self):
		offered = {spec.name for spec in registry.available_to("Administrator")}
		self.assertIn("crm.search_deals", offered)
		self.assertIn("manufacturing.search_work_orders", offered)

	def test_execution_reports_permission_denial_as_data(self):
		"""A refusal comes back as data, never as an exception — a turn has to
		survive one bad call so the model can correct itself.

		Guest is refused by the role gate before ERPNext is consulted, which is
		the cheaper and coarser of the two checks and the one that should fire
		first. Both codes mean refused; what matters here is that neither raises.
		"""
		frappe.set_user("Guest")

		result = registry.execute("crm.search_deals", {})

		self.assertFalse(result["ok"])
		self.assertIn(result["error"]["code"], ("permission_denied", "not_permitted"))

	def test_a_role_that_may_reach_a_tool_still_meets_erpnext(self):
		"""The role gate must not replace the permission check, only precede it.
		The viewer is an employee, so the gate lets procurement through — and
		ERPNext refuses it, because they have no Purchase User."""
		frappe.set_user("korkem.viewer@example.com")

		result = registry.execute("procurement.search_purchase_orders", {})

		self.assertFalse(result["ok"])
		self.assertEqual(result["error"]["code"], "permission_denied")

	def test_reads_go_through_the_permission_aware_api(self):
		"""`frappe.db.get_all` bypasses permission query conditions entirely.
		Its appearance in a tool would silently leak other people's rows, so
		the catalogue is checked for it directly."""
		import inspect

		source = inspect.getsource(catalog)
		self.assertNotIn("frappe.db.get_all", source)
		self.assertNotIn("frappe.db.get_list", source)
		self.assertIn("frappe.get_list", source)
