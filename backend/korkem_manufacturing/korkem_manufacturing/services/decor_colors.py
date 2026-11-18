# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""A film «на глаз» by its colour (owner, 18.11.2026): the closest decors to
a photo of a customer's sample, and a film's analogues at other makers.

**What a decor looks like, in two numbers.** Its *tone* — the average colour
in CIE L*a*b*, where a distance means what the eye sees (ΔE ≈ 2: barely, 10:
clearly another colour) — and its *texture*: how much the lightness varies
across the picture. A white wood and a white solid have one tone and are
not the same film; the texture tells them apart.

Tones are worked out once, when a decor's picture comes in (`remember`), and
for the pictures already there by `backfill`. A decor with no picture but a
colour code (`hex`) has that colour and no texture.

**A photo from a phone** is never the swatch: the light, the white balance,
the shadow of the hand. Only its middle is read (the edges are the table it
lies on), and the answer is a short list to look at, closest first, with
what the shop has on its shelf marked — a suggestion for a person's eye,
never a decision.
"""

from __future__ import annotations

import base64
import io
import math

import frappe
from frappe.utils import flt

from korkem_manufacturing.services import film_decors, material_stock
from korkem_manufacturing.services.scope import current_company

#: How much of a photo is read: the middle, this share of each side.
CENTRE = 0.6
#: A texture point weighs this many ΔE: wood against solid of one tone.
TEXTURE_WEIGHT = 0.6
#: Answers shown.
SHOWN = 12
PHOTO_MAX = 12 * 1024 * 1024


def _linear(c: float) -> float:
	c /= 255.0
	return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _lab(r: float, g: float, b: float) -> tuple[float, float, float]:
	"""sRGB (0–255) → CIE L*a*b* (D65)."""
	rl, gl, bl = _linear(r), _linear(g), _linear(b)
	x = (rl * 0.4124 + gl * 0.3576 + bl * 0.1805) / 0.95047
	y = rl * 0.2126 + gl * 0.7152 + bl * 0.0722
	z = (rl * 0.0193 + gl * 0.1192 + bl * 0.9505) / 1.08883

	def f(t: float) -> float:
		return t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116

	fx, fy, fz = f(x), f(y), f(z)
	return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


def signature(content: bytes, centre: float = 1.0) -> dict:
	"""The tone and texture of a picture; `centre` < 1 reads only its middle."""
	from PIL import Image

	try:
		im = Image.open(io.BytesIO(content)).convert("RGB")
	except Exception:
		frappe.throw("Картинка не прочиталась — нужен jpg, png или webp.")
	if centre < 1:
		w, h = im.size
		dx, dy = int(w * (1 - centre) / 2), int(h * (1 - centre) / 2)
		im = im.crop((dx, dy, w - dx, h - dy))
	im.thumbnail((64, 64))
	pixels = list(im.getdata())
	labs = [_lab(*p) for p in pixels]
	n = len(labs) or 1
	mean = tuple(sum(v[i] for v in labs) / n for i in range(3))
	spread = math.sqrt(sum((v[0] - mean[0]) ** 2 for v in labs) / n)
	return {"l": round(mean[0], 2), "a": round(mean[1], 2), "b": round(mean[2], 2), "texture": round(spread, 2)}


def from_hex(code: str | None) -> dict | None:
	code = (code or "").strip().lstrip("#")
	if len(code) != 6:
		return None
	try:
		r, g, b = (int(code[i:i + 2], 16) for i in (0, 2, 4))
	except ValueError:
		return None
	lab = _lab(r, g, b)
	return {"l": round(lab[0], 2), "a": round(lab[1], 2), "b": round(lab[2], 2), "texture": 0.0}


def distance(one: dict, other: dict) -> float:
	"""ΔE between tones, plus the texture's difference at its weight."""
	de = math.sqrt((one["l"] - other["l"]) ** 2 + (one["a"] - other["a"]) ** 2 + (one["b"] - other["b"]) ** 2)
	return de + TEXTURE_WEIGHT * abs(flt(one.get("texture")) - flt(other.get("texture")))


def remember(decor: str, content: bytes) -> None:
	"""A decor's picture came in: keep its tone."""
	try:
		sig = signature(content)
	except Exception:
		return
	frappe.db.set_value(film_decors.DOCTYPE, decor, {"tone_l": sig["l"], "tone_a": sig["a"], "tone_b": sig["b"],
													 "texture": sig["texture"]}, update_modified=False)


def _file_content(url: str) -> bytes | None:
	name = frappe.db.get_value("File", {"file_url": url}, "name")
	if not name:
		return None
	try:
		return frappe.get_doc("File", name).get_content()
	except Exception:
		return None


def backfill(company: str | None = None) -> dict:
	"""The tones of every decor whose picture came before this module."""
	filters = {"tone_l": ["in", [0, None]]}
	if company:
		filters["company"] = company
	done = missed = 0
	for row in frappe.get_all(film_decors.DOCTYPE, filters=filters, fields=["name", "image", "hex"],
							  limit_page_length=0):
		content = _file_content(row.image) if row.image else None
		sig = signature(content) if content else from_hex(row.hex)
		if not sig:
			missed += 1
			continue
		frappe.db.set_value(film_decors.DOCTYPE, row.name, {"tone_l": sig["l"], "tone_a": sig["a"],
															 "tone_b": sig["b"], "texture": sig["texture"]},
							update_modified=False)
		done += 1
	frappe.db.commit()
	return {"done": done, "missed": missed}


