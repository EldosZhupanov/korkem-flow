"""«Узоры ЧПУ» — facade patterns to G-code, behind a switch (owner, 18.11.2026).

The owner: «загружать и тестировать, но он пока не должен вмешиваться в
работу приложения». So the module is a sandbox, four ways:

1. **A switch, off by default, per site.** The working base and the test
   base each keep their own; turning it on in the test base leaves the
   working one exactly as it was. Only the owner turns it on, and names who
   else may see it.
2. **It changes nothing it does not own.** It reads an order's sizes and
   millings; it never writes an order, the store, money or a stage. Its own
   things — the cutters, the patterns, the machine — live in one settings
   record, so switching it off removes it whole.
3. **Nothing goes to the machine by itself.** The result is a file; the
   operator looks at it and runs it.
4. **Examples, not truths.** The patterns it starts with are marked as
   examples, to be cut on an offcut before a facade.

The geometry and the G-code are `cnc_geometry`, pure functions.
"""

from __future__ import annotations

import json
import re

import frappe
from frappe.utils import cint, flt, now

from korkem_manufacturing.services import audit, cnc_geometry, staff
from korkem_manufacturing.services.cnc_geometry import MACHINE_DEFAULT, PatternError, Tool
from korkem_manufacturing.services.scope import current_company

_KEY = "korkem_cnc_patterns"
NAME_MAX = 60
ELEMENTS_MAX = 6

#: What a shop starts with — the commonest MDF facade styles, as examples.
SEED_TOOLS = {
	"V-90° 12 мм": {"kind": "v", "diameter": 12.0, "angle": 90.0, "feed": 3000.0, "plunge": 1000.0,
					"rpm": 18000.0, "pass_depth": 3.0},
	"Радиусная R3 (6 мм)": {"kind": "ball", "diameter": 6.0, "angle": 0.0, "feed": 2500.0, "plunge": 800.0,
							"rpm": 18000.0, "pass_depth": 2.0},
}
SEED_PATTERNS = {
	"Классика": {"milling": "Классика", "min_w": 250, "min_h": 250, "fallback": None, "example": True,
				 "elements": [{"kind": "frame", "tool": "V-90° 12 мм", "depth": 4, "offset": 60,
							   "corner": "cove", "radius": 15}]},
	"Квадро": {"milling": "Квадро", "min_w": 200, "min_h": 200, "fallback": None, "example": True,
			   "elements": [{"kind": "frame", "tool": "V-90° 12 мм", "depth": 3, "offset": 50,
							 "corner": "round", "radius": 10}]},
	"Рифлёный": {"milling": "Рифлёный", "min_w": 100, "min_h": 100, "fallback": None, "example": True,
				 "elements": [{"kind": "grooves", "tool": "Радиусная R3 (6 мм)", "depth": 3,
							   "direction": "vertical", "step": 30, "side": 0, "ends": 0}]},
	"Модерн": {"milling": "Модерн", "min_w": 300, "min_h": 300, "fallback": "Квадро", "example": True,
			   "elements": [{"kind": "frame", "tool": "V-90° 12 мм", "depth": 3, "offset": 50,
							 "corner": "square", "radius": 0},
							{"kind": "grooves", "tool": "Радиусная R3 (6 мм)", "depth": 2,
							 "direction": "horizontal", "step": 40, "side": 80, "ends": 80}]},
	"Арка": {"milling": "Арка", "min_w": 300, "min_h": 400, "fallback": "Классика", "example": True,
			 "elements": [{"kind": "arch", "tool": "V-90° 12 мм", "depth": 4, "offset": 60, "rise": 80}]},
}
ELEMENT_KEYS = {
	"frame": ("offset", "corner", "radius"),
	"arch": ("offset", "rise"),
	"grooves": ("direction", "step", "side", "ends"),
}
ELEMENT_LIMITS = {"depth": (0.1, 30), "offset": (1, 1500), "radius": (0, 500), "rise": (1, 1500),
				  "step": (1, 500), "side": (0, 1500), "ends": (0, 1500)}


# --------------------------------------------------------------------------
# The switch, and who sees it
# --------------------------------------------------------------------------


