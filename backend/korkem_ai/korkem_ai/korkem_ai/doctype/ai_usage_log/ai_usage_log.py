# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""One row per model turn. What it cost, who spent it, and which turn it was.

This is the transaction half of the `AI Credit Ledger` in
`docs/architecture/domain_model.md`. The balance half — prepaid credits, and a
tenant to charge them to — is deliberately not built: ADR-0018 defers
multi-tenancy, and a balance nobody debits is a table that lies about being
meaningful.

## Two zeros that mean different things

`total_tokens = 0` with `tokens_reported = 0` means **the provider said
nothing**. `total_tokens = 0` with `tokens_reported = 1` would mean it said
zero. `AIUsage` in the orchestrator protocol keeps that distinction with `None`
and it must survive the trip into the database, because a budget that counts
unreported turns as free is a budget that can be exhausted for nothing.

The same reasoning gives `cost_basis` its two values. No provider returns a
charge alongside a completion, so every figure here is multiplied out from a
rate somebody typed. Where no rate is configured, `estimated_cost` stays 0 and
`cost_basis` says `not priced` — the zero is not a claim that the turn was free.
"""

from __future__ import annotations

import frappe
from frappe.model.document import Document


class AIUsageLog(Document):
	def validate(self) -> None:
		# Kept consistent here rather than at every call site: a row written by
		# a future caller that forgets to sum is still correct.
		self.total_tokens = (self.input_tokens or 0) + (self.output_tokens or 0)

		if not self.tokens_reported and self.total_tokens:
			frappe.throw(
				"A usage row carries token counts but is not marked as reported. "
				"One of the two is wrong, and guessing which would corrupt every "
				"budget computed from this table."
			)

		if self.cost_basis == "not priced" and self.estimated_cost:
			frappe.throw(
				"A usage row has a cost but no basis for it. Set cost_basis to "
				"'provider rate', or leave the cost at zero."
			)
