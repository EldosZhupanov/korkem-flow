# Copyright (c) 2026, KORKEM and Contributors
# See license.txt

from unittest.mock import MagicMock, patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai import budget, errors
from korkem_ai.korkem_ai.orchestrator import inbound, intent, llm
from korkem_ai.korkem_ai.orchestrator.protocol import AIUsage


class _Settings:
	"""Stands in for the AI Settings single.

	Provider selection is pure decision logic over five fields; driving it
	through `set_single_value` would make each case a database round trip and
	would test Frappe rather than the branch under test. The two cases that
	*are* about persistence still go through the real doc.
	"""

	def __init__(self, provider, model, api_key, base_url, effort="low", enabled=1):
		self.enabled = enabled
		self.provider = provider
		self.model = model
		self.effort = effort
		self.base_url = base_url
		self._api_key = api_key

	def get_password(self, fieldname, raise_exception=True):
		return self._api_key


def _settings(provider, api_key, base_url, model="a-model"):
	return _Settings(provider=provider, model=model, api_key=api_key, base_url=base_url)


class TestIntentNormalization(IntegrationTestCase):
	"""Pure logic — no provider involved."""

	def test_valid_intent_passes_through(self):
		result = intent.normalize(
			{
				"intent": "new_order_inquiry",
				"customer_name": "Altay Sadykov",
				"product_description": "kitchen facades",
				"quantity": 12,
			}
		)
		self.assertEqual(result["intent"], "new_order_inquiry")
		self.assertEqual(result["customer_name"], "Altay Sadykov")
		self.assertEqual(result["quantity"], 12)

	def test_unknown_intent_falls_back_to_other(self):
		"""A local model can return an out-of-enum value; it must not reach the router."""
		result = intent.normalize({"intent": "buy_a_horse"})
		self.assertEqual(result["intent"], "other")

	def test_missing_intent_falls_back_to_other(self):
		self.assertEqual(intent.normalize({})["intent"], "other")

	def test_empty_strings_normalize_to_none(self):
		result = intent.normalize(
			{"intent": "other", "customer_name": "", "product_description": "", "quantity": 0}
		)
		self.assertIsNone(result["customer_name"])
		self.assertIsNone(result["product_description"])
		self.assertIsNone(result["quantity"])


class TestAnthropicProvider(IntegrationTestCase):
	@patch.object(llm.AnthropicProvider, "_client")
	def test_structured_output_keeps_usage(self, client):
		response = MagicMock()
		response.stop_reason = "end_turn"
		response.content = [MagicMock(type="text", text='{"intent": "other"}')]
		response.usage = MagicMock(input_tokens=19, output_tokens=7)
		client.return_value.messages.create.return_value = response
		provider = llm.AnthropicProvider(model="claude-test")

		result = provider.complete_json("sys", "hello", {"type": "object"})

		self.assertEqual(result["intent"], "other")
		self.assertEqual(provider.usage.total_tokens, 26)


