# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Раскрой на форматно-раскроечной пиле — the job, its sheets, its history.

Owner, 28.11.2026. The shop's panel saw has a manual fence and, for now, a
paper map: the office enters the parts (numbers first, the name last), the
layout is made by `saw_engine`, a technologist checks it, the map and the
labels are printed, and each sheet is marked sawn — by scanning the QR on its
map or from the office. A later screen at the saw will mark the same thing.

**What is kept, and why.** A job keeps the parts as entered and the saw's
settings as they were when it was made, so a job made last month reads as it
was sawn even after the kerf changed. A change after it was made is a new
version; the old one lives in the audit trail. A sheet already sawn cannot be
changed by changing the job — the board is cut; the job is cancelled, with a
reason, and a new one made.

**Who sawed it.** Said on the sheet when it is marked; not said — the one
person on the cutting post (`team.posts_for_stage("cut")`), as a stage tick
does since #153: the mark never stops to ask. Several on the post — nobody,
not a guess; it is said later.

**What follows from a sheet.** Its offcuts go on the shelf (`offcuts`), each
with its QR. The last sheet marked ticks «Раскрой» on the facade orders of
the job, with the same sawyer.

Who may: office staff who keep the material norms, and the production
manager, make, check and cancel; anyone on the staff reads and marks sheets.
Nothing here moves stock: the sheets are written off as the rest of the
material is, by the order (`facade_materials`) — NOT IMPLEMENTED for the
saw's own sheets yet.
"""

from __future__ import annotations

import base64
import csv
import io
import json
import re

import frappe
from frappe.utils import cint, flt, get_fullname, getdate, now_datetime

from korkem_manufacturing.services import audit, facade_materials, material_stock, offcuts, saw_engine
from korkem_manufacturing.services.scope import current_company

JOB, SHEET = "Cutting Job", "Cutting Job Sheet"
NORMS = "Facade Material Norms"
#: The shop's saw until its settings are saved (owner, 28.11.2026).
DEFAULT_SAW = {
	"kerf_mm": 4.0,
	"trim_mm": 10.0,
	"offcut_min_length_mm": 300,
	"offcut_min_width_mm": 300,
	"fence_side": "left",
	"edge_deduct": True,
}
FENCES = ("left", "right")
#: Who makes, checks and cancels a job besides the stock's editors.
MAKERS = frozenset({"Manufacturing Manager"})
#: A job's states, and the ones a sheet may be marked in.
DRAFT, CHECKED, CUTTING, DONE, CANCELLED = "Draft", "Checked", "Cutting", "Done", "Cancelled"
MARKABLE = (CHECKED, CUTTING, DONE)
#: Bounds that catch a typo, not a shop's practice.
MAX_ROWS, MAX_QTY, MAX_MM, MAX_EDGE = 500, 1000, 5000, 5
#: The QR on a sheet's map: «SAW:Р-0042:1».
QR_PREFIX = "SAW"


def can_make() -> bool:
	return material_stock.can_edit() or bool(MAKERS.intersection(frappe.get_roles()))


def _ensure_maker() -> None:
	if not can_make():
		frappe.throw("Раскрой составляют и проверяют менеджеры и начальник производства.", frappe.PermissionError)


# --------------------------------------------------------------------------
# The saw's settings
# --------------------------------------------------------------------------

_SAW_FIELDS = ["saw_saved", "saw_kerf_mm", "saw_trim_mm", "saw_offcut_min_length_mm", "saw_offcut_min_width_mm",
			   "saw_fence_side", "saw_edge_deduct", "saw_sheets"]


def saw_settings(company: str | None = None) -> dict:
	"""The saw: kerf, edge trim, the smallest offcut kept, the fence's side,
	whether a band is taken off a size, and a sheet per thickness."""
	company = company or current_company()
	row = frappe.db.get_value(NORMS, company, _SAW_FIELDS, as_dict=True) if frappe.db.exists(NORMS, company) else None
	norms = facade_materials.norms(company)
	default_sheet = {"height_mm": norms["sheet_length_mm"], "width_mm": norms["sheet_width_mm"]}
	if row and cint(row.saw_saved):
		values = {
			"kerf_mm": flt(row.saw_kerf_mm),
			"trim_mm": flt(row.saw_trim_mm),
			"offcut_min_length_mm": cint(row.saw_offcut_min_length_mm),
			"offcut_min_width_mm": cint(row.saw_offcut_min_width_mm),
			"fence_side": row.saw_fence_side if row.saw_fence_side in FENCES else "left",
			"edge_deduct": bool(cint(row.saw_edge_deduct)),
		}
		sheets = _sheets(row.saw_sheets) or []
	else:
		values, sheets = dict(DEFAULT_SAW), []
	return values | {"sheets": sheets, "default_sheet": default_sheet, "saved": bool(row and cint(row.saw_saved)),
					 "can_edit": can_make()}


def save_saw_settings(**values) -> dict:
	_ensure_maker()
	company = current_company()
	before = saw_settings(company)
	doc = frappe.get_doc(NORMS, company) if frappe.db.exists(NORMS, company) else frappe.new_doc(NORMS)
	doc.company = company

	def number(key: str, low: float, high: float, message: str) -> float:
		raw = values.get(key)
		if raw in (None, ""):
			return before[key]
		value = flt(raw)
		if value < low or value > high:
			frappe.throw(message)
		return value

	kerf = number("kerf_mm", 0, 20, "Пропил — от 0 до 20 мм.")
	trim = number("trim_mm", 0, 100, "Обрезка края — от 0 до 100 мм.")
	least_l = number("offcut_min_length_mm", 50, MAX_MM, "Обрезок на склад — от 50 мм.")
	least_w = number("offcut_min_width_mm", 50, MAX_MM, "Обрезок на склад — от 50 мм.")
	fence = values.get("fence_side") or before["fence_side"]
	if fence not in FENCES:
		frappe.throw("Упор — слева или справа.")
	deduct = values.get("edge_deduct")
	deduct = before["edge_deduct"] if deduct in (None, "") else str(deduct).lower() not in ("0", "false")
	sheets = before["sheets"]
	if values.get("sheets") not in (None, ""):
		sheets = _sheets(values["sheets"])
		if sheets is None:
			frappe.throw("Листы — толщина, высота и ширина в мм; высота и ширина от 300 до 5000.")
	doc.update({
		"saw_saved": 1, "saw_kerf_mm": kerf, "saw_trim_mm": trim, "saw_offcut_min_length_mm": cint(least_l),
		"saw_offcut_min_width_mm": cint(least_w), "saw_fence_side": fence, "saw_edge_deduct": 1 if deduct else 0,
		"saw_sheets": json.dumps(sheets, ensure_ascii=False),
	})
	doc.save(ignore_permissions=True)
	after = saw_settings(company)
	keys = [*DEFAULT_SAW, "sheets"]
	audit.record_audit(action="saw.settings_saved", entity_type=NORMS, entity_id=company,
					   diff={"before": {k: before[k] for k in keys}, "after": {k: after[k] for k in keys}})
	return after


def _sheets(raw) -> list[dict] | None:
	if raw in (None, ""):
		return []
	if isinstance(raw, str):
		try:
			raw = json.loads(raw)
		except ValueError:
			return None
	if not isinstance(raw, list):
		return None
	out, seen = [], set()
	for item in raw:
		if not isinstance(item, dict):
			return None
		thickness, height, width = flt(item.get("thickness_mm")), cint(item.get("height_mm")), cint(item.get("width_mm"))
		if not 0 < thickness <= 100 or not 300 <= height <= MAX_MM or not 300 <= width <= MAX_MM:
			return None
		if thickness in seen:
			continue
		seen.add(thickness)
		out.append({"thickness_mm": thickness, "height_mm": height, "width_mm": width})
	return sorted(out, key=lambda s: s["thickness_mm"])


def sheet_for(settings: dict, thickness: float | None) -> dict:
	"""The sheet of this thickness — the default one when none is set for it."""
	for s in settings["sheets"]:
		if thickness and abs(s["thickness_mm"] - flt(thickness)) < 0.01:
			return {"height_mm": s["height_mm"], "width_mm": s["width_mm"]}
	return dict(settings["default_sheet"])


# --------------------------------------------------------------------------
# Materials and parts
# --------------------------------------------------------------------------


def materials(company: str | None = None) -> list[dict]:
	"""The boards a job may be cut from: the company's sheet materials with a thickness."""
	company = company or current_company()
	rows = frappe.get_all(
		"Item",
		filters={"korkem_material_company": company, "disabled": 0,
				 "korkem_material_kind": ["in", [material_stock.MDF, material_stock.OTHER]],
				 "korkem_thickness_mm": ["is", "set"]},
		fields=["name", "item_name", "korkem_thickness_mm", "korkem_material_kind"],
		order_by="item_name asc",
		limit_page_length=500,
	)
	return [{"item": r.name, "name": r.item_name or r.name, "thickness_mm": flt(r.korkem_thickness_mm),
			 "kind": r.korkem_material_kind} for r in rows if flt(r.korkem_thickness_mm) > 0]


