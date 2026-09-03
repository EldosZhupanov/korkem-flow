# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Push на телефон — сигнал, а не сообщение.

## Что уходит наружу, и почему так мало

Push идёт через серверы Google. Обещание клиенту противоположное: заказы, цены,
имена и зарплаты не покидают его здания (R6, `docs/operations/privacy_policy.md`).
Уведомление «Заказ Ерлана на 650 000 ₸ просрочен» нарушило бы это обещание, не
нарушив ни строчки кода — поэтому наружу уходит **только признак события**:

    {"data": {"kind": "attention"}}

Ни заголовка, ни текста, ни идентификаторов. Телефон будит приложение, оно идёт
за подробностями на свой узел по TLS и показывает их уже само. Человек видит то
же самое; через Google не проходит ничего.

Это стоит одного лишнего запроса на уведомление и является единственной
причиной, по которой push здесь вообще допустим.

## Чей это Firebase

Проект Firebase принадлежит владельцу узла, как и ключ ИИ, токен Telegram и
доступ к Kaspi — та же развилка 7 из `ROADMAP.md`. Ключ сервисного аккаунта
лежит в `Push Settings` полем типа `Password`: Frappe держит такие в `__Auth`,
шифрует ключом сайта и наружу через API не отдаёт.
"""

from __future__ import annotations

import json
import time

import frappe
import requests

SETTINGS_DOCTYPE = "Push Settings"
IDENTITY_DOCTYPE = "Channel Identity"
CHANNEL = "Push"

#: Google выдаёт токен доступа на час; берём с запасом, чтобы не отправить
#: уведомление с ключом, протухшим по дороге.
_TOKEN_TTL = 3300

_FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
_FCM_ENDPOINT = "https://fcm.googleapis.com/v1/projects/{project}/messages:send"

_token_cache: dict[str, tuple[str, float]] = {}


class PushNotConfigured(frappe.ValidationError):
	"""Узел не знает, куда отправлять. Не ошибка доставки, а отсутствие настройки."""


def register_device(token: str, user: str | None = None) -> dict:
	"""Запомнить адрес устройства как ещё один способ дозвониться до человека.

	Один и тот же телефон может прийти дважды — при переустановке приложения или
	после очистки данных Firebase выдаёт новый адрес, а старый ещё какое-то время
	живёт. Поэтому запись ищется по адресу, а не создаётся всегда: иначе у
	человека накапливаются мёртвые устройства, и каждое уведомление уходит в них
	тоже.
	"""
	token = (token or "").strip()
	if not token:
		frappe.throw("Пустой адрес устройства.")

	user = user or frappe.session.user
	if user in ("Guest", "Administrator"):
		frappe.throw("Уведомления привязываются к живому человеку, а не к служебной учётной записи.")

	existing = frappe.db.get_value(
		IDENTITY_DOCTYPE, {"channel": CHANNEL, "external_id": token}, ["name", "user"]
	)
	if existing:
		name, owner = existing
		if owner != user:
			# Телефон сменил хозяина — так бывает в цехе. Старая привязка
			# должна исчезнуть, иначе прошлый работник продолжит получать
			# уведомления завода на устройство, которое ему больше не принадлежит.
			frappe.db.set_value(IDENTITY_DOCTYPE, name, "user", user)
		frappe.db.set_value(IDENTITY_DOCTYPE, name, "enabled", 1)
		frappe.db.set_value(IDENTITY_DOCTYPE, name, "last_seen_on", frappe.utils.now_datetime())
		return {"identity": name, "created": False}

	doc = frappe.get_doc(
		{
			"doctype": IDENTITY_DOCTYPE,
			"channel": CHANNEL,
			"external_id": token,
			"user": user,
			"enabled": 1,
			"last_seen_on": frappe.utils.now_datetime(),
		}
	).insert(ignore_permissions=True)
	return {"identity": doc.name, "created": True}


def forget_device(token: str) -> dict:
	"""Выход из приложения — это «на этот телефон больше не присылать»."""
	name = frappe.db.get_value(IDENTITY_DOCTYPE, {"channel": CHANNEL, "external_id": token})
	if not name:
		return {"forgotten": False}
	frappe.db.set_value(IDENTITY_DOCTYPE, name, "enabled", 0)
	return {"forgotten": True}


def send(external_id: str, kind: str = "attention") -> dict:
	"""Разбудить одно устройство. Без текста — см. заголовок модуля.

	`kind` говорит приложению, куда сходить за подробностями, и не говорит
	ничего о самом деле: «attention» — это «посмотри, что требует внимания»,
	а не «просрочен заказ такой-то».
	"""
	project, access = _credentials()
	response = requests.post(
		_FCM_ENDPOINT.format(project=project),
		headers={"Authorization": f"Bearer {access}", "Content-Type": "application/json"},
		json={"message": {"token": external_id, "data": {"kind": kind}}},
		timeout=15,
	)
	if response.status_code == 404 or (
		response.status_code == 400 and "UNREGISTERED" in response.text
	):
		# Устройство больше не существует: приложение удалили или очистили.
		# Google сообщает об этом один раз; не выключить запись здесь значит
		# стучаться в него до конца времён.
		forget_device(external_id)
		return {"ok": False, "reason": "device_gone"}
	if response.status_code >= 400:
		frappe.throw(f"Firebase ответил {response.status_code}: {response.text[:300]}")
	return {"ok": True}


def _credentials() -> tuple[str, str]:
	"""Идентификатор проекта и свежий токен доступа Google."""
	settings = frappe.get_single(SETTINGS_DOCTYPE)
	if not settings.enabled:
		raise PushNotConfigured("Push-уведомления выключены в настройках узла.")

	raw = settings.get_password("service_account_json", raise_exception=False)
	if not raw:
		raise PushNotConfigured("Не задан ключ сервисного аккаунта Firebase.")

	try:
		account = json.loads(raw)
	except json.JSONDecodeError as exc:
		raise PushNotConfigured(
			"Ключ сервисного аккаунта не читается как JSON. Это файл, который "
			"Firebase даёт целиком — его вставляют целиком."
		) from exc

	project = account.get("project_id")
	if not project:
		raise PushNotConfigured("В ключе нет project_id: это не ключ сервисного аккаунта.")

	cached = _token_cache.get(project)
	if cached and cached[1] > time.time():
		return project, cached[0]

	access = _mint_access_token(account)
	_token_cache[project] = (access, time.time() + _TOKEN_TTL)
	return project, access


def _mint_access_token(account: dict) -> str:
	"""Обменять ключ сервисного аккаунта на часовой токен доступа.

	Google требует подписанный JWT; библиотека `google-auth` делает это сама и
	уже стоит в окружении Frappe как зависимость Google-интеграций. Своя
	реализация подписи здесь была бы криптографией, написанной ради экономии
	одного импорта.
	"""
	from google.oauth2 import service_account

	credentials = service_account.Credentials.from_service_account_info(
		account, scopes=[_FCM_SCOPE]
	)
	from google.auth.transport.requests import Request

	credentials.refresh(Request())
	return credentials.token
