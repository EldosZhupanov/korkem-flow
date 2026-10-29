"""Repair sites installed without Sales Order.korkem_state.

`add_korkem_state_to_sales_order` reached `patches.txt` but not `after_install`.
A site installed after that patch was added therefore recorded it as applied in
Patch Log without ever running it, and `bench migrate` will not run it again.
This patch has a new name, so migrate runs it once; it delegates to the same
idempotent implementation and does nothing where the field already exists.
"""

from korkem_manufacturing.patches.v0_0.add_korkem_state_to_sales_order import execute as add_korkem_state


def execute():
	add_korkem_state()