class TestProviderSelection(IntegrationTestCase):
	def tearDown(self):
		frappe.db.set_single_value("AI Settings", "enabled", 0)
		frappe.db.rollback()

	def test_raises_when_disabled(self):
		frappe.db.set_single_value("AI Settings", "enabled", 0)
		with self.assertRaises(frappe.ValidationError):
			llm.get_provider()

	def test_selects_anthropic_provider(self):
		frappe.db.set_single_value("AI Settings", "enabled", 1)
		frappe.db.set_single_value("AI Settings", "provider", "Anthropic")
		frappe.db.set_single_value("AI Settings", "model", "claude-opus-5")

		provider = llm.get_provider()

		self.assertIsInstance(provider, llm.AnthropicProvider)
		self.assertEqual(provider.model, "claude-opus-5")

	def test_selects_ollama_provider(self):
		frappe.db.set_single_value("AI Settings", "enabled", 1)
		frappe.db.set_single_value("AI Settings", "provider", "Ollama")
		frappe.db.set_single_value("AI Settings", "model", "qwen2.5-coder:7b")
		frappe.db.set_single_value("AI Settings", "base_url", "http://example:11434")

		provider = llm.get_provider()

		self.assertIsInstance(provider, llm.OllamaProvider)
		self.assertEqual(provider.base_url, "http://example:11434")

	def test_ollama_needs_no_key(self):
		"""A local model has nothing to authenticate against, so a blank key is
		a valid configuration rather than an error."""
		frappe.db.set_single_value("AI Settings", "enabled", 1)
		frappe.db.set_single_value("AI Settings", "provider", "Ollama")
		frappe.db.set_single_value("AI Settings", "model", "qwen2.5-coder:7b")
		frappe.db.set_single_value("AI Settings", "base_url", "")

		provider = llm.get_provider()

		self.assertEqual(provider.base_url, llm.DEFAULT_BASE_URLS["Ollama"])

	def test_openai_family_shares_one_adapter(self):
		"""OpenAI, OpenRouter and a custom endpoint differ only in URL and key,
		so they are one adapter — and each gets its own default endpoint."""
		for provider_name, expected_url in (
			("OpenAI", llm.DEFAULT_BASE_URLS["OpenAI"]),
			("OpenRouter", llm.DEFAULT_BASE_URLS["OpenRouter"]),
		):
			with self.subTest(provider=provider_name):
				settings = _settings(provider=provider_name, api_key="k", base_url=None)
				provider = llm.get_provider(settings)

				self.assertIsInstance(provider, llm.OpenAICompatibleProvider)
				self.assertEqual(provider.base_url, expected_url)

	def test_configured_base_url_overrides_the_default(self):
		settings = _settings(
			provider="OpenAI", api_key="k", base_url="https://gateway.internal/v1/"
		)
		provider = llm.get_provider(settings)

		self.assertEqual(provider.base_url, "https://gateway.internal/v1")

	def test_openai_compatible_refuses_to_guess_an_endpoint(self):
		"""The one provider with no default. Guessing would send a credential
		somewhere nobody chose."""
		settings = _settings(provider="OpenAI-compatible", api_key="k", base_url=None)

		with self.assertRaises(frappe.ValidationError):
			llm.get_provider(settings)

	def test_cloud_providers_require_a_key(self):
		for provider_name in ("OpenAI", "OpenRouter", "Google Gemini", "OpenAI-compatible"):
			with self.subTest(provider=provider_name):
				settings = _settings(
					provider=provider_name, api_key=None, base_url="https://example/v1"
				)
				with self.assertRaises(frappe.ValidationError):
					llm.get_provider(settings)

	def test_selects_gemini_provider(self):
		settings = _settings(provider="Google Gemini", api_key="k", base_url=None)
		provider = llm.get_provider(settings)

		self.assertIsInstance(provider, llm.GeminiProvider)
		self.assertEqual(provider.base_url, llm.DEFAULT_BASE_URLS["Google Gemini"])

	def test_unknown_provider_is_refused(self):
		settings = _settings(provider="Telepathy", api_key="k", base_url="https://example")

		with self.assertRaises(frappe.ValidationError):
			llm.get_provider(settings)

	def test_missing_model_is_refused(self):
		settings = _settings(provider="OpenAI", api_key="k", base_url=None)
		settings.model = ""

		with self.assertRaises(frappe.ValidationError):
			llm.get_provider(settings)

	def test_ollama_strips_trailing_slash(self):
		provider = llm.OllamaProvider(model="m", base_url="http://example:11434/")
		self.assertEqual(provider.base_url, "http://example:11434")


class TestOllamaProvider(IntegrationTestCase):
	"""The HTTP call is mocked — these verify we build the right request and parse
	the response, not that a model is reachable."""

	@patch("korkem_ai.korkem_ai.orchestrator.llm.requests.post")
	def test_sends_schema_and_parses_content(self, mock_post):
		mock_response = MagicMock()
		mock_response.status_code = 200
		mock_response.json.return_value = {
			"message": {"content": '{"intent": "new_order_inquiry"}'},
			"prompt_eval_count": 11,
			"eval_count": 4,
		}
		mock_post.return_value = mock_response

		provider = llm.OllamaProvider(model="qwen2.5-coder:7b", base_url="http://example:11434")
		result = provider.complete_json("sys", "user msg", {"type": "object"})

		_, kwargs = mock_post.call_args
		self.assertEqual(kwargs["json"]["model"], "qwen2.5-coder:7b")
		self.assertEqual(kwargs["json"]["format"], {"type": "object"})
		self.assertFalse(kwargs["json"]["stream"])
		self.assertEqual(kwargs["json"]["messages"][0]["role"], "system")
		self.assertEqual(result["intent"], "new_order_inquiry")
		self.assertEqual(provider.usage.total_tokens, 15)

	@patch("korkem_ai.korkem_ai.orchestrator.llm.requests.post")
	def test_raises_on_empty_content(self, mock_post):
		mock_response = MagicMock()
		mock_response.status_code = 200
		mock_response.json.return_value = {"message": {"content": ""}}
		mock_post.return_value = mock_response

		provider = llm.OllamaProvider(model="m", base_url="http://example:11434")
		with self.assertRaises(frappe.ValidationError):
			provider.complete_json("sys", "user", {})


