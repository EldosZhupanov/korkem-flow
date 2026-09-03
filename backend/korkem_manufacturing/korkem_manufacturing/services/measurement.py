# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Замер — этап 2 цепочки, звено между заявкой и ценой.

До замера известно, что клиент чего-то хочет. После — известно, чего именно и
сколько, и только тогда можно назвать цену. Поэтому здесь заканчивается «мы
приняли обращение» и начинается «мы знаем, что делаем».

Решения, из-за которых файл выглядит так.

**Замер закрывает задачу, а не создаёт новую сущность.** Задача замерщику уже
создана на этапе 1 и уже привязана к сказанному. Заводить отдельный документ
«Замер» значило бы держать два места, где написано одно и то же, и однажды они
разойдутся. Результат замера ложится на заявку, а задача становится
выполненной — тем же действием, потому что человек делает это одним движением.

**Адрес — не заметка.** Он нужен доставке и монтажу, то есть двум звеньям в
конце цепочки, до которых полгода. Записанный текстом в комментарий, он к тому
моменту будет потерян среди других комментариев. Поэтому адрес идёт в
`Address` ERPNext, привязанный к клиенту, — туда, где его будут искать.

**Фотография стены — это тоже размер.** Замерщик стоит на объекте с телефоном,
и то, что он видит, словами не передаётся: розетка не на месте, труба в углу,
пол с уклоном. Через месяц в цехе такой снимок стоит дороже всех заметок,
поэтому фото ложится на ту же заявку, что и размеры, — туда, где его будут
искать дизайн, доставка и монтаж.

