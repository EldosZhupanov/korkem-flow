"""Exact dated estimates from operator-supplied rates, not a vendor price list."""

from datetime import date
from decimal import Decimal, InvalidOperation, localcontext


def _rate(value):
	if isinstance(value, bool):
		raise ValueError("Invalid provider rate")
	try:
		result = Decimal(str(value))
	except InvalidOperation as exc:
		raise ValueError("Invalid provider rate") from exc
	if not result.is_finite() or result < 0:
		raise ValueError("Invalid provider rate")
	return result


def estimate(*, provider, model, on, input_tokens, output_tokens, rates):
	"""Return None for unknown usage/rate; zero only for explicitly priced zero.

	Rates are scoped by exact provider AND model, denominated per million tokens.
	Historical entries remain applicable to their original effective dates.
	"""
	if input_tokens is None or output_tokens is None:
		return None
	for count in (input_tokens, output_tokens):
		if isinstance(count, bool) or not isinstance(count, int) or count < 0:
			raise ValueError("Invalid token count")
	day = date.fromisoformat(on)
	matches = [
		r
		for r in rates
		if r.get("provider") == provider
		and r.get("model") == model
		and date.fromisoformat(r["effective_from"]) <= day
	]
	if not matches:
		return None
	row = max(matches, key=lambda r: r["effective_from"])
	if not isinstance(row.get("currency"), str) or not row["currency"].strip():
		raise ValueError("Pricing currency is required")
	with localcontext() as context:
		context.prec = 50
		cost = (
			input_tokens * _rate(row["input_price_per_million"])
			+ output_tokens * _rate(row["output_price_per_million"])
		) / Decimal(1000000)
		text = format(cost, "f")
		if "." in text:
			text = text.rstrip("0").rstrip(".")
	return {"cost": text, "currency": row["currency"], "effective_from": row["effective_from"]}
