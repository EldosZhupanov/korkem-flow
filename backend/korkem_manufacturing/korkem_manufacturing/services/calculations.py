"""Exact, stateless geometry. No prices, stock assertions or cutting optimizer.

Inputs explicitly use millimetres and pieces. Decimal strings in results avoid
rounding an exact area at the JSON boundary. Bounds limit computational abuse,
not the manufacturing capabilities of a particular machine.
"""

from decimal import ROUND_CEILING, Decimal


def _number(value, name, *, minimum=0, maximum=1000000, positive=True):
	if isinstance(value, bool) or not isinstance(value, (int, float, Decimal)):
		raise ValueError(f"{name} must be a number")
	result = Decimal(str(value))
	if not result.is_finite() or result < minimum or result > maximum or (positive and result == minimum):
		raise ValueError(f"{name} is outside the permitted range")
	return result


def _count(value, name="quantity", *, minimum=1, maximum=1000000):
	if isinstance(value, bool) or not isinstance(value, int) or not minimum <= value <= maximum:
		raise ValueError(f"{name} must be an integer from {minimum} to {maximum}")
	return value


def _text(value):
	return format(value, "f").rstrip("0").rstrip(".") if "." in format(value, "f") else format(value, "f")


def calculate_panel_area(width_mm, height_mm, quantity):
	width = _number(width_mm, "width_mm")
	height = _number(height_mm, "height_mm")
	quantity = _count(quantity)
	area = width * height / Decimal(1000000)
	return {
		"area_m2": _text(area * quantity),
		"piece_area_m2": _text(area),
		"quantity": quantity,
		"unit": "m²",
		"source": "domain_calculation",
	}


def calculate_facade_area(width_mm, height_mm, quantity):
	return calculate_panel_area(width_mm, height_mm, quantity)


def calculate_edge_length(width_mm, height_mm, quantity, *, width_edges, height_edges):
	width = _number(width_mm, "width_mm")
	height = _number(height_mm, "height_mm")
	quantity = _count(quantity)
	w = _count(width_edges, "width_edges", minimum=0, maximum=2)
	h = _count(height_edges, "height_edges", minimum=0, maximum=2)
	length = (width * w + height * h) * quantity / Decimal(1000)
	return {"length_m": _text(length), "unit": "m", "quantity": quantity, "source": "domain_calculation"}


def calculate_material_quantity(
	width_mm, height_mm, quantity, *, sheet_width_mm, sheet_height_mm, waste_percent
):
	area = calculate_panel_area(width_mm, height_mm, quantity)
	sw = _number(sheet_width_mm, "sheet_width_mm")
	sh = _number(sheet_height_mm, "sheet_height_mm")
	waste = _number(waste_percent, "waste_percent", maximum=100, positive=False)
	w, h = Decimal(str(width_mm)), Decimal(str(height_mm))
	if not ((w <= sw and h <= sh) or (w <= sh and h <= sw)):
		raise ValueError("Panel does not fit the sheet in either orientation")
	required = Decimal(area["area_m2"]) * (1 + waste / 100)
	sheet_area = sw * sh / Decimal(1000000)
	return {
		"required_area_m2": _text(required),
		"sheet_area_m2": _text(sheet_area),
		"minimum_sheets": int((required / sheet_area).to_integral_value(rounding=ROUND_CEILING)),
		"cut_plan_verified": False,
		"unit": "m²",
		"source": "domain_calculation",
		"warning": "Area lower bound only. Grain, kerf and nesting are not calculated.",
	}