def _rows(parts) -> list[dict]:
	"""The parts as entered, checked: numbered from 1 in their order."""
	if isinstance(parts, str):
		try:
			parts = json.loads(parts)
		except ValueError:
			frappe.throw("Список деталей не прочитан.")
	if not isinstance(parts, list) or not parts:
		frappe.throw("Добавьте хотя бы одну деталь.")
	if len(parts) > MAX_ROWS:
		frappe.throw(f"Больше {MAX_ROWS} строк в одном раскрое — разделите его.")
	out = []
	for n, raw in enumerate(parts, start=1):
		if not isinstance(raw, dict):
			frappe.throw(f"Строка {n} не прочитана.")
		height, width, qty = flt(raw.get("height")), flt(raw.get("width")), cint(raw.get("qty") or 1)
		if height <= 0 or width <= 0:
			frappe.throw(f"Строка {n}: нужны высота и ширина.")
		if height > MAX_MM or width > MAX_MM:
			frappe.throw(f"Строка {n}: больше {MAX_MM} мм — проверьте размер.")
		if not 1 <= qty <= MAX_QTY:
			frappe.throw(f"Строка {n}: количество от 1 до {MAX_QTY}.")
		edges = [flt(e) for e in (list(raw.get("edges") or []) + [0, 0, 0, 0])[:4]]
		if any(e < 0 or e > MAX_EDGE for e in edges):
			frappe.throw(f"Строка {n}: кромка от 0 до {MAX_EDGE} мм.")
		rotate = raw.get("rotate", True)
		out.append({
			"n": n, "height": height, "width": width, "qty": qty,
			"rotate": str(rotate).lower() not in ("0", "false", "none"),
			"edges": edges,
			"name": " ".join(str(raw.get("name") or "").split())[:80],
			"order": (raw.get("order") or None),
		})
	return out


