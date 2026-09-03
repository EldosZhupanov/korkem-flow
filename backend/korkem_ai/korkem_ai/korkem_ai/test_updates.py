# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Обновления: узел говорит приложению, что вышло новее."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_ai.korkem_ai import updates


def _release(build: int, published=1, mandatory=0, platform="Android", url=None) -> str:
	doc = frappe.get_doc(
		{
			"doctype": updates.DOCTYPE,
			"platform": platform,
			"version": f"9.{build}.0",
			"build_number": build,
			"file_url": url or f"https://example.test/korkem-9.{build}.0.apk",
			"published": published,
			"mandatory": mandatory,
			"notes": "проверка",
		}
	)
	doc.insert(ignore_permissions=True)
	return doc.name


class TestWhatTheAppIsTold(IntegrationTestCase):
	def setUp(self):
		frappe.db.delete(updates.DOCTYPE)

	def tearDown(self):
		frappe.db.delete(updates.DOCTYPE)
		frappe.set_user("Administrator")

	def test_a_node_with_no_releases_says_so_instead_of_failing(self):
		"""Узел без выпущенных сборок — обычное состояние, а не поломка."""
		answer = updates.latest("Android", build=1)

		self.assertFalse(answer["available"])

	def test_the_newest_published_build_wins_not_the_newest_row(self):
		"""Порядок задаёт номер сборки, а не дата создания записи.

		Выпуски заводят руками и не всегда по порядку: исправление к старой
		версии могут внести после того, как выпустили новую.
		"""
		_release(30)
		_release(10)

		answer = updates.latest("Android", build=1)

		self.assertEqual(answer["build"], 30)

	def test_an_unpublished_build_is_invisible(self):
		"""Собрали и ещё не проверили — люди этого видеть не должны."""
		_release(50, published=0)

		self.assertFalse(updates.latest("Android", build=1)["available"])

	def test_the_same_build_is_not_an_update(self):
		_release(20)

		self.assertFalse(updates.latest("Android", build=20)["available"])

	def test_a_newer_app_than_the_server_knows_is_not_asked_to_downgrade(self):
		"""Собранное локально приложение новее выпущенного — так бывает у нас же."""
		_release(20)

		self.assertFalse(updates.latest("Android", build=25)["available"])

	def test_windows_is_not_offered_an_android_build(self):
		_release(40, platform="Android")

		self.assertFalse(updates.latest("Windows", build=1)["available"])

	def test_a_build_number_that_is_nonsense_is_treated_as_the_oldest(self):
		"""Клиент может прислать что угодно; отказывать ему в обновлении нельзя."""
		_release(20)

		for junk in ("", "не число", None):
			with self.subTest(build=junk):
				self.assertTrue(updates.latest("Android", build=junk)["available"])

	def test_a_relative_address_is_answered_as_a_full_one(self):
		"""Склеивать путь на клиенте — способ однажды скачать не то."""
		_release(60, url="/files/korkem.apk")

		self.assertTrue(updates.latest("Android", build=1)["url"].startswith("http"))


class TestAnUpdateCannotArriveOverAnOpenChannel(IntegrationTestCase):
	"""Установочный файл подменяют не ради шалости."""

	def tearDown(self):
		frappe.db.delete(updates.DOCTYPE)

	def test_publishing_over_http_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			_release(70, url="http://example.test/korkem.apk")

	def test_an_unpublished_draft_over_http_is_allowed_to_exist(self):
		"""Запретить черновик значило бы запретить готовить выпуск."""
		name = _release(71, published=0, url="http://example.test/korkem.apk")

		self.assertTrue(frappe.db.exists(updates.DOCTYPE, name))


class TestTheAnswerIsSafeToGiveAnyone(IntegrationTestCase):
	"""Открыто для гостя намеренно — но только это и открыто."""

	def setUp(self):
		frappe.db.delete(updates.DOCTYPE)
		_release(80)

	def tearDown(self):
		frappe.db.delete(updates.DOCTYPE)
		frappe.set_user("Administrator")

	def test_a_stranger_is_told_the_version_and_nothing_about_the_factory(self):
		frappe.set_user("Guest")
		answer = updates.latest("Android", build=1)

		self.assertTrue(answer["available"])
		self.assertEqual(
			set(answer),
			{"available", "platform", "version", "build", "url", "notes", "mandatory"},
			"в ответе не должно появиться ничего про компанию, людей или заказы",
		)
