"""Move the money fields of orders, deliveries and purchase orders to level 1.

See `services/price_visibility.py` for the rule. Idempotent: a field already
at level 1 is left alone, and roles that always see money get their level-1
read before any field moves, so no Sales or Accounts form ever loses a total.
"""

from korkem_manufacturing.services import price_visibility


def execute():
	price_visibility.apply_field_levels()
