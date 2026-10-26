# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""A facade order, priced: pieces, m², sum, prepayment, balance.

Every number comes from this company's own settings — the price matrix
(`facade_prices`) and `Facade Pricing Settings` — which the administrator and
the order managers keep. Nothing here has a built-in rate. A rule nobody has
set is refused in words ("двусторонние фасады не настроены"), never priced at
a guess: a figure on a quote is a promise the factory has to honour.

Money is Decimal throughout and rounded once per line to whole tenge, so the
sum of the lines is the total the customer is shown.
"""

from __future__ import annotations

from decimal import ROUND_HALF_UP, Decimal, InvalidOperation

import frappe
from frappe.utils import flt

from korkem_manufacturing.services import facade_prices
from korkem_manufacturing.services.scope import current_company

TENGE = Decimal("1")
HUNDRED = Decimal("100")
PER_M2, PER_PIECE, PER_ORDER = "За м²", "За штуку", "За заказ"

#: Sanity bounds, not machine limits: a facade of 0.1 mm or 10 m is a typo.
MIN_MM, MAX_MM = 30, 3000
MAX_LINES = 200


def settings(company: str | None = None) -> dict:
	"""This company's rules, with unset ones as None."""
	company = company or current_company()
	row = frappe.db.get_value(
		"Facade Pricing Settings",
		company,
		[
			"double_sided_factor",
			"customer_material_offered",
			"customer_material_discount_percent",
			"demolition_unit",
			"demolition_rate",
			"prepayment_percent",
		],
		as_dict=True,
	) or {}
	return {
		"company": company,
		"double_sided_factor": flt(row.get("double_sided_factor")) or None,
		"customer_material_offered": bool(row.get("customer_material_offered")),
		"customer_material_discount_percent": flt(row.get("customer_material_discount_percent")),
		"demolition_unit": row.get("demolition_unit") or None,
		"demolition_rate": flt(row.get("demolition_rate")) or None,
		"prepayment_percent": flt(row.get("prepayment_percent")) if row else None,
	}


def read_settings() -> dict:
	facade_prices.ensure_editor()
	return {**settings(), "can_edit": True}


def save_settings(**values) -> dict:
	"""Change the rules. Only the fields sent are changed."""
	facade_prices.ensure_editor()
	from korkem_manufacturing.services import audit

	company = current_company()
	allowed = {
		"double_sided_factor",
		"customer_material_offered",
		"customer_material_discount_percent",
		"demolition_unit",
		"demolition_rate",
		"prepayment_percent",
	}
	changes = {k: v for k, v in values.items() if k in allowed}
	doc = (
		frappe.get_doc("Facade Pricing Settings", company)
		if frappe.db.exists("Facade Pricing Settings", company)
		else frappe.new_doc("Facade Pricing Settings")
	)
	before = settings(company)
	doc.company = company
	for key, value in changes.items():
		doc.set(key, value if value not in ("", None) else None)
	doc.save()
	audit.record_audit(
		action="settings.facade_pricing",
		entity_type="Facade Pricing Settings",
		entity_id=company,
		diff={"before": before, "after": settings(company)},
	)
	return read_settings()


def _dec(value, field: str) -> Decimal:
	try:
		number = Decimal(str(value))
	except (InvalidOperation, TypeError, ValueError):
		frappe.throw(f"{field}: нужно число, а пришло {value!r}.")
	if not number.is_finite():
		frappe.throw(f"{field}: нужно число.")
	return number


def _flag(value) -> bool:
	if isinstance(value, str):
		return value.strip().lower() in ("1", "true", "yes", "да")
	return bool(value)


