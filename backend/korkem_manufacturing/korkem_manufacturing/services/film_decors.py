"""Makers' decor catalogues with pictures (owner, 18.11.2026).

The owner: films should be seen «на глаз» when they are chosen. The makers
publish catalogues — MC Group a PDF with a swatch per decor — so:

- **A catalogue is a reference, not stock.** Each decor is a `Film Decor`:
  maker, name, collection, code, the thicknesses it comes in, its average
  colour and its swatch. 284 decors of MC Group do not become 284 films on
  the store; a film is made from a decor when the shop takes it in.
- **A film shows its decor's picture** — the same maker, the same name —
  until it has a photo of its own (`Item.image`): a sample photographed in
  the shop, or a file from the supplier.
- **A catalogue comes in as a pack**: a zip with a `manifest.json` and the
  pictures. The pack is made once from the maker's PDF or site and loaded on
  each base; loading it again updates, it does not double.

The pictures belong to the makers; they are shown inside the shop's own
program to pick the films bought from them.
"""

from __future__ import annotations

import base64
import io
import json
import os
import re
import zipfile

import frappe
from frappe.utils import cint

from korkem_manufacturing.services import audit, film_catalog, material_stock
from korkem_manufacturing.services.scope import current_company

DOCTYPE = "Film Decor"
IMAGE_MAX = 8 * 1024 * 1024
PACK_MAX = 60 * 1024 * 1024
IMAGE_EXT = (".jpg", ".jpeg", ".png", ".webp")
_HEX = re.compile(r"^#[0-9A-Fa-f]{6}$")


def _key(text: str | None) -> str:
	"""«Сиена  Верде» and «сиена верде» are one decor."""
	return " ".join(str(text or "").replace("ё", "е").replace("Ё", "Е").split()).casefold()


def _code_key(text: str | None) -> str:
	return re.sub(r"[\s_\-.]+", "", str(text or "")).casefold()


# --------------------------------------------------------------------------
# Reading
# --------------------------------------------------------------------------


def _rows(company: str, maker: str | None = None) -> list:
	filters = {"company": company}
	if maker:
		filters["maker"] = maker
	return frappe.get_all(
		DOCTYPE,
		filters=filters,
		fields=["name", "maker", "decor_name", "collection", "code", "thickness", "hex", "image", "source"],
		order_by="maker asc, collection asc, decor_name asc",
		limit_page_length=0,
	)


def images_by_film(company: str) -> dict[tuple[str, str], str]:
	"""(maker, name) → the decor's picture: what a film without a photo shows."""
	return {
		(_key(r.maker), _key(r.decor_name)): r.image
		for r in frappe.get_all(DOCTYPE, filters={"company": company, "image": ["is", "set"]},
								fields=["maker", "decor_name", "image"], limit_page_length=0)
	}


def image_of(company: str, maker: str | None, colour: str | None) -> dict:
	"""One film's decor picture, in the shape `images_by_film` gives."""
	if not maker or not colour:
		return {}
	image = frappe.db.get_value(DOCTYPE, {"company": company, "maker": maker, "decor_name": colour}, "image")
	return {(_key(maker), _key(colour)): image} if image else {}


def decors(maker: str | None = None) -> dict:
	"""The catalogues: each decor with its picture and, when the shop has
	the film, which one and how much is on hand."""
	material_stock._ensure_staff()
	company = current_company()
	films: dict[tuple[str, str], list[dict]] = {}
	for f in film_catalog.catalog()["films"]:
		if f["maker"] and f["colour"]:
			films.setdefault((_key(f["maker"]), _key(f["colour"])), []).append(f)
	out = []
	for r in _rows(company, maker):
		mine = films.get((_key(r.maker), _key(r.decor_name)), [])
		out.append({
			"decor": r.name, "maker": r.maker, "name": r.decor_name, "collection": r.collection,
			"code": r.code, "thickness": r.thickness, "hex": r.hex, "image": r.image,
			"films": [{"item": f["item"], "label": f["label"], "on_hand": f["on_hand"],
					   "thickness_mm": f["thickness_mm"]} for f in mine if not f["archived"]],
		})
	makers: dict[str, int] = {}
	for d in out:
		makers[d["maker"]] = makers.get(d["maker"], 0) + 1
	return {"decors": out, "makers": [{"maker": m, "count": n} for m, n in sorted(makers.items())],
			"can_edit": material_stock.can_edit()}


# --------------------------------------------------------------------------
# A pack in
# --------------------------------------------------------------------------


