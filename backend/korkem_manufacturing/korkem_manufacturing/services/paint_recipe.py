# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""How a square metre is painted here, and what that takes (owner,
15.11.2026: «грунт с комплектом — разбавитель, отвердитель; краска с
комплектом; водим м² — система считает, сколько кг уйдёт, цену и
окончательную цену; цены — в настройках»).

**The recipe** is the shop's own, set once: its layers — primer, enamel,
lacquer — each so many grams a square metre a coat, so many coats; and what
goes into each kilogram of it — hardener, thinner — so many kilograms per
kilogram. A layer of no coats is not painted. The enamel is the one layer of
the order's colour; the rest are the same whatever the colour.

**A plan** is the recipe applied to so many m²: kilograms of each material,
what each costs and what it all costs — and so a square metre. A
material's price is the one written in the recipe, when the shop writes one
(«цены — в настройках»); else what it costs on the shelf now (ERPNext's
average); with none on the shelf, what it last came at.

Beside the cost the recipe keeps **the shop's price a m²** for painting and
**a markup**: the calculator says what is left of a m² and of the order, and
what the markup would ask.

The store keeps the materials as `paint_stock` does: the enamel by its
colour, the others by their name with no colour — «Грунт», «Отвердитель».
"""

from __future__ import annotations

import json
from decimal import Decimal, InvalidOperation

import frappe
from frappe.utils import flt

from korkem_manufacturing.services import audit, material_stock, price_visibility
from korkem_manufacturing.services.scope import current_company

_KEY = "korkem_paint_recipe"
MAX_LAYERS = 6
MAX_PARTS = 4
MAX_G_M2 = 2000
MAX_COATS = 6
MAX_PER_KG = 5
MAX_PRICE = 10_000_000
MAX_NAME = 60
MAX_MARKUP = 1000

#: A common two-pack PU system on MDF — the shop puts in its own figures.
DEFAULT = {
	"layers": [
		{"name": "Грунт", "colour": False, "g_m2": 150, "coats": 1, "price_kg": 0,
		 "parts": [{"name": "Отвердитель", "per_kg": 0.5, "price_kg": 0},
				   {"name": "Разбавитель", "per_kg": 0.2, "price_kg": 0}]},
		{"name": "Эмаль", "colour": True, "g_m2": 120, "coats": 2, "price_kg": 0,
		 "parts": [{"name": "Отвердитель", "per_kg": 0.5, "price_kg": 0},
				   {"name": "Разбавитель", "per_kg": 0.2, "price_kg": 0}]},
		{"name": "Лак", "colour": False, "g_m2": 100, "coats": 0, "price_kg": 0,
		 "parts": [{"name": "Отвердитель", "per_kg": 0.5, "price_kg": 0},
				   {"name": "Разбавитель", "per_kg": 0.2, "price_kg": 0}]},
	],
	"price_m2": 0,
	"markup_pct": 0,
}


def _name(value) -> str:
	return " ".join(str(value or "").split())[:MAX_NAME]


def _number(value, label: str, top: float) -> float:
	try:
		figure = Decimal(str(value if value not in (None, "") else 0).replace(",", ".").replace(" ", ""))
	except (InvalidOperation, ValueError):
		frappe.throw(f"{label} — число.")
	if not figure.is_finite() or figure < 0 or figure > Decimal(str(top)):
		frappe.throw(f"{label} — от нуля до {top:g}.")
	return float(figure)


def _clean(recipe) -> dict:
	"""The recipe as sent, checked: names, figures in their bounds, one
	colour layer at most."""
	if isinstance(recipe, str):
		try:
			recipe = json.loads(recipe)
		except ValueError:
			frappe.throw("Рецепт не читается.")
	layers = (recipe or {}).get("layers") if isinstance(recipe, dict) else None
	if not isinstance(layers, list) or not layers:
		frappe.throw("В рецепте нет ни одного слоя.")
	if len(layers) > MAX_LAYERS:
		frappe.throw(f"Слоёв — не больше {MAX_LAYERS}.")
	out, seen, coloured = [], set(), 0
	for raw in layers:
		raw = raw if isinstance(raw, dict) else {}
		name = _name(raw.get("name"))
		if not name:
			frappe.throw("У слоя нет названия.")
		if name.lower() in seen:
			frappe.throw(f"Слой «{name}» дважды.")
		seen.add(name.lower())
		colour = bool(raw.get("colour"))
		coloured += colour
		parts, part_names = [], set()
		for p in (raw.get("parts") or [])[:MAX_PARTS]:
			p = p if isinstance(p, dict) else {}
			part = _name(p.get("name"))
			if not part:
				continue
			if part.lower() in part_names or part.lower() == name.lower():
				frappe.throw(f"«{part}» в слое «{name}» дважды.")
			part_names.add(part.lower())
			parts.append({"name": part, "per_kg": _number(p.get("per_kg"), f"{part} на 1 кг", MAX_PER_KG),
						  "price_kg": _number(p.get("price_kg"), f"Цена «{part}»", MAX_PRICE)})
		out.append({
			"name": name, "colour": colour,
			"g_m2": _number(raw.get("g_m2"), f"Расход «{name}», г/м²", MAX_G_M2),
			"coats": int(_number(raw.get("coats"), f"Слоёв «{name}»", MAX_COATS)),
			"price_kg": _number(raw.get("price_kg"), f"Цена «{name}»", MAX_PRICE),
			"parts": parts,
		})
	if coloured > 1:
		frappe.throw("Цвет заказа — у одного слоя, эмали.")
	return {"layers": out, "price_m2": _number(recipe.get("price_m2"), "Цена за м²", MAX_PRICE),
			"markup_pct": _number(recipe.get("markup_pct"), "Наценка, %", MAX_MARKUP)}


def recipe(company: str | None = None) -> dict:
	"""The shop's recipe; the common one until it says its own."""
	raw = frappe.db.get_default(f"{_KEY}:{company or current_company()}")
	if raw:
		try:
			return _clean(json.loads(raw))
		except (ValueError, frappe.ValidationError):
			pass
	return json.loads(json.dumps(DEFAULT))


