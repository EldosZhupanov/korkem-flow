# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Поиск по материалам цеха.

## Почему поиск, а не список

Каталог живого цеха — тысячи позиций. Отдать их разом нельзя ни экрану, ни
модели: экран задохнётся, а модель получит на вход весь склад вместо ответа на
вопрос. Поэтому здесь только выборка с фильтрами и страницами.

## Что ищут на самом деле

Не название. Мебельщик держит в голове **код декора** — `W1000 ST9` — и ищет по
нему; название «белый премиум» у трёх производителей разное. Поэтому поиск идёт
по коду, названию и производителю сразу, а код виден в каждой строке.

## Чего здесь нет

Цен и остатков. Ими занимается `Item` и `Item Price` ERPNext, и заводить им
второй дом — верный способ однажды показать в двух местах разные числа.
"""

from __future__ import annotations

import frappe

from korkem_manufacturing.services.scope import current_company

DOCTYPE = "Furniture Material"
HARDWARE = "Furniture Hardware"

BOARD = "board"
EDGE = "edge"

#: Больше страницы за раз не отдаём. Не из вежливости к серверу: страница
#: существует, чтобы человек мог выбрать, а из двухсот строк не выбирают.
MAX_PAGE = 100
DEFAULT_PAGE = 50

FIELDS = (
	"name as id",
	"kind",
	"manufacturer",
	"decor_code",
	"material_name as name",
	"thickness_mm",
	"sheet_width_mm",
	"sheet_height_mm",
	"edge_width_mm",
	"fits_thickness_mm",
	"color_family",
	"active",
)


HARDWARE_FIELDS = (
	"name as id",
	"hardware_type",
	"brand",
	"model",
	"hardware_name as name",
	"overlay",
	"cup_diameter_mm",
	"cup_depth_mm",
	"mounting_system",
	"opening_angle_deg",
	"soft_close",
	"length_mm",
	"load_kg",
	"colour",
)


def search(
	*,
	query: str | None = None,
	kind: str | None = None,
	thickness: float | None = None,
	color_family: str | None = None,
	limit: int = DEFAULT_PAGE,
	start: int = 0,
) -> dict:
	"""Материалы этой компании, подходящие под запрос."""
	filters = {"company": current_company(), "active": 1}
	if kind:
		filters["kind"] = kind
	if color_family:
		filters["color_family"] = color_family
	if thickness:
		filters["thickness_mm"] = float(thickness)

	or_filters = None
	if query and query.strip():
		like = f"%{query.strip()}%"
		or_filters = {
			"decor_code": ["like", like],
			"material_name": ["like", like],
			"manufacturer": ["like", like],
		}

	limit = max(1, min(int(limit or DEFAULT_PAGE), MAX_PAGE))
	rows = frappe.get_list(
		DOCTYPE,
		filters=filters,
		or_filters=or_filters,
		fields=list(FIELDS),
		order_by="decor_code asc, material_name asc",
		limit_start=int(start or 0),
		limit_page_length=limit,
	)
	total = len(
		frappe.get_list(
			DOCTYPE,
			filters=filters,
			or_filters=or_filters,
			pluck="name",
			limit_page_length=0,
		)
	)
	return {"materials": rows, "total": total}


def hinges_for(overlay: str) -> list[dict]:
	"""Петли, которые встанут на такой фасад.

	Подбор — геометрия, а не бренд: накладная петля любого производителя
	ставится одинаково. Поэтому решает тип наложения, а не список «подходит к»,
	который пришлось бы вести руками и который разошёлся бы с действительностью
	на третьей позиции.

	Толщина фасада сюда пока не приходит, и параметра для неё нет намеренно.
	Она начнёт сужать выбор, когда в каталоге появятся петли под тонкий фасад
	(глубина чашки 10 мм против 11,3) — тогда и добавится. Аргумент, который
	принимают и не используют, обещает проверку, которой нет.
	"""
	rows = frappe.get_list(
		HARDWARE,
		filters={
			"company": current_company(),
			"active": 1,
			"hardware_type": "hinge",
			"overlay": overlay,
		},
		fields=list(HARDWARE_FIELDS),
		order_by="brand asc, model asc",
	)
	return rows


def runners_for(depth_mm: float) -> list[dict]:
	"""Направляющие, помещающиеся в корпус такой глубины.

	Направляющая длиннее корпуса не встанет — это не предпочтение, а размер.
	Ровно поэтому подбор здесь, а не у модели.
	"""
	return frappe.get_list(
		HARDWARE,
		filters={
			"company": current_company(),
			"active": 1,
			"hardware_type": "runner",
			"length_mm": ["<=", float(depth_mm)],
		},
		fields=list(HARDWARE_FIELDS),
		order_by="length_mm desc",
	)


def edges_for(thickness: float) -> list[dict]:
	"""Кромка, которой можно закрыть торец плиты этой толщины.

	Совместимость здесь — не мнение и не список «подходит к», а число: лента
	идёт под конкретную толщину плиты. Спрашивать об этом модель незачем.
	"""
	return frappe.get_list(
		DOCTYPE,
		filters={
			"company": current_company(),
			"active": 1,
			"kind": EDGE,
			"fits_thickness_mm": float(thickness),
		},
		fields=list(FIELDS),
		order_by="edge_width_mm asc",
	)
