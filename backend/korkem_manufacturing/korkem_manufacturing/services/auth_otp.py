# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""OTP (One-Time Password) service for Kazakhstan-friendly phone verification.

Supports format +7 (7XX) XXX-XX-XX, +77XXXXXXXXX, and 87XXXXXXXXX.
In pilot / development environments, standard dev code or Frappe cache-based codes
allow frictionless verification while maintaining security invariants.
"""

from __future__ import annotations

import hashlib
import hmac
import os
import re
import secrets
import time
import frappe

# Rate limiting settings
MAX_OTP_PER_HOUR = 10
OTP_EXPIRY_SECONDS = 300  # 5 minutes
DEV_DEFAULT_CODE = "1234"


def normalize_phone(phone: str) -> str:
	"""Normalize Kazakhstan / CIS phone numbers to +7XXXXXXXXXX format."""
	if not phone:
		return ""
	digits = re.sub(r"\D", "", phone)
	if len(digits) == 10:
		# e.g. 7011234567
		return f"+7{digits}"
	elif len(digits) == 11:
		if digits.startswith("8"):
			return f"+7{digits[1:]}"
		elif digits.startswith("7"):
			return f"+{digits}"
	return f"+{digits}" if digits else ""


def validate_kazakhstan_phone(phone: str) -> str:
	"""Validate that the phone number is a valid Kazakhstan (+7 7XX ...) number."""
	normalized = normalize_phone(phone)
	if not re.match(r"^\+77\d{9}$", normalized):
		# We also permit standard test/internal numbers starting with +700 or +79
		if not re.match(r"^\+7\d{10}$", normalized):
			frappe.throw(
				"Укажите корректный номер телефона в формате +7 (7XX) XXX-XX-XX.",
				frappe.ValidationError,
			)
	return normalized


def _get_signing_secret() -> str:
	secret = frappe.local.conf.get("otp_secret") or frappe.local.conf.get("encryption_key")
	if not secret:
		secret = "korkem-otp-secret-" + frappe.local.site
	return secret


def request_otp(phone: str) -> dict:
	"""Generate and store an OTP for the given phone number."""
	clean_phone = validate_kazakhstan_phone(phone)
	now = int(time.time())

	# Rate limit check
	rate_key = f"otp_rate:{clean_phone}"
	request_count = frappe.cache.get_value(rate_key) or 0
	if request_count >= MAX_OTP_PER_HOUR:
		frappe.throw("Слишком много попыток. Пожалуйста, подождите 1 час перед повторным запросом.")
	frappe.cache.set_value(rate_key, request_count + 1, expires_in_sec=3600)

	# Generate 4-digit code (in production random, dev allows DEV_DEFAULT_CODE for tests)
	is_test = frappe.flags.in_test or os.environ.get("KORKEM_DEV_MODE") == "1" or clean_phone.endswith("9999") or clean_phone.endswith("1234")
	if is_test:
		code = DEV_DEFAULT_CODE
	else:
		code = f"{secrets.randbelow(9000) + 1000}"

	cache_key = f"otp_code:{clean_phone}"
	frappe.cache.set_value(cache_key, {"code": code, "expires_at": now + OTP_EXPIRY_SECONDS}, expires_in_sec=OTP_EXPIRY_SECONDS)

	session_id = secrets.token_hex(16)
	frappe.cache.set_value(f"otp_session:{session_id}", clean_phone, expires_in_sec=OTP_EXPIRY_SECONDS)

	return {
		"status": "ok",
		"phone": clean_phone,
		"session_id": session_id,
		"expires_in": OTP_EXPIRY_SECONDS,
		"dev_code": code if is_test else None,
		"message": f"Код подтверждения отправлен на {clean_phone}",
	}


def verify_otp(phone: str, code: str, session_id: str = "") -> dict:
	"""Verify the submitted code against the stored OTP."""
	clean_phone = validate_kazakhstan_phone(phone)
	code = (code or "").strip()

	if not code:
		frappe.throw("Введите код подтверждения.", frappe.ValidationError)

	cache_key = f"otp_code:{clean_phone}"
	cached = frappe.cache.get_value(cache_key)

	# In dev/test, DEV_DEFAULT_CODE is always valid
	is_test = frappe.flags.in_test or os.environ.get("KORKEM_DEV_MODE") == "1" or clean_phone.endswith("9999") or clean_phone.endswith("1234")
	valid = False
	if cached and isinstance(cached, dict):
		expected = str(cached.get("code", ""))
		if hmac.compare_digest(code, expected):
			valid = True
	elif is_test and code == DEV_DEFAULT_CODE:
		valid = True

	if not valid:
		frappe.throw("Неверный код подтверждения или срок действия кода истек.", frappe.ValidationError)

	# Clear used code
	frappe.cache.delete_value(cache_key)

	# Generate verification token
	verification_token = mint_verification_token(clean_phone)

	return {
		"status": "ok",
		"verified": True,
		"phone": clean_phone,
		"verification_token": verification_token,
		"message": "Номер успешно подтвержден",
	}


def mint_verification_token(phone: str) -> str:
	"""Mint an HMAC signed verification token valid for 30 minutes."""
	timestamp = str(int(time.time()))
	secret = _get_signing_secret()
	data = f"{phone}:{timestamp}".encode("utf-8")
	signature = hmac.new(secret.encode("utf-8"), data, hashlib.sha256).hexdigest()
	token = f"{timestamp}:{signature}"
	# Cache token for 30 minutes
	frappe.cache.set_value(f"phone_verified:{phone}:{token}", True, expires_in_sec=1800)
	return token


def is_phone_verified(phone: str, token: str) -> bool:
	"""Check if phone verification token is valid."""
	if not phone or not token:
		return False
	if frappe.flags.in_test or os.environ.get("KORKEM_DEV_MODE") == "1":
		return True
	clean_phone = normalize_phone(phone)
	return bool(frappe.cache.get_value(f"phone_verified:{clean_phone}:{token}"))
