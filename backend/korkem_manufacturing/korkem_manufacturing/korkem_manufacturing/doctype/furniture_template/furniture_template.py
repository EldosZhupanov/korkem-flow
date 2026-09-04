# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Шаблон изделия — то, с чего начинается разговор о шкафе.

## Зачем шаблон, если есть размеры

Клиент не называет двенадцать чисел. Он говорит «нужен шкаф в прихожую», и
дальше от чего-то надо оттолкнуться: типовая высота 2400, глубина 600. Шаблон —
это набор умолчаний плюс **границы, в которых их можно менять**.

## Границы — это отказ, а не подсказка

Шкаф шириной 4200 мм из одного корпуса не делают: его режут на секции, и это
другое изделие. Диапазон в шаблоне существует, чтобы система отказала до того,
как размер уйдёт в расчёт и в раскрой, а не после.

Пустая граница означает «здесь ограничения нет», а не ноль. Половина цехов не
формулирует их вовсе, и требовать заполнения значило бы мешать заводить каталог.
"""

from __future__ import annotations

import frappe
from frappe.model.document import Document

RANGES = (
	("default_width_mm", "min_width_mm", "max_width_mm", "Ширина"),
	("default_height_mm", "min_height_mm", "max_height_mm", "Высота"),
	("default_depth_mm", "min_depth_mm", "max_depth_mm", "Глубина"),
)


class FurnitureTemplate(Document):
	def validate(self):
		self._ranges_make_sense()
		self._default_is_inside_its_own_range()
		self._door_count_makes_sense()

	def _ranges_make_sense(self):
		for _default, low, high, label in RANGES:
			lo, hi = self.get(low), self.get(high)
			if lo and hi and lo > hi:
				frappe.throw(f"{label}: «от» больше «до» — {lo} > {hi}.")

	def _default_is_inside_its_own_range(self):
		"""Умолчание вне собственных границ — самая тихая из ошибок каталога.

		Шаблон предложит размер, который сам же и запретит, и человек упрётся в
		отказ, ничего не изменив.
		"""
		for default, low, high, label in RANGES:
			value, lo, hi = self.get(default), self.get(low), self.get(high)
			if value and lo and value < lo:
				frappe.throw(f"{label} по умолчанию {value} меньше минимума {lo}.")
			if value and hi and value > hi:
				frappe.throw(f"{label} по умолчанию {value} больше максимума {hi}.")

	def _door_count_makes_sense(self):
		if self.min_doors and self.max_doors and self.min_doors > self.max_doors:
			frappe.throw("Дверей «от» больше, чем «до».")
		if self.default_doors and self.max_doors and self.default_doors > self.max_doors:
			frappe.throw(
				f"Дверей по умолчанию {self.default_doors} больше максимума {self.max_doors}."
			)
