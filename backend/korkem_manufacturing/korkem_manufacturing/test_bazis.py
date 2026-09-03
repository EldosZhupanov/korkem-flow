# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Чтение выгрузки БАЗИС.

Файлы здесь **выдуманы по документации**, а не выгружены с производства.
Одного настоящего экспорта всё ещё нет, и до него эти тесты закрепляют наше
понимание формата, а не сам формат. Когда файл появится, первое действие —
прогнать его через `inspect` и сверить с тем, что здесь написано.
"""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.services import bazis as service

SPECIFICATION = """<?xml version="1.0" encoding="utf-8"?>
<Проект>
  <Изделие>
    <Наименование>Кухонный гарнитур «Астана»</Наименование>
    <Артикул>KG-001</Артикул>
    <Заказ>SO-2026-0042</Заказ>
    <Количество>1</Количество>
    <Цена>780000,00</Цена>
    <СписокЭлементов>
      <Объект>
        <Наименование>Боковина левая</Наименование>
        <Код>D-101</Код>
        <Тип>Панель</Тип>
        <Длина>2100</Длина>
        <Ширина>560</Ширина>
        <Толщина>16</Толщина>
        <Количество>2</Количество>
        <СписокКромок>
          <Кромка><Наименование>Кромка ПВХ 2мм дуб</Наименование></Кромка>
          <Кромка><Наименование>Кромка ПВХ 0.4мм дуб</Наименование></Кромка>
        </СписокКромок>
        <ОсновнойМатериал>
          <SyncID>MAT-LDSP-DUB-16</SyncID>
          <Наименование>ЛДСП Дуб Сонома 16мм</Наименование>
          <Код>L-16-DS</Код>
          <ЕдИзм>м2</ЕдИзм>
          <Количество>2,352</Количество>
          <Цена>4200,50</Цена>
        </ОсновнойМатериал>
      </Объект>
      <Объект Наименование="Полка" Код="D-102" Тип="Панель"
              Длина="560" Ширина="300" Толщина="16" Количество="4" />
    </СписокЭлементов>
    <СписокОпераций>
      <Сдельная_операция>
        <SyncID>OP-CUT</SyncID>
        <Наименование>Раскрой</Наименование>
        <Количество>6</Количество>
        <Цена>350</Цена>
        <Трудоёмкость>12,5</Трудоёмкость>
      </Сдельная_операция>
      <Сдельная_операция>
        <SyncID>OP-EDGE</SyncID>
        <Наименование>Кромление</Наименование>
        <Количество>6</Количество>
        <Цена>200</Цена>
        <Трудоёмкость>8</Трудоёмкость>
      </Сдельная_операция>
    </СписокОпераций>
  </Изделие>