def edge_metres(rows: list[dict]) -> dict[str, float]:
	"""Band by thickness, in metres: top and bottom run the width, the sides the height."""
	out: dict[str, float] = {}
	for r in rows:
		for side, e in enumerate(r["edges"]):
			if e:
				length = r["width"] if side < 2 else r["height"]
				key = f"{e:g}"
				out[key] = round(out.get(key, 0) + length * r["qty"] / 1000, 2)
	return out


# --------------------------------------------------------------------------
# Import: TXT, CSV, Excel, a paste
# --------------------------------------------------------------------------

_HEADS = {
	"height": ("высота", "длина", "h", "height", "length", "биіктігі", "ұзындығы"),
	"width": ("ширина", "w", "width", "ені"),
	"qty": ("кол", "колво", "количество", "шт", "qty", "count", "саны"),
	"name": ("название", "наименование", "деталь", "name", "атауы"),
	"edge": ("кромка", "edge", "жиек"),
	"top": ("верх", "top"),
	"bottom": ("низ", "bottom"),
	"left": ("лево", "левая", "left"),
	"right": ("право", "правая", "right"),
	"rotate": ("поворот", "rotate"),
}
_NUMBER = re.compile(r"^-?\d+(?:[.,]\d+)?$")
_EDGES = re.compile(r"^\d+(?:[.,]\d+)?(?:-\d+(?:[.,]\d+)?){3}$")
_TIMES = re.compile(r"[x×хХX*]")


def _num(token) -> float | None:
	if isinstance(token, (int, float)):
		return float(token)
	text = str(token or "").strip().replace(" ", "")
	return float(text.replace(",", ".")) if _NUMBER.match(text) else None


def _head(cell) -> str | None:
	text = re.sub(r"[^a-zа-яёәіңғүұқөһ]", "", str(cell or "").lower())
	for key, words in _HEADS.items():
		if text and any(text == w or (len(w) > 2 and text.startswith(w)) for w in words):
			return key
	return None


def _tokens(line: str) -> list[str]:
	if "\t" in line or ";" in line:
		return [c.strip() for c in re.split(r"[\t;]", line)]
	if line.count(",") >= 2 and " " not in line.strip():
		return [c.strip() for c in line.split(",")]
	return [t for t in re.split(r"\s+", _TIMES.sub(" ", line).strip()) if t]


def rows_from_cells(table: list[list]) -> dict:
	"""Rows of cells — a sheet, a CSV, a paste — as parts, and what was not read.

	A first row of headings (Высота, Ширина, Кол-во, Название, Кромка, Верх…)
	says which column is which; without it the first three numbers of a row
	are its height, width and quantity, and its words its name."""
	rows, errors, heads = [], [], None
	for index, cells in enumerate(table, start=1):
		cells = ["" if c is None else c for c in cells]
		if not any(str(c).strip() for c in cells):
			continue
		if heads is None and not rows and not errors:
			marked = [_head(c) for c in cells]
			if sum(1 for m in marked if m) >= 2 and not any(_num(c) is not None for c in cells):
				heads = marked
				continue
		text = " ".join(str(c) for c in cells if str(c).strip())
		if heads:
			got = {}
			for key, cell in zip(heads, cells):
				if key and str(cell).strip():
					got.setdefault(key, cell)
			height, width = _num(got.get("height")), _num(got.get("width"))
			qty = _num(got.get("qty")) if got.get("qty") not in (None, "") else 1
			name = str(got.get("name") or "").strip()
			edges = [_num(got.get(k)) or 0 for k in ("top", "bottom", "left", "right")]
			if got.get("edge") and _EDGES.match(str(got["edge"]).replace(" ", "")):
				edges = [_num(e) or 0 for e in str(got["edge"]).replace(" ", "").split("-")]
			rotate = str(got.get("rotate", "")).strip().lower() not in ("нет", "no", "0", "false", "жоқ")
		else:
			numbers, words, edges = [], [], [0.0, 0.0, 0.0, 0.0]
			for token in cells if len(cells) > 1 else _tokens(str(cells[0])):
				token = str(token).strip()
				value = _num(token)
				if value is not None and len(numbers) < 3:
					numbers.append(value)
				elif _EDGES.match(token.replace(" ", "")):
					edges = [_num(e) or 0 for e in token.replace(" ", "").split("-")]
				elif token:
					words.append(token)
			height = numbers[0] if numbers else None
			width = numbers[1] if len(numbers) > 1 else None
			qty = numbers[2] if len(numbers) > 2 else 1
			name, rotate = " ".join(words), True
		reason = None
		if height is None:
			reason = "no_size"
		elif width is None:
			reason = "no_width"
		elif height <= 0 or width <= 0 or height > MAX_MM or width > MAX_MM:
			reason = "size"
		elif qty is None or qty != int(qty) or not 1 <= qty <= MAX_QTY:
			reason = "qty"
		if reason:
			errors.append({"line": index, "text": text[:120], "reason": reason})
			continue
		rows.append({"height": height, "width": width, "qty": int(qty), "name": name[:80], "rotate": rotate,
					 "edges": [min(max(flt(e), 0), MAX_EDGE) for e in edges]})
	return {"rows": rows[:MAX_ROWS], "errors": errors, "more": max(0, len(rows) - MAX_ROWS)}