def _settings(company: str) -> dict:
	raw = frappe.db.get_default(f"{_KEY}:{company}")
	try:
		value = json.loads(raw) if raw else {}
	except ValueError:
		value = {}
	return {
		"enabled": bool(value.get("enabled")),
		"users": [u for u in value.get("users") or [] if isinstance(u, str)],
		"tools": dict(value.get("tools") or {}),
		"patterns": dict(value.get("patterns") or {}),
		"machine": {**MACHINE_DEFAULT, **dict(value.get("machine") or {})},
		"changed_by": value.get("changed_by"),
		"changed_on": value.get("changed_on"),
	}


def _save(company: str, settings: dict) -> None:
	settings = {**settings, "changed_by": frappe.session.user, "changed_on": now()}
	frappe.db.set_default(f"{_KEY}:{company}", json.dumps(settings, ensure_ascii=False))


def can_manage() -> bool:
	"""Turning the module on, and its library: the owner's."""
	return staff.can_invite()


def visible(company: str | None = None) -> bool:
	"""Is the module on here, for the one asking."""
	company = company or current_company()
	settings = _settings(company)
	return settings["enabled"] and (can_manage() or frappe.session.user in settings["users"])


def _ensure_visible() -> tuple[str, dict]:
	company = current_company()
	settings = _settings(company)
	if not (settings["enabled"] and (can_manage() or frappe.session.user in settings["users"])):
		frappe.throw("«Узоры ЧПУ» выключены. Включает владелец: «Справочники и цены» → «Узоры ЧПУ».",
					 frappe.PermissionError)
	return company, settings


def _ensure_manage() -> tuple[str, dict]:
	if not can_manage():
		frappe.throw("Менять «Узоры ЧПУ» может только владелец.", frappe.PermissionError)
	company = current_company()
	return company, _settings(company)


def status() -> dict:
	"""The switch, and — when on — the library, the machine and the millings to link."""
	company = current_company()
	settings = _settings(company)
	manage = can_manage()
	shown = settings["enabled"] and (manage or frappe.session.user in settings["users"])
	out = {"enabled": settings["enabled"], "visible": shown, "can_manage": manage}
	if manage:
		out["users"] = settings["users"]
		out["people"] = [{"user": p["email"], "name": p["full_name"]} for p in staff.members()
						 if p.get("enabled") and not p.get("is_owner")]
	if shown:
		from korkem_manufacturing.services import facade_prices

		out["tools"] = [{"name": n, **c} for n, c in sorted(settings["tools"].items())]
		out["patterns"] = [{"name": n, **c} for n, c in sorted(settings["patterns"].items())]
		out["machine"] = settings["machine"]
		out["millings"] = facade_prices.millings(company)
	return out


def set_enabled(enabled: bool, users: list[str] | None = None) -> dict:
	"""On or off, and who besides the owner sees it. The first time on, the
	example cutters and patterns arrive, so there is something to try."""
	company, settings = _ensure_manage()
	allowed = {p["email"] for p in staff.members()}
	if users is not None:
		unknown = [u for u in users if u not in allowed]
		if unknown:
			frappe.throw(f"Нет такого сотрудника: {', '.join(unknown)}.")
		settings["users"] = list(dict.fromkeys(users))
	settings["enabled"] = bool(enabled)
	if settings["enabled"] and not settings["tools"] and not settings["patterns"]:
		settings["tools"] = json.loads(json.dumps(SEED_TOOLS))
		settings["patterns"] = json.loads(json.dumps(SEED_PATTERNS))
	_save(company, settings)
	audit.record_audit(action="cnc_patterns.switch", entity_type="Company", entity_id=company,
					   diff={"enabled": settings["enabled"], "users": settings["users"]}, company=company)
	return status()


# --------------------------------------------------------------------------
# The library: cutters, patterns, the machine
# --------------------------------------------------------------------------


def _name(value, what: str) -> str:
	name = re.sub(r"\s+", " ", str(value or "")).strip()
	if not name or len(name) > NAME_MAX:
		frappe.throw(f"Название {what} — от 1 до {NAME_MAX} знаков.")
	return name


