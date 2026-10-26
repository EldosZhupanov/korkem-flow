"""Installation and test setup for KORKEM Manufacturing."""


def after_install():
	"""Install metadata that extends doctypes owned by other applications.

	Frappe does not execute an application's patches while that application is
	being installed for the first time.  Keep the patch for upgrades, and call
	the same idempotent implementation here for a genuinely new site.
	"""
	from korkem_manufacturing.patches.v0_0.add_originating_deal_to_work_order import (
		execute as add_originating_deal,
	)
	from korkem_manufacturing.patches.v0_0.add_korkem_state_to_sales_order import (
		execute as add_korkem_state,
	)
	from korkem_manufacturing.patches.v0_0.grant_order_read import execute as grant_order_read
	from korkem_manufacturing.services import price_visibility

	add_originating_deal()
	grant_order_read()
	# Every patch in patches.txt that adds metadata belongs here as well. This
	# one was not (2026-09-17), so every site installed from then on had no
	# Sales Order.korkem_state and the order state machine failed with
	# "Unknown column 'korkem_state'".
	add_korkem_state()
	# After grant_order_read: the floor roles must already read the order for
	# the level-0/level-1 split to mean anything.
	price_visibility.apply_field_levels()
	from korkem_manufacturing.services import facade_prices

	facade_prices.seed_all_companies()


def before_tests():
	"""Provision the ERPNext masters required by the manufacturing tests."""
	from korkem_manufacturing import setup

	setup.provision()