def parse_parts(text: str | None = None, content: str | None = None, filename: str | None = None) -> dict:
	"""A file — .xlsx, .xls, .csv, .txt — or pasted text, read as parts. Nothing is saved."""
	material_stock._ensure_staff()
	name = (filename or "").lower()
	if content:
		try:
			data = base64.b64decode(content)
		except ValueError:
			frappe.throw("Файл не прочитан.")
		if len(data) > 5 * 1024 * 1024:
			frappe.throw("Файл больше 5 МБ.")
		if name.endswith(".xlsx"):
			from frappe.utils.xlsxutils import read_xlsx_file_from_attached_file

			return rows_from_cells(read_xlsx_file_from_attached_file(fcontent=data) or [])
		if name.endswith(".xls"):
			from frappe.utils.xlsxutils import read_xls_file_from_attached_file

			return rows_from_cells(read_xls_file_from_attached_file(data) or [])
		for encoding in ("utf-8-sig", "cp1251"):
			try:
				text = data.decode(encoding)
				break
			except UnicodeDecodeError:
				continue
		else:
			frappe.throw("Файл не в тексте — сохраните его как .xlsx, .csv или .txt.")
	lines = (text or "").splitlines()
	if name.endswith(".csv"):
		dialect = ";" if sum(l.count(";") for l in lines[:5]) >= sum(l.count(",") for l in lines[:5]) else ","
		return rows_from_cells([r for r in csv.reader(lines, delimiter=dialect)])
	return rows_from_cells([[line] for line in lines])


# --------------------------------------------------------------------------
# The layout
# --------------------------------------------------------------------------


def _layout(rows: list[dict], settings: dict, sheet: dict) -> dict:
	kw = {
		"sheet_h": sheet["height_mm"], "sheet_w": sheet["width_mm"], "kerf": settings["kerf_mm"],
		"trim": settings["trim_mm"],
		"min_offcut": (settings["offcut_min_length_mm"], settings["offcut_min_width_mm"]),
	}
	try:
		plans = saw_engine.plan(rows, edge_deduct=settings["edge_deduct"], **kw)
	except ValueError as e:
		frappe.throw(str(e))
	out = {"choices": [], "plans": {}}
	for key, p in saw_engine.choices(plans):
		laid = saw_engine.as_dict(p, **kw)
		out["plans"][key] = laid
		biggest = max((r for r in (laid["sheets"][-1]["offcuts"] if laid["sheets"] else [])),
					  key=lambda r: r["width"] * r["height"], default=None)
		out["choices"].append({
			"key": key, "sheets": len(laid["sheets"]), "fences": laid["fences"], "waste_pct": laid["waste_pct"],
			"offcut": [round(biggest["width"]), round(biggest["height"])] if biggest else None,
		})
	return out


def _material(item: str | None, company: str) -> tuple[str | None, str, float]:
	if not item:
		frappe.throw("Выберите материал.")
	row = frappe.db.get_value("Item", item, ["item_name", "korkem_thickness_mm", "korkem_material_company"],
							  as_dict=True)
	if not row or row.korkem_material_company != company:
		frappe.throw("Такого материала на складе нет.", frappe.DoesNotExistError)
	return item, row.item_name or item, flt(row.korkem_thickness_mm)


def calculate(material_item: str, parts) -> dict:
	"""The layouts of these parts on this material's sheet — nothing is saved."""
	_ensure_maker()
	company = current_company()
	_, _, thickness = _material(material_item, company)
	rows = _rows(parts)
	settings = saw_settings(company)
	sheet = sheet_for(settings, thickness)
	return {"sheet": sheet, "settings": settings, "edges": edge_metres(rows), **_layout(rows, settings, sheet)}


# --------------------------------------------------------------------------
# The job
# --------------------------------------------------------------------------


def short_customer(name: str | None) -> str:
	"""«Дастан Жақсылықов» → «Дастан Ж.»; a firm keeps its name."""
	words = (name or "").split()
	if len(words) < 2 or words[0].upper().strip(".") in ("ТОО", "ИП", "АО", "LLP", "ООО", "TOO"):
		return " ".join(words)
	return f"{words[0]} {words[1][0]}."


def order_number(name: str) -> str:
	return f"№{name.rsplit('-', 1)[-1]}"


def _orders(orders, company: str) -> list[dict]:
	if isinstance(orders, str):
		try:
			orders = json.loads(orders) if orders.strip().startswith("[") else [orders]
		except ValueError:
			orders = [orders]
	out = []
	for so in dict.fromkeys(o for o in (orders or []) if o):
		row = frappe.db.get_value("Sales Order", so, ["company", "customer_name", "customer", "delivery_date"],
								  as_dict=True)
		if not row or row.company != company:
			frappe.throw("Такого заказа нет.", frappe.DoesNotExistError)
		out.append({"order": so, "customer": short_customer(row.customer_name or row.customer),
					"due": str(row.delivery_date) if row.delivery_date else None})
	return out