def quote(
	lines: list[dict],
	*,
	demolition: bool = False,
	prepayment_amount=None,
) -> dict:
	"""Price a facade order.

	Each line: `width_mm`, `height_mm`, `qty`, `milling`, `finish`, and
	optionally `double_sided`, `customer_material`. `prepayment_amount`, when
	given, is the manager's figure and replaces the default percentage.
	"""
	facade_prices.ensure_editor()
	if isinstance(lines, str):
		lines = frappe.parse_json(lines)
	if not lines or not isinstance(lines, list):
		frappe.throw("Добавьте хотя бы один фасад.")
	if len(lines) > MAX_LINES:
		frappe.throw(f"Не больше {MAX_LINES} строк в одном расчёте.")

	company = current_company()
	rules = settings(company)
	priced = []
	pieces = 0
	area_total = Decimal("0")
	facades_total = Decimal("0")

	for index, raw in enumerate(lines, start=1):
		if not isinstance(raw, dict):
			frappe.throw(f"Строка {index}: непонятный формат.")
		label = f"Строка {index}"
		width = _dec(raw.get("width_mm"), f"{label}, ширина")
		height = _dec(raw.get("height_mm"), f"{label}, высота")
		for size, name in ((width, "ширина"), (height, "высота")):
			if not MIN_MM <= size <= MAX_MM:
				frappe.throw(f"{label}: {name} {size} мм — вне {MIN_MM}–{MAX_MM} мм.")
		qty = _dec(raw.get("qty", 1), f"{label}, количество")
		if qty != qty.to_integral_value() or qty < 1:
			frappe.throw(f"{label}: количество — целое число от 1.")
		milling = (raw.get("milling") or "").strip()
		finish = raw.get("finish") or ""
		rate = facade_prices.price_for(milling, finish, company)
		if rate is None:
			frappe.throw(f"{label}: «{milling} — {finish}» нет в прайсе. Добавьте цену в настройках.")

		notes = []
		if _flag(raw.get("double_sided")):
			factor = rules["double_sided_factor"]
			if not factor:
				frappe.throw(
					f"{label}: двусторонние фасады не настроены. Укажите коэффициент в настройках цен."
				)
			rate = rate * Decimal(str(factor))
			notes.append(f"двусторонний ×{factor:g}")
		if _flag(raw.get("customer_material")):
			if not rules["customer_material_offered"]:
				frappe.throw(f"{label}: материал заказчика не принимается — включите его в настройках цен.")
			discount = Decimal(str(rules["customer_material_discount_percent"]))
			rate = rate * (HUNDRED - discount) / HUNDRED
			notes.append(f"материал заказчика −{discount:g}%")

		piece_area = width * height / Decimal(1_000_000)
		area = piece_area * qty
		amount = (area * rate).quantize(TENGE, rounding=ROUND_HALF_UP)

		pieces += int(qty)
		area_total += area
		facades_total += amount
		priced.append(
			{
				"line": index,
				"width_mm": float(width),
				"height_mm": float(height),
				"qty": int(qty),
				"milling": milling,
				"finish": finish,
				"area_m2": float(area.quantize(Decimal("0.0001"))),
				"rate_per_m2": float(rate.quantize(TENGE, rounding=ROUND_HALF_UP)),
				"amount": float(amount),
				"notes": notes,
			}
		)

	demolition_amount = Decimal("0")
	if _flag(demolition):
		unit, demolition_rate = rules["demolition_unit"], rules["demolition_rate"]
		if not unit or not demolition_rate:
			frappe.throw("Демонтаж не настроен. Укажите способ и цену в настройках цен.")
		basis = {PER_M2: area_total, PER_PIECE: Decimal(pieces), PER_ORDER: Decimal(1)}[unit]
		demolition_amount = (basis * Decimal(str(demolition_rate))).quantize(TENGE, rounding=ROUND_HALF_UP)

	total = facades_total + demolition_amount

	if prepayment_amount not in (None, ""):
		prepayment = _dec(prepayment_amount, "Предоплата").quantize(TENGE, rounding=ROUND_HALF_UP)
		if prepayment < 0 or prepayment > total:
			frappe.throw(f"Предоплата должна быть от 0 до {total} ₸.")
		prepayment_source = "manager"
	elif rules["prepayment_percent"] is not None:
		percent = Decimal(str(rules["prepayment_percent"]))
		prepayment = (total * percent / HUNDRED).quantize(TENGE, rounding=ROUND_HALF_UP)
		prepayment_source = "settings"
	else:
		prepayment = Decimal("0")
		prepayment_source = "not_set"

	return {
		"company": company,
		"lines": priced,
		"pieces": pieces,
		"area_m2": float(area_total.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)),
		"facades_total": float(facades_total),
		"demolition": float(demolition_amount),
		"total": float(total),
		"prepayment": float(prepayment),
		"prepayment_source": prepayment_source,
		"balance": float(total - prepayment),
		"currency": "KZT",
	}
