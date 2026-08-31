# Copyright (c) 2026, KORKEM and Contributors
# See license.txt

import frappe
from frappe.tests import IntegrationTestCase


class TestAISettingsValidation(IntegrationTestCase):
	"""A configuration that cannot work should not save.

	The alternative — save cleanly, fail at the first message — is
	indistinguishable, to the person who saved it, from the feature being
	broken. These are the four ways to get it wrong.
	"""

	def tearDown(self):
		frappe.db.rollback()

	def _settings(self, **values):
		settings = frappe.get_single("AI Settings")
		settings.update({"enabled": 1, "model": "a-model", **values})
		return settings

	def test_disabled_settings_are_never_validated(self):
		"""Half-finished configuration is exactly what "disabled" is for."""
		settings = self._settings(enabled=0, provider="OpenAI-compatible", base_url="")
		settings.save()  # must not raise

	def test_openai_compatible_without_a_base_url_is_refused(self):
		settings = self._settings(provider="OpenAI-compatible", base_url="", api_key="k")
		with self.assertRaises(frappe.ValidationError):
			settings.save()

	def test_a_base_url_must_be_a_url(self):
		settings = self._settings(
			provider="OpenAI-compatible", base_url="api.example.com/v1", api_key="k"
		)
		with self.assertRaises(frappe.ValidationError):
			settings.save()

	def test_cloud_provider_without_a_key_is_refused(self):
		settings = self._settings(provider="OpenAI", base_url="", api_key="")
		with self.assertRaises(frappe.ValidationError):
			settings.save()

	def test_ollama_saves_without_a_key(self):
		"""A local model has nothing to authenticate against."""
		settings = self._settings(provider="Ollama", api_key="", base_url="")
		settings.save()

		self.assertEqual(frappe.db.get_single_value("AI Settings", "provider"), "Ollama")

	def test_anthropic_saves_without_a_key(self):
		"""Its SDK also resolves a key from the environment, so blank is a real
		configuration rather than an oversight."""
		settings = self._settings(provider="Anthropic", api_key="", base_url="")
		settings.save()

	def test_trailing_slash_is_normalised_on_save(self):
		settings = self._settings(
			provider="OpenAI-compatible", base_url="https://gateway.internal/v1/", api_key="k"
		)
		settings.save()

		self.assertEqual(settings.base_url, "https://gateway.internal/v1")

	def test_the_key_is_stored_encrypted_not_in_the_singles_table(self):
		"""The whole reason the credential lives here rather than on a device.
		A Password field is kept in the auth store; what lands in `tabSingles`
		must not be the secret itself."""
		settings = self._settings(
			provider="OpenAI", base_url="https://api.example/v1", api_key="super-secret"
		)
		settings.save()

		# `order_by=None` because `tabSingles` has no `creation` column and the
		# default ordering would be invalid SQL against it.
		stored = frappe.db.get_value(
			"Singles",
			{"doctype": "AI Settings", "field": "api_key"},
			"value",
			order_by=None,
		)
		self.assertNotEqual(stored, "super-secret")
		self.assertEqual(settings.get_password("api_key"), "super-secret")
