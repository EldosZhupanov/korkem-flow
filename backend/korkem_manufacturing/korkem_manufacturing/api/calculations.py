"""Stateless calculations available to every authenticated client, without LLM."""

import frappe

from korkem_manufacturing.services import calculations as service
from korkem_manufacturing.services.scope import current_company


def _run(handler, **arguments):
	if not frappe.session.user or frappe.session.user == "Guest":
		frappe.throw("Authentication required.", frappe.PermissionError)
	current_company()  # Session-derived; never accepted from model/client.
	try:
		return handler(**arguments)
	except ValueError as exc:
		frappe.throw(str(exc))


@frappe.whitelist(methods=["GET", "POST"])
def calculate_facade_area(width_mm: float, height_mm: float, quantity: int) -> dict:
	return _run(service.calculate_facade_area, width_mm=width_mm, height_mm=height_mm, quantity=quantity)


@frappe.whitelist(methods=["GET", "POST"])
def calculate_panel_area(width_mm: float, height_mm: float, quantity: int) -> dict:
	return _run(service.calculate_panel_area, width_mm=width_mm, height_mm=height_mm, quantity=quantity)


@frappe.whitelist(methods=["GET", "POST"])
def calculate_edge_length(
	width_mm: float, height_mm: float, quantity: int, width_edges: int, height_edges: int
) -> dict:
	return _run(
		service.calculate_edge_length,
		width_mm=width_mm,
		height_mm=height_mm,
		quantity=quantity,
		width_edges=width_edges,
		height_edges=height_edges,
	)


@frappe.whitelist(methods=["GET", "POST"])
def calculate_material_quantity(
	width_mm: float,
	height_mm: float,
	quantity: int,
	sheet_width_mm: float,
	sheet_height_mm: float,
	waste_percent: float,
) -> dict:
	return _run(
		service.calculate_material_quantity,
		width_mm=width_mm,
		height_mm=height_mm,
		quantity=quantity,
		sheet_width_mm=sheet_width_mm,
		sheet_height_mm=sheet_height_mm,
		waste_percent=waste_percent,
	)