def _title(orders: list[dict]) -> str:
	return " · ".join(f"{order_number(o['order'])} {o['customer']}".strip() for o in orders)[:140]


def save_job(name: str | None = None, material_item: str | None = None, parts=None, orders=None,
			 choice: str | None = None, due_date: str | None = None) -> dict:
	"""Make a job, or change one no sheet of which is sawn yet. A change of
	the parts, the material or the orders is a new version; the old one is
	in the history. Every change wants checking again."""
	_ensure_maker()
	company = current_company()
	item, material, thickness = _material(material_item, company)
	rows = _rows(parts)
	linked = _orders(orders, company)
	for r in rows:
		if r["order"] and r["order"] not in {o["order"] for o in linked}:
			linked += _orders([r["order"]], company)
	settings = saw_settings(company)
	sheet = sheet_for(settings, thickness)
	laid = _layout(rows, settings, sheet)
	if not laid["choices"]:
		frappe.throw("Ни одна деталь не помещается на лист.")
	key = choice if choice in laid["plans"] else laid["choices"][0]["key"]
	chosen = laid["plans"][key]
	if chosen["too_big"]:
		numbers = ", ".join(str(n) for n in chosen["too_big"])
		frappe.throw(f"Деталь {numbers} больше листа {sheet['height_mm']} × {sheet['width_mm']} — проверьте размеры.")
	savepoint = "korkem_saw_" + frappe.generate_hash(length=8)
	frappe.db.savepoint(savepoint)
	try:
		if name:
			doc = _own(name)
			if doc.status in (DONE, CANCELLED) or any(s.status == "Done" for s in doc.sheets):
				frappe.throw("Лист уже распилен — раскрой не меняется. Отмените его и составьте новый.")
			before = {"version": cint(doc.version), "material": doc.material, "orders": json.loads(doc.orders or "[]"),
					  "parts": json.loads(doc.parts_json or "[]")}
			changed = (before["material"] != material or before["parts"] != rows
					   or [o["order"] for o in before["orders"]] != [o["order"] for o in linked])
			if changed:
				doc.version = cint(doc.version) + 1
		else:
			doc = frappe.new_doc(JOB)
			doc.company, doc.version, doc.made_by = company, 1, frappe.session.user
			before, changed = None, True
		dues = [o["due"] for o in linked if o["due"]]
		doc.update({
			"status": DRAFT, "checked_by": None, "checked_at": None,
			"title": _title(linked), "orders": json.dumps(linked, ensure_ascii=False),
			"due_date": getdate(due_date) if due_date else (min(dues) if dues else None),
			"material_item": item, "material": material, "thickness_mm": thickness,
			"sheet_height_mm": sheet["height_mm"], "sheet_width_mm": sheet["width_mm"],
			"kerf_mm": settings["kerf_mm"], "trim_mm": settings["trim_mm"],
			"min_offcut_length_mm": settings["offcut_min_length_mm"],
			"min_offcut_width_mm": settings["offcut_min_width_mm"],
			"edge_deduct": 1 if settings["edge_deduct"] else 0, "fence_side": settings["fence_side"],
			"choice": key, "sheets_total": len(chosen["sheets"]), "sheets_done": 0,
			"waste_pct": chosen["waste_pct"], "fences": chosen["fences"],
			"parts_json": json.dumps(rows, ensure_ascii=False),
			"plan_json": json.dumps({"choice": key, "choices": laid["choices"], "plan": chosen}, ensure_ascii=False),
		})
		doc.set("sheets", [{"sheet_no": i, "status": "Waiting"} for i in range(1, len(chosen["sheets"]) + 1)])
		doc.save(ignore_permissions=True) if name else doc.insert(ignore_permissions=True)
		audit.record_audit(
			action="saw.job_saved", entity_type=JOB, entity_id=doc.name,
			diff={"version": cint(doc.version), "changed": changed, "choice": key, "sheets": len(chosen["sheets"]),
				  "waste_pct": chosen["waste_pct"], "orders": [o["order"] for o in linked], "material": material,
				  **({"before": before} if before and changed else {})},
		)
	except Exception:
		frappe.db.rollback(save_point=savepoint)
		raise
	frappe.db.release_savepoint(savepoint)
	return job(doc.name)


def check_job(name: str, checked=True) -> dict:
	"""«Проверено» — the layout may be printed and sawn; or the mark taken back."""
	_ensure_maker()
	doc = _own(name)
	checked = str(checked).lower() not in ("0", "false", "")
	if checked and doc.status != DRAFT:
		frappe.throw("Проверяют раскрой, который ещё не начали пилить.")
	if not checked and doc.status != CHECKED:
		frappe.throw("Отметку снимают, пока не распилен ни один лист.")
	doc.status = CHECKED if checked else DRAFT
	doc.checked_by = frappe.session.user if checked else None
	doc.checked_at = now_datetime() if checked else None
	doc.save(ignore_permissions=True)
	audit.record_audit(action="saw.job_checked" if checked else "saw.job_unchecked", entity_type=JOB,
					   entity_id=doc.name, diff={"version": cint(doc.version)})
	return job(doc.name)


