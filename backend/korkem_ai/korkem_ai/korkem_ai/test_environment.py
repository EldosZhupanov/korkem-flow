# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""What a site says it is, and what that stops it from doing.

The interesting cases are all the ones where the setting is *absent or wrong*.
A guard that only works when configured correctly protects the deployments that
were never in danger.
"""

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai import environment

PLANNER = "korkem.planner@example.com"


class _EnvironmentTestCase(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		self.addCleanup(frappe.set_user, "Administrator")

	def as_env(self, **conf):
		"""Run the rest of the test with this site configuration."""
		patcher = patch.dict(frappe.local.conf, conf)
		patcher.start()
		self.addCleanup(patcher.stop)


class TestTheSiteKnowsWhatItIs(_EnvironmentTestCase):
	def test_an_explicit_environment_is_taken_at_its_word(self):
		for name in environment.ENVIRONMENTS:
			with self.subTest(name):
				self.as_env(korkem_env=name)
				self.assertEqual(environment.current(), name)

	def test_case_and_whitespace_do_not_change_the_answer(self):
		self.as_env(korkem_env="  Pilot ")
		self.assertEqual(environment.current(), environment.PILOT)

	def test_a_developer_mode_bench_with_no_setting_is_development(self):
		self.as_env(korkem_env=None, developer_mode=1)
		self.assertEqual(environment.current(), environment.DEVELOPMENT)

	def test_no_setting_and_no_developer_mode_is_production(self):
		"""The fail-closed case: an unlabelled site is assumed to be real."""
		self.as_env(korkem_env=None, developer_mode=0)
		self.assertEqual(environment.current(), environment.PRODUCTION)

	def test_an_unrecognised_value_is_production(self):
		"""A typo in a deployment variable must not read as permission."""
		self.as_env(korkem_env="piolt", developer_mode=1)
		self.assertEqual(environment.current(), environment.PRODUCTION)

	def test_only_pilot_and_production_hold_real_data(self):
		self.as_env(korkem_env=environment.DEVELOPMENT)
		self.assertFalse(environment.is_production_like())
		for name in (environment.PILOT, environment.PRODUCTION):
			with self.subTest(name):
				self.as_env(korkem_env=name)
				self.assertTrue(environment.is_production_like())


class TestTheRefusal(_EnvironmentTestCase):
	def test_development_is_allowed_through_silently(self):
		self.as_env(korkem_env=environment.DEVELOPMENT)
		self.assertIsNone(environment.require_non_production("Anything at all"))

	def test_a_pilot_refuses_and_says_which_environment_and_which_setting(self):
		self.as_env(korkem_env=environment.PILOT)
		with self.assertRaises(frappe.ValidationError) as caught:
			environment.require_non_production("Deleting everything")

		message = str(caught.exception)
		self.assertIn("Deleting everything", message)
		self.assertIn(environment.PILOT, message)
		self.assertIn(environment.CONFIG_KEY, message)

	def test_production_refuses_too(self):
		self.as_env(korkem_env=environment.PRODUCTION)
		with self.assertRaises(frappe.ValidationError):
			environment.require_non_production("Deleting everything")


class TestTheDescriptionCarriesNoSecret(_EnvironmentTestCase):
	def test_it_reports_exactly_four_facts(self):
		self.as_env(korkem_env=environment.PILOT)
		self.assertEqual(
			set(environment.describe()),
			{"environment", "configured", "developer_mode", "allow_tests"},
		)

	def test_it_says_when_the_environment_was_only_inferred(self):
		self.as_env(korkem_env=None, developer_mode=1)
		self.assertFalse(environment.describe()["configured"])
		self.as_env(korkem_env=environment.PILOT)
		self.assertTrue(environment.describe()["configured"])

	def test_no_value_from_the_site_config_is_copied_into_it(self):
		"""The one thing a health report must never do is quote the config."""
		self.as_env(korkem_env=environment.PILOT)
		described = str(environment.describe())
		for key in ("db_password", "encryption_key", "admin_password", "db_name"):
			value = frappe.conf.get(key)
			if value:
				with self.subTest(key):
					self.assertNotIn(str(value), described)


class TestTheDemoFixturesRefuseOnARealSite(_EnvironmentTestCase):
	"""`seed_demo.remove()` cancels and deletes real documents.

	Every entry point is checked, not a representative one: the dangerous call
	is whichever one somebody types by mistake.
	"""

	ENTRY_POINTS = (
		"seed",
		"remove",
		"seed_users",
		"remove_users",
		"seed_buying",
		"remove_buying",
		"seed_selling",
		"remove_selling",
		"seed_shop_floor",
		"remove_shop_floor",
	)

	def test_every_entry_point_refuses_on_a_pilot(self):
		from korkem_manufacturing import seed_demo

		self.as_env(korkem_env=environment.PILOT)
		for name in self.ENTRY_POINTS:
			with self.subTest(name), self.assertRaises(frappe.ValidationError):
				getattr(seed_demo, name)()

	def test_every_entry_point_refuses_on_production(self):
		from korkem_manufacturing import seed_demo

		self.as_env(korkem_env=environment.PRODUCTION)
		for name in self.ENTRY_POINTS:
			with self.subTest(name), self.assertRaises(frappe.ValidationError):
				getattr(seed_demo, name)()

	def test_the_refusal_happens_before_anything_is_deleted(self):
		"""A guard that throws halfway through a teardown is not a guard."""
		from korkem_manufacturing import seed_demo

		seed_demo.seed_users()
		self.assertTrue(frappe.db.exists("User", PLANNER))

		self.as_env(korkem_env=environment.PILOT)
		with self.assertRaises(frappe.ValidationError):
			seed_demo.remove_users()

		self.assertTrue(frappe.db.exists("User", PLANNER))

	def test_a_developer_bench_is_still_allowed_to_seed(self):
		"""The guard must not have made the development workflow impossible."""
		from korkem_manufacturing import seed_demo

		self.as_env(korkem_env=environment.DEVELOPMENT)
		self.assertIn(PLANNER, seed_demo.seed_users())
