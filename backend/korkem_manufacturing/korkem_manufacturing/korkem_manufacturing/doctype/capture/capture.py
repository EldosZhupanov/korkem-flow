# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""One thing a person said, before it is anything else.

This doctype exists because the interview that reshaped the product named a
loss that happens *before* any business object exists: the owner is standing at
the CNC machine, a customer calls, he writes the size on a notepad, and the
evening transfer into a spreadsheet never happens. The order is not late
because production is slow. It is late because a sentence never left his head.

So the sentence itself is the record. It is deliberately **not** a lead: it may
become a lead, a task, a note, or nothing, and forcing it into `CRM Lead` at
capture time would mean deciding what it is at the one moment nobody has time
to decide. Recorded first, understood second, converted third.

It is also what proves the product's economic claim. The owner's question is
"can I avoid hiring an administrator" — and an administrator's job is exactly
this: catch what was said, and make sure somebody acts on it. Counting captures,
what became of them and what went stale answers that question with numbers
rather than argument.
"""

from __future__ import annotations

import frappe
from frappe.model.document import Document


class Capture(Document):
	def before_insert(self):
		if not self.spoken_at:
			self.spoken_at = frappe.utils.now_datetime()
