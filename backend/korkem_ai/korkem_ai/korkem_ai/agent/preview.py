# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Что именно произойдёт, если человек согласится.

Экран согласований показывал название навыка и целевую сущность:

    crm.create_deal · CRM Deal Заказ кухни для Ерлана

Для действия с деньгами этого мало. Владелец, подтверждающий счёт, должен
видеть счёт — клиента, заказ, сумму и срок, — а не имя функции. Согласие,
данное на непонятную строку, юридически и человечески ничего не стоит: человек
согласился с тем, чего не прочитал.

## Почему заголовки и подписи здесь, а не в приложении

Что показывать человеку — решение о деле, а не о вёрстке. Оно принадлежит той
стороне, которая знает, что `delivery_date` это «срок сдачи», а `qty` в
контексте раскроя — «количество деталей». Приложение, разбирающее аргументы
само, повторяет знание о предметной области во втором месте, и однажды они
разойдутся.

## Чего здесь нет

Выдуманных полей. Если суммы в действии нет, строки «сумма не указана» не будет:
человек, увидевший выдуманное поле, перестаёт верить и остальным.
"""

from __future__ import annotations

#: Подписи к аргументам — словами накладной, а не разработчика.
#:
#: Ключи те же, что в схемах инструментов. Отсутствующий здесь аргумент
#: показывается как есть: показать сырое имя честнее, чем спрятать значение.
LABELS = {
	"customer": "Клиент",
	"customer_name": "Клиент",
	"party_name": "Клиент",
	"supplier": "Поставщик",
	"sales_order": "Заказ",
	"order": "Заказ",
	"item": "Позиция",
	"item_code": "Позиция",
	"item_name": "Позиция",
	"qty": "Количество",
	"quantity": "Количество",
	"uom": "Единица",
	"rate": "Цена",
	"amount": "Сумма",
	"total": "Сумма",
	"price": "Цена",
	"delivery_date": "Срок",
	"due_date": "Срок",
	"date": "Дата",
	"warehouse": "Склад",
	"workstation": "Рабочее место",
	"operation": "Операция",
	"employee": "Сотрудник",
	"assign_to": "Кому",
	"user": "Сотрудник",
	"text": "Текст",
	"note": "Примечание",
	"reason": "Причина",
	"address": "Адрес",
	"phone": "Телефон",
	"email": "Почта",
	"company": "Компания",
	"contract": "Договор",
	"invoice": "Счёт",
	"status": "Состояние",
}

#: Глагол в будущем времени: человек читает про то, чего ещё не случилось.
#:
#: Три формы, потому что заголовок обязан согласоваться: «будет создан счёт»,
#: «будет создана задача», «будет создано обращение». «Будет создан задача» на
#: экране, где подтверждают деньги, подрывает доверие ко всему остальному —
#: человек видит, что писали небрежно, и переносит это на суть.
TITLES = {
	"create": ("Будет создан", "Будет создана", "Будет создано"),
	"add": ("Будет добавлен", "Будет добавлена", "Будет добавлено"),
	"record": ("Будет записан", "Будет записана", "Будет записано"),
	"start": ("Будет начат", "Будет начата", "Будет начато"),
	"complete": ("Будет завершён", "Будет завершена", "Будет завершено"),
	"stop": ("Будет остановлен", "Будет остановлена", "Будет остановлено"),
	"reserve": ("Будет зарезервирован", "Будет зарезервирована", "Будет зарезервировано"),
	"accept": ("Будет принят", "Будет принята", "Будет принято"),
	"reject": ("Будет отклонён", "Будет отклонена", "Будет отклонено"),
	"assign": ("Будет назначен", "Будет назначена", "Будет назначено"),
	"set": ("Будет изменён", "Будет изменена", "Будет изменено"),
	"update": ("Будет изменён", "Будет изменена", "Будет изменено"),
	"convert": ("Будет превращён", "Будет превращена", "Будет превращено"),
	"cancel": ("Будет отменён", "Будет отменена", "Будет отменено"),
	"delete": ("Будет удалён", "Будет удалена", "Будет удалено"),
}

#: Род предмета: 0 мужской, 1 женский, 2 средний.
MASCULINE, FEMININE, NEUTER = 0, 1, 2

#: Предметы, о которых идёт речь. Второе слово заголовка.
SUBJECTS = {
	"invoice": ("счёт", MASCULINE),
	"order": ("заказ", MASCULINE),
	"deal": ("сделка", FEMININE),
	"lead": ("заявка", FEMININE),
	"task": ("задача", FEMININE),
	"quote": ("коммерческое предложение", NEUTER),
	"quotation": ("коммерческое предложение", NEUTER),
	"delivery": ("отгрузка", FEMININE),
	"contract": ("договор", MASCULINE),
	"material_request": ("заявка на материал", FEMININE),
	"purchase_order": ("заказ поставщику", MASCULINE),
	"production": ("производство", NEUTER),
	"operation": ("операция", FEMININE),
	"measurement": ("замер", MASCULINE),
	"capture": ("обращение", NEUTER),
	"item": ("позиция номенклатуры", FEMININE),
	"price": ("цена", FEMININE),
	"warehouse": ("склад", MASCULINE),
	"employee": ("сотрудник", MASCULINE),
	"installation": ("монтаж", MASCULINE),
	"inspection": ("проверка", FEMININE),
	"rework": ("переделка", FEMININE),
}


def build(tool: str, arguments: dict | None) -> dict | None:
	"""Предпросмотр действия или ничего.

	Ничего — законный ответ. Отсутствие красивого описания не повод прятать
	кнопку: приложение покажет то, что показывало раньше.
	"""
	fields = _fields(arguments or {})
	if not fields:
		return None
	return {"title": _title(tool), "fields": fields}


def _title(tool: str) -> str:
	"""«Будет создан счёт» из `sales.create_invoice`."""
	name = tool.split(".")[-1] if "." in tool else tool
	parts = name.split("_")

	forms = next((TITLES[p] for p in parts if p in TITLES), None)
	subject = next((SUBJECTS[p] for p in parts if p in SUBJECTS), None)
	if not subject:
		# Составное имя вроде `create_material_request`: пробуем целиком.
		rest = "_".join(p for p in parts if p not in TITLES)
		subject = SUBJECTS.get(rest)

	if forms and subject:
		word, gender = subject
		return f"{forms[gender]} {word}"
	if subject:
		return f"Действие: {subject[0]}"
	# Ни глагола, ни предмета — честнее назвать инструмент, чем сочинить фразу.
	return f"Действие: {tool}"


def _fields(arguments: dict) -> list[dict]:
	"""Пары «подпись — значение», без пустых и без выдуманных."""
	fields = []
	for key, value in arguments.items():
		shown = _value(value)
		if not shown:
			continue
		fields.append({"label": LABELS.get(key, key), "value": shown})
	return fields


def _value(value) -> str:
	"""Значение строкой, если его вообще стоит показывать.

	Списки и словари не разворачиваются: строка «[{'item': ...}]» человеку не
	говорит ничего, а разворачивать вложенное в накладную значит рисовать
	накладную — этим занимается экран заказа, а не карточка согласования.
	"""
	if value is None or value == "" or value == [] or value == {}:
		return ""
	if isinstance(value, bool):
		return "да" if value else "нет"
	if isinstance(value, (list, dict)):
		count = len(value)
		return f"{count} шт." if isinstance(value, list) and count else ""
	return str(value).strip()