**Размеры остаются текстом, и это осознанно.** «3200 на 600, высота 2100, угол
слева» — это то, что говорит замерщик, и разбирать это на поля значит
навязывать форму, которой у мебели на заказ нет. Разбор придёт вместе с
импортом из БАЗИС, где размеры уже структурированы технологом.
"""

from __future__ import annotations

import frappe

from korkem_manufacturing.services.scope import scoped


def record(
	*,
	enquiry: str,
	dimensions: str | None = None,
	notes: str | None = None,
	address_line: str | None = None,
	city: str | None = None,
	measured_on: str | None = None,
) -> dict:
	"""Записать результат замера на заявку и закрыть задачу замерщика."""
	opportunity = _visible_enquiry(enquiry)

	dimensions = (dimensions or "").strip()
	notes = (notes or "").strip()
	if not dimensions and not notes:
		frappe.throw(
			"Замер без единого измерения и без единого слова — это не замер. "
			"Запишите хотя бы размеры или то, что увидели."
		)

	address = None
	if address_line:
		address = _address(opportunity, address_line, city)

	_write_result(opportunity, dimensions, notes, measured_on)
	closed = _close_the_task(opportunity)

	return {
		"enquiry": opportunity.name,
		"address": address,
		"task_closed": closed,
		"measured_on": measured_on or frappe.utils.nowdate(),
	}


#: Что мы соглашаемся принять с телефона. Ровно то, что делает камера, и
#: ничего сверх: Pillow умеет открыть четыре десятка форматов, включая PSD и
#: WMF, и каждый лишний — это ещё один разборщик, которому мы отдаём чужой файл.
PHOTO_FORMATS: dict[str, str] = {"JPEG": "jpg", "PNG": "png"}

#: Предел на один снимок. Телефонная камера даёт 3–8 МБ; двадцать оставляет
#: запас и всё ещё отсекает «случайно отправил видео».
MAX_PHOTO_BYTES = 20 * 1024 * 1024


def attach_photo(*, enquiry: str, filename: str, content: bytes) -> dict:
	"""Приложить снимок с замера к заявке.

	Снимок сохраняется **без EXIF**. Телефон записывает в него координаты места
	съёмки, то есть адрес квартиры клиента, — и делает это молча. Frappe умеет
	их срезать, но только для JPEG, только если у файла проставлен тип, и только
	когда включена настройка сайта; три условия, любое из которых однажды
	окажется ложным. Здесь оно безусловно.

	Файл кладётся **закрытым**. Открытый файл в Frappe доступен по ссылке
	любому, кто её знает, а это фотография чужой квартиры: где окно, где дверь,
	что стоит в комнате. Такая ссылка не должна существовать.

	Тип определяется разбором, а не первыми байтами. Имя файла приходит с
	телефона и означает ровно то, что в нём написал отправитель, а шапку JPEG
	приписать к чему угодно — минута. Frappe всё равно откроет файл, чтобы
	срезать EXIF, и на подделке падает пятисоткой; лучше отказать здесь, словами.
	"""
	opportunity = _visible_enquiry(enquiry)

	if not content:
		frappe.throw("Пустой файл. Снимок не дошёл — попробуйте ещё раз.")

	if len(content) > MAX_PHOTO_BYTES:
		frappe.throw(
			f"Снимок больше {MAX_PHOTO_BYTES // (1024 * 1024)} МБ. "
			"Похоже, это видео, а не фотография."
		)

	extension = _photo_kind(content)
	content = _without_exif(content, extension)

	doc = frappe.get_doc(
		{
			"doctype": "File",
			"file_name": _safe_name(filename, extension),
			"attached_to_doctype": "Opportunity",
			"attached_to_name": opportunity.name,
			"is_private": 1,
			"content": content,
		}
	)
	doc.insert()

	return {
		"enquiry": opportunity.name,
		"file": doc.name,
		"file_name": doc.file_name,
		"size": len(content),
		"status": "attached",
	}


def photos(*, enquiry: str) -> list[dict]:
	"""Что уже приложено к этой заявке."""
	opportunity = _visible_enquiry(enquiry)
	return [
		{"file": row["name"], "file_name": row["file_name"], "size": row.get("file_size")}
		for row in frappe.get_all(
			"File",
			filters={
				"attached_to_doctype": "Opportunity",
				"attached_to_name": opportunity.name,
			},
			fields=["name", "file_name", "file_size"],
			order_by="creation asc",
		)
	]


def _photo_kind(content: bytes) -> str:
	"""Какой это снимок — по содержимому, с отказом словами, если никакой."""
	import io

	from PIL import Image, UnidentifiedImageError

	refusal = (
		"Это не фотография. С замера принимаются снимки JPEG и PNG — "
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


def _safe_name(filename: str, extension: str) -> str:
	"""Имя, за которое отвечаем мы, а не отправитель.

	От присланного остаётся только основа, и та обрезанная; расширение ставится
	по содержимому. Путь, кавычки и точки из имени уходят: файл с именем
	`../../x.png` — не имя, а попытка.
	"""
	base = (filename or "").rsplit("/", 1)[-1].rsplit("\\", 1)[-1]
	base = base.rsplit(".", 1)[0]
	base = "".join(c for c in base if c.isalnum() or c in " -_")[:40].strip()
	return f"{base or 'замер'}-{frappe.generate_hash(length=6)}.{extension}"


def _visible_enquiry(name: str):
	if not frappe.get_list("Opportunity", filters=scoped({"name": name}), pluck="name"):
		frappe.throw("Нет такой заявки в этой компании.", frappe.PermissionError)
	return frappe.get_doc("Opportunity", name)


def _address(opportunity, line: str, city: str | None) -> str | None:
	"""Адрес там, где его будет искать доставка, а не в ленте комментариев."""
	savepoint = "korkem_measure_addr_" + frappe.generate_hash(length=8)
	try:
		frappe.db.savepoint(savepoint)
		doc = frappe.get_doc(
			{
				"doctype": "Address",
				"address_title": opportunity.party_name or opportunity.name,
				"address_type": "Shipping",
				"address_line1": line.strip(),
				"city": (city or "").strip() or None,
				"links": [
					{"link_doctype": "Customer", "link_name": opportunity.party_name}
				]
				if opportunity.party_name
				else [],
			}
		)
		doc.flags.ignore_mandatory = True
		doc.insert(ignore_permissions=True)
		frappe.db.release_savepoint(savepoint)
		return doc.name
	except Exception:
		try:
			frappe.db.rollback(save_point=savepoint)
		except Exception:
			pass
		# Адрес важен, но не настолько, чтобы потерять из-за него весь замер:
		# размеры записаны, задача закрыта, а адрес добавят руками.
		frappe.log_error(
			title="Could not store a measurement address",
			message=frappe.get_traceback(with_context=True),
		)
		return None


def _write_result(opportunity, dimensions: str, notes: str, measured_on: str | None) -> None:
	parts = [f"KORKEM: замер {measured_on or frappe.utils.nowdate()}"]
	if dimensions:
		parts.append(f"Размеры: {dimensions}")
	if notes:
		parts.append(notes)

	frappe.get_doc(
		{
			"doctype": "Comment",
			"comment_type": "Info",
			"reference_doctype": "Opportunity",
			"reference_name": opportunity.name,
			"content": "\n".join(parts),
		}
	).insert(ignore_permissions=True)


def _close_the_task(opportunity) -> str | None:
	"""Закрыть задачу замерщика, если она есть.

	Задача привязана к сказанному, а не к заявке: её создали в тот момент, когда
	заявки ещё не было. Поэтому идём через захват, который эту заявку породил.
	"""
	captures = frappe.get_list(
		"Capture",
		filters=scoped({"enquiry": opportunity.name}),
		fields=["name", "task"],
		limit_page_length=1,
	)
	if not captures or not captures[0].get("task"):
		return None

	task = captures[0]["task"]
	if not frappe.db.exists("CRM Task", task):
		return None

	frappe.db.set_value("CRM Task", task, "status", "Done")
	return str(task)
