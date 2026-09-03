# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Есть ли сборка новее той, что у человека в руках.

## Зачем это существует

Владелец сказал прямо: «если наши клиенты которые один раз скачали наше
приложение они тоже будут каждый раз скачивать? нет так не должно быть». Он
прав. Приложение, обновляемое пересылкой файла, обновляется у одного человека —
у того, кому файл переслали.

Google Play делает это сам, и туда мы идём. Но до Play, и для тех, кому Play
недоступен, узел обязан уметь сказать приложению: «есть версия новее, вот она».
Это ровно то, что архитектура продукта разрешает держать снаружи завода —
манифест обновлений, — в отличие от заказов и цен.

## Почему открыто для гостя

Ответ состоит из номера версии и адреса файла. Файл и так лежит открыто: его
скачивают по ссылке из браузера. Прятать за входом номер версии значило бы, что
приложение, устаревшее настолько, что не может войти, не узнает и о том, что
устарело.
"""

from __future__ import annotations

import frappe

DOCTYPE = "App Release"


@frappe.whitelist(allow_guest=True)
def latest(platform: str = "Android", build: int | str | None = None) -> dict:
	"""Самая свежая опубликованная сборка для платформы.

	`build` — номер сборки, которая спрашивает. Сравнение делает сервер, а не
	клиент: правило «что считать новее» тогда одно на всех, и старое приложение
	не начнёт спорить с новым сервером.
	"""
	platform = (platform or "Android").strip()

	rows = frappe.get_all(
		DOCTYPE,
		filters={"platform": platform, "published": 1},
		fields=["version", "build_number", "file_url", "notes", "mandatory"],
		order_by="build_number desc",
		limit_page_length=1,
	)
	if not rows:
		# Ни одной опубликованной сборки — это не ошибка, а состояние узла,
		# в котором обновлений просто нет.
		return {"available": False, "platform": platform}

	release = rows[0]
	try:
		mine = int(build) if build is not None else 0
	except (TypeError, ValueError):
		mine = 0

	newer = release["build_number"] > mine
	return {
		"available": newer,
		"platform": platform,
		"version": release["version"],
		"build": release["build_number"],
		# Адрес отдаётся абсолютным: приложение может быть настроено на другой
		# адрес узла, чем тот, что записан в справочнике, и склеивать пути на
		# клиенте — верный способ однажды скачать не то.
		"url": _absolute(release["file_url"]),
		"notes": release["notes"] or "",
		"mandatory": bool(release["mandatory"]),
	}


def _absolute(url: str) -> str:
	if url.startswith("http://") or url.startswith("https://"):
		return url
	return f"{frappe.utils.get_url()}{url if url.startswith('/') else '/' + url}"