def calculate_quote(
	*,
	materials: list[dict] | None = None,
	operations: list[dict] | None = None,
	markup_percent: float = 30.0,
	waste_percent: float = 10.0,
	outsourcing_cost: float = 0.0,
	overhead_percent: float = 5.0,
	sales_order: str | None = None,
) -> dict:
	"""Детерминированный расчёт себестоимости и коммерческого предложения (Quote).

	Все финансовые вычисления проводятся в Decimal с фиксацией до 2 знаков.
	Никаких приблизительных расчетов и LLM-галлюцинаций.

	Output:
	- materials_cost
	- hardware_cost
	- facades_cost
	- edge_cost
	- labor_cost
	- outsourcing_cost
	- waste_cost
	- overhead_cost
	- total_cost
	- margin
	- selling_price
	- breakdown (детализированная смета для клиента и владельца)
	"""
	from decimal import Decimal, ROUND_HALF_UP

	def _d(v):
		return Decimal(str(v or 0)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)

	mat_cost = Decimal("0.00")
	hw_cost = Decimal("0.00")
	fcd_cost = Decimal("0.00")
	edg_cost = Decimal("0.00")

	for item in materials or []:
		qty = Decimal(str(item.get("qty") or item.get("qty_required") or 1))
		rate = Decimal(str(item.get("rate") or item.get("price") or 0))
		item_total = qty * rate
		code = (item.get("item_code") or item.get("code") or "").upper()
		kind = (item.get("kind") or item.get("item_group") or "").upper()

		if "EDGE" in code or "КРОМКА" in code:
			edg_cost += item_total
		elif "FACADE" in code or "ФАСАД" in code or "MDF" in code:
			fcd_cost += item_total
		elif "HINGE" in code or "RUNNER" in code or "HANDLE" in code or "ФУРНИТУРА" in kind or "NOS" in str(item.get("stock_uom", "")).upper():
			hw_cost += item_total
		else:
			mat_cost += item_total

	# Прямая стоимость материалов
	direct_materials = mat_cost + hw_cost + fcd_cost + edg_cost

	# Технологический отход (waste) на листовой материал и кромку
	waste_pct = Decimal(str(waste_percent))
	waste_cost = ((mat_cost + fcd_cost + edg_cost) * (waste_pct / Decimal("100"))).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)

	# Оплата труда (Labor) по операциям
	labor_cost = Decimal("0.00")
	for op in operations or []:
		op_qty = Decimal(str(op.get("qty") or op.get("quantity") or 1))
		op_rate = Decimal(str(op.get("rate") or op.get("price") or 0))
		labor_cost += op_qty * op_rate
	labor_cost = labor_cost.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)

	outsource = _d(outsourcing_cost)

	# Накладные цеховые расходы (Overhead)
	overhead_pct = Decimal(str(overhead_percent))
	overhead_cost = ((direct_materials + labor_cost) * (overhead_pct / Decimal("100"))).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)

	# Итоговая производственная себестоимость
	total_cost = direct_materials + waste_cost + labor_cost + outsource + overhead_cost

	# Наценка и продажная стоимость
	markup_pct = Decimal(str(markup_percent))
	margin = (total_cost * (markup_pct / Decimal("100"))).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
	selling_price = total_cost + margin

	# Explainable breakdown
	tot_float = float(total_cost) if total_cost > 0 else 1.0
	breakdown = [
		{"category": "Плитные материалы (ЛДСП)", "amount": float(mat_cost), "share_pct": round(float(mat_cost) / tot_float * 100, 1)},
		{"category": "Фасады (МДФ)", "amount": float(fcd_cost), "share_pct": round(float(fcd_cost) / tot_float * 100, 1)},
		{"category": "Кромочные материалы", "amount": float(edg_cost), "share_pct": round(float(edg_cost) / tot_float * 100, 1)},
		{"category": "Фурнитура и крепеж", "amount": float(hw_cost), "share_pct": round(float(hw_cost) / tot_float * 100, 1)},
		{"category": "Технологический отход (Waste)", "amount": float(waste_cost), "share_pct": round(float(waste_cost) / tot_float * 100, 1)},
		{"category": "Оплата труда (Сдельная)", "amount": float(labor_cost), "share_pct": round(float(labor_cost) / tot_float * 100, 1)},
		{"category": "Аутсорсинг и подряд", "amount": float(outsource), "share_pct": round(float(outsource) / tot_float * 100, 1)},
		{"category": "Цеховые накладные расходы", "amount": float(overhead_cost), "share_pct": round(float(overhead_cost) / tot_float * 100, 1)},
	]

	return {
		"sales_order": sales_order,
		"materials_cost": float(mat_cost),
		"facades_cost": float(fcd_cost),
		"edge_cost": float(edg_cost),
		"hardware_cost": float(hw_cost),
		"direct_materials_cost": float(direct_materials),
		"waste_cost": float(waste_cost),
		"labor_cost": float(labor_cost),
		"outsourcing_cost": float(outsource),
		"overhead_cost": float(overhead_cost),
		"total_cost": float(total_cost),
		"margin": float(margin),
		"selling_price": float(selling_price),
		"markup_percent": float(markup_pct),
		"breakdown": breakdown,
	}

