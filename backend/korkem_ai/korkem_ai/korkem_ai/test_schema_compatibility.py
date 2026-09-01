# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""The node never runs an older schema contract against newer site data."""

from unittest.mock import MagicMock, patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai import environment


class TestSchemaCompatibility(IntegrationTestCase):
	def set_schema_version(self, version, *, database_version=None):
		patcher = patch.dict(frappe.local.conf, {environment.SCHEMA_CONFIG_KEY: version})
		patcher.start()
		self.addCleanup(patcher.stop)
		if database_version is None:
			database_version = 0 if version is None or not isinstance(version, int) else version
		database_patcher = patch.object(
			environment,
			"database_schema_version",
			return_value=database_version,
		)
		database_patcher.start()
		self.addCleanup(database_patcher.stop)

	def test_data_newer_than_code_refuses_startup_with_recovery_instructions(self):
		self.set_schema_version(environment.SCHEMA_VERSION + 1)

		with self.assertRaises(environment.SchemaCompatibilityError) as caught:
			environment.assert_schema_compatible()

		message = str(caught.exception)
		self.assertIn("START REFUSED", message)
		self.assertIn(f"version is {environment.SCHEMA_VERSION + 1}", message)
		self.assertIn(f"supports only version {environment.SCHEMA_VERSION}", message)
		self.assertIn("bench --site", message)
		self.assertIn("migrate", message)

	def test_data_older_than_code_is_allowed_to_reach_migration(self):
		self.set_schema_version(environment.SCHEMA_VERSION - 1)

		self.assertIsNone(environment.assert_schema_compatible())
		self.assertEqual(environment.schema_compatibility()["state"], "data_older")

	def test_equal_versions_are_allowed(self):
		self.set_schema_version(environment.SCHEMA_VERSION)

		self.assertIsNone(environment.assert_schema_compatible())
		self.assertEqual(environment.schema_compatibility()["state"], "equal")

	def test_a_site_without_a_marker_is_an_old_version_not_a_bypass(self):
		self.set_schema_version(None)

		self.assertEqual(environment.data_schema_version(), 0)
		self.assertEqual(environment.schema_compatibility()["state"], "data_older")

	def test_a_newer_database_marker_refuses_even_when_site_config_is_old(self):
		self.set_schema_version(0, database_version=environment.SCHEMA_VERSION + 1)

		with self.assertRaises(environment.SchemaCompatibilityError):
			environment.assert_schema_compatible()

	def test_a_malformed_marker_fails_closed(self):
		self.set_schema_version("newest")

		with self.assertRaises(environment.SchemaCompatibilityError) as caught:
			environment.assert_schema_compatible()

		self.assertIn("site config", str(caught.exception))

	def test_after_migrate_records_only_from_the_after_commit_callback(self):
		callback_manager = MagicMock()
		with (
			patch.object(frappe.db, "after_commit", callback_manager),
			patch("frappe.defaults.set_default") as set_database_default,
		):
			environment.record_schema_version_after_migrate()

		set_database_default.assert_called_once_with(
			environment.SCHEMA_DATABASE_KEY,
			environment.SCHEMA_VERSION,
			"__default",
		)
		callback_manager.add.assert_called_once_with(environment._write_migrated_schema_version)

		with patch("frappe.installer.update_site_config") as update_site_config:
			environment._write_migrated_schema_version()

		update_site_config.assert_called_once_with(
			environment.SCHEMA_CONFIG_KEY,
			environment.SCHEMA_VERSION,
		)
