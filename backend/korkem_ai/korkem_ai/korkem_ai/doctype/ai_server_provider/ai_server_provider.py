# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Резервный пул KORKEM: наши ключи с оплатой, на случай когда у клиента кончилось.

## Почему это отдельный доктайп, а не поле в `AI Provider`

`AI Provider` именуется своим типом (`autoname: field:provider`), поэтому
«Gemini клиента» и «Gemini KORKEM» в одной таблице не помещаются: имена
совпадут. Но дело не только в этом.

Разделение обязано быть **структурным, а не фильтром**. Ключ клиента и ключ
KORKEM отличаются тем, кто платит и чья квота расходуется; смешать их — значит
однажды обслужить одного клиента ключом другого. Это то, что провайдеры
называют обходом опубликованных ограничений, и блокируют за это аккаунт
клиента, а не наш (`ADR-0029`).

Фильтр `where scope = 'user'` можно забыть в одном запросе из десяти. Отдельная
таблица забыться не может.

## Что здесь не хранится

Ничего клиентского. Ни компании, ни привязки к пользователю: этот пул общий по
определению — он наш. Пул клиента живёт в `AI Provider` и принадлежит узлу,
а узел принадлежит одной компании.

## Ключ не покидает сервер

Ни один whitelisted-эндпоинт не возвращает `api_key`, и приложение не знает про
этот доктайп вовсе. Владелец видит только строку «резерв KORKEM включён» —
факт, а не ключ.
"""

from __future__ import annotations

import frappe
from frappe.model.document import Document


class AIServerProvider(Document):
	def validate(self):
		self.model = (self.model or "").strip()
		if self.enabled and not self.get_password("api_key", raise_exception=False):
			frappe.throw(
				"Резервный провайдер без ключа не резерв. Либо ключ, либо выключить."
			)
		if self.priority is None or self.priority < 1:
			self.priority = 100