def _limited(value, key: str, limits: dict, what: str) -> float:
	low, high = limits[key]
	try:
		number = float(value)
	except (TypeError, ValueError):
		frappe.throw(f"{what}: «{key}» — число.")
	if not low <= number <= high:
		frappe.throw(f"{what}: «{key}» — от {low:g} до {high:g}.")
	return number


def _tool_card(name: str, kind: str, diameter, angle=None, feed=None, plunge=None, rpm=None,
			   pass_depth=None) -> dict:
	if kind not in cnc_geometry.TOOL_KINDS:
		frappe.throw("Фреза — V-образная, радиусная или прямая.")
	base = Tool(name=name, kind=kind)
	card = {"kind": kind}
	for key, value in (("diameter", diameter), ("angle", angle), ("feed", feed), ("plunge", plunge),
					   ("rpm", rpm), ("pass_depth", pass_depth)):
		if key == "angle" and kind != "v":
			card[key] = 0.0
			continue
		card[key] = _limited(getattr(base, key) if value in (None, "") else value, key,
							 cnc_geometry.TOOL_LIMITS, "Фреза")
	return card


def save_tool(name: str, kind: str, diameter, angle=None, feed=None, plunge=None, rpm=None, pass_depth=None,
			  old_name: str | None = None) -> dict:
	"""A cutter: its shape, size and the speeds it cuts MDF at."""
	company, settings = _ensure_manage()
	name = _name(name, "фрезы")
	card = _tool_card(name, kind, diameter, angle, feed, plunge, rpm, pass_depth)
	if old_name and old_name != name:
		_rename(settings, "tools", old_name, name)
		for pattern in settings["patterns"].values():
			for element in pattern.get("elements") or []:
				if element.get("tool") == old_name:
					element["tool"] = name
	elif name in settings["tools"] and not old_name:
		frappe.throw(f"Фреза «{name}» уже есть.")
	settings["tools"][name] = card
	_save(company, settings)
	audit.record_audit(action="cnc_patterns.tool", entity_type="Company", entity_id=company,
					   diff={"tool": name, **card}, company=company)
	return status()


# --- ArtCAM's tool database (owner, 19.11.2026) ---------------------------

#: What a tool of the file cannot be here, in words.
_WHY = {
	"profile": "фасонная фреза — узоры её пока не режут",
	"have": "такая фреза уже есть",
}


def _artcam_rows(content_b64: str, settings: dict) -> list[dict]:
	import base64

	from korkem_manufacturing.services import artcam_tools

	try:
		content = base64.b64decode(content_b64 or "", validate=False)
	except ValueError:
		frappe.throw("Файл не прочитался.")
	try:
		tools = artcam_tools.read(content)
	except ValueError as e:
		frappe.throw(str(e))
	rows = []
	for index, t in enumerate(tools):
		row = {**{k: t[k] for k in ("group", "name", "artcam_type", "kind", "diameter", "angle", "pass_depth",
									 "rpm", "feed", "plunge")}, "index": index, "card": None, "why": None}
		if not t["kind"]:
			row["why"] = _WHY["profile"]
		elif t["name"] in settings["tools"]:
			row["why"] = _WHY["have"]
		else:
			try:
				row["card"] = _tool_card(t["name"][:NAME_MAX], t["kind"], t["diameter"], t["angle"], t["feed"],
										 t["plunge"], t["rpm"], t["pass_depth"])
			except frappe.ValidationError as e:
				row["why"] = _artcam_limit(str(e))
			frappe.clear_messages()
		rows.append(row)
	return rows


def _artcam_limit(message: str) -> str:
	words = {"diameter": "диаметр", "angle": "угол", "feed": "подача", "plunge": "врезание",
			 "rpm": "обороты", "pass_depth": "глубина за проход"}
	for key, word in words.items():
		if f"«{key}»" in message:
			low, high = cnc_geometry.TOOL_LIMITS[key]
			return f"{word} вне {low:g}–{high:g} — проверьте в ArtCAM"
	return message


def artcam_preview(content_b64: str) -> dict:
	"""A tool database from ArtCAM, read: each tool, what it would be here
	— or why it cannot be. Nothing is written."""
	_company, settings = _ensure_manage()
	rows = _artcam_rows(content_b64, settings)
	return {"tools": rows, "ready": sum(1 for r in rows if r["card"])}


