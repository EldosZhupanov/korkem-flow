"""Installation and test setup for KORKEM Manufacturing."""


def after_install():
	"""Install metadata that extends doctypes owned by other applications.

	Frappe does not execute an application's patches while that application is
	being installed for the first time.  Keep the patch for upgrades, and call
	the same idempotent implementation here for a genuinely new site.
	"""
	from korkem_manufacturing.patches.v0_0.add_originating_deal_to_work_order import execute

	execute()


def before_tests():
	"""Provision the ERPNext masters required by the manufacturing tests."""
	from korkem_manufacturing import setup

	setup.provision()
