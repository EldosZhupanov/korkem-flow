# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt

from __future__ import annotations

import frappe
from frappe.model.document import Document
from frappe.utils import flt

MIN_OFFCUT_SIDE_MM = 100.0
MIN_OFFCUT_AREA_M2 = 0.04  # 400 cm2 (e.g. 200mm x 200mm)


class StockOffcut(Document):
	def before_insert(self):
		# 1. Compute area in square meters
		self.area_m2 = round((flt(self.length_mm) * flt(self.width_mm)) / 1_000_000.0, 4)

		# 2. Generate QR code payload if empty
		if not self.qr_code:
			salt = frappe.generate_hash(length=8)
			self.qr_code = f"OFFCUT:{self.company}:{self.material_item}:{int(flt(self.length_mm))}x{int(flt(self.width_mm))}:{salt}"

		# 3. Generate barcode payload if empty
		if not self.barcode:
			self.barcode = f"OFC-{frappe.generate_hash(length=10).upper()}"

	def validate(self):
		# 1. Tenant scope check
		from korkem_manufacturing.services.scope import enforce_tenant_scope
		enforce_tenant_scope(self.company)

		# 2. Recompute area
		self.area_m2 = round((flt(self.length_mm) * flt(self.width_mm)) / 1_000_000.0, 4)

		# 3. Minimum dimensions threshold for usable stock
		if self.status != "Scrapped":
			if flt(self.length_mm) < MIN_OFFCUT_SIDE_MM or flt(self.width_mm) < MIN_OFFCUT_SIDE_MM:
				frappe.throw(
					f"Габариты делового остатка ({self.length_mm}x{self.width_mm} мм) меньше минимального предела ({MIN_OFFCUT_SIDE_MM}x{MIN_OFFCUT_SIDE_MM} мм). Такой остаток считается опилом/отходом и подлежит списанию (Scrapped).",
					frappe.ValidationError,
				)
			if flt(self.area_m2) < MIN_OFFCUT_AREA_M2:
				frappe.throw(
					f"Площадь делового остатка ({self.area_m2} м²) меньше минимальной ({MIN_OFFCUT_AREA_M2} м²). Такой остаток подлежит списанию (Scrapped).",
					frappe.ValidationError,
				)

		# 4. Status invariants on modification
		if not self.is_new():
			old_status = frappe.db.get_value("Stock Offcut", self.name, "status")
			if old_status == "Consumed" and self.status != "Consumed":
				frappe.throw("Использованный остаток (Consumed) не может быть изменен или возвращен в статус Available.", frappe.ValidationError)
			if old_status == "Scrapped" and self.status != "Scrapped":
				frappe.throw("Списанный остаток (Scrapped) не подлежит возврату в оборот.", frappe.ValidationError)

	def on_trash(self):
		# Prevent physical deletion: soft-delete only via Scrapped
		frappe.throw(
			"Деловые остатки (Stock Offcut) запрещено удалять физически. Переведите статус остатка в 'Scrapped'.",
			frappe.PermissionError,
		)