def artcam_add(content_b64: str, picked) -> dict:
	"""The tools picked from the file, added. The file is read again: the
	server takes its own reading, not the window's."""
	company, settings = _ensure_manage()
	if isinstance(picked, str):
		picked = json.loads(picked or "[]")
	wanted = {cint(i) for i in picked or []}
	added = []
	for row in _artcam_rows(content_b64, settings):
		if row["index"] in wanted and row["card"] and row["name"][:NAME_MAX] not in settings["tools"]:
			settings["tools"][row["name"][:NAME_MAX]] = row["card"]
			added.append(row["name"][:NAME_MAX])
	if added:
		_save(company, settings)
		audit.record_audit(action="cnc_patterns.tools_imported", entity_type="Company", entity_id=company,
						   diff={"from": "ArtCAM", "tools": added}, company=company)
	return status() | {"added": added}


def delete_tool(name: str) -> dict:
	company, settings = _ensure_manage()
	users = [p for p, c in settings["patterns"].items()
			 if any(e.get("tool") == name for e in c.get("elements") or [])]
	if users:
		frappe.throw(f"Фрезой «{name}» режут узоры: {', '.join(users)}. Сначала поменяйте фрезу в них.")
	settings["tools"].pop(name, None)
	_save(company, settings)
	audit.record_audit(action="cnc_patterns.tool_deleted", entity_type="Company", entity_id=company,
					   diff={"tool": name}, company=company)
	return status()


def _rename(settings: dict, kind: str, old: str, new: str) -> None:
	if old not in settings[kind]:
		frappe.throw(f"Нет «{old}».")
	if new in settings[kind]:
		frappe.throw(f"«{new}» уже есть.")
	settings[kind][new] = settings[kind].pop(old)


def _clean_pattern(settings: dict, name: str, milling, min_w, min_h, fallback, elements) -> dict:
	if isinstance(elements, str):
		try:
			elements = json.loads(elements)
		except ValueError:
			frappe.throw("Элементы узора не прочитались.")
	if not isinstance(elements, list) or not 1 <= len(elements) <= ELEMENTS_MAX:
		frappe.throw(f"В узоре — от 1 до {ELEMENTS_MAX} элементов.")
	clean = []
	for i, element in enumerate(elements, 1):
		what = f"Элемент {i}"
		kind = element.get("kind") if isinstance(element, dict) else None
		if kind not in ELEMENT_KEYS:
			frappe.throw(f"{what}: рамка, арка или пазы.")
		tool = element.get("tool")
		if tool not in settings["tools"]:
			frappe.throw(f"{what}: нет фрезы «{tool or ''}».")
		item = {"kind": kind, "tool": tool, "depth": _limited(element.get("depth"), "depth", ELEMENT_LIMITS, what)}
		for key in ELEMENT_KEYS[kind]:
			value = element.get(key)
			if key == "corner":
				item[key] = value if value in cnc_geometry.CORNERS else "square"
			elif key == "direction":
				item[key] = value if value in cnc_geometry.DIRECTIONS else "vertical"
			else:
				item[key] = _limited(0 if value in (None, "") else value, key, ELEMENT_LIMITS, what)
		clean.append(item)
	if fallback and (fallback == name or fallback not in settings["patterns"]):
		frappe.throw("Запасной узор — другой узор из списка.")
	return {"milling": (str(milling).strip() or None) if milling else None,
			"min_w": cint(min_w) or 0, "min_h": cint(min_h) or 0, "fallback": fallback or None,
			"example": False, "elements": clean}


