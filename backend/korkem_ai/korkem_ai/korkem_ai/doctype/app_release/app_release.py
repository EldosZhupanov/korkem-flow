# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Одна выпущенная сборка приложения."""

from __future__ import annotations

import frappe
from frappe.model.document import Document


class AppRelease(Document):
	def validate(self):
		self.version = (self.version or "").strip()
		self.file_url = (self.file_url or "").strip()

		if self.build_number is None or self.build_number < 1:
			frappe.throw("Номер сборки начинается с единицы и растёт.")

		if not self.file_url:
			frappe.throw("Без адреса файла обновлению неоткуда взяться.")

		if self.published and self.file_url.startswith("http://"):
			# Приложение обещает пользователю, что трафик шифруется. Скачать
			# установочный файл по открытому каналу — это позволить подменить
			# его по дороге, а установочный файл подменяют не ради шалости.
			frappe.throw("Опубликовать обновление можно только по https.")