def default_sawyer(company: str) -> str | None:
	"""The one person on the cutting post — several or none: nobody."""
	from korkem_manufacturing.services import team

	people = team.holders(team.posts_for_stage("cut"), company)
	return people[0]["employee"] if len(people) == 1 else None


def sheet_done(name: str, sheet_no, done=True, sawn_by: str | None = None, defects: str | None = None) -> dict:
	"""A sheet sawn — from the scan of its map or from the office — or the mark taken back."""
	material_stock._ensure_staff()
	doc = _own(name)
	done = str(done).lower() not in ("0", "false", "")
	if doc.status not in MARKABLE:
		frappe.throw("Сначала раскрой проверяют." if doc.status == DRAFT else "Раскрой отменён.")
	row = next((s for s in doc.sheets if cint(s.sheet_no) == cint(sheet_no)), None)
	if not row:
		frappe.throw(f"В раскрое нет листа {sheet_no}.")
	if done == (row.status == "Done"):
		frappe.throw("Лист уже отмечен распиленным." if done else "Лист ещё не отмечен.")
	savepoint = "korkem_sheet_" + frappe.generate_hash(length=8)
	frappe.db.savepoint(savepoint)
	try:
		put: list[str] = []
		if done:
			worker = sawn_by or default_sawyer(doc.company)
			if worker and frappe.db.get_value("Employee", worker, "company") != doc.company:
				frappe.throw("Такого сотрудника в компании нет.")
			put = _shelve(doc, cint(sheet_no))
			row.update({"status": "Done", "sawn_by": worker or None,
						"sawn_by_name": frappe.db.get_value("Employee", worker, "employee_name") if worker else None,
						"marked_by": frappe.session.user, "sawn_at": now_datetime(),
						"defects": " ".join(str(defects or "").split())[:280] or None,
						"offcuts": json.dumps(put) if put else None})
		else:
			for offcut in json.loads(row.offcuts or "[]"):
				if frappe.db.get_value(offcuts.DOCTYPE, offcut, "status") == "Available":
					offcuts.scrap_offcut(offcut, f"{doc.name}: отметка листа {sheet_no} снята")
			row.update({"status": "Waiting", "sawn_by": None, "sawn_by_name": None, "marked_by": None,
						"sawn_at": None, "defects": None, "offcuts": None})
		done_count = sum(1 for s in doc.sheets if s.status == "Done")
		doc.sheets_done = done_count
		doc.status = DONE if done_count == len(doc.sheets) else (CUTTING if done_count else CHECKED)
		doc.save(ignore_permissions=True)
		audit.record_audit(
			action="saw.sheet_done" if done else "saw.sheet_undone", entity_type=JOB, entity_id=doc.name,
			diff={"sheet": cint(sheet_no), "sawn_by": row.sawn_by_name, "defects": row.defects, "offcuts": put},
		)
		if doc.status == DONE:
			_tick_orders(doc, row.sawn_by)
	except Exception:
		frappe.db.rollback(save_point=savepoint)
		raise
	frappe.db.release_savepoint(savepoint)
	return job(doc.name)


def note_defect(name: str, sheet_no, defects: str | None = None) -> dict:
	"""What was spoilt on a sheet already marked — written from the paper map."""
	material_stock._ensure_staff()
	doc = _own(name)
	row = next((s for s in doc.sheets if cint(s.sheet_no) == cint(sheet_no)), None)
	if not row or row.status != "Done":
		frappe.throw("Брак записывают на распиленный лист.")
	row.defects = " ".join(str(defects or "").split())[:280] or None
	doc.save(ignore_permissions=True)
	audit.record_audit(action="saw.defect_noted", entity_type=JOB, entity_id=doc.name,
					   diff={"sheet": cint(sheet_no), "defects": row.defects})
	return job(doc.name)


def _shelve(doc, sheet_no: int) -> list[str]:
	"""The sheet's offcuts on the shelf, each with its QR."""
	plan = json.loads(doc.plan_json or "{}").get("plan") or {}
	sheets = plan.get("sheets") or []
	if not doc.material_item or not 1 <= sheet_no <= len(sheets):
		return []
	warehouse = material_stock._receiving_warehouse(doc.company, None)
	orders = json.loads(doc.orders or "[]")
	names = []
	for r in sheets[sheet_no - 1].get("offcuts") or []:
		length, width = sorted((flt(r["width"]), flt(r["height"])), reverse=True)
		made = offcuts.create_offcut(
			company=doc.company, material_item=doc.material_item, length_mm=round(length), width_mm=round(width),
			thickness_mm=flt(doc.thickness_mm), warehouse=warehouse,
			source_order=orders[0]["order"] if orders else None, notes=f"{doc.name} · лист {sheet_no}",
		)
		names.append(made.name)
	return names