class TestOpenAICompatibleProvider(IntegrationTestCase):
	"""What we put on the wire, and what we make of what comes back. The HTTP
	call is mocked: this is about the protocol, not about reachability."""

	def _response(self, status=200, payload=None):
		mock_response = MagicMock()
		mock_response.status_code = status
		mock_response.text = "provider said no"
		mock_response.json.return_value = payload or {}
		return mock_response

	@patch("korkem_ai.korkem_ai.orchestrator.llm.requests.post")
	def test_constrains_output_to_the_schema(self, mock_post):
		mock_post.return_value = self._response(
			payload={
				"choices": [{"message": {"content": '{"intent": "other"}'}}],
				"usage": {"prompt_tokens": 13, "completion_tokens": 5},
			}
		)

		provider = llm.OpenAICompatibleProvider(
			model="gpt-5", api_key="secret", base_url="https://api.example/v1"
		)
		result = provider.complete_json("sys", "user", {"type": "object"})

		args, kwargs = mock_post.call_args
		self.assertEqual(args[0], "https://api.example/v1/chat/completions")
		self.assertEqual(kwargs["headers"]["Authorization"], "Bearer secret")
		response_format = kwargs["json"]["response_format"]
		self.assertEqual(response_format["type"], "json_schema")
		self.assertTrue(response_format["json_schema"]["strict"])
		self.assertEqual(result["intent"], "other")
		self.assertEqual(provider.usage.total_tokens, 18)

	@patch("korkem_ai.korkem_ai.orchestrator.llm.requests.post")
	def test_provider_error_is_reported_not_swallowed(self, mock_post):
		mock_post.return_value = self._response(status=401)

		provider = llm.OpenAICompatibleProvider(
			model="m", api_key="wrong", base_url="https://api.example/v1"
		)
		with self.assertRaises(frappe.ValidationError):
			provider.complete_json("sys", "user", {})

	@patch("korkem_ai.korkem_ai.orchestrator.llm.requests.post")
	def test_no_choices_is_an_error_not_an_empty_answer(self, mock_post):
		mock_post.return_value = self._response(payload={"choices": []})

		provider = llm.OpenAICompatibleProvider(
			model="m", api_key="k", base_url="https://api.example/v1"
		)
		with self.assertRaises(frappe.ValidationError):
			provider.complete_json("sys", "user", {})


class TestStrictSchema(IntegrationTestCase):
	"""Обратная сторона того же расхождения диалектов.

	Gemini выбрасывает `additionalProperties`; OpenAI и Groq при `strict: true`
	его требуют — на каждом объекте, вместе с `required` на все свойства.

	Найдено 4 сентября на настоящем ключе Groq: экран настроек сказал «провайдер
	недоступен» о провайдере, который отвечает без единой запинки. Виноват был
	наш запрос, а человек пошёл бы искать неполадку в сети.
	"""

	def test_every_object_gets_additional_properties_false(self):
		strict = llm.strict_schema(
			{
				"type": "object",
				"properties": {
					"ok": {"type": "boolean"},
					"nested": {"type": "object", "properties": {"a": {"type": "string"}}},
					"list": {"type": "array", "items": {"type": "object", "properties": {}}},
				},
			}
		)

		self.assertIs(strict["additionalProperties"], False)
		self.assertIs(strict["properties"]["nested"]["additionalProperties"], False)
		self.assertIs(strict["properties"]["list"]["items"]["additionalProperties"], False)

	def test_required_lists_every_property(self):
		"""Строгий режим не знает необязательных полей: назвать надо все."""
		strict = llm.strict_schema(
			{
				"type": "object",
				"properties": {"ok": {"type": "boolean"}, "why": {"type": "string"}},
				"required": ["ok"],
			}
		)

		self.assertEqual(sorted(strict["required"]), ["ok", "why"])

	def test_what_is_not_an_object_is_left_alone(self):
		strict = llm.strict_schema({"type": "string", "description": "просто строка"})

		self.assertNotIn("additionalProperties", strict)
		self.assertEqual(strict["description"], "просто строка")

	def test_the_original_schema_is_not_modified(self):
		"""Схема приходит из реестра инструментов и живёт дольше одного вызова."""
		original = {"type": "object", "properties": {"ok": {"type": "boolean"}}}

		llm.strict_schema(original)

		self.assertNotIn("additionalProperties", original)


