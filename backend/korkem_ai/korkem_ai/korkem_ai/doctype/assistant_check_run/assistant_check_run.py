# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Один прогон проверок ассистента.

Хранится строкой, а не в кэше: владелец должен видеть, что показывали вчера,
когда сегодня что-то перестало проходить. Сравнение с прошлым прогоном — это и
есть ответ на вопрос «оно сломалось от смены модели или было таким всегда».
"""

from __future__ import annotations

from frappe.model.document import Document


class AssistantCheckRun(Document):
	pass
