# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Shortage → purchase request, and everything that must stop it.

The interesting cases are business ones, not schema ones: ordering material
that is already reserved, ordering it twice, and ordering more of it than is
actually missing. Each of those costs a factory real money, and none of them
looks like an error from inside the tool.

No provider is contacted — the model is scripted, because a real one proposes
something slightly different each run and the test would assert nothing.
"""

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai import chat
from korkem_ai.korkem_ai.orchestrator.protocol import AIResponse, AIToolCall
from korkem_ai.korkem_ai.tools import catalog, registry  # noqa: F401
from korkem_ai.korkem_ai.tools.registry import Risk

TOOL = "inventory.create_material_request"
BOARD = "ДСП 16мм"
EDGE = "Кромка 2мм"


def _order():
	rows = frappe.get_all(
		"Sales Order", filters={"customer": "Мебель Астана", "docstatus": 1}, pluck="name"
	)
	return rows[0] if rows else None


class _Proposer:
	"""Proposes the request, then summarises — with a different provider call
	id each time, which is what a real provider does."""

	streams_natively = False
	model = "scripted-1"

	def __init__(self, arguments):
		self.arguments = arguments
		self.asks = 0

	def chat(self, system, messages, tools=()):
		if any(message.role == "tool" for message in messages):
			return AIResponse(text="Готово.")
		self.asks += 1
		return AIResponse(
			text="Оформляю заявку.",
			tool_calls=(AIToolCall(id=f"provider-{self.asks}", name=TOOL, arguments=self.arguments),),
		)


class _ProcurementTestCase(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		self.order = _order()
		if not self.order:
			self.skipTest("seed_demo has not been run on this site")
		self._clean()

	def tearDown(self):
		frappe.set_user("Administrator")
		frappe.db.rollback()
		self._clean()

	def _clean(self):
		for name in frappe.get_all("Material Request", pluck="name"):
			doc = frappe.get_doc("Material Request", name)
			if doc.docstatus == 1:
				doc.cancel()
			frappe.delete_doc("Material Request", name, force=1, ignore_permissions=True)
		frappe.db.delete("Pending Action", {"tool": TOOL})
		frappe.db.commit()

	def requests(self):
		return frappe.db.count("Material Request")

	def shortage(self):
		result = registry.execute("inventory.material_shortage", {"sales_order": self.order})
		self.assertTrue(result["ok"], result.get("error"))
		return {row["item_code"]: row for row in result["data"]["items"]}

	def create(self, **overrides):
		args = {"sales_order": self.order, "items": [{"item_code": BOARD, "qty": 4}]}
		args.update(overrides)
		return registry.execute(TOOL, args)

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
				turn_id="mr1",
				message="не хватает материалов, создай заявку",
				history=[],
				approved_calls=approved or [],
			)
		return published


class TestTheShortageIsNotDoubleCounted(_ProcurementTestCase):
	"""The finding this module was built around.

	ERPNext's own Production Plan engine answers 42 sheets and 120 metres for
	this order, because it assumes nothing is reserved yet. A Work Order for
	all ten cabinets already reserved the lot, so the real answer is 4 and 0.
	"""

	def test_material_already_reserved_by_a_work_order_is_not_requested_again(self):
		edge = self.shortage()[EDGE]

		self.assertGreater(edge["reserved_qty"], 0, "the fixture no longer has a work order")
		self.assertEqual(edge["required_qty"], 180.0)
		self.assertEqual(
			edge["shortage_qty"], 0.0, "ordered edge banding that the factory already holds"
		)

	def test_the_shortage_is_what_erpnext_projects_the_bin_short_by(self):
		board = self.shortage()[BOARD]

		self.assertEqual(board["projected_qty"], -4.0)
		self.assertEqual(board["shortage_qty"], 4.0)


class TestProductionDoesNotInflateTheShoppingList(_ProcurementTestCase):
	"""What Phase 22 found, and the reason the seed can manufacture at all.

	The engine is asked for the whole order — ten cabinets, 42 sheets — because
	that is what the order is for. But `_reserved_for` nets `consumed_qty` out
	of its side of the subtraction, so leaving it in on the requirement side
	counts every produced unit twice: once as material that has left the bin,
	once as material still to buy.

	Measured before the correction, with six cabinets genuinely built: a
	four-sheet shortage read 29.2, and 48 metres of edge banding the shop
	already held appeared on the shopping list. The physical truth never moved
	— 16.8 sheets needed, 12.8 on the shelf, short 4.
	"""

	def test_consumed_material_is_not_asked_for_again(self):
		board = self.shortage()[BOARD]

		self.assertGreater(board["consumed_qty"], 0, "the seed no longer manufactures anything")
		self.assertEqual(
			board["remaining_required_qty"],
			round(board["required_qty"] - board["consumed_qty"], 3),
			"remaining requirement must be the order's, less what production ate",
		)

	def test_the_shortage_survives_real_production(self):
		"""The invariant that let the fixture stop lying: producing six of the
		ten cabinets must not change what has to be bought."""
		board = self.shortage()[BOARD]

		self.assertEqual(board["shortage_qty"], 4.0)
		self.assertEqual(board["physical_shortage_qty"], 4.0)

	def test_a_material_the_shop_still_holds_enough_of_stays_off_the_list(self):
		"""Edge banding: 180 for the order, 108 consumed, 72 to go, 132 on the
		shelf. Counting the consumed 108 again would order 48 metres of it."""
		edge = self.shortage()[EDGE]

		self.assertGreater(edge["consumed_qty"], 0)
		self.assertEqual(edge["shortage_qty"], 0.0)
		self.assertEqual(edge["physical_shortage_qty"], 0.0)
		self.assertGreater(edge["available_qty"], edge["remaining_required_qty"])

	def test_the_two_shortage_tools_agree_about_the_same_board(self):
		"""`factory_shortage` applies the same correction, or the factory-wide
		answer and the per-order one would diverge the moment anything is made."""
		from korkem_ai.korkem_ai.tools.procurement import factory_shortage

		frappe.set_user("Administrator")
		factory = {row["item_code"]: row for row in factory_shortage()["items"]}

		self.assertIn(BOARD, factory)
		self.assertEqual(factory[BOARD]["shortage_qty"], self.shortage()[BOARD]["shortage_qty"])


class TestNothingIsOrderedUntilAHumanAgrees(_ProcurementTestCase):
	def test_the_tool_is_declared_as_a_write_needing_confirmation(self):
		spec = registry.get(TOOL)

		self.assertIs(spec.risk, Risk.WRITE)
		self.assertTrue(spec.requires_confirmation)

	def test_proposing_creates_no_material_request(self):
		published = self.run_turn(_Proposer({"sales_order": self.order, "items": [{"item_code": BOARD, "qty": 4}]}))

		self.assertEqual(published[-1]["type"], "needs_confirmation")
		self.assertEqual(self.requests(), 0, "material was ordered before anyone agreed")

	def test_confirming_creates_exactly_one_material_request(self):
		proposer = _Proposer({"sales_order": self.order, "items": [{"item_code": BOARD, "qty": 4}]})
		call = self.run_turn(proposer)[-1]["calls"][0]

		self.run_turn(proposer, approved=[call["id"]])

		self.assertEqual(self.requests(), 1)

	def test_a_repeated_confirmation_orders_nothing_further(self):
		proposer = _Proposer({"sales_order": self.order, "items": [{"item_code": BOARD, "qty": 4}]})
		call = self.run_turn(proposer)[-1]["calls"][0]
		self.run_turn(proposer, approved=[call["id"]])

		self.run_turn(proposer, approved=[call["id"]])

		self.assertEqual(self.requests(), 1, "a replayed confirmation bought the material twice")


class TestTheResultIsARealDocument(_ProcurementTestCase):
	def test_a_valid_shortage_produces_a_submitted_request_naming_the_order(self):
		result = self.create()

		self.assertTrue(result["ok"], result.get("error"))
		data = result["data"]
		self.assertEqual(data["status"], "created")

		doc = frappe.get_doc("Material Request", data["material_request"])
		self.assertEqual(doc.docstatus, 1, "a draft reaches neither purchasing nor the next check")
		self.assertEqual(doc.material_request_type, "Purchase")
		self.assertEqual(doc.items[0].item_code, BOARD)
		self.assertEqual(doc.items[0].qty, 4.0)
		self.assertEqual(doc.items[0].sales_order, self.order)

	def test_submitting_closes_the_shortage_it_was_raised_for(self):
		"""ERPNext's own bookkeeping, and the reason duplicates are checked first."""
		self.create()

		self.assertEqual(self.shortage()[BOARD]["shortage_qty"], 0.0)