def set_recipe(value) -> dict:
	"""The shop's own recipe — whoever keeps the store sets it."""
	material_stock._ensure_editor()
	clean = _clean(value)
	company = current_company()
	frappe.db.set_default(f"{_KEY}:{company}", json.dumps(clean, ensure_ascii=False))
	audit.record_audit(action="paint.recipe", entity_type="Company", entity_id=company, diff=clean)
	return {"recipe": clean, "kg_m2": kg_m2(clean)}


def kg_m2(rec: dict | None = None) -> float:
	"""Kilograms a square metre takes by the recipe, every material together."""
	rec = rec or recipe()
	total = 0.0
	for layer in rec["layers"]:
		kg = layer["g_m2"] / 1000 * layer["coats"]
		total += kg * (1 + sum(p["per_kg"] for p in layer["parts"]))
	return round(total, 3)


def materials(m2: float, rec: dict | None = None) -> list[dict]:
	"""Kilograms of each material for so many m²: the colour layer flagged;
	a material in several layers (one hardener for primer and enamel) once,
	added up. In the recipe's order."""
	rec = rec or recipe()
	out: dict[tuple[str, bool], dict] = {}
	for layer in rec["layers"]:
		if not layer["coats"] or not layer["g_m2"]:
			continue
		kg = m2 * layer["g_m2"] / 1000 * layer["coats"]
		rows = [(layer["name"], layer["colour"], kg, layer["price_kg"])]
		rows += [(p["name"], False, kg * p["per_kg"], p["price_kg"]) for p in layer["parts"] if p["per_kg"]]
		for name, colour, amount, price in rows:
			row = out.setdefault((name.lower(), colour), {"name": name, "colour": colour, "kg": 0.0,
														   "recipe_price_kg": price})
			row["kg"] += amount
			row["recipe_price_kg"] = row["recipe_price_kg"] or price
	return [{**r, "kg": round(r["kg"], 2)} for r in out.values() if round(r["kg"], 2) > 0]


