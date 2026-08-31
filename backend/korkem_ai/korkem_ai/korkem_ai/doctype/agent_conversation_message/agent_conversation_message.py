# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

from frappe.model.document import Document


class AgentConversationMessage(Document):
	# begin: auto-generated types
	# This code is auto-generated. Do not modify anything in this block.

	from typing import TYPE_CHECKING

	if TYPE_CHECKING:
		from frappe.types import DF

		content: DF.SmallText
		conversation: DF.Link
		sender: DF.Literal["User", "Agent", "System"]
		sent_at: DF.Datetime | None
	# end: auto-generated types