class TestGeminiProvider(IntegrationTestCase):
	def test_prunes_schema_keys_gemini_rejects(self):
		"""Gemini's schema dialect is a subset; passing the full thing 400s."""
		pruned = llm.GeminiProvider.prune_schema(
			{
				"$schema": "https://json-schema.org/draft/2020-12/schema",
				"type": "object",
				"additionalProperties": False,
				"properties": {
					"nested": {"type": "object", "additionalProperties": False},
					"list": {"type": "array", "items": {"additionalProperties": True}},
				},
			}
		)

		self.assertNotIn("$schema", pruned)
		self.assertNotIn("additionalProperties", pruned)
		self.assertNotIn("additionalProperties", pruned["properties"]["nested"])
		self.assertNotIn("additionalProperties", pruned["properties"]["list"]["items"])
		self.assertEqual(pruned["type"], "object")

	@patch("korkem_ai.korkem_ai.orchestrator.llm.requests.post")
	def test_sends_key_as_header_and_reads_the_first_candidate(self, mock_post):
		mock_response = MagicMock()
		mock_response.status_code = 200
		mock_response.json.return_value = {
			"candidates": [{"content": {"parts": [{"text": '{"ok": true}'}]}}],
			"usageMetadata": {"promptTokenCount": 17, "candidatesTokenCount": 6},
		}
		mock_post.return_value = mock_response

		provider = llm.GeminiProvider(
			model="gemini-2.5-pro", api_key="secret", base_url="https://g.example/v1beta"
		)
		result = provider.complete_json("sys", "user", {"type": "object"})

		args, kwargs = mock_post.call_args
		self.assertEqual(
			args[0], "https://g.example/v1beta/models/gemini-2.5-pro:generateContent"
		)
		# The key is a header, never a query parameter — a URL ends up in logs.
		self.assertEqual(kwargs["headers"]["x-goog-api-key"], "secret")
		self.assertNotIn("secret", args[0])
		self.assertEqual(
			kwargs["json"]["generationConfig"]["responseMimeType"], "application/json"
		)
		self.assertTrue(result["ok"])
		self.assertEqual(provider.usage.total_tokens, 23)