def items_of(name: str, company: str) -> list[str]:
	"""The store's materials of a name and no colour — «Грунт», and any
	«Грунт …» kept apart (owner's own names) — the exact name first."""
	low = name.lower()
	rows = frappe.get_all(
		"Item",
		filters={"korkem_material_company": company, "korkem_material_kind": material_stock.PAINT,
				 "korkem_color": ["is", "not set"]},
		fields=["name", "korkem_paint_base"],
		limit_page_length=0,
	)
	found = [r for r in rows if (r.korkem_paint_base or "").lower() == low
			 or (r.korkem_paint_base or "").lower().startswith(low + " ")]
	return [r.name for r in sorted(found, key=lambda r: (r.korkem_paint_base or "").lower() != low)]


def _price(items: list[str], company: str) -> float | None:
	"""What a kilo of these costs: on the shelf now, else as last bought."""
	from korkem_manufacturing.services import paint_stock

	if not items:
		return None
	on_hand = material_stock._stock(items, company)
	kg = sum(q for q, _ in on_hand.values() if q > 0)
	if kg:
		return round(sum(q * p for q, p in on_hand.values() if q > 0) / kg, 2)
	last = paint_stock._last_receipts(items, company)
	rates = [flt(d.basic_rate) for d in last.values() if flt(d.basic_rate)]
	return rates[0] if rates else None


def plan(m2, colour: str | None = None, company: str | None = None, rec: dict | None = None) -> dict:
	"""What so many m² take: each material in kg, at what a kilo, for how
	much; the total, and a square metre. `colour`: the enamel's own price is
	that colour's."""
	from korkem_manufacturing.services import paint_stock

	company = company or current_company()
	area = _number(m2, "Площадь, м²", 100_000)
	rec = rec or recipe(company)
	allowed = price_visibility.can_see_prices()
	lines, total, priced = [], 0.0, True
	for row in materials(area, rec):
		if row["colour"]:
			items = [i for i, _ in paint_stock._paints_of(company, colour)] if colour else []
		else:
			items = items_of(row["name"], company)
		price = row["recipe_price_kg"] or _price(items, company) or None
		cost = round(row["kg"] * price, 2) if price else None
		if cost is None:
			priced = False
		else:
			total += cost
		lines.append({
			"name": row["name"], "colour": colour if row["colour"] else None, "kg": row["kg"],
			"price_kg": price_visibility.money(price, allowed=allowed) if price else None,
			"cost": price_visibility.money(cost, allowed=allowed) if cost is not None else None,
		})
	total = round(total, 2)
	price_m2, markup = rec.get("price_m2") or 0, rec.get("markup_pct") or 0
	return {
		"m2": area, "colour": colour, "lines": lines,
		"price_m2": price_visibility.money(price_m2, allowed=allowed) if price_m2 else None,
		"markup_pct": markup,
		"kg": round(sum(line["kg"] for line in lines), 2),
		"cost": price_visibility.money(total, allowed=allowed),
		"cost_m2": price_visibility.money(round(total / area, 2), allowed=allowed) if area else None,
		# A material with no price anywhere leaves the total short — said so.
		"priced": priced,
	}


def request_text(m2, colour: str | None = None, company: str | None = None) -> str:
	"""What to ask the supplier who tints, or the customer who brings his own:
	«RAL 9016 · глянец — 14 м²: Эмаль 3,36 кг; Отвердитель 2,73 кг; …»."""
	return text_of(plan(m2, colour, company))


def text_of(p: dict) -> str:
	head = " — ".join(x for x in (p.get("colour"), f"{_fmt(p['m2'])} м²") if x)
	return head + ": " + "; ".join(f"{line['name']} {_fmt(line['kg'])} кг" for line in p["lines"])


def _fmt(value: float) -> str:
	return f"{value:g}".replace(".", ",")