def save_pattern(name: str, elements, milling: str | None = None, min_w=0, min_h=0,
				 fallback: str | None = None, old_name: str | None = None) -> dict:
	"""A pattern: its elements, the milling it cuts, the smallest facade it
	fits and the pattern for smaller ones."""
	company, settings = _ensure_manage()
	name = _name(name, "узора")
	card = _clean_pattern(settings, name, milling, min_w, min_h, fallback, elements)
	if card["milling"]:
		taken = [p for p, c in settings["patterns"].items()
				 if c.get("milling") == card["milling"] and p not in (name, old_name)]
		if taken:
			frappe.throw(f"Фрезеровка «{card['milling']}» уже у узора «{taken[0]}».")
	if old_name and old_name != name:
		_rename(settings, "patterns", old_name, name)
		for other in settings["patterns"].values():
			if other.get("fallback") == old_name:
				other["fallback"] = name
	elif name in settings["patterns"] and not old_name:
		frappe.throw(f"Узор «{name}» уже есть.")
	settings["patterns"][name] = card
	_save(company, settings)
	audit.record_audit(action="cnc_patterns.pattern", entity_type="Company", entity_id=company,
					   diff={"pattern": name, **card}, company=company)
	return status()


def delete_pattern(name: str) -> dict:
	company, settings = _ensure_manage()
	settings["patterns"].pop(name, None)
	for other in settings["patterns"].values():
		if other.get("fallback") == name:
			other["fallback"] = None
	_save(company, settings)
	audit.record_audit(action="cnc_patterns.pattern_deleted", entity_type="Company", entity_id=company,
					   diff={"pattern": name}, company=company)
	return status()


def set_machine(**values) -> dict:
	"""How the router wants its program: extension, arcs, comments, line
	numbers, heights, the rapid speed, axes."""
	company, settings = _ensure_manage()
	machine = dict(settings["machine"])
	for key in ("comments", "arcs", "line_numbers", "swap_xy"):
		if key in values and values[key] is not None:
			machine[key] = bool(cint(values[key]))
	if values.get("ext"):
		if values["ext"] not in cnc_geometry.EXTENSIONS:
			frappe.throw(f"Расширение — одно из: {', '.join(cnc_geometry.EXTENSIONS)}.")
		machine["ext"] = values["ext"]
	for key in cnc_geometry.MACHINE_LIMITS:
		if values.get(key) not in (None, ""):
			machine[key] = _limited(values[key], key, cnc_geometry.MACHINE_LIMITS, "Станок")
	if machine["clear_z"] >= machine["safe_z"]:
		frappe.throw("Высота подхода должна быть ниже безопасной высоты.")
	settings["machine"] = machine
	_save(company, settings)
	audit.record_audit(action="cnc_patterns.machine", entity_type="Company", entity_id=company, diff=machine,
					   company=company)
	return status()


# --------------------------------------------------------------------------
# A pattern on a facade
# --------------------------------------------------------------------------


def _tools(settings: dict) -> dict[str, Tool]:
	return {n: Tool.of(n, c) for n, c in settings["tools"].items()}


def _resolve(settings: dict, pattern: str | dict, w: float, h: float) -> tuple[str, dict, str | None]:
	"""The pattern to cut — its fallback when the facade is smaller than it
	allows; and a sentence saying so."""
	if isinstance(pattern, dict):
		return pattern.get("name") or "—", pattern, None
	seen = []
	name = pattern
	while True:
		card = settings["patterns"].get(name)
		if card is None:
			raise PatternError(f"Нет узора «{name}».")
		short, long_ = min(w, h), max(w, h)
		small, big = sorted((flt(card.get("min_w")), flt(card.get("min_h"))))
		if short >= small and long_ >= big:
			note = f"Фасад меньше, чем нужен «{pattern}» — режется «{name}»." if seen else None
			return name, card, note
		seen.append(name)
		fallback = card.get("fallback")
		if not fallback or fallback in seen:
			raise PatternError(f"«{name}» не помещается на {w:g}×{h:g}: нужно от {small:g}×{big:g} мм.")
		name = fallback


def _cut(settings: dict, pattern, w: float, h: float, title: str) -> dict:
	tools = _tools(settings)
	name, card, note = _resolve(settings, pattern, w, h)
	paths, warnings = cnc_geometry.build(card, w, h, tools)
	if note:
		warnings.insert(0, note)
	files = cnc_geometry.gcode(paths, tools, settings["machine"], f"{title} · {name} · {w:g}x{h:g}")
	return {"pattern": name, "example": bool(card.get("example")), "warnings": warnings,
			"paths": cnc_geometry.preview(paths, tools), "files": files,
			"minutes": round(sum(f["stats"]["minutes"] for f in files), 1)}


