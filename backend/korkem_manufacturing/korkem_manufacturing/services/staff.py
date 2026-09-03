# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Что происходит с человеком после приглашения: должность и уход.

Последний пункт «администрирования без админки», и единственный из пяти, где
цена ошибки не «неудобно», а «чужой человек читает базу клиентов».

Три правила, и все три — про то, чего нельзя, а не про то, как удобнее.

**Свою должность не меняет никто, включая владельца.** Для сотрудника это R5:
повышение себе прав. Для владельца это другое, но не лучше — он единственный
System Manager, и, понизив себя, запирает завод снаружи: вернуть права будет
некому. Отказ здесь дешевле восстановления.

**Ушедший отключается, а не удаляется.** Он подписывал замеры, вёл заказы и
принимал работу; удалить учётную запись значит оторвать имя от всего, что он
сделал. `enabled = 0` закрывает вход и оставляет историю читаемой.

**И вместе с входом закрываются открытые сессии.** Одного `enabled = 0` мало, и
это проверено живым запросом: новый вход после отключения даёт 401, а приложение,
уже открытое на телефоне, продолжает работать с прежней сессией как ни в чём не
бывало. Уволенный сотрудник не выходит из приложения — он просто уходит с ним;
именно этот случай функция и должна закрывать, а закрывала бы только тот, где он
предупредительно нажал «выйти».

**Последнего владельца отключить нельзя.** Компания без единого System Manager
не может ни пригласить, ни исправить, ни включить обратно — только через
консоль, до которой у владельца мебельной мастерской нет ни доступа, ни повода.

Смена должности, в отличие от отключения, действует на открытую сессию сразу:
Frappe сбрасывает кеш ролей при сохранении `User`. Проверено тем же способом —
понижение до склада, и следующий же запрос к предложениям отвечает 403.

**Роли снимаются только те, что мы выдавали.** Должность — это набор ролей из
`invitations.POSITIONS`; всё, что стоит на человеке помимо них, поставили не мы,
и молча снимать это при смене должности значит менять то, о чём не просили.
"""

from __future__ import annotations

import frappe

from korkem_manufacturing.services.invitations import POSITIONS
from korkem_manufacturing.services.scope import current_company

#: Роль, без которой компанией некому управлять.
OWNER_ROLE = "System Manager"


def change_position(*, email: str, position: str) -> dict:
	"""Сменить должность человека — то есть набор его прав."""
	frappe.only_for(OWNER_ROLE)

	user = _visible_user(email)
	_refuse_self(user.name, "Свою должность не меняют")

	position = (position or "").strip().lower()
	roles = POSITIONS.get(position)
	if not roles:
		frappe.throw(
			"Неизвестная должность. Выберите из тех, что предлагает сервер: "
			+ ", ".join(sorted(POSITIONS))
		)

	ours = {role for names in POSITIONS.values() for role in names}
	kept = {row.role for row in user.get("roles") or []} - ours
	user.set("roles", [])
	for role in sorted(kept | set(roles)):
		user.append("roles", {"role": role})
	user.save(ignore_permissions=True)

	_audit(user.name, f"должность изменена на «{position}»")

	return {
		"user": user.name,
		"position": position,
		"roles": sorted(row.role for row in user.get("roles") or []),
		"enabled": bool(user.enabled),
	}


def deactivate(*, email: str) -> dict:
	"""Закрыть вход ушедшему. История его работы остаётся на месте."""
	frappe.only_for(OWNER_ROLE)

	user = _visible_user(email)
	_refuse_self(user.name, "Себя не отключают")
	_refuse_last_owner(user)

	if not user.enabled:
		return {"user": user.name, "enabled": False, "status": "already_disabled"}

	# Считаем до сохранения: Frappe при некоторых изменениях `User` чистит
	# сессии сам, и счёт, снятый после, показывал бы ноль там, где человека
	# только что выкинули. Число в ответе должно означать то, что написано.
	open_now = frappe.db.count("Sessions", {"user": user.name})

	user.enabled = 0
	user.save(ignore_permissions=True)

	closed = _close_open_sessions(user.name, open_now)
	_audit(user.name, f"доступ закрыт, сессий завершено: {closed}")

	return {
		"user": user.name,
		"enabled": False,
		"sessions_closed": closed,
		"status": "disabled",
	}


def reactivate(*, email: str) -> dict:
	"""Вернуть доступ — человек вышел из отпуска или вернулся на работу."""
	frappe.only_for(OWNER_ROLE)

	user = _visible_user(email)
	if user.enabled:
		return {"user": user.name, "enabled": True, "status": "already_enabled"}

	user.enabled = 1
	user.save(ignore_permissions=True)
	_audit(user.name, "доступ возвращён")

	return {"user": user.name, "enabled": True, "status": "enabled"}


def _close_open_sessions(user: str, open_now: int) -> int:
	"""Выкинуть человека из уже открытых приложений, а не только со входа.

	Frappe сам этого не делает: он завершает сессии при смене типа
	пользователя, но не при `enabled = 0`. Проверено живым запросом — после
	отключения новый вход даёт 401, а уже открытое приложение продолжает
	работать как ни в чём не бывало.
	"""
	import frappe.sessions

	frappe.sessions.clear_sessions(user=user, keep_current=False, force=True)
	return open_now


def _visible_user(email: str):
	"""Человек этой компании. Чужой сотрудник — не наш, даже если почта известна."""
	email = (email or "").strip().lower()
	if not email or not frappe.db.exists("User", email):
		frappe.throw("Нет такого пользователя.")

	company = current_company()
	bound = frappe.db.exists(
		"User Permission",
		{"user": email, "allow": "Company", "for_value": company},
	)
	if not bound and email != frappe.session.user:
		frappe.throw(
			"Этот человек не относится к вашей компании.", frappe.PermissionError
		)
	return frappe.get_doc("User", email)


def _refuse_self(name: str, what: str) -> None:
	if name == frappe.session.user:
		frappe.throw(
			f"{what}. Владелец, понизив себя, запирает завод снаружи: вернуть "
			"права будет некому.",
			frappe.PermissionError,
		)


def _refuse_last_owner(user) -> None:
	if OWNER_ROLE not in {row.role for row in user.get("roles") or []}:
		return
	others = frappe.get_all(
		"Has Role",
		filters={"role": OWNER_ROLE, "parenttype": "User", "parent": ["!=", user.name]},
		parent_doctype="User",
		pluck="parent",
	)
	active = [
		name
		for name in set(others)
		if name not in ("Administrator", "Guest")
		and frappe.db.get_value("User", name, "enabled")
	]
	if not active:
		frappe.throw(
			"Это последний владелец. Компания без него не сможет ни пригласить, "
			"ни исправить, ни включить обратно.",
			frappe.PermissionError,
		)


def _audit(subject: str, what: str) -> None:
	"""Кто и что сделал с чужим доступом — R9: опасное действие оставляет след."""
	savepoint = "korkem_staff_audit_" + frappe.generate_hash(length=8)
	try:
		frappe.db.savepoint(savepoint)
		frappe.get_doc(
			{
				"doctype": "Comment",
				"comment_type": "Info",
				"reference_doctype": "User",
				"reference_name": subject,
				"content": f"KORKEM: {what} — {frappe.session.user}",
			}
		).insert(ignore_permissions=True)
		frappe.db.release_savepoint(savepoint)
	except Exception:
		try:
			frappe.db.rollback(save_point=savepoint)
		except Exception:
			pass
		frappe.log_error(
			title="Could not record a staff access change",
			message=frappe.get_traceback(with_context=True),
		)