def _candidates(company: str) -> list[dict]:
	rows = frappe.get_all(
		film_decors.DOCTYPE,
		filters={"company": company},
		fields=["name", "maker", "decor_name", "collection", "code", "hex", "image", "tone_l", "tone_a", "tone_b",
				"texture"],
		limit_page_length=0,
	)
	out = []
	for r in rows:
		sig = ({"l": flt(r.tone_l), "a": flt(r.tone_a), "b": flt(r.tone_b), "texture": flt(r.texture)}
			   if r.tone_l else from_hex(r.hex))
		if sig:
			out.append({**r, "sig": sig})
	return out


def _shelf(company: str) -> dict[tuple[str, str], list[dict]]:
	"""(maker, decor) → the shop's films of it, with what is free."""
	from korkem_manufacturing.services import film_catalog

	films: dict[tuple[str, str], list[dict]] = {}
	for f in film_catalog.catalog()["films"]:
		if f["maker"] and f["colour"] and not f["archived"]:
			free = flt(f.get("on_hand")) - flt(f.get("held"))
			films.setdefault((film_decors._key(f["maker"]), film_decors._key(f["colour"])), []).append(
				{"item": f["item"], "label": f["label"] or f["title"], "free": round(free, 2)})
	return films


def _answer(target: dict, rows: list[dict], shelf: dict, skip: str | None = None,
			other_maker: str | None = None) -> list[dict]:
	scored = []
	for r in rows:
		if r["name"] == skip:
			continue
		if other_maker and film_decors._key(r["maker"]) == film_decors._key(other_maker):
			continue
		scored.append((distance(target, r["sig"]), r))
	scored.sort(key=lambda p: p[0])
	out = []
	for d, r in scored[:SHOWN]:
		films = shelf.get((film_decors._key(r["maker"]), film_decors._key(r["decor_name"])), [])
		out.append({
			"decor": r["name"], "maker": r["maker"], "name": r["decor_name"], "collection": r["collection"],
			"code": r["code"], "hex": r["hex"], "image": r["image"], "distance": round(d, 1),
			"likeness": "close" if d < 6 else "near" if d < 12 else "far",
			"films": films, "on_shelf": round(sum(f["free"] for f in films if f["free"] > 0), 2),
		})
	# What is on the shelf first among the equally close: a sample matched
	# from stock is a sale today.
	out.sort(key=lambda a: (a["likeness"] != "close", a["on_shelf"] <= 0, a["distance"]))
	return out


def match_photo(content_b64: str) -> dict:
	"""The decors closest to a photo of a sample, what the shop has marked."""
	material_stock._ensure_staff()
	try:
		content = base64.b64decode((content_b64 or "").split(",")[-1])
	except (ValueError, TypeError):
		frappe.throw("Фото не прочиталось.")
	if not content or len(content) > PHOTO_MAX:
		frappe.throw(f"Фото — до {PHOTO_MAX // (1024 * 1024)} МБ.")
	company = current_company()
	target = signature(content, CENTRE)
	return {"tone": target, "matches": _answer(target, _candidates(company), _shelf(company))}


def analogues(decor: str | None = None, item: str | None = None) -> dict:
	"""A decor's or a film's closest look-alikes at the other makers."""
	material_stock._ensure_staff()
	company = current_company()
	rows = _candidates(company)
	maker, skip = None, None
	if decor:
		mine = next((r for r in rows if r["name"] == decor), None)
		if not mine:
			frappe.throw("У этого декора нет картинки или цвета — не с чем сравнить.", frappe.DoesNotExistError)
		target, maker, skip = mine["sig"], mine["maker"], decor
	elif item:
		film = frappe.db.get_value("Item", {"name": item, "korkem_material_company": company},
								   ["korkem_manufacturer", "korkem_color", "korkem_film_hex", "image"], as_dict=True)
		if not film:
			frappe.throw("Такой плёнки нет.", frappe.DoesNotExistError)
		maker = film.korkem_manufacturer
		mine = next((r for r in rows if film_decors._key(r["maker"]) == film_decors._key(maker)
					 and film_decors._key(r["decor_name"]) == film_decors._key(film.korkem_color)), None)
		target = mine["sig"] if mine else None
		if mine:
			skip = mine["name"]
		if not target and film.image:
			content = _file_content(film.image)
			target = signature(content) if content else None
		target = target or from_hex(film.get("korkem_film_hex"))
		if not target:
			frappe.throw("У этой плёнки нет картинки или цвета — не с чем сравнить.", frappe.DoesNotExistError)
	else:
		frappe.throw("Укажите декор или плёнку.")
	return {"maker": maker, "analogues": _answer(target, rows, _shelf(company), skip=skip, other_maker=maker)}
