# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""What `/health` and `/health/ready` tell a stranger, and what they don't.

Two properties matter more than the rest and are tested hardest: an anonymous
caller gets a traffic light and no detail, and **nothing on either path can
carry a credential** — not a password, not the encryption key, not a database
name, and not the text of an exception that might quote any of them.
"""

import json
from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai import environment, health


class _HealthTestCase(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		self.addCleanup(frappe.set_user, "Administrator")

	def as_guest(self):
		frappe.set_user("Guest")


class TestLiveness(_HealthTestCase):
	def test_it_answers_without_asking_anything_else(self):
		"""Liveness must not fail because a *dependency* is down."""
		with patch.object(health, "_database", side_effect=AssertionError("not called")):
			self.assertEqual(health.live()["status"], health.OK)

	def test_it_names_the_service(self):
		self.assertEqual(health.live()["service"], "korkem")


class TestReadinessAsAnOperator(_HealthTestCase):
	def test_every_component_is_reported(self):
		body = health.ready()
		self.assertEqual(
			set(body["components"]),
			{"database", "redis_cache", "redis_queue", "workers", "scheduler", "erpnext"},
		)

	def test_the_database_and_both_redis_instances_are_up_in_a_working_bench(self):
		components = health.ready()["components"]
		for name in ("database", "redis_cache", "redis_queue", "erpnext"):
			with self.subTest(name):
				self.assertEqual(components[name]["status"], health.OK)

	def test_a_system_manager_is_given_the_detail(self):
		body = health.ready()
		self.assertIn("environment", body)
		self.assertIn("versions", body)
		self.assertIn("queues", body)
		self.assertEqual(body["environment"]["environment"], environment.current())

	def test_the_expected_apps_are_all_installed(self):
		versions = health.ready()["versions"]
		self.assertEqual(set(versions), set(health.EXPECTED_APPS))
		for app, version in versions.items():
			with self.subTest(app):
				self.assertIsNotNone(version)

	def test_one_component_down_makes_the_whole_answer_degraded(self):
		with patch.object(health, "_redis_queue", return_value={"status": health.DOWN}):
			self.assertEqual(health.ready()["status"], "degraded")


class TestReadinessAsAStranger(_HealthTestCase):
	def test_a_guest_gets_a_traffic_light_and_nothing_else(self):
		self.as_guest()
		for name, component in health.ready()["components"].items():
			with self.subTest(name):
				self.assertEqual(set(component), {"status"})

	def test_a_guest_is_told_no_version_no_environment_and_no_site(self):
		self.as_guest()
		body = health.ready()
		for key in ("versions", "environment", "queues", "site"):
			with self.subTest(key):
				self.assertNotIn(key, body)

	def test_a_guest_still_learns_whether_the_site_is_usable(self):
		"""The point of the endpoint survives the redaction."""
		self.as_guest()
		self.assertIn(health.ready()["status"], (health.OK, "degraded"))

	def test_a_signed_in_user_without_system_manager_is_still_a_stranger(self):
		frappe.set_user("korkem.planner@example.com")
		body = health.ready()
		self.assertNotIn("versions", body)
		self.assertEqual(set(body["components"]["database"]), {"status"})

	def test_asking_for_detail_does_not_grant_it(self):
		self.as_guest()
		self.assertNotIn("versions", health.ready(detail=True))


class TestAFailureNeverQuotesItself(_HealthTestCase):
	def test_a_broken_component_reports_its_exception_class_and_not_its_message(self):
		class OperationalError(Exception):
			pass

		secret = "host=db user=root password=hunter2"
		with patch.object(frappe.db, "sql", side_effect=OperationalError(secret)):
			result = health._database()

		self.assertEqual(result["status"], health.DOWN)
		self.assertEqual(result["reason"], "OperationalError")
		self.assertNotIn("hunter2", json.dumps(result))

	def test_a_broken_component_is_reported_and_not_raised(self):
		"""A health endpoint that 500s tells the operator less than one that answers."""
		with patch("frappe.utils.background_jobs.get_redis_conn", side_effect=RuntimeError):
			self.assertEqual(health._redis_queue()["status"], health.DOWN)


class TestNoCredentialCanReachEitherAnswer(_HealthTestCase):
	#: Every site-config key that holds something an attacker would want.
	SECRETS = ("db_password", "encryption_key", "admin_password", "db_name", "db_user")

	def _assert_clean(self, body):
		rendered = json.dumps(body, default=str)
		for key in self.SECRETS:
			value = frappe.conf.get(key)
			if value:
				with self.subTest(key):
					self.assertNotIn(str(value), rendered)

	def test_the_operator_answer_carries_none(self):
		self._assert_clean(health.ready())

	def test_the_anonymous_answer_carries_none(self):
		self.as_guest()
		self._assert_clean(health.ready())

	def test_liveness_carries_none(self):
		self._assert_clean(health.live())


class TestTheRoutes(_HealthTestCase):
	def test_it_serves_the_two_health_paths(self):
		for path in ("/health", "/health/ready", "health/ready"):
			with self.subTest(path):
				self.assertTrue(health.HealthPage(path).can_render())

	def test_it_serves_nothing_else(self):
		for path in ("/", "/app", "/api/method/ping", "/healthz", "/health/ready/extra"):
			with self.subTest(path):
				self.assertFalse(health.HealthPage(path).can_render())

	def test_a_healthy_site_answers_200_with_json(self):
		response = health.HealthPage("/health").render()
		self.assertEqual(response.status_code, 200)
		self.assertEqual(response.mimetype, "application/json")
		self.assertEqual(json.loads(response.get_data())["status"], health.OK)

	def test_a_degraded_site_answers_503(self):
		"""An orchestrator reads the status code; a degraded 200 gets traffic."""
		with patch.object(health, "_workers", return_value={"status": health.DOWN}):
			response = health.HealthPage("/health/ready").render()

		self.assertEqual(response.status_code, 503)
		self.assertEqual(json.loads(response.get_data())["status"], "degraded")

	def test_the_answer_is_never_cached(self):
		"""A cached health answer reports a state that has already passed."""
		response = health.HealthPage("/health").render()
		self.assertEqual(response.headers["Cache-Control"], "no-store")
