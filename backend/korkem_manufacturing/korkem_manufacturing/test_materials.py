# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""Материалы: то, без чего нельзя раскроить и подобрать пару.

Каталог мебельного цеха — это не список названий. Проверяется здесь ровно то,
что отличает его от списка: код декора как способ поиска, толщина как условие
раскроя и кромка, привязанная к толщине плиты, а не к цвету.

Отраслевые факты, из которых это следует, — в `docs/product/furniture_reference.md`.
"""

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.services import materials
from korkem_manufacturing.services.scope import current_company


class _MaterialCase(IntegrationTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		self.company = current_company()
		frappe.db.delete(materials.DOCTYPE, {"manufacturer": "ТестЭггер"})
		self.addCleanup(
			frappe.db.delete, materials.DOCTYPE, {"manufacturer": "ТестЭггер"}
		)

	def board(self, decor_code, name, thickness=16.0, color_family="white"):
		return frappe.get_doc(
			{
				"doctype": materials.DOCTYPE,
				"kind": materials.BOARD,
				"company": self.company,
				"manufacturer": "ТестЭггер",
				"decor_code": decor_code,
				"material_name": name,
				"thickness_mm": thickness,
				"sheet_width_mm": 2800,
				"sheet_height_mm": 2070,
				"color_family": color_family,
			}
		).insert(ignore_permissions=True)

	def edge(self, name, fits, width=22.0):
		return frappe.get_doc(
			{
				"doctype": materials.DOCTYPE,
				"kind": materials.EDGE,
				"company": self.company,
				"manufacturer": "ТестЭггер",
				"material_name": name,
				"fits_thickness_mm": fits,
				"edge_width_mm": width,
			}
		).insert(ignore_permissions=True)


class TestWhatMakesItACatalogue(_MaterialCase):
	def test_a_board_without_a_thickness_is_refused(self):
		"""Плита без толщины не режется, и заводить её незачем."""
		with self.assertRaises(frappe.ValidationError):
			frappe.get_doc(
				{
					"doctype": materials.DOCTYPE,
					"kind": materials.BOARD,
					"company": self.company,
					"material_name": "Плита без толщины",
					"manufacturer": "ТестЭггер",
				}
			).insert(ignore_permissions=True)

	def test_an_edge_must_say_which_thickness_it_closes(self):
		"""Лентой под 18 мм торец 16 мм не закрыть."""
		with self.assertRaises(frappe.ValidationError):
			frappe.get_doc(
				{
					"doctype": materials.DOCTYPE,
					"kind": materials.EDGE,
					"company": self.company,
					"material_name": "Кромка ниоткуда",
					"manufacturer": "ТестЭггер",
				}
			).insert(ignore_permissions=True)

	def test_search_finds_by_decor_code(self):
		"""Мебельщик ищет по коду: «белых премиумов» у трёх производителей три."""
		self.board("W1000 ST9", "Белый премиум")
		self.board("U999 ST2", "Чёрный", color_family="black")

		found = materials.search(query="W1000")["materials"]

		self.assertEqual([m["decor_code"] for m in found], ["W1000 ST9"])

	def test_search_finds_by_name_too(self):
		self.board("W1000 ST9", "Белый премиум")

		found = materials.search(query="премиум")["materials"]

		self.assertEqual(len(found), 1)

	def test_thickness_filters(self):
		self.board("W1000 ST9", "Белый премиум", thickness=16.0)
		self.board("W1100 ST9", "Белый альпийский", thickness=18.0)

		found = materials.search(query="ТестЭггер", thickness=18)["materials"]

		self.assertEqual([m["decor_code"] for m in found], ["W1100 ST9"])


class TestEdgeIsMatchedByThicknessNotByColour(_MaterialCase):
	def test_only_the_edge_that_fits_comes_back(self):
		"""Совместимость здесь — число, а не мнение: спрашивать модель незачем."""
		self.edge("Кромка ПВХ 22 мм под 16", fits=16.0)
		self.edge("Кромка ПВХ 23 мм под 18", fits=18.0, width=23.0)

		fitting = materials.edges_for(18.0)

		self.assertEqual([e["name"] for e in fitting], ["Кромка ПВХ 23 мм под 18"])

	def test_nothing_fits_is_an_empty_answer_not_a_guess(self):
		self.edge("Кромка ПВХ 22 мм под 16", fits=16.0)

		self.assertEqual(materials.edges_for(25.0), [])


class TestThePageIsBounded(_MaterialCase):
	def test_a_caller_cannot_ask_for_the_whole_warehouse(self):
		"""Каталог живого цеха — тысячи позиций. Ни экран, ни модель не должны
		получить их разом."""
		for i in range(3):
			self.board(f"U{200 + i} ST9", f"Серая {i}", color_family="grey")

		page = materials.search(query="ТестЭггер", limit=10_000)

		self.assertLessEqual(len(page["materials"]), materials.MAX_PAGE)

	def test_total_counts_everything_the_filter_matches(self):
		"""Страница показывает часть, но человек должен знать, из скольки."""
		for i in range(3):
			self.board(f"U{300 + i} ST9", f"Серая {i}", color_family="grey")

		page = materials.search(query="ТестЭггер", limit=2)

		self.assertEqual(len(page["materials"]), 2)
		self.assertEqual(page["total"], 3)


class TestHardwareIsMatchedByGeometry(_MaterialCase):
	"""Подойдёт ли петля — решают числа, а не бренд.

	Накладная петля Boyard и накладная Blum ставятся одинаково. Поэтому в
	каталоге нет списка «подходит к»: его пришлось бы вести руками, и он
	разошёлся бы с действительностью на третьей позиции.
	"""

	def hinge(self, name, overlay, brand="ТестБренд"):
		return frappe.get_doc(
			{
				"doctype": "Furniture Hardware",
				"hardware_type": "hinge",
				"company": self.company,
				"hardware_name": name,
				"brand": brand,
				"overlay": overlay,
				"cup_diameter_mm": 35.0,
				"cup_depth_mm": 11.3,
				"mounting_system": "german",
				"opening_angle_deg": 110.0,
			}
		).insert(ignore_permissions=True)

	def runner(self, name, length):
		return frappe.get_doc(
			{
				"doctype": "Furniture Hardware",
				"hardware_type": "runner",
				"company": self.company,
				"hardware_name": name,
				"brand": "ТестБренд",
				"length_mm": length,
			}
		).insert(ignore_permissions=True)

	def setUp(self):
		super().setUp()
		frappe.db.delete("Furniture Hardware", {"brand": "ТестБренд"})
		self.addCleanup(frappe.db.delete, "Furniture Hardware", {"brand": "ТестБренд"})

	def test_a_hinge_without_a_cup_is_refused(self):
		"""Без диаметра чашки нет присадки — такую петлю невозможно поставить."""
		with self.assertRaises(frappe.ValidationError):
			frappe.get_doc(
				{
					"doctype": "Furniture Hardware",
					"hardware_type": "hinge",
					"company": self.company,
					"hardware_name": "Петля ниоткуда",
					"brand": "ТестБренд",
					"overlay": "full",
				}
			).insert(ignore_permissions=True)

	def test_a_hinge_without_an_overlay_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			frappe.get_doc(
				{
					"doctype": "Furniture Hardware",
					"hardware_type": "hinge",
					"company": self.company,
					"hardware_name": "Петля без наложения",
					"brand": "ТестБренд",
					"cup_diameter_mm": 35.0,
				}
			).insert(ignore_permissions=True)

	def test_only_the_overlay_asked_for_comes_back(self):
		self.hinge("Накладная 110°", "full")
		self.hinge("Вкладная 110°", "inset")

		fitting = materials.hinges_for("inset")

		self.assertEqual([h["name"] for h in fitting], ["Вкладная 110°"])

	def test_a_runner_longer_than_the_carcass_is_not_offered(self):
		"""Направляющая длиннее корпуса не встанет — это размер, а не вкус."""
		self.runner("Направляющая 450", 450.0)
		self.runner("Направляющая 550", 550.0)

		fitting = materials.runners_for(500.0)

		self.assertEqual([r["name"] for r in fitting], ["Направляющая 450"])

	def test_the_longest_that_fits_comes_first(self):
		"""В ящике полезна глубина: из подходящих сначала самая длинная."""
		self.runner("Направляющая 350", 350.0)
		self.runner("Направляющая 450", 450.0)

		fitting = materials.runners_for(500.0)

		self.assertEqual([r["length_mm"] for r in fitting], [450.0, 350.0])


class TestTemplateBoundsRefuseBeforeTheCut(IntegrationTestCase):
	"""Границы шаблона существуют, чтобы отказать до раскроя, а не после.

	Шкаф шириной 4200 мм из одного корпуса не делают — его режут на секции, и
	это другое изделие. Проверка должна поймать это в каталоге, а не в цеху.
	"""

	def setUp(self):
		frappe.set_user("Administrator")
		self.company = current_company()
		frappe.db.delete("Furniture Template", {"template_name": ["like", "Тест%"]})
		self.addCleanup(
			frappe.db.delete, "Furniture Template", {"template_name": ["like", "Тест%"]}
		)

	def template(self, **overrides):
		values = {
			"doctype": "Furniture Template",
			"company": self.company,
			"category": "wardrobe",
			"template_name": "Тестовый шкаф",
			"default_width_mm": 2000.0,
			"default_height_mm": 2400.0,
			"default_depth_mm": 600.0,
		}
		values.update(overrides)
		return frappe.get_doc(values).insert(ignore_permissions=True)

	def test_a_sensible_template_saves(self):
		doc = self.template(min_width_mm=1200.0, max_width_mm=3000.0)

		self.assertEqual(doc.default_width_mm, 2000.0)

	def test_a_range_with_from_above_to_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			self.template(min_width_mm=3000.0, max_width_mm=1200.0)

	def test_a_default_outside_its_own_range_is_refused(self):
		"""Самая тихая ошибка каталога: шаблон предложит размер, который сам же
		и запретит, и человек упрётся в отказ, ничего не изменив."""
		with self.assertRaises(frappe.ValidationError):
			self.template(min_width_mm=2500.0, max_width_mm=3000.0)

	def test_an_absent_bound_means_no_bound_not_zero(self):
		"""Половина цехов границ не формулирует. Требовать их — мешать заводить
		каталог."""
		doc = self.template()

		self.assertFalse(doc.min_width_mm)

	def test_more_default_doors_than_the_maximum_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			self.template(min_doors=2, max_doors=3, default_doors=4)