def _attach(doctype: str, name: str, field: str, file_name: str, content: bytes) -> str:
	if len(content) > IMAGE_MAX:
		frappe.throw(f"Картинка больше {IMAGE_MAX // (1024 * 1024)} МБ.")
	if not file_name.lower().endswith(IMAGE_EXT):
		frappe.throw("Картинка — jpg, png или webp.")
	for old in frappe.get_all("File", filters={"attached_to_doctype": doctype, "attached_to_name": name,
												"attached_to_field": field}, pluck="name"):
		frappe.delete_doc("File", old, ignore_permissions=True, force=True)
	f = frappe.get_doc({
		"doctype": "File", "file_name": file_name, "attached_to_doctype": doctype, "attached_to_name": name,
		"attached_to_field": field, "is_private": 0, "content": content,
	}).insert(ignore_permissions=True)
	frappe.db.set_value(doctype, name, field, f.file_url, update_modified=False)
	return f.file_url


def _manifest(z: zipfile.ZipFile) -> list[dict]:
	names = [n for n in z.namelist() if n.lower().endswith(".json") and not n.startswith("__MACOSX")]
	if not names:
		frappe.throw("В архиве нет manifest.json.")
	name = next((n for n in names if os.path.basename(n) == "manifest.json"), names[0])
	try:
		rows = json.loads(z.read(name).decode("utf-8"))
	except (ValueError, UnicodeDecodeError):
		frappe.throw(f"{name} не прочитался.")
	if isinstance(rows, dict):
		rows = rows.get("decors") or []
	if not isinstance(rows, list) or not rows:
		frappe.throw("В manifest.json нет декоров.")
	return rows


def import_pack(content: bytes, maker: str | None = None, source: str | None = None) -> dict:
	"""Load a maker's catalogue: new decors are added, known ones (the same
	maker and name) updated — loading the same pack twice changes nothing."""
	material_stock._ensure_editor()
	company = current_company()
	if len(content) > PACK_MAX:
		frappe.throw(f"Архив больше {PACK_MAX // (1024 * 1024)} МБ.")
	try:
		z = zipfile.ZipFile(io.BytesIO(content))
	except zipfile.BadZipFile:
		frappe.throw("Это не zip-архив.")
	files = {os.path.basename(n): n for n in z.namelist() if n.lower().endswith(IMAGE_EXT)}
	known = {(_key(r.maker), _key(r.decor_name)): r.name for r in _rows(company)}
	added = updated = pictures = 0
	makers = set()
	for row in _manifest(z):
		if not isinstance(row, dict):
			continue
		who = " ".join(str(maker or row.get("maker") or "").split())
		title = " ".join(str(row.get("name") or "").split())[:140]
		if not who or len(title) < 2:
			continue
		makers.add(who)
		values = {
			"collection": " ".join(str(row.get("collection") or "").split())[:140] or None,
			"code": " ".join(str(row.get("code") or "").split())[:60] or None,
			"thickness": " ".join(str(row.get("thickness") or "").split())[:60] or None,
			"hex": row.get("hex") if _HEX.match(str(row.get("hex") or "")) else None,
			"source": (source or row.get("source") or "")[:140] or None,
		}
		key = (_key(who), _key(title))
		if key in known:
			frappe.db.set_value(DOCTYPE, known[key], values)
			name = known[key]
			updated += 1
		else:
			name = frappe.get_doc({"doctype": DOCTYPE, "company": company, "maker": who, "decor_name": title,
								   **values}).insert(ignore_permissions=True).name
			known[key] = name
			added += 1
		picture = files.get(os.path.basename(str(row.get("image") or "")))
		if picture:
			content = z.read(picture)
			_attach(DOCTYPE, name, "image", os.path.basename(picture), content)
			_remember_tone(name, content)
			pictures += 1
		elif values["hex"]:
			_remember_tone(name, None, values["hex"])
	for who in makers:
		if who not in material_stock.enabled_values(film_catalog.MAKERS, company):
			material_stock.put_option(film_catalog.MAKERS, who)
	audit.record_audit(action="film_decors.import", entity_type="Company", entity_id=company,
					   diff={"makers": sorted(makers), "added": added, "updated": updated, "pictures": pictures},
					   company=company)
	return {"added": added, "updated": updated, "pictures": pictures, "makers": sorted(makers)}


def import_pack_file(path: str, maker: str | None = None, source: str | None = None) -> dict:
	"""The same, from a file on the server — how a pack is loaded on a base
	from the laptop's own script."""
	with open(path, "rb") as fh:
		return import_pack(fh.read(), maker, source)


