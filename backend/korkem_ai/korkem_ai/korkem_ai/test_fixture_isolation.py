# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The test suite must not drag ERPNext's own test bootstrap into our doctypes.

## The failure this file exists to prevent

Three doctype suites — Agent Conversation, Agent Conversation Message and
Pending Action — used to die in `setUpClass` with:

    DuplicateEntryError: ('Price List', 'Standard Buying',
        IntegrityError(1062, "Duplicate entry 'Standard Buying' for key 'PRIMARY'"))

Nothing in KORKEM inserts a price list. The chain was:

    make_test_records("Agent Conversation")
      → its Link field `user` → User
        → User's test module declares Email Account
          → Email Account links Company
            → loading Company's *test* module imports erpnext/tests/utils.py
              → which runs `BootStrapTestData()` **at module import time**

`BootStrapTestData.make_price_list()` guards itself with

    frappe.db.exists("Price List", {"price_list_name": ..., "currency": "INR", ...})

but `Price List` autonames from `price_list_name` **alone**. On this site
`Standard Buying` exists with `currency = "KZT"`, because KORKEM is a Kazakh
company. So the guard matched nothing, the insert collided on the primary key,
and every suite whose dependency walk reached Company failed before its first
assertion — on a clean volume, deterministically.

## Why the fix is a declaration and not a `try/except`

None of those three suites uses a generated `User` record. They pass
`"Administrator"`, which exists on every Frappe site by construction. The
dependency was never real, so `IGNORE_TEST_RECORD_DEPENDENCIES` states the
truth rather than hiding a symptom — and it is Frappe's own supported
mechanism for exactly this (`frappe/tests/utils/generators.py`).

The alternative fixes were all worse: patching vendored ERPNext violates
ADR-0004, and changing the price list's currency to INR would corrupt real
business data to satisfy a test bootstrap.

## What this test does

It walks the same dependency resolution the runner walks, and asserts the
closure stays inside KORKEM. It fails the day somebody adds a Link field that
reopens the path — which is the only way this defect can come back.
"""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase
from frappe.tests.utils.generators import get_missing_records_doctypes


def _app_of(doctype: str) -> str | None:
	"""Which installed app owns a doctype, via its module."""
	module = frappe.db.get_value("DocType", doctype, "module")
	if not module:
		return None
	return frappe.db.get_value("Module Def", module, "app_name")

#: The doctypes whose suites died, and which must stay independent of ERPNext's
#: test bootstrap.
GUARDED = ("Agent Conversation", "Agent Conversation Message", "Pending Action")

#: Reaching any of these means the walk has entered ERPNext's test modules,
#: whose import has side effects on the database.
FORBIDDEN = ("Company", "Email Account", "Account", "Price List")


class TestFixtureIsolation(IntegrationTestCase):
	def test_no_guarded_doctype_pulls_in_erpnext_test_bootstrap(self):
		for doctype in GUARDED:
			with self.subTest(doctype=doctype):
				closure = get_missing_records_doctypes(doctype)
				leaked = sorted(set(closure) & set(FORBIDDEN))
				self.assertEqual(
					leaked,
					[],
					f"{doctype} test records depend on {leaked}; loading their test "
					"modules imports erpnext/tests/utils.py, which writes to the "
					"database at import time and collides on Price List.",
				)

	def test_the_walk_never_leaves_frappe_and_korkem(self):
		"""The general form of the rule, so a new ERPNext link cannot sneak in.

		The named doctypes above are the ones that actually bit; the real
		invariant is broader and does not need updating every time Frappe adds
		a link field: **no KORKEM doctype suite may depend on test records from
		ERPNext.** ERPNext's test modules write to the database when imported,
		and that is what makes them unsafe to reach from here — the price list
		was one symptom of it, not the whole problem.

		Frappe's own doctypes are fine: `Pending Action.entity_type` links
		`DocType`, which legitimately pulls Role, Module Def and friends.
		"""
		for doctype in GUARDED:
			with self.subTest(doctype=doctype):
				foreign = sorted(
					{dt for dt in get_missing_records_doctypes(doctype) if _app_of(dt) == "erpnext"}
				)
				self.assertEqual(
					foreign,
					[],
					f"{doctype} test records now depend on ERPNext doctypes {foreign}. "
					"Loading their test modules imports erpnext/tests/utils.py, which "
					"writes to the database at import time. Either the dependency is "
					"real — in which case say so here and explain why the import is "
					"safe — or add it to IGNORE_TEST_RECORD_DEPENDENCIES.",
				)