class TestRouter(IntegrationTestCase):
	def setUp(self):
		class Adapter:
			model = "router-test-model"
			usage = None

		patcher = patch(
			"korkem_ai.korkem_ai.orchestrator.llm.resolve", return_value=Adapter()
		)
		patcher.start()
		self.addCleanup(patcher.stop)

	def tearDown(self):
		frappe.db.rollback()

	def _conversation(self):
		return frappe.get_doc(
			{
				"doctype": "Agent Conversation",
				"contact_phone": "77011234567",
				"channel": "WhatsApp",
			}
		).insert()

	def test_an_unconfigured_provider_does_not_break_routing(self):
		"""Resolving a provider is an accounting need, not a routing one.

		The adapter is looked up so the spend can be attributed to a provider
		and a model. When that lookup raised, `AINotConfigured` escaped the
		whole sales path — even for a caller that had supplied its own
		classifier and needed no provider at all. One end-to-end test caught it;
		this one holds the boundary, because the failure is invisible in every
		targeted suite that patches `resolve`.

		`classify` still falls back to `llm.get_provider()` and still says so
		in its own words when there is nothing to fall back to.
		"""
		conversation = self._conversation()

		with patch(
			"korkem_ai.korkem_ai.orchestrator.llm.resolve",
			side_effect=errors.AINotConfigured("AI is not enabled in AI Settings"),
		), patch(
			"korkem_ai.korkem_ai.orchestrator.inbound.intent_module.classify",
			return_value={"intent": "other", "confidence": 1.0},
		):
			result = inbound.handle_message(conversation.name, "Здравствуйте")

		# The assertion is simply that it returned. `AINotConfigured` used to
		# propagate out of this call and abandon the sales path entirely.
		self.assertEqual(result["intent"], "other")
		self.assertTrue(result["reply"], "the customer still got an answer")

	@patch("korkem_ai.korkem_ai.orchestrator.intent.classify")
	@patch(
		"korkem_ai.korkem_ai.budget.check",
		side_effect=budget.BudgetExceeded("guest budget exhausted"),
	)
	def test_an_unlinked_sender_is_refused_before_the_provider(self, _check, classify):
		conversation = self._conversation()

		result = inbound.handle_message(conversation.name, "Нужна кухня")

		self.assertEqual(result["status"], "refused")
		classify.assert_not_called()

	@patch("korkem_ai.korkem_ai.orchestrator.intent.classify")
	@patch("korkem_ai.korkem_ai.orchestrator.llm.resolve")
	@patch("korkem_ai.korkem_ai.usage.record_turn")
	def test_an_unlinked_provider_call_is_accounted(self, record_usage, resolve, classify):
		class Adapter:
			model = "guest-model"
			usage = AIUsage(input_tokens=7, output_tokens=2)

		resolve.return_value = Adapter()
		classify.return_value = {
			"intent": "other",
			"customer_name": None,
			"product_description": None,
			"quantity": None,
		}
		conversation = self._conversation()

		inbound.handle_message(
			conversation.name,
			"Здравствуйте",
			request_id="WhatsApp:provider-message-1",
			channel="WhatsApp",
		)

		record_usage.assert_called_once()
		kwargs = record_usage.call_args.kwargs
		self.assertEqual(kwargs["user"], "Guest")
		self.assertEqual(kwargs["request_id"], "WhatsApp:provider-message-1")
		self.assertEqual(kwargs["channel"], "WhatsApp")
		self.assertEqual(record_usage.call_args.args[0].usage.total_tokens, 9)

	@patch("korkem_ai.korkem_ai.orchestrator.intent.classify")
	def test_order_inquiry_creates_pending_action(self, mock_classify):
		mock_classify.return_value = {
			"intent": "new_order_inquiry",
			"customer_name": "Altay Sadykov",
			"product_description": "kitchen facades",
			"quantity": 12,
		}
		conversation = self._conversation()

		result = inbound.handle_message(conversation.name, "Нужны фасады для кухни, 12 штук")

		self.assertTrue(result["handled"])
		action = frappe.get_doc("Pending Action", result["pending_action"])
		self.assertEqual(action.status, "Pending")
		self.assertEqual(action.agent_skill, "sales_agent")
		self.assertEqual(action.entity_type, "Agent Conversation")

	@patch("korkem_ai.korkem_ai.orchestrator.intent.classify")
	def test_order_inquiry_writes_nothing_to_crm_before_approval(self, mock_classify):
		"""ADR-0015: the agent proposes; approval is what writes."""
		mock_classify.return_value = {
			"intent": "new_order_inquiry",
			"customer_name": "Unapproved Customer LLC",
			"product_description": "doors",
			"quantity": 3,
		}
		conversation = self._conversation()

		inbound.handle_message(conversation.name, "need doors")

		self.assertFalse(frappe.db.exists("CRM Organization", "Unapproved Customer LLC"))

	@patch("korkem_ai.korkem_ai.orchestrator.intent.classify")
	def test_unhandled_intent_replies_without_pending_action(self, mock_classify):
		mock_classify.return_value = {
			"intent": "general_question",
			"customer_name": None,
			"product_description": None,
			"quantity": None,
		}
		conversation = self._conversation()

		result = inbound.handle_message(conversation.name, "What are your hours?")

		self.assertFalse(result["handled"])
		self.assertIn("reply", result)
		self.assertEqual(
			frappe.db.count("Pending Action", {"conversation": conversation.name}), 0
		)

	@patch("korkem_ai.korkem_ai.orchestrator.intent.classify")
	def test_records_classification_on_conversation(self, mock_classify):
		mock_classify.return_value = {
			"intent": "other",
			"customer_name": None,
			"product_description": None,
			"quantity": None,
		}
		conversation = self._conversation()

		inbound.handle_message(conversation.name, "hi")

		messages = frappe.get_all(
			"Agent Conversation Message",
			filters={"conversation": conversation.name},
			fields=["content"],
		)
		self.assertTrue(any("Classified intent: other" in m.content for m in messages))