# --------------------------------------------------------------------------
# A film from a decor; a film's own photo
# --------------------------------------------------------------------------


def from_decor(decor: str, thickness: str | None = None, width: str | None = None, **card) -> dict:
	"""Take a decor in as a film: its maker, name, collection, code and
	average colour come from the catalogue; the picture shows by itself."""
	material_stock._ensure_editor()
	company = current_company()
	d = frappe.db.get_value(DOCTYPE, decor, ["company", "maker", "decor_name", "collection", "code", "hex"],
							as_dict=True)
	if not d or d.company != company:
		frappe.throw("Такого декора нет.", frappe.DoesNotExistError)
	if d.maker not in material_stock.enabled_values(film_catalog.MAKERS, company):
		material_stock.put_option(film_catalog.MAKERS, d.maker)
	if d.collection and d.collection not in film_catalog.collections(company).get(d.maker, []):
		material_stock.put_option(film_catalog.COLLECTIONS, film_catalog.label(d.maker, d.collection))
	given = {k: v for k, v in card.items() if k in film_catalog.CARD and str(v or "").strip()}
	if d.code and not given.get("code"):
		given["code"] = d.code
	if d.hex and not given.get("hex"):
		given["hex"] = d.hex
	return film_catalog.add(d.maker, d.decor_name, thickness=thickness, width=width, collection=d.collection,
							**given)


def _decode(content_b64: str) -> bytes:
	try:
		raw = base64.b64decode(str(content_b64 or "").split(",")[-1], validate=False)
	except (ValueError, TypeError):
		frappe.throw("Картинка не прочиталась.")
	if not raw:
		frappe.throw("Пустая картинка.")
	return raw


def set_film_image(item: str, file_name: str, content_b64: str) -> dict:
	"""A film's own photo — a sample photographed in the shop, or a file
	from the supplier. It goes on every thickness of the film."""
	material_stock._ensure_editor()
	material_stock._own_item(item)
	if frappe.db.get_value("Item", item, "korkem_material_kind") != material_stock.FILM:
		frappe.throw("Это не плёнка.")
	url = _attach("Item", item, "image", file_name, _decode(content_b64))
	for other in film_catalog.siblings(item):
		if other != item:
			frappe.db.set_value("Item", other, "image", url, update_modified=False)
	audit.record_audit(action="film.image", entity_type="Item", entity_id=item, diff={"image": url})
	return film_catalog.film(item)


def clear_film_image(item: str) -> dict:
	"""Back to the decor's picture, if the catalogue has one."""
	material_stock._ensure_editor()
	material_stock._own_item(item)
	for other in film_catalog.siblings(item):
		frappe.db.set_value("Item", other, "image", None, update_modified=False)
	audit.record_audit(action="film.image", entity_type="Item", entity_id=item, diff={"image": None})
	return film_catalog.film(item)


def set_decor_image(decor: str, file_name: str, content_b64: str) -> dict:
	material_stock._ensure_editor()
	if frappe.db.get_value(DOCTYPE, decor, "company") != current_company():
		frappe.throw("Такого декора нет.", frappe.DoesNotExistError)
	content = _decode(content_b64)
	_attach(DOCTYPE, decor, "image", file_name, content)
	_remember_tone(decor, content)
	return {"decor": decor, "image": frappe.db.get_value(DOCTYPE, decor, "image")}


def _remember_tone(decor: str, content: bytes | None, code: str | None = None) -> None:
	"""The decor's colour for «подбор по фото» and its analogues (`decor_colors`)."""
	from korkem_manufacturing.services import decor_colors

	if content:
		decor_colors.remember(decor, content)
	elif sig := decor_colors.from_hex(code):
		frappe.db.set_value(DOCTYPE, decor, {"tone_l": sig["l"], "tone_a": sig["a"], "tone_b": sig["b"],
											 "texture": 0}, update_modified=False)


def delete_maker(maker: str) -> dict:
	"""A maker's whole catalogue off — the films stay, with their own photos."""
	material_stock._ensure_editor()
	company = current_company()
	gone = 0
	for name in frappe.get_all(DOCTYPE, filters={"company": company, "maker": maker}, pluck="name"):
		frappe.delete_doc(DOCTYPE, name, ignore_permissions=True, force=True)
		gone += 1
	audit.record_audit(action="film_decors.delete", entity_type="Company", entity_id=company,
					   diff={"maker": maker, "decors": gone}, company=company)
	return {"deleted": cint(gone)}
