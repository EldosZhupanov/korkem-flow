# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Every whitelisted endpoint can actually be called over HTTP.

Frappe refuses a whitelisted function with an unannotated parameter
(`FrappeTypeError: ... missing type annotation`) — but only when it is called
through the request path, so a service-level test passes and the app fails.
Found on `facade_prices.create_order`, 2026-10-26.
"""

from __future__ import annotations

import importlib
import inspect
import pkgutil

import frappe
from frappe.tests import IntegrationTestCase

import korkem_manufacturing.api as api_package


def _whitelisted():
	for info in pkgutil.iter_modules(api_package.__path__):
		module = importlib.import_module(f"{api_package.__name__}.{info.name}")
		for name, func in inspect.getmembers(module, inspect.isfunction):
			if func.__module__ != module.__name__:
				continue
			if func in frappe.whitelisted or getattr(func, "__wrapped__", None) in frappe.whitelisted:
				yield f"{module.__name__}.{name}", func


class TestEveryEndpointIsCallable(IntegrationTestCase):
	def test_every_parameter_is_annotated(self):
		missing = [
			f"{path}({param.name})"
			for path, func in _whitelisted()
			for param in inspect.signature(inspect.unwrap(func)).parameters.values()
			if param.annotation is inspect.Parameter.empty
			and param.kind not in (param.VAR_POSITIONAL, param.VAR_KEYWORD)
		]
		self.assertEqual(missing, [], "Frappe will refuse these over HTTP")

	def test_the_check_sees_the_new_endpoints(self):
		paths = {path for path, _ in _whitelisted()}
		self.assertIn("korkem_manufacturing.api.facade_prices.create_order", paths)
		self.assertIn("korkem_manufacturing.api.price_visibility.save", paths)
