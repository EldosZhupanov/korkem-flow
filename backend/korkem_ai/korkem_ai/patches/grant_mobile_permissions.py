# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Grant the roles the mobile app needs. See korkem_ai.korkem_ai.permissions."""

from korkem_ai.korkem_ai import permissions


def execute():
	permissions.apply()