def _tick_orders(doc, worker: str | None) -> None:
	"""«Раскрой» on the job's facade orders, by the one who sawed the last sheet."""
	from korkem_manufacturing.services import directions, mdf_orders

	field = mdf_orders.STAGES["cut"]
	for o in json.loads(doc.orders or "[]"):
		row = frappe.db.get_value("Sales Order", o["order"], ["korkem_direction", "docstatus", field], as_dict=True)
		if row and row.korkem_direction == directions.FACADES and row.docstatus == 1 and not row.get(field):
			mdf_orders._tick(o["order"], "cut", True, worker)


def cancel_job(name: str, reason: str | None = None) -> dict:
	_ensure_maker()
	doc = _own(name)
	reason = " ".join(str(reason or "").split())[:280]
	if not reason:
		frappe.throw("Напишите, почему раскрой отменяют.")
	if doc.status in (DONE, CANCELLED):
		frappe.throw("Распиленный или отменённый раскрой не отменяют.")
	doc.status, doc.cancel_reason = CANCELLED, reason
	doc.save(ignore_permissions=True)
	audit.record_audit(action="saw.job_cancelled", entity_type=JOB, entity_id=doc.name, reason=reason,
					   diff={"sheets_done": cint(doc.sheets_done)})
	return job(doc.name)


def merge_jobs(names) -> dict:
	"""Two or more jobs on one material, none of it sawn, as one — the parts
	renumbered in order, the originals cancelled with a pointer to it."""
	_ensure_maker()
	if isinstance(names, str):
		names = json.loads(names) if names.strip().startswith("[") else [names]
	names = list(dict.fromkeys(names or []))
	if len(names) < 2:
		frappe.throw("Выберите два раскроя или больше.")
	docs = [_own(n) for n in names]
	if len({d.material_item for d in docs}) != 1:
		frappe.throw("Вместе пилят раскрои одного материала.")
	if any(d.status not in (DRAFT, CHECKED) for d in docs):
		frappe.throw("Объединяют раскрои, которые ещё не начали пилить.")
	parts, orders = [], []
	for d in docs:
		parts += [{k: v for k, v in r.items() if k != "n"} for r in json.loads(d.parts_json or "[]")]
		orders += [o["order"] for o in json.loads(d.orders or "[]")]
	merged = save_job(material_item=docs[0].material_item, parts=parts, orders=orders)
	for d in docs:
		d.status, d.cancel_reason = CANCELLED, f"объединён в {merged['name']}"
		d.save(ignore_permissions=True)
		audit.record_audit(action="saw.job_merged", entity_type=JOB, entity_id=d.name,
						   diff={"into": merged["name"]})
	return job(merged["name"])


def _own(name: str):
	if not name or not frappe.db.exists(JOB, name):
		frappe.throw("Такого раскроя нет.", frappe.DoesNotExistError)
	doc = frappe.get_doc(JOB, name)
	if doc.company != current_company():
		frappe.throw("Такого раскроя нет.", frappe.DoesNotExistError)
	return doc


def job(name: str) -> dict:
	"""A job as its card shows it: the parts, the saw, the layout, the sheets, the history."""
	material_stock._ensure_staff()
	doc = _own(name)
	plan = json.loads(doc.plan_json or "{}")
	return {
		"name": doc.name, "status": doc.status, "version": cint(doc.version), "title": doc.title,
		"orders": json.loads(doc.orders or "[]"), "due_date": str(doc.due_date) if doc.due_date else None,
		"material_item": doc.material_item, "material": doc.material, "thickness_mm": flt(doc.thickness_mm),
		"saw": {
			"sheet_height_mm": flt(doc.sheet_height_mm), "sheet_width_mm": flt(doc.sheet_width_mm),
			"kerf_mm": flt(doc.kerf_mm), "trim_mm": flt(doc.trim_mm),
			"offcut_min_length_mm": flt(doc.min_offcut_length_mm), "offcut_min_width_mm": flt(doc.min_offcut_width_mm),
			"edge_deduct": bool(cint(doc.edge_deduct)), "fence_side": doc.fence_side or "left",
		},
		"parts": json.loads(doc.parts_json or "[]"),
		"edges": edge_metres(json.loads(doc.parts_json or "[]")),
		"choice": plan.get("choice"), "choices": plan.get("choices") or [], "plan": plan.get("plan") or {},
		"sheets_total": cint(doc.sheets_total), "sheets_done": cint(doc.sheets_done),
		"waste_pct": flt(doc.waste_pct), "fences": cint(doc.fences),
		"sheets": [{"sheet_no": cint(s.sheet_no), "status": s.status, "sawn_by": s.sawn_by,
					"sawn_by_name": s.sawn_by_name, "sawn_at": str(s.sawn_at) if s.sawn_at else None,
					"defects": s.defects, "offcuts": json.loads(s.offcuts or "[]")} for s in doc.sheets],
		"made_by": get_fullname(doc.made_by) if doc.made_by else None,
		"checked_by": get_fullname(doc.checked_by) if doc.checked_by else None,
		"checked_at": str(doc.checked_at) if doc.checked_at else None,
		"cancel_reason": doc.cancel_reason,
		"default_sawyer": default_sawyer(doc.company),
		"can_make": can_make(),
		"history": history(doc.name),
	}