def _size(value, what: str) -> float:
	number = flt(value)
	if not 50 <= number <= 3000:
		frappe.throw(f"{what} — от 50 до 3000 мм.")
	return number


def preview(pattern, width, height) -> dict:
	"""A pattern — saved, by its name, or as edited and not yet saved — on a
	facade of this size: the cuts to draw, the program, the minutes."""
	_company, settings = _ensure_visible()
	if isinstance(pattern, str) and pattern.strip().startswith("{"):
		try:
			raw = json.loads(pattern)
		except ValueError:
			frappe.throw("Узор не прочитался.")
		card = _clean_pattern(settings, raw.get("name") or "—", raw.get("milling"), raw.get("min_w"),
							  raw.get("min_h"), None, raw.get("elements"))
		pattern = {**card, "name": raw.get("name") or "—"}
	w, h = _size(width, "Ширина"), _size(height, "Высота")
	try:
		cut = _cut(settings, pattern, w, h, "KORKEM")
	except PatternError as e:
		return {"error": str(e), "paths": [], "files": [], "warnings": [], "minutes": 0}
	return {**cut, "ext": settings["machine"]["ext"]}


def _file_name(*parts) -> str:
	text = "-".join(str(p) for p in parts if p not in (None, ""))
	return re.sub(r"[^0-9A-Za-zА-Яа-яЁёӘәҒғҚқҢңӨөҰұҮүҺһІі×x._-]+", "_", text).strip("_")


def _order_lines(order: str) -> list:
	from korkem_manufacturing.services import glue_stock

	return glue_stock._lines([order])


def for_order(order: str) -> dict:
	"""The order's positions as the router sees them: which pattern each
	milling is, whether it fits, how long it takes. Reads only."""
	company, settings = _ensure_visible()
	if frappe.db.get_value("Sales Order", order, "company") != company:
		frappe.throw("Нет такого заказа.", frappe.PermissionError)
	by_milling = {c.get("milling"): n for n, c in settings["patterns"].items() if c.get("milling")}
	lines, minutes = [], 0.0
	for no, line in enumerate(_order_lines(order), 1):
		w, h = flt(line.korkem_width_mm), flt(line.korkem_height_mm)
		row = {"line": line.name, "no": no, "height": h, "width": w, "qty": flt(line.qty),
			   "milling": line.korkem_milling, "pattern": by_milling.get(line.korkem_milling), "error": None,
			   "warnings": [], "minutes": None}
		if row["pattern"]:
			try:
				cut = _cut(settings, row["pattern"], w, h, order)
				row.update(pattern=cut["pattern"], warnings=cut["warnings"], minutes=cut["minutes"],
						   example=cut["example"])
				minutes += cut["minutes"] * flt(line.qty)
			except PatternError as e:
				row["error"] = str(e)
		lines.append(row)
	return {"order": order, "lines": lines, "minutes": round(minutes, 1), "ext": settings["machine"]["ext"]}


def order_files(order: str, line: str | None = None) -> dict:
	"""The programs for an order's positions (or one), named so the operator
	finds them: order, position, size, pattern, cutter."""
	company, settings = _ensure_visible()
	plan = for_order(order)
	files = []
	ext = settings["machine"]["ext"]
	for row in plan["lines"]:
		if (line and row["line"] != line) or not row["pattern"] or row["error"]:
			continue
		cut = _cut(settings, row["pattern"], row["width"], row["height"], order)
		many = len(cut["files"]) > 1
		for i, f in enumerate(cut["files"], 1):
			files.append({
				"name": _file_name(order, f"{row['no']:02d}", f"{row['height']:g}x{row['width']:g}",
								   cut["pattern"], f"{i}-{f['tool']}" if many else None) + f".{ext}",
				"text": f["text"], "qty": row["qty"], "minutes": f["stats"]["minutes"]})
	if not files:
		frappe.throw("Для этих позиций нет ни одного узора, который помещается.")
	audit.record_audit(action="cnc_patterns.files", entity_type="Sales Order", entity_id=order,
					   diff={"files": [f["name"] for f in files]}, company=company)
	return {"order": order, "files": files}
