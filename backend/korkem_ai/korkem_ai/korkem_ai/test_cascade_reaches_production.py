# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Каскад включается там, где ходят люди, а не только в своих тестах.

## Почему этот файл появился

4 сентября владелец написал боту «привет» и получил «не удалось связаться с
моделью». В учёте: одна попытка, Gemini, переход не состоялся — хотя рядом были
настроены Groq и OpenRouter.

Причина была не в провайдере. Оба вызывающих — и приложение, и канал —
закрепляли модель:

    adapter = llm.resolve(provider, model)   # на пустой запрос вернёт модель
    loop.run_turn(messages, provider=adapter)  # по умолчанию, а не None

`run_turn` идёт к роутеру только при `provider is None`. Значит **весь каскад с
двумя пулами ключей был мёртвым кодом в бою**, и узнать об этом можно было
единственным способом: когда первая модель откажет живому человеку.

Тесты роутера этого не ловили и не могли: они вызывают роутер напрямую. Тесты
цикла — тоже: они передают подставного провайдера явно, как и положено тесту.
Дыра была ровно между ними, в том, **с чем реальный код зовёт эту функцию**.

Поэтому здесь проверяется не поведение роутера, а один-единственный факт: то,
что до него доходит очередь.
"""

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai import chat
from korkem_ai.korkem_ai.channels import gateway


class TestTheRouterIsActuallyReached(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")

	def test_the_app_does_not_pin_a_model_nobody_asked_for(self):
		"""Ход без названной модели обязан дойти до роутера."""
		with patch("korkem_ai.korkem_ai.agent.loop.run_turn") as run_turn, patch(
			"korkem_ai.korkem_ai.orchestrator.llm.ensure_configured"
		), patch("korkem_ai.korkem_ai.usage.record_turn"), patch(
			"korkem_ai.korkem_ai.usage.record_failure"
		), patch("frappe.publish_realtime"):
			run_turn.return_value = _answered()
			chat.run_turn_job(
				user="Administrator", turn_id="t1", message="привет", history=[], approved_calls=[]
			)

		self.assertIsNone(
			run_turn.call_args.kwargs.get("provider"),
			"модель закреплена — каскад отменён, и человек получит отказ первой",
		)

	def test_the_app_still_honours_a_model_the_person_named(self):
		"""«Ответь этим» — законная просьба, и роутер её не переигрывает."""
		with patch("korkem_ai.korkem_ai.agent.loop.run_turn") as run_turn, patch(
			"korkem_ai.korkem_ai.orchestrator.llm.resolve"
		) as resolve, patch("korkem_ai.korkem_ai.usage.record_turn"), patch(
			"korkem_ai.korkem_ai.usage.record_failure"
		), patch("frappe.publish_realtime"):
			run_turn.return_value = _answered()
			chat.run_turn_job(
				user="Administrator",
				turn_id="t2",
				message="привет",
				history=[],
				approved_calls=[],
				provider="Groq",
			)

		self.assertIsNotNone(run_turn.call_args.kwargs.get("provider"))
		resolve.assert_called_once()

	def test_a_channel_turn_never_pins(self):
		"""В мессенджере модель не называет никто — значит выбирает роутер."""
		captured = {}

		def fake_run_turn(messages, **kwargs):
			captured.update(kwargs)
			return _answered()

		with patch("korkem_ai.korkem_ai.agent.loop.run_turn", side_effect=fake_run_turn), patch(
			"korkem_ai.korkem_ai.orchestrator.llm.ensure_configured"
		), patch("korkem_ai.korkem_ai.channels.gateway.deliver"), patch(
			"korkem_ai.korkem_ai.usage.record_turn"
		), patch("korkem_ai.korkem_ai.budget.check"), patch(
			"korkem_ai.korkem_ai.channels.confirmation.handle", return_value=None
		):
			conversation = _conversation()
			gateway._run_turn(
				doc_name=conversation,
				user="Administrator",
				text="привет",
				channel=gateway.TELEGRAM,
				chat_id="1",
				turn="t3",
			)

		self.assertNotIn("provider", captured)


def _answered():
	from korkem_ai.korkem_ai.agent.loop import TurnResult

	return TurnResult(status="answered", text="здравствуйте")


def _conversation():
	doc = frappe.get_doc(
		{
			"doctype": "Agent Conversation",
			"channel": "Telegram",
			"status": "Active",
			"external_chat_id": "cascade-test",
		}
	).insert(ignore_permissions=True)
	return doc.name