def history(name: str) -> list[dict]:
	"""What happened to a job, newest first: who, when, what."""
	rows = frappe.get_all(
		"Domain Audit Event",
		filters={"company": current_company(), "entity_type": JOB, "entity_id": name},
		fields=["action", "actor", "reason", "diff_json", "creation"],
		order_by="creation desc",
		limit_page_length=200,
	)
	out = []
	for r in rows:
		try:
			diff = json.loads(r.diff_json or "{}")
		except ValueError:
			diff = {}
		diff.pop("before", None)
		out.append({"action": r.action.removeprefix("saw."), "at": str(r.creation)[:16],
					"who": get_fullname(r.actor) if r.actor else None, "reason": r.reason, **diff})
	return out


def listing(status: str | None = None, search: str | None = None, material: str | None = None,
			sawyer: str | None = None) -> dict:
	"""The journal: what to saw first — by due date — and what was sawn, newest first."""
	material_stock._ensure_staff()
	company = current_company()
	filters: dict = {"company": company}
	groups = {"check": [DRAFT], "cutting": [CHECKED, CUTTING], "done": [DONE], "cancelled": [CANCELLED]}
	filters["status"] = ["in", groups[status]] if status in groups else ["!=", CANCELLED]
	if material:
		filters["material_item"] = material
	if sawyer:
		parents = frappe.get_all(SHEET, filters={"parenttype": JOB, "sawn_by": sawyer}, pluck="parent",
								 limit_page_length=0)
		filters["name"] = ["in", list(set(parents)) or [""]]
	or_filters = None
	if search and search.strip():
		like = f"%{search.strip()}%"
		or_filters = {"name": ["like", like], "title": ["like", like], "material": ["like", like]}
		found = offcuts.get_offcut_by_qr(search.strip(), company)
		if found:
			or_filters = {"name": ["like", f"%{_source_job(found.name) or search.strip()}%"]}
	rows = frappe.get_all(
		JOB, filters=filters, or_filters=or_filters,
		fields=["name", "status", "title", "orders", "due_date", "material_item", "material", "thickness_mm",
				"sheets_total", "sheets_done", "waste_pct", "fences", "modified"],
		limit_page_length=300,
	)
	people: dict[str, list[str]] = {}
	for s in frappe.get_all(SHEET, filters={"parenttype": JOB, "parent": ["in", [r.name for r in rows] or [""]],
											"status": "Done"},
							fields=["parent", "sawn_by_name"], order_by="sheet_no asc", limit_page_length=0):
		if s.sawn_by_name and s.sawn_by_name not in people.setdefault(s.parent, []):
			people[s.parent].append(s.sawn_by_name)
	active = [r for r in rows if r.status not in (DONE, CANCELLED)]
	closed = [r for r in rows if r.status in (DONE, CANCELLED)]
	active.sort(key=lambda r: (r.due_date is None, str(r.due_date or ""), r.name))
	closed.sort(key=lambda r: str(r.modified), reverse=True)
	return {
		"jobs": [{
			"name": r.name, "status": r.status, "title": r.title, "orders": json.loads(r.orders or "[]"),
			"due_date": str(r.due_date) if r.due_date else None, "material_item": r.material_item,
			"material": r.material, "thickness_mm": flt(r.thickness_mm), "sheets_total": cint(r.sheets_total),
			"sheets_done": cint(r.sheets_done), "waste_pct": flt(r.waste_pct), "fences": cint(r.fences),
			"sawn_by": people.get(r.name, []),
		} for r in active + closed],
		"together": together(company, active),
		"materials": materials(company),
		"can_make": can_make(),
	}


def _source_job(offcut: str) -> str | None:
	note = frappe.db.get_value(offcuts.DOCTYPE, offcut, "notes") or ""
	match = re.match(r"^(\S+) · лист", note)
	return match.group(1) if match else None


def together(company: str, active) -> list[dict]:
	"""Jobs on one material not yet begun that cost a sheet less sawn together."""
	settings = saw_settings(company)
	by_material: dict[str, list] = {}
	for r in active:
		if r.status in (DRAFT, CHECKED) and r.material_item:
			by_material.setdefault(r.material_item, []).append(r)
	out = []
	for item, jobs in by_material.items():
		jobs = jobs[:6]
		if len(jobs) < 2:
			continue
		apart = sum(cint(j.sheets_total) for j in jobs)
		parts = []
		for j in jobs:
			parts += json.loads(frappe.db.get_value(JOB, j.name, "parts_json") or "[]")
		rows = [dict(r, n=i) for i, r in enumerate(parts, start=1)]
		sheet = sheet_for(settings, flt(jobs[0].thickness_mm))
		laid = _layout(rows, settings, sheet)
		if laid["choices"] and laid["choices"][0]["sheets"] < apart:
			out.append({"jobs": [j.name for j in jobs], "material": jobs[0].material, "apart": apart,
						"together": laid["choices"][0]["sheets"]})
	return out


def scan(code: str) -> dict:
	"""What a sheet map's QR names: «SAW:Р-0042:1» → the job, the sheet."""
	material_stock._ensure_staff()
	parts = (code or "").strip().split(":")
	if len(parts) != 3 or parts[0] != QR_PREFIX or not parts[2].isdigit():
		frappe.throw("Это не QR карты раскроя.")
	data = job(parts[1])
	return {"job": data, "sheet_no": int(parts[2])}