class TestProcurementIsNotDuplicatedSilently(_ProcurementTestCase):
	def test_an_existing_open_request_is_reported_instead_of_repeated(self):
		first = self.create()["data"]["material_request"]

		again = self.create()

		self.assertTrue(again["ok"])
		self.assertEqual(again["data"]["status"], "duplicate")
		self.assertEqual(again["data"]["existing"][0]["material_requests"], [first])
		self.assertEqual(self.requests(), 1)

	def test_the_duplicate_is_reported_before_the_shortage_is_consulted(self):
		"""Otherwise the user is told the item is not short — true, because
		their own request closed it, and useless as an explanation."""
		self.create()

		message = str(self.create()["data"])

		self.assertNotIn("not short", message)


class TestArgumentsAreCheckedAgainstTheDatabase(_ProcurementTestCase):
	def test_more_than_the_shortage_is_trimmed_to_the_shortage(self):
		"""The model has just been told four. If it asks for four hundred —
		misread, mis-summarised, or steered by something in the data — the
		database is what decides how much is bought.

		Trimmed rather than refused, because the same path handles the case
		that actually happens: stock moves between the proposal and the tap,
		and refusing the whole request then leaves the user with nothing and a
		puzzle. The adjustment is reported so nobody is told a number they did
		not ask for without being told it changed."""
		result = self.create(items=[{"item_code": BOARD, "qty": 400}])

		self.assertTrue(result["ok"], result.get("error"))
		line = result["data"]["items"][0]
		self.assertEqual(line["qty"], 4.0)
		self.assertEqual(line["requested_qty"], 400)
		self.assertTrue(line["adjusted"])

		doc = frappe.get_doc("Material Request", result["data"]["material_request"])
		self.assertEqual(doc.items[0].qty, 4.0, "four hundred sheets reached ERPNext")

	def test_an_item_that_is_not_short_produces_no_document(self):
		"""An empty purchase request is noise in somebody's approval queue."""
		result = self.create(items=[{"item_code": EDGE, "qty": 50}])

		self.assertTrue(result["ok"], result.get("error"))
		self.assertEqual(result["data"]["status"], "not_needed")
		self.assertEqual(self.requests(), 0)

	def test_an_unknown_item_is_refused(self):
		result = self.create(items=[{"item_code": "НЕТ ТАКОГО", "qty": 1}])

		self.assertFalse(result["ok"])
		self.assertIn("does not exist", result["error"]["message"])

	def test_an_unknown_warehouse_is_refused(self):
		result = self.create(items=[{"item_code": BOARD, "qty": 1, "warehouse": "Nowhere - KRK"}])

		self.assertFalse(result["ok"])
		self.assertIn("does not exist", result["error"]["message"])

	def test_a_group_warehouse_is_refused(self):
		"""A group warehouse holds nothing; material received into one has
		nowhere to land."""
		result = self.create(items=[{"item_code": BOARD, "qty": 1, "warehouse": "All Warehouses - KRK"}])

		self.assertFalse(result["ok"])
		self.assertIn("group", result["error"]["message"])

	def test_a_non_positive_quantity_is_refused(self):
		for qty in (0, -5):
			with self.subTest(qty=qty):
				result = self.create(items=[{"item_code": BOARD, "qty": qty}])

				self.assertFalse(result["ok"])
				self.assertIn("greater than zero", result["error"]["message"])

	def test_a_purpose_outside_the_allowlist_is_refused(self):
		"""`Material Issue` is a real ERPNext purpose and deliberately not one
		an assistant may reach for."""
		result = self.create(purpose="Material Issue")

		self.assertFalse(result["ok"])
		self.assertEqual(result["error"]["code"], "invalid_arguments")

	def test_an_unknown_argument_is_refused_rather_than_ignored(self):
		result = self.create(docstatus=1)

		self.assertFalse(result["ok"])
		self.assertIn("not a known argument", result["error"]["message"])
		self.assertEqual(self.requests(), 0)

	def test_an_unknown_sales_order_is_a_sentence_not_a_traceback(self):
		result = self.create(sales_order="SAL-ORD-9999-99999")

		self.assertFalse(result["ok"])
		self.assertIn("not found", result["error"]["message"])


class TestPermissionFollowsRisk(_ProcurementTestCase):
	def test_the_write_needs_create_permission_not_merely_read(self):
		self.assertEqual(registry.get(TOOL).risk.permission_type, "create")

	def test_a_user_who_cannot_create_requests_is_refused(self):
		with patch(
			"korkem_ai.korkem_ai.tools.registry.frappe.has_permission", return_value=False
		):
			result = self.create()

		self.assertFalse(result["ok"])
		self.assertEqual(result["error"]["code"], "permission_denied")
		self.assertEqual(self.requests(), 0)
