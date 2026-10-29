# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""A new site must have the same schema as an upgraded one.

Frappe marks every patch in `patches.txt` as applied when an app is installed
for the first time, without running it. A patch that adds a Custom Field is
therefore invisible to a fresh site unless `after_install` calls it too — which
is how every site installed after 2026-09-17 ended up without
`Sales Order.korkem_state`.
"""

from __future__ import annotations

import inspect
from pathlib import Path

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing import install

APP_DIR = Path(__file__).resolve().parent


def _metadata_patches() -> list[str]:
	"""Patch modules that create Custom Fields, as listed in patches.txt."""
	modules = []
	for line in (APP_DIR / "patches.txt").read_text().splitlines():
		line = line.split("#", 1)[0].strip()
		if not line or line.startswith("["):
			continue
		source = APP_DIR.parent / Path(*line.split(".")).with_suffix(".py")
		if source.exists() and "create_custom_field" in source.read_text():
			modules.append(line)
	return modules


class TestAFreshSiteGetsEveryField(IntegrationTestCase):
	def test_every_custom_field_patch_also_runs_on_install(self):
		installed_by = inspect.getsource(install.after_install)
		missing = [m for m in _metadata_patches() if m.rsplit(".", 1)[-1] not in installed_by]
		self.assertEqual(missing, [], "these patches never run on a freshly installed site")

	def test_the_order_state_field_exists(self):
		self.assertTrue(frappe.get_meta("Sales Order").has_field("korkem_state"))