</Проект>
"""


class TestReadingABazisExport(IntegrationTestCase):
	def _bytes(self, text: str = SPECIFICATION, encoding: str = "utf-8") -> bytes:
		declared = text.replace('encoding="utf-8"', f'encoding="{encoding}"')
		return declared.encode(encoding)

	def test_the_product_is_read_with_its_order_number(self):
		"""Номер заказа — то, чем выгрузка привязывается к сделке клиента."""
		result = service.inspect(content=self._bytes())
		product = result["products"][0]

		self.assertEqual(product["name"], "Кухонный гарнитур «Астана»")
		self.assertEqual(product["order"], "SO-2026-0042")
		self.assertEqual(product["price"], 780000.0)

	def test_a_comma_is_a_decimal_point(self):
		"""Русская локаль Windows пишет дробную часть через запятую."""
		result = service.inspect(content=self._bytes())
		material = result["products"][0]["materials"][0]

		self.assertEqual(material["qty"], 2.352)
		self.assertEqual(material["price"], 4200.5)

	def test_values_are_read_from_elements_and_from_attributes(self):
		"""Выгрузки встречаются в обоих видах — спорить с файлом бесполезно."""
		parts = service.inspect(content=self._bytes())["products"][0]["parts"]
		by_code = {part["code"]: part for part in parts}

		self.assertEqual(by_code["D-101"]["name"], "Боковина левая")
		self.assertEqual(by_code["D-102"]["name"], "Полка")
		self.assertEqual(by_code["D-102"]["qty"], 4)

	def test_edges_are_kept_per_part(self):
		part = service.inspect(content=self._bytes())["products"][0]["parts"][0]
		self.assertEqual(len(part["edges"]), 2)
		self.assertIn("Кромка ПВХ 2мм дуб", part["edges"])

	def test_operations_carry_the_rate_and_the_time(self):
		"""Из них собирается маршрут: время в задание, расценка в себестоимость."""
		operations = service.inspect(content=self._bytes())["products"][0]["operations"]
		by_id = {row["sync_id"]: row for row in operations}

		self.assertEqual(by_id["OP-CUT"]["name"], "Раскрой")
		self.assertEqual(by_id["OP-CUT"]["minutes"], 12.5)
		self.assertEqual(by_id["OP-EDGE"]["price"], 200)

	def test_materials_keep_their_sync_id(self):
		"""Повторная выгрузка — «обновить то же», а не «создать ещё раз»."""
		material = service.inspect(content=self._bytes())["products"][0]["materials"][0]
		self.assertEqual(material["sync_id"], "MAT-LDSP-DUB-16")

	def test_a_windows_1251_export_reads_the_same(self):
		"""БАЗИС — программа под Windows; кодировку берём из объявления."""
		result = service.inspect(content=self._bytes(encoding="windows-1251"))
		self.assertEqual(
			result["products"][0]["name"], "Кухонный гарнитур «Астана»"
		)

	def test_totals_say_what_was_read(self):
		totals = service.inspect(content=self._bytes())["totals"]
		self.assertEqual(totals["products"], 1)
		self.assertEqual(totals["parts"], 2)
		self.assertEqual(totals["operations"], 2)

	def test_a_file_without_a_product_is_refused_with_the_reason(self):
		empty = '<?xml version="1.0" encoding="utf-8"?><Проект></Проект>'
		with self.assertRaises(frappe.ValidationError):
			service.inspect(content=empty.encode("utf-8"))

	def test_something_that_is_not_xml_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			service.inspect(content=b"\\x00\\x01 not xml at all")

	def test_an_empty_file_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			service.inspect(content=b"")

	def test_reading_writes_nothing(self):
		"""Разбор чужого формата не должен оставлять документов."""
		before = frappe.db.count("Item")
		service.inspect(content=self._bytes())
		self.assertEqual(frappe.db.count("Item"), before)


class TestBuildingASpecification(IntegrationTestCase):
	"""Из выгрузки собирается состав и маршрут — то, чем цех пилит."""

	def setUp(self):
		frappe.set_user("Administrator")

	def _import(self, text: str = SPECIFICATION) -> dict:
		return service.import_specification(content=text.encode("utf-8"))

	def test_the_product_becomes_an_item(self):
		result = self._import()
		product = result["products"][0]

		self.assertEqual(product["item"], "KG-001")
		self.assertTrue(frappe.db.exists("Item", "KG-001"))
		# Мебель на заказ на складе не лежит.
		self.assertEqual(frappe.db.get_value("Item", "KG-001", "is_stock_item"), 0)

	def test_materials_are_found_by_sync_id_not_by_name(self):
		"""Наименование технолог правит чаще всего остального."""
		self._import()
		code = f"{service.CODE_PREFIX}-MAT-LDSP-DUB-16"

		self.assertTrue(frappe.db.exists("Item", code))
		self.assertEqual(frappe.db.get_value("Item", code, "is_stock_item"), 1)
		self.assertEqual(frappe.db.get_value("Item", code, "stock_uom"), "Square Meter")

	def test_a_renamed_material_updates_and_does_not_double(self):
		self._import()
		renamed = SPECIFICATION.replace(
			"ЛДСП Дуб Сонома 16мм", "ЛДСП Дуб Сонома 16 мм (Egger)"
		)
		self._import(renamed)

		code = f"{service.CODE_PREFIX}-MAT-LDSP-DUB-16"
		self.assertEqual(
			frappe.db.get_value("Item", code, "item_name"),
			"ЛДСП Дуб Сонома 16 мм (Egger)",
		)
		like = frappe.get_all(
			"Item", filters={"item_code": ["like", f"{service.CODE_PREFIX}-MAT-LDSP%"]}, pluck="name"
		)
		self.assertEqual(len(like), 1)

	def test_the_specification_is_a_draft(self):
		"""Проведённая спецификация — решение человека, а не импорта."""
		bom = self._import()["products"][0]["bom"]
		self.assertEqual(frappe.db.get_value("BOM", bom, "docstatus"), 0)

	def test_reimporting_edits_the_same_draft(self):
		"""Три выгрузки за день не должны стать тремя спецификациями."""
		first = self._import()["products"][0]
		second = self._import()["products"][0]

		self.assertEqual(first["bom"], second["bom"])
		self.assertEqual(second["bom_status"], "updated")

		drafts = frappe.get_all(
			"BOM", filters={"item": "KG-001", "docstatus": 0}, pluck="name"
		)
		self.assertEqual(len(drafts), 1)

	def test_an_operation_without_a_workstation_waits_instead_of_guessing(self):
		"""БАЗИС не знает, на каком станке ЭТОЙ мастерской делают раскрой."""
		if frappe.db.exists("Operation", "Раскрой"):
			frappe.db.set_value("Operation", "Раскрой", "workstation", None)

		product = self._import()["products"][0]

		self.assertIn("Раскрой", product["operations_awaiting_workstation"])
		self.assertTrue(frappe.db.exists("Operation", "Раскрой"))

	def test_once_the_workstation_is_named_the_operation_joins_the_route(self):
		"""Владелец говорит это один раз — в справочнике операций ERPNext."""
		self._import()
		workstation = frappe.get_all("Workstation", pluck="name", limit_page_length=1)[0]
		frappe.db.set_value("Operation", "Раскрой", "workstation", workstation)

		product = self._import()["products"][0]
		self.assertIn("Раскрой", product["operations"])

		bom = frappe.get_doc("BOM", product["bom"])
		by_name = {row.operation: row for row in bom.operations}
		self.assertEqual(by_name["Раскрой"].time_in_mins, 12.5)
		self.assertEqual(by_name["Раскрой"].workstation, workstation)

	def test_an_unknown_unit_stops_the_import_before_anything_is_written(self):
		"""Подстановка штук напечатала бы в накладной неправду."""
		odd = SPECIFICATION.replace("<ЕдИзм>м2</ЕдИзм>", "<ЕдИзм>погонных саженей</ЕдИзм>")
		before = frappe.db.count("Item")

		with self.assertRaises(frappe.ValidationError):
			self._import(odd)

		self.assertEqual(frappe.db.count("Item"), before)

	def test_the_refusal_names_the_unit_it_did_not_understand(self):
		odd = SPECIFICATION.replace("<ЕдИзм>м2</ЕдИзм>", "<ЕдИзм>погонных саженей</ЕдИзм>")
		try:
			self._import(odd)
		except frappe.ValidationError as error:
			self.assertIn("погонных саженей", str(error))
		else:
			self.fail("Импорт не отказал")

	def test_a_product_without_materials_is_refused(self):
		bare = """<?xml version="1.0" encoding="utf-8"?>
<Проект><Изделие><Наименование>Пустое</Наименование><Артикул>EMPTY-1</Артикул>
</Изделие></Проект>"""
		with self.assertRaises(frappe.ValidationError):
			self._import(bare)

	def test_an_employee_cannot_import_a_specification(self):
		"""Импорт заводит номенклатуру и расценки. Это делает владелец."""
		from korkem_manufacturing.services import invitations

		email = f"zamer-{frappe.generate_hash(length=8)}@korkem.kz"
		invitations.invite_employee(email=email, position="shop_floor")
		self.addCleanup(frappe.set_user, "Administrator")

		frappe.set_user(email)
		with self.assertRaises(frappe.PermissionError):
			self._import()
