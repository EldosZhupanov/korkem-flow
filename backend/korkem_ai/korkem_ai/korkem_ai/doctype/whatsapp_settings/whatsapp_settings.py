# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

from frappe.model.document import Document


class WhatsAppSettings(Document):
	# begin: auto-generated types
	# This code is auto-generated. Do not modify anything in this block.

	from typing import TYPE_CHECKING

	if TYPE_CHECKING:
		from frappe.types import DF

		access_token: DF.Password | None
		api_version: DF.Data | None
		app_secret: DF.Password | None
		business_account_id: DF.Data | None
		enabled: DF.Check
		phone_number_id: DF.Data | None
		webhook_verify_token: DF.Password | None
	# end: auto-generated types
