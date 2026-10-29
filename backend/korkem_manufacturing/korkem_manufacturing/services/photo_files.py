# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""A photo from a phone, made safe to keep.

Moved out of `services/measurement.py` unchanged when a second kind of photo —
a defect on the shop floor — arrived: one parser allow-list, one EXIF strip,
one size limit, so the two can never drift apart. See `measurement.attach_photo`
for why each rule exists.
"""

from __future__ import annotations

import frappe


def cleaned(filename: str, content: bytes, *, fallback_name: str) -> tuple[str, bytes]:
	"""The name to store under and the pixels to store, or a refusal in words."""
	if not content:
		frappe.throw("Пустой файл. Снимок не дошёл — попробуйте ещё раз.")

	if len(content) > MAX_PHOTO_BYTES:
		frappe.throw(
			f"Снимок больше {MAX_PHOTO_BYTES // (1024 * 1024)} МБ. "
			"Похоже, это видео, а не фотография."
		)

	extension = _photo_kind(content)
	return _safe_name(filename, extension, fallback_name), _without_exif(content, extension)


#: Что мы соглашаемся принять с телефона. Ровно то, что делает камера, и
#: ничего сверх: Pillow умеет открыть четыре десятка форматов, включая PSD и
#: WMF, и каждый лишний — это ещё один разборщик, которому мы отдаём чужой файл.
PHOTO_FORMATS: dict[str, str] = {"JPEG": "jpg", "PNG": "png"}

#: Предел на один снимок. Телефонная камера даёт 3–8 МБ; двадцать оставляет
#: запас и всё ещё отсекает «случайно отправил видео».
MAX_PHOTO_BYTES = 20 * 1024 * 1024



def _photo_kind(content: bytes) -> str:
	"""Какой это снимок — по содержимому, с отказом словами, если никакой."""
	import io

	from PIL import Image, UnidentifiedImageError

	refusal = (
		"Это не фотография. Принимаются снимки JPEG и PNG — "
		"то, что делает камера телефона."
	)
	try:
		with Image.open(io.BytesIO(content)) as image:
			image.verify()
			fmt = image.format
	except (UnidentifiedImageError, OSError, ValueError):
		frappe.throw(refusal)

	if fmt not in PHOTO_FORMATS:
		frappe.throw(refusal)
	return PHOTO_FORMATS[fmt]


def _without_exif(content: bytes, extension: str) -> bytes:
	"""Пересобрать снимок из одних пикселей.

	Пересжатие теряет немного качества, и это правильная цена: снимок нужен,
	чтобы увидеть розетку и трубу, а не чтобы печатать. Всё остальное, что
	телефон дописал сбоку, — координаты, модель, время — уходит вместе с
	контейнером.
	"""
	import io

	from PIL import Image

	with Image.open(io.BytesIO(content)) as image:
		pixels = Image.new(image.mode, image.size)
		pixels.putdata(list(image.getdata()))
		buffer = io.BytesIO()
		if extension == "jpg":
			pixels.convert("RGB").save(buffer, format="JPEG", quality=90)
		else:
			pixels.save(buffer, format="PNG")
	return buffer.getvalue()


def _safe_name(filename: str, extension: str, fallback_name: str) -> str:
	"""Имя, за которое отвечаем мы, а не отправитель.

	От присланного остаётся только основа, и та обрезанная; расширение ставится
	по содержимому. Путь, кавычки и точки из имени уходят: файл с именем
	`../../x.png` — не имя, а попытка.
	"""
	base = (filename or "").rsplit("/", 1)[-1].rsplit("\\", 1)[-1]
	base = base.rsplit(".", 1)[0]
	base = "".join(c for c in base if c.isalnum() or c in " -_")[:40].strip()
	return f"{base or fallback_name}-{frappe.generate_hash(length=6)}.{extension}"
