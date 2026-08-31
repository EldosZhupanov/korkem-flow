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
	from korkem_manufacturing.patches.v0_0.grant_order_read import execute as grant_order_read

	add_originating_deal()
	grant_order_read()


def before_tests():
	"""Provision the ERPNext masters required by the manufacturing tests."""
	from korkem_manufacturing import setup

	setup.provision()
