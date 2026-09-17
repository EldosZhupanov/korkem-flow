# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Company Invitations and Team Roles Service.

Canonical roles for furniture production:
- OWNER
- ADMIN
- MEASURER
- DESIGNER_TECHNOLOGIST
- PRODUCTION_MANAGER
- CUTTING_OPERATOR
- EDGEBANDING_OPERATOR
- CNC_OPERATOR
- ASSEMBLER
- INSTALLER
- DRIVER
- ACCOUNTANT

Supports:
- Cryptographically secure invitation links (https://korkem.asia/join/<token>)
- WhatsApp / Telegram localized sharing
- Direct deep link resolution and company/role context
- Atomic one-time token acceptance and tenant isolation
- Expiration and manual revocation
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import secrets
import urllib.parse
from datetime import datetime

import frappe
from frappe.utils import add_days, get_datetime, now_datetime

from korkem_ai.korkem_ai import onboarding
from korkem_manufacturing.services.scope import current_company

#: Роли цеха, одинаковые для всех, кто стоит у станка.
_STANDS_AT_A_MACHINE = onboarding.DEFAULT_EMPLOYEE_ROLES

#: Канонические роли KORKEM Flow с описаниями, правами ERPNext и целевым экраном
CANONICAL_ROLES = {
	"OWNER": {
		"title_ru": "Владелец",
		"title_kz": "Иесі",
		"desc_ru": "Полный доступ к цеху, финансам, заказам и персоналу",
		"desc_kz": "Цех, қаржы, тапсырыстар және қызметкерлерге толық қолжетімділік",
		"roles": (
			"System Manager",
			"Manufacturing Manager",
			"Stock Manager",
			"Sales Manager",
			"Purchase Manager",
		),
		"landing_route": "/dashboard",
	},
	"ADMIN": {
		"title_ru": "Администратор",
		"title_kz": "Әкімші",
		"desc_ru": "Управление заказами, продажами, клиентами и снабжением",
		"desc_kz": "Тапсырыстарды, сатылымдарды және жабдықтауды басқару",
		"roles": (
			"System Manager",
			"Manufacturing Manager",
			"Stock Manager",
			"Sales Manager",
		),
		"landing_route": "/dashboard",
	},
	"PRODUCTION_MANAGER": {
		"title_ru": "Начальник производства",
		"title_kz": "Өндіріс бастығы",
		"desc_ru": "Очередь производства, распределение смен, контроль участков",
		"desc_kz": "Өндіріс кезегі, ауысымдарды бөлу, учаскелерді қадағалау",
		"roles": ("Manufacturing Manager", "Manufacturing User", "Stock User"),
		"landing_route": "/orders",
	},
	"DESIGNER_TECHNOLOGIST": {
		"title_ru": "Конструктор-технолог",
		"title_kz": "Конструктор-технолог",
		"desc_ru": "Импорт проектов БАЗИС, карт раскроя, спецификаций и чертежей",
		"desc_kz": "БАЗИС жобаларын, пішу карталарын, сызбаларды импорттау",
		"roles": ("Manufacturing User", "Item Manager"),
		"landing_route": "/bazis-import",
	},
	"MEASURER": {
		"title_ru": "Замерщик",
		"title_kz": "Өлшеуші",
		"desc_ru": "Выезды на замер, фото помещений, прикрепление замеров к лидам",
		"desc_kz": "Өлшеуге шығу, фотолар түсіру, өлшемдерді лидтерге бекіту",
		"roles": ("Sales User",),
		"landing_route": "/tasks",
	},
	"CUTTING_OPERATOR": {
		"title_ru": "Оператор раскроя",
		"title_kz": "Пішу операторы",
		"desc_ru": "Задания на форматный / пильный центр, учет делового остатка",
		"desc_kz": "Пішу орталығының тапсырмалары, іскерлік қалдықты есепке алу",
		"roles": ("Manufacturing User", "Stock User"),
		"landing_route": "/workstations/Раскрой",
	},
	"EDGEBANDING_OPERATOR": {
		"title_ru": "Оператор кромкооблицовки",
		"title_kz": "Жиектеу операторы",
		"desc_ru": "Очередь кромления деталей, учет расхода кромочного материала",
		"desc_kz": "Бөлшектерді жиектеу кезегі, жиек материалын шығындау",
		"roles": ("Manufacturing User", "Stock User"),
		"landing_route": "/workstations/Кромкооблицовка",
	},
	"CNC_OPERATOR": {
		"title_ru": "Оператор ЧПУ",
		"title_kz": "СББ операторы",
		"desc_ru": "Фрезеровка фасадов, присадка отверстий, выполнение УП",
		"desc_kz": "Қасбеттерді фрезерлеу, бұрғылау, ББ бағдарламаларын орындау",
		"roles": ("Manufacturing User", "Stock User"),
		"landing_route": "/workstations/ЧПУ",
	},
	"ASSEMBLER": {
		"title_ru": "Сборщик цеха",
		"title_kz": "Цех құрастырушысы",
		"desc_ru": "Сборка корпусов, фурнитуры, упаковка и маркировка модулей",
		"desc_kz": "Корпустарды, фурнитураны құрастыру, орау және таңбалау",
		"roles": ("Manufacturing User", "Stock User"),
		"landing_route": "/workstations/Сборка",
	},
	"INSTALLER": {
		"title_ru": "Монтажник / Сборщик на объекте",
		"title_kz": "Орнатушы / Нысанда құрастырушы",
		"desc_ru": "Установка мебели у заказчика, рекламации, акт приемки",
		"desc_kz": "Тапсырыс берушіде жиһаз орнату, актіге қол қойғызу",
		"roles": ("Manufacturing User", "Stock User"),
		"landing_route": "/tasks",
	},
	"DRIVER": {
		"title_ru": "Водитель-доставщик",
		"title_kz": "Жүргізуші-жеткізуші",
		"desc_ru": "Логистика, погрузка, маршруты и доставка готовых заказов",
		"desc_kz": "Логистика, тиеу, бағыттар және дайын тапсырыстарды жеткізу",
		"roles": ("Manufacturing User", "Stock User"),
		"landing_route": "/settings/deliveries",
	},
	"ACCOUNTANT": {
		"title_ru": "Бухгалтер / Кассир",
		"title_kz": "Бухгалтер / Кассир",
		"desc_ru": "Учет оплат, предоплаты Kaspi, сдельная зарплата мастеров",
		"desc_kz": "Төлемдерді есепке алу, Kaspi төлемдері, кесімді жалақы",
		"roles": ("Accounts User",),
		"landing_route": "/today",
	},
}

#: Синонимы и совместимость со старыми названиями должностей
ROLE_ALIASES = {
	"cutter": "CUTTING_OPERATOR",
	"edge_banding": "EDGEBANDING_OPERATOR",
	"edgebanding": "EDGEBANDING_OPERATOR",
	"cnc": "CNC_OPERATOR",
	"assembler": "ASSEMBLER",
	"measurer": "MEASURER",
	"designer": "DESIGNER_TECHNOLOGIST",
	"shop_manager": "PRODUCTION_MANAGER",
	"shopmanager": "PRODUCTION_MANAGER",
	"installer": "INSTALLER",
	"accountant": "ACCOUNTANT",
	"manager": "ADMIN",
	"admin": "ADMIN",
	"owner": "OWNER",
	"warehouse": "PRODUCTION_MANAGER",
	"painter": "ASSEMBLER",
	"shop_floor": "CUTTING_OPERATOR",
	"shopfloor": "CUTTING_OPERATOR",
	"driver": "DRIVER",
}

#: Сохраненный для обратной совместимости словарь POSITIONS
POSITIONS = {
	"manager": ("Sales User", "Sales Manager"),
	"measurer": ("Sales User",),
	"designer": ("Manufacturing User", "Item Manager"),
	"shop_manager": ("Manufacturing Manager", "Manufacturing User", "Stock User"),
	"cutter": _STANDS_AT_A_MACHINE,
	"edge_banding": _STANDS_AT_A_MACHINE,
	"cnc": _STANDS_AT_A_MACHINE,
	"painter": _STANDS_AT_A_MACHINE,
	"assembler": _STANDS_AT_A_MACHINE,
	"warehouse": ("Stock User",),
	"installer": ("Manufacturing User", "Stock User"),
	"accountant": ("Accounts User",),
	"shop_floor": _STANDS_AT_A_MACHINE,
}


def normalize_role_name(role: str) -> str:
	"""Convert any input role/position string into a canonical role name."""
	clean = (role or "").strip()
	upper = clean.upper()
	if upper in CANONICAL_ROLES:
		return upper
	lower = clean.lower().replace("-", "_")
	if lower in ROLE_ALIASES:
		return ROLE_ALIASES[lower]
	if lower in POSITIONS:
		return ROLE_ALIASES.get(lower, "CUTTING_OPERATOR")
	# Fallback
	return "CUTTING_OPERATOR"


def hash_token(raw_token: str) -> str:
	"""Compute SHA-256 hash of token for safe DB storage."""
	return hashlib.sha256(raw_token.strip().encode("utf-8")).hexdigest()


def prevent_self_role_change(doc, method=None) -> None:
	"""R5 at the generic Frappe boundary."""
	del method
	if doc.name != frappe.session.user or doc.name == "Administrator" or doc.is_new():
		return
	before = doc.get_doc_before_save()
	if not before:
		return
	old_roles = {row.role for row in before.get("roles") or []}
	new_roles = {row.role for row in doc.get("roles") or []}
	if new_roles != old_roles:
		frappe.throw(
			"You cannot change your own roles. Ask the factory owner.",
			frappe.PermissionError,
		)


def create_invitation(
	*,
	role_name: str,
	phone: str = "",
	max_uses: int = 1,
	expires_days: int = 7,
	company: str | None = None,
) -> dict:
	"""Create a cryptographically secure company invitation.

	Only users with permission to invite (Owner / System Manager / Admin) may call this.
	"""
	caller = frappe.session.user
	if caller != "Administrator" and "System Manager" not in frappe.get_roles(caller):
		frappe.throw("Только владелец или администратор цеха может создавать приглашения.", frappe.PermissionError)

	company = company or current_company()
	canonical_role = normalize_role_name(role_name)
	meta = CANONICAL_ROLES[canonical_role]

	raw_token = secrets.token_urlsafe(32)
	token_digest = hash_token(raw_token)
	now = now_datetime()
	expires_at = add_days(now, max(1, expires_days))

	doc = frappe.get_doc(
		{
			"doctype": "Company Invitation",
			"company": company,
			"role_name": canonical_role,
			"invited_by": caller,
			"phone": phone.strip() if phone else "",
			"token_hash": token_digest,
			"expires_at": expires_at,
			"max_uses": max(1, max_uses),
			"uses_count": 0,
			"status": "ACTIVE",
			"created_at": now,
		}
	)
	doc.insert(ignore_permissions=True)
	frappe.db.commit()

	invite_url = f"https://korkem.asia/join/{raw_token}"
	share_data = format_sharing_data(
		company_name=company,
		role_title_ru=meta["title_ru"],
		role_title_kz=meta["title_kz"],
		invite_url=invite_url,
	)

	_audit(company, f"token:{doc.name}", canonical_role)

	from korkem_manufacturing.services import analytics
	analytics.track_event(
		"invite_created",
		company=company,
		properties={"role": canonical_role, "invitation_id": doc.name},
		reference_doctype="Company Invitation",
		reference_name=doc.name,
	)

	return {
		"status": "ok",
		"invitation_id": doc.name,
		"token": raw_token,
		"invite_url": invite_url,
		"short_code": doc.name.replace("INV-", ""),
		"company": company,
		"role_name": canonical_role,
		"role_title_ru": meta["title_ru"],
		"role_title_kz": meta["title_kz"],
		"landing_route": meta["landing_route"],
		"expires_at": str(doc.expires_at),
		**share_data,
	}


def format_sharing_data(
	company_name: str,
	role_title_ru: str,
	role_title_kz: str,
	invite_url: str,
) -> dict:
	"""Generate WhatsApp, Telegram and localized invite strings."""
	text_kz = (
		f"Сәлем! Сені Korkem Flow жүйесіндегі {company_name} компаниясына "
		f"{role_title_kz} рөліне шақырды. Қосылу үшін мына сілтемені басыңыз: {invite_url}"
	)
	text_ru = (
		f"Привет! Вас пригласили в компанию {company_name} в Korkem Flow на роль "
		f"{role_title_ru}. Нажмите на ссылку для входа: {invite_url}"
	)

	wa_kz = f"https://wa.me/?text={urllib.parse.quote(text_kz)}"
	wa_ru = f"https://wa.me/?text={urllib.parse.quote(text_ru)}"
	tg_kz = f"https://t.me/share/url?url={urllib.parse.quote(invite_url)}&text={urllib.parse.quote(text_kz)}"
	tg_ru = f"https://t.me/share/url?url={urllib.parse.quote(invite_url)}&text={urllib.parse.quote(text_ru)}"

	return {
		"share_text_kz": text_kz,
		"share_text_ru": text_ru,
		"whatsapp_url_kz": wa_kz,
		"whatsapp_url_ru": wa_ru,
		"telegram_url_kz": tg_kz,
		"telegram_url_ru": tg_ru,
	}


def get_invitation_info(token: str) -> dict:
	"""Public query: Get company & role details for an invitation token."""
	if not token or len(token.strip()) < 8:
		return {"valid": False, "error": "Неверный или поврежденный токен приглашения"}

	token_digest = hash_token(token)
	invites = frappe.get_all(
		"Company Invitation",
		filters={"token_hash": token_digest},
		fields=["name", "company", "role_name", "invited_by", "phone", "expires_at", "max_uses", "uses_count", "status"],
		limit_page_length=1,
	)
	if not invites:
		return {"valid": False, "error": "Приглашение не найдено или ссылка недействительна"}

	invite = invites[0]
	now = now_datetime()

	# Check revocation
	if invite.status == "REVOKED":
		return {"valid": False, "status": "REVOKED", "error": "Это приглашение было отозвано владельцем цеха"}

	# Check expiration
	if get_datetime(invite.expires_at) < now:
		if invite.status != "EXPIRED":
			frappe.db.set_value("Company Invitation", invite.name, "status", "EXPIRED", update_modified=False)
			frappe.db.commit()
		return {"valid": False, "status": "EXPIRED", "error": "Срок действия приглашения истек (срок 7 дней)"}

	# Check uses count
	if invite.uses_count >= invite.max_uses or invite.status == "ACCEPTED":
		return {"valid": False, "status": "ACCEPTED", "error": "Это приглашение уже было использовано"}

	canonical_role = normalize_role_name(invite.role_name)
	meta = CANONICAL_ROLES.get(canonical_role, CANONICAL_ROLES["CUTTING_OPERATOR"])

	# Company details
	company_name = invite.company
	company_logo = frappe.db.get_value("Company", company_name, "company_logo")
	inviter_name = frappe.db.get_value("User", invite.invited_by, "full_name") or invite.invited_by
	from korkem_manufacturing.services import analytics
	analytics.track_event(
		"invite_opened",
		company=company_name,
		properties={"role": canonical_role, "invitation_id": invite.name},
		reference_doctype="Company Invitation",
		reference_name=invite.name,
	)

	return {
		"valid": True,
		"invitation_id": invite.name,
		"company_name": company_name,
		"company_logo": company_logo or "",
		"role_name": canonical_role,
		"role_title_ru": meta["title_ru"],
		"role_title_kz": meta["title_kz"],
		"desc_ru": meta["desc_ru"],
		"desc_kz": meta["desc_kz"],
		"landing_route": meta["landing_route"],
		"invited_by": inviter_name,
		"phone": invite.phone or "",
		"expires_at": str(invite.expires_at),
		"short_code": invite.name.replace("INV-", ""),
	}


def accept_invitation(
	*,
	token: str,
	phone: str,
	full_name: str,
	email: str = "",
	password: str = "",
) -> dict:
	"""Public endpoint: employee accepts invitation, binds to company & role."""
	clean_token = (token or "").strip()
	if not clean_token:
		frappe.throw("Отсутствует токен приглашения.", frappe.ValidationError)

	token_digest = hash_token(clean_token)

	# Fetch inside transaction
	invites = frappe.get_all(
		"Company Invitation",
		filters={"token_hash": token_digest},
		fields=["name", "company", "role_name", "status", "expires_at", "max_uses", "uses_count"],
		limit_page_length=1,
	)
	if not invites:
		frappe.throw("Приглашение не найдено.", frappe.DoesNotExistError)

	invite = invites[0]
	now = now_datetime()

	if invite.status == "REVOKED":
		frappe.throw("Это приглашение было отозвано владельцем.", frappe.PermissionError)

	if get_datetime(invite.expires_at) < now:
		frappe.db.set_value("Company Invitation", invite.name, "status", "EXPIRED", update_modified=False)
		frappe.db.commit()
		frappe.throw("Срок действия приглашения истек.", frappe.ValidationError)

	if invite.uses_count >= invite.max_uses or invite.status == "ACCEPTED":
		frappe.throw("Это приглашение уже было использовано.", frappe.ValidationError)

	from korkem_manufacturing.services import auth_otp
	clean_phone = auth_otp.normalize_phone(phone)
	if not clean_phone:
		frappe.throw("Укажите номер телефона.", frappe.ValidationError)

	full_name = (full_name or "").strip()
	if not full_name:
		frappe.throw("Укажите имя и фамилию.", frappe.ValidationError)

	canonical_role = normalize_role_name(invite.role_name)
	meta = CANONICAL_ROLES.get(canonical_role, CANONICAL_ROLES["CUTTING_OPERATOR"])
	target_roles = list(meta["roles"])

	# Determine user email: reuse existing user by phone if present
	user_email = (email or "").strip().lower()
	if not user_email:
		existing_by_phone = frappe.db.get_value("User", {"mobile_no": clean_phone}, "name")
		if existing_by_phone:
			user_email = existing_by_phone
		else:
			# Synthetic email for phone-based identity
			phone_digits = "".join(c for c in clean_phone if c.isdigit())
			user_email = f"user_{phone_digits}@korkem.user"

	first_name, _, last_name = full_name.partition(" ")
	if not first_name:
		first_name = full_name

	# Execute user provisioning as Administrator
	caller = frappe.session.user
	frappe.set_user("Administrator")
	try:
		if frappe.db.exists("User", user_email):
			user_doc = frappe.get_doc("User", user_email)
			user_doc.first_name = first_name
			if last_name:
				user_doc.last_name = last_name
			user_doc.mobile_no = clean_phone
			user_doc.enabled = 1
		else:
			user_doc = frappe.new_doc("User")
			user_doc.update(
				{
					"email": user_email,
					"first_name": first_name,
					"last_name": last_name,
					"mobile_no": clean_phone,
					"user_type": "System User",
					"enabled": 1,
					"send_welcome_email": 0,
				}
			)

		# Add required roles
		existing_roles = {r.role for r in user_doc.get("roles") or []}
		for r in target_roles:
			if r not in existing_roles and frappe.db.exists("Role", r):
				user_doc.append("roles", {"role": r})

		user_doc.save(ignore_permissions=True)

		# Set password if provided
		if password and len(password) >= 6:
			from frappe.utils.password import update_password
			update_password(user_email, password)

		# Bind company via User Permission
		if not frappe.db.exists("User Permission", {"user": user_email, "allow": "Company", "for_value": invite.company}):
			frappe.get_doc(
				{
					"doctype": "User Permission",
					"user": user_email,
					"allow": "Company",
					"for_value": invite.company,
					"apply_to_all_doctypes": 1,
				}
			).insert(ignore_permissions=True)

		# Update invitation status atomically
		new_uses = invite.uses_count + 1
		new_status = "ACCEPTED" if new_uses >= invite.max_uses else "ACTIVE"
		frappe.db.set_value(
			"Company Invitation",
			invite.name,
			{
				"uses_count": new_uses,
				"status": new_status,
				"accepted_at": now,
				"accepted_by": user_email,
			},
			update_modified=False,
		)

		_audit(invite.company, user_email, canonical_role)

		from korkem_manufacturing.services import analytics
		analytics.track_event(
			"invite_accepted",
			user=user_email,
			company=invite.company,
			properties={"role": canonical_role, "invitation_id": invite.name},
			reference_doctype="Company Invitation",
			reference_name=invite.name,
		)
		analytics.track_event(
			"onboarding_completed",
			user=user_email,
			company=invite.company,
			properties={"role": canonical_role},
		)

		frappe.db.commit()

		return {
			"status": "ok",
			"user": user_email,
			"phone": clean_phone,
			"full_name": full_name,
			"company": invite.company,
			"role_name": canonical_role,
			"role_title_ru": meta["title_ru"],
			"role_title_kz": meta["title_kz"],
			"landing_route": meta["landing_route"],
			"message": "Приглашение успешно принято",
		}
	finally:
		frappe.set_user(caller)


def revoke_invitation(invitation_id: str) -> dict:
	"""Revoke an active invitation so it can no longer be accepted."""
	caller = frappe.session.user
	if caller != "Administrator" and "System Manager" not in frappe.get_roles(caller):
		frappe.throw("Недостаточно прав для отзыва приглашения.", frappe.PermissionError)

	if not frappe.db.exists("Company Invitation", invitation_id):
		frappe.throw("Приглашение не найдено.", frappe.DoesNotExistError)

	doc = frappe.get_doc("Company Invitation", invitation_id)
	doc.status = "REVOKED"
	doc.save(ignore_permissions=True)
	frappe.db.commit()

	return {"status": "ok", "invitation_id": invitation_id, "message": "Приглашение успешно отозвано"}


def resend_invitation(invitation_id: str) -> dict:
	"""Get sharing info and text for an existing invitation."""
	if not frappe.db.exists("Company Invitation", invitation_id):
		frappe.throw("Приглашение не найдено.", frappe.DoesNotExistError)

	doc = frappe.get_doc("Company Invitation", invitation_id)
	if doc.status != "ACTIVE":
		frappe.throw(f"Приглашение имеет статус {doc.status}, повторная отправка невозможна.", frappe.ValidationError)

	canonical_role = normalize_role_name(doc.role_name)
	meta = CANONICAL_ROLES[canonical_role]
	# Generate a new random token for resending
	new_token = secrets.token_urlsafe(32)
	doc.token_hash = hash_token(new_token)
	doc.expires_at = add_days(now_datetime(), 7)
	doc.save(ignore_permissions=True)
	frappe.db.commit()

	invite_url = f"https://korkem.asia/join/{new_token}"
	share_data = format_sharing_data(
		company_name=doc.company,
		role_title_ru=meta["title_ru"],
		role_title_kz=meta["title_kz"],
		invite_url=invite_url,
	)

	return {
		"status": "ok",
		"invitation_id": doc.name,
		"token": new_token,
		"invite_url": invite_url,
		"role_name": canonical_role,
		"role_title_ru": meta["title_ru"],
		"role_title_kz": meta["title_kz"],
		"expires_at": str(doc.expires_at),
		**share_data,
	}


def change_invitation_role(invitation_id: str, new_role: str) -> dict:
	"""Change the intended role for an active pending invitation."""
	caller = frappe.session.user
	if caller != "Administrator" and "System Manager" not in frappe.get_roles(caller):
		frappe.throw("Недостаточно прав для изменения роли.", frappe.PermissionError)

	if not frappe.db.exists("Company Invitation", invitation_id):
		frappe.throw("Приглашение не найдено.", frappe.DoesNotExistError)

	canonical_role = normalize_role_name(new_role)
	frappe.db.set_value("Company Invitation", invitation_id, "role_name", canonical_role)
	frappe.db.commit()

	meta = CANONICAL_ROLES[canonical_role]
	return {
		"status": "ok",
		"invitation_id": invitation_id,
		"new_role": canonical_role,
		"role_title_ru": meta["title_ru"],
		"role_title_kz": meta["title_kz"],
	}


def list_invitations(company: str | None = None) -> list[dict]:
	"""List all invitations for the company."""
	company = company or current_company()
	rows = frappe.get_all(
		"Company Invitation",
		filters={"company": company},
		fields=["name", "role_name", "invited_by", "phone", "expires_at", "max_uses", "uses_count", "status", "created_at", "accepted_at", "accepted_by"],
		order_by="created_at desc",
		limit_page_length=0,
	)
	now = now_datetime()
	result = []
	for r in rows:
		canonical_role = normalize_role_name(r.role_name)
		meta = CANONICAL_ROLES.get(canonical_role, CANONICAL_ROLES["CUTTING_OPERATOR"])
		is_expired = get_datetime(r.expires_at) < now and r.status == "ACTIVE"
		status = "EXPIRED" if is_expired else r.status

		result.append(
			{
				"id": r.name,
				"role_name": canonical_role,
				"role_title_ru": meta["title_ru"],
				"role_title_kz": meta["title_kz"],
				"invited_by": r.invited_by,
				"phone": r.phone or "",
				"expires_at": str(r.expires_at),
				"status": status,
				"created_at": str(r.created_at),
				"accepted_at": str(r.accepted_at) if r.accepted_at else None,
				"accepted_by": r.accepted_by or None,
			}
		)
	return result


# Legacy support for invite_employee
def invite_employee(*, email: str, first_name: str = "", position: str) -> dict:
	"""Create one company-bound employee with the roles for position (legacy API)."""
	frappe.only_for("System Manager")
	canonical_role = normalize_role_name(position)
	meta = CANONICAL_ROLES.get(canonical_role)
	roles = meta["roles"] if meta else POSITIONS.get(position.lower().strip())
	if not roles:
		roles = _STANDS_AT_A_MACHINE

	company = current_company()
	result = onboarding.create_employee(
		email=email,
		first_name=first_name,
		roles=list(roles),
		company=company,
	)
	_audit(company, result["user"], canonical_role)
	return {**result, "position": canonical_role.lower()}


def _audit(company: str, invited: str, position: str) -> None:
	"""R9: who invited whom, to which company and job."""
	savepoint = "korkem_invitation_audit_" + frappe.generate_hash(length=8)
	try:
		frappe.db.savepoint(savepoint)
		frappe.get_doc(
			{
				"doctype": "Comment",
				"comment_type": "Info",
				"reference_doctype": "Company",
				"reference_name": company,
				"content": (
					f"KORKEM: {frappe.session.user} пригласил {invited}; "
					f"должность {position}."
				),
			}
		).insert(ignore_permissions=True)
	except Exception:
		frappe.db.rollback(save_point=savepoint)
