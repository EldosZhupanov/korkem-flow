# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Настройки push для этого узла.

Одиночный документ, как `Telegram Settings` и `AI Provider`: узел принадлежит
одной компании, и её ключи — ключи узла. Если продукт когда-нибудь станет
хостингом, где на одном сайте живут несколько компаний, этот документ станет
обычным и получит поле компании — это развилка 7 из `ROADMAP.md`, и решать её
надо до биллинга, а не здесь.
"""

from __future__ import annotations

import json

import frappe
from frappe.model.document import Document


class PushSettings(Document):
	def validate(self):
		"""Отказать при сохранении, а не при первой недоставленной новости.

		Ключ проверяется на то, что он вообще ключ: владелец вставляет сюда файл
		из консоли Firebase, и перепутать его с `google-services.json` — обычное
		дело. Тот тоже JSON, тоже от Firebase, и тоже выглядит правильно.
		"""
		if not self.enabled:
			return

		raw = self.get_password("service_account_json", raise_exception=False)
		if not raw:
			frappe.throw("Чтобы включить уведомления, нужен ключ сервисного аккаунта Firebase.")

		try:
			account = json.loads(raw)
		except json.JSONDecodeError:
			frappe.throw(
				"Ключ не читается как JSON. Это файл целиком — его вставляют целиком, "
				"вместе с фигурными скобками."
			)

		if account.get("type") != "service_account":
			frappe.throw(
				"Это не ключ сервисного аккаунта. Похоже на google-services.json — "
				"тот файл кладут в приложение, а сюда нужен ключ из раздела "
				"«Сервисные аккаунты» в настройках проекта Firebase."
			)

		for field in ("project_id", "client_email", "private_key"):
			if not account.get(field):
				frappe.throw(f"В ключе нет поля «{field}»: файл неполный.")
