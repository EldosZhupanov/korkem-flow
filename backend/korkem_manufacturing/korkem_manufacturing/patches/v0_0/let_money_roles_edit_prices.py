"""Give money roles write on the price fields they could already edit.

`hide_money_from_floor_roles` granted level 1 as read only, so on sites where
it ran a Sales User's change to a rate was silently discarded. Idempotent.
"""

from korkem_manufacturing.services import price_visibility


def execute():
	price_visibility.apply_field_levels()
