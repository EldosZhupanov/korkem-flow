# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Configuring providers from the app — and never handing a key back.

The tests that matter most here are the negative ones. A settings API is the one
place in the product that *holds* a credential, so most of what it must do is
refuse: refuse to return the key, refuse a non-manager, refuse to overwrite a
stored key with the bullets a form posted back.

No real credential appears anywhere in this file. `test-secret-…` is a literal.
"""

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai import settings_api

FAKE_KEY = "test-secret-0123456789-abcdef"


class _ProviderTestCase(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")

	def tearDown(self):
		frappe.set_user("Administrator")
		frappe.db.rollback()
		for name in frappe.get_all(
			"AI Provider", filters={"provider": "OpenRouter"}, pluck="name"
		):
			frappe.delete_doc("AI Provider", name, force=True)
		frappe.db.commit()

	def _save(self, **overrides):
		payload = {
			"provider": "OpenRouter",
			"model": "some/model",
			"api_key": FAKE_KEY,
			"enabled": 1,
		}
		payload.update(overrides)
		return settings_api.save_provider(**payload)


class TestAKeyGoesInAndNeverComesOut(_ProviderTestCase):
	def test_saving_returns_a_mask_not_the_key(self):
		saved = self._save()

		self.assertTrue(saved["has_key"])
		self.assertNotIn(FAKE_KEY, str(saved))
		self.assertTrue(saved["masked_key"].startswith("test"))
		self.assertTrue(saved["masked_key"].endswith("cdef"))

	def test_no_endpoint_in_this_module_returns_the_key(self):
		"""Swept rather than asserted one endpoint at a time: the risk is a
		*new* endpoint added later that forgets, and a sweep catches that."""
		self._save()

		responses = [
			settings_api.list_providers(),
			settings_api.save_provider(provider="OpenRouter", model="another/model"),
		]

		for response in responses:
			self.assertNotIn(FAKE_KEY, frappe.as_json(response))

	def test_a_short_key_is_hidden_entirely(self):
		"""Masking four characters of a six-character secret is not masking."""
		self._save(api_key="short")
		row = frappe.get_doc("AI Provider", "OpenRouter")

		self.assertEqual(row.masked_key(), "•" * 8)

	def test_omitting_the_key_leaves_the_stored_one_alone(self):
		"""A screen that renders the mask and posts the form back must not
		overwrite the real key with bullets."""
		self._save()

		settings_api.save_provider(provider="OpenRouter", model="changed/model")

		row = frappe.get_doc("AI Provider", "OpenRouter")
		self.assertEqual(row.get_password("api_key"), FAKE_KEY)
		self.assertEqual(row.model, "changed/model")


class TestConfiguringIsForManagersOnly(_ProviderTestCase):
	def test_an_ordinary_user_cannot_read_or_write_provider_configuration(self):
		"""Using the assistant is for everyone; configuring what it talks to,
		and spending the money, is not."""
		self._save()
		user = frappe.db.get_value(
			"User", {"name": ["not in", ("Administrator", "Guest")], "enabled": 1}, "name"
		)
		self.assertTrue(user, "the site needs a second user for this test")
		frappe.set_user(user)

		for call in (
			settings_api.list_providers,
			lambda: settings_api.save_provider(provider="OpenRouter", model="x"),
			lambda: settings_api.test_provider("OpenRouter"),
			lambda: settings_api.delete_provider("OpenRouter"),
		):
			with self.subTest(call=call):
				with self.assertRaises(frappe.PermissionError):
					call()


class TestTheCatalogueIsHonest(_ProviderTestCase):
	def test_every_supported_provider_is_listed_even_unconfigured(self):
		"""So the screen can offer "add provider" without its own copy of the
		list, which would drift from what the backend can actually build."""
		listed = {p["provider"] for p in settings_api.list_providers()["providers"]}

		self.assertEqual(listed, set(settings_api.SUPPORTED_PROVIDERS))

	def test_capabilities_are_reported_before_any_key_exists(self):
		entry = next(
			p
			for p in settings_api.list_providers()["providers"]
			if p["provider"] == "Anthropic"
		)

		self.assertFalse(entry["configured"])
		self.assertEqual(entry["capabilities"]["supports_tools"], "yes")

	def test_ollama_reports_tool_support_as_unknown(self):
		"""Measured, not assumed: `qwen2.5-coder:7b` advertises tools through
		Ollama and then returns the call as prose. Claiming "yes" here would
		promise the user something the local model does not do."""
		entry = next(
			p
			for p in settings_api.list_providers()["providers"]
			if p["provider"] == "Ollama"
		)

		self.assertEqual(entry["capabilities"]["supports_tools"], "unknown")

	def test_it_says_which_providers_need_what(self):
		by_name = {
			p["provider"]: p for p in settings_api.list_providers()["providers"]
		}

		self.assertTrue(by_name["OpenAI"]["needs_key"])
		self.assertFalse(by_name["Ollama"]["needs_key"])
		self.assertTrue(by_name["OpenAI-compatible"]["needs_base_url"])


class TestConfigurationIsValidatedOnTheWayIn(_ProviderTestCase):
	def test_an_unknown_provider_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			settings_api.save_provider(provider="Skynet", model="hal-9000")

	def test_an_enabled_cloud_provider_needs_a_key(self):
		with self.assertRaises(frappe.ValidationError):
			settings_api.save_provider(
				provider="OpenRouter", model="some/model", api_key="", enabled=1
			)

	def test_openai_compatible_needs_somewhere_to_send_the_request(self):
		with self.assertRaises(frappe.ValidationError):
			settings_api.save_provider(
				provider="OpenAI-compatible",
				model="m",
				api_key=FAKE_KEY,
				base_url="",
				enabled=1,
			)

	def test_a_base_url_must_look_like_one(self):
		with self.assertRaises(frappe.ValidationError):
			self._save(base_url="not-a-url")
