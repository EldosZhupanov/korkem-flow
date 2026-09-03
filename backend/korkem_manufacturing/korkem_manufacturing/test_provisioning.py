# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Claiming a node — the one action that runs before anybody has an account.

These tests run on a bench that has a company, which makes it claimed — see
`is_claimed` for why a company is enough and ERPNext's own flag is not. So the
refusals are tested for real here, and the happy path against a patched
`is_claimed`; the full build of a company by ERPNext's wizard needs a genuinely
fresh site and was verified there (ADR-0027 records the measurements).
"""

from __future__ import annotations

from unittest.mock import patch

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.api import provisioning as api
from korkem_manufacturing.services import provisioning


class TestNodeIsAlreadyClaimed(IntegrationTestCase):
	"""Any bench with a company is claimed, and every door must be shut.

	The first version of this class assumed a developer bench is claimed
	because ERPNext's wizard has run. CI disagreed, and CI was right: our own
	`bootstrap.sh` seeds a company without ever running that wizard, so the
	flag is 0 on a bench that plainly belongs to somebody. The lesson is in
	`is_claimed`, not here — a node with a company must never be claimable,
	whatever ERPNext thinks of its own setup.
	"""

	def test_a_company_is_enough_to_count_as_claimed(self):
		"""Even with ERPNext's own flag unset, as on a bootstrapped bench."""
		self.assertTrue(frappe.db.count("Company"))
		with patch.object(provisioning.frappe, "is_setup_complete", return_value=False):
			self.assertTrue(provisioning.is_claimed())

	def test_status_reports_claimed(self):
		self.assertTrue(provisioning.is_claimed())
		self.assertEqual(api.status()["claimed"], True)

	def test_status_tells_a_stranger_nothing_else(self):
		"""An unauthenticated caller learns the state and the languages.

		Not the company, not the owner, not how many people work here. A node
		on a tunnel answers this to anyone who asks.
		"""
		self.assertEqual(set(api.status()), {"claimed", "languages"})

	def test_a_claimed_node_refuses_even_with_a_right_code(self):
		with self.assertRaises(provisioning.NodeAlreadyClaimed):
			provisioning.claim(
				code="WHATEVER",
				company="Second Company",
				owner_email="intruder@example.com",
				owner_name="Intruder",
				owner_password="x",
			)

	def test_the_endpoint_answers_409_rather_than_a_traceback(self):
		result = api.claim(
			code="WHATEVER",
			company="Second Company",
			owner_email="intruder@example.com",
			owner_password="x",
		)
		self.assertEqual(result["status"], "already_claimed")
		self.assertEqual(frappe.local.response.get("http_status_code"), 409)

	def test_no_claim_code_is_minted_for_a_claimed_node(self):
		with self.assertRaises(provisioning.NodeAlreadyClaimed):
			provisioning.claim_code()


class TestClaimCode(IntegrationTestCase):
	"""The code is the only thing between an unclaimed node and a stranger."""

	def setUp(self):
		self.addCleanup(frappe.db.set_default, provisioning.CLAIM_CODE_KEY, "")
		self.addCleanup(frappe.db.set_default, provisioning.CLAIM_ATTEMPTS_KEY, "")

	def test_a_code_is_long_and_unambiguous(self):
		with patch.object(provisioning, "is_claimed", return_value=False):
			code = provisioning.claim_code()

		self.assertEqual(len(code), 16)
		# No I, L, O or U: a code is read off a screen and typed on a phone in a
		# workshop, and those four are what people get wrong.
		self.assertFalse(set(code) & set("ILOU"))

	def test_the_plain_code_is_never_stored(self):
		with patch.object(provisioning, "is_claimed", return_value=False):
			code = provisioning.claim_code()

		stored = frappe.db.get_default(provisioning.CLAIM_CODE_KEY)
		self.assertNotEqual(stored, code)
		self.assertNotIn(code, stored)
		self.assertEqual(len(stored), 64)

	def test_two_codes_are_not_the_same(self):
		with patch.object(provisioning, "is_claimed", return_value=False):
			first = provisioning.claim_code()
			second = provisioning.claim_code()
		self.assertNotEqual(first, second)

	def test_a_wrong_code_is_refused_and_counted(self):
		with patch.object(provisioning, "is_claimed", return_value=False):
			provisioning.claim_code()

			with self.assertRaises(provisioning.ClaimCodeRefused):
				provisioning.claim(
					code="WRONGWRONGWRONG1",
					company="X",
					owner_email="a@example.com",
					owner_name="A",
					owner_password="p",
				)

		self.assertEqual(int(frappe.db.get_default(provisioning.CLAIM_ATTEMPTS_KEY)), 1)

	def test_guessing_stops_after_ten_tries(self):
		with patch.object(provisioning, "is_claimed", return_value=False):
			provisioning.claim_code()
			frappe.db.set_default(
				provisioning.CLAIM_ATTEMPTS_KEY, str(provisioning.MAX_ATTEMPTS)
			)

			with self.assertRaises(provisioning.ClaimCodeRefused) as refusal:
				provisioning.claim(
					code="ANYTHINGATALL123",
					company="X",
					owner_email="a@example.com",
					owner_name="A",
					owner_password="p",
				)

		self.assertIn("Restart the node", str(refusal.exception))

	def test_a_node_with_no_code_yet_refuses_rather_than_letting_anyone_in(self):
		frappe.db.set_default(provisioning.CLAIM_CODE_KEY, "")
		with patch.object(provisioning, "is_claimed", return_value=False):
			with self.assertRaises(provisioning.ClaimCodeRefused):
				provisioning.claim(
					code="",
					company="X",
					owner_email="a@example.com",
					owner_name="A",
					owner_password="p",
				)


class TestTheCompanyAbbreviation(IntegrationTestCase):
	"""It ends up inside every warehouse and account name, permanently."""

	def test_punctuation_never_reaches_a_warehouse_name(self):
		self.assertEqual(provisioning._abbreviation("Мебель+"), "МЕБЕЛ")
		self.assertEqual(provisioning._abbreviation('ТОО "Астана"'), "ТООАС")

	def test_a_nameless_company_still_gets_something_usable(self):
		self.assertEqual(provisioning._abbreviation("!!!"), "KRK")


class TestTheGuestWhoBuildsTheCompany(IntegrationTestCase):
	"""Присвоение приходит от гостя — и должно строить компанию от админа.

	Найдено первой настоящей установкой 3 сентября 2026, а не этим набором.
	Приложение дошло до сервера, ввело верный код и получило:

	    User guest does not have access to this document: System Settings

	Читается как дефект прав в KORKEM, и им не является: endpoint открыт гостю
	намеренно — на неприсвоенном узле аккаунтов ещё нет, — а мастер ERPNext
	пишет `System Settings`, чего гостю нельзя. Ни один тест этого не поймал,
	потому что все они идут от Administrator: гостевая дорога не была пройдена
	ни разу.

	Здесь проверяется ровно то, чего не хватало: кто именно строит компанию, и
	что вызывающий возвращается на место после — в том числе когда сборка
	упала.
	"""

	def tearDown(self):
		frappe.set_user("Administrator")

	def _claim_as_guest(self, setup_spy):
		"""Пройти присвоение от имени гостя, подменив всё, что пишет в базу."""
		code = None
		with patch.object(provisioning, "is_claimed", return_value=False):
			code = provisioning.claim_code()

		frappe.set_user("Guest")
		with (
			patch.object(provisioning, "is_claimed", side_effect=[False, True]),
			patch.object(provisioning, "_run_erpnext_setup", setup_spy),
			patch.object(provisioning, "name_the_shipping_warehouse"),
			patch.object(
				provisioning, "_make_owner", return_value={"user": "x@example.com"}
			),
			patch.object(provisioning, "_audit"),
		):
			return provisioning.claim(
				code=code,
				company="Гостевая проверка",
				owner_email="guest-claim@example.com",
				owner_name="Проверка",
				owner_password="не-читается-никем",
			)

	def test_the_wizard_runs_as_administrator_not_as_the_guest_who_asked(self):
		seen = []

		def spy(**_kwargs):
			seen.append(frappe.session.user)

		self._claim_as_guest(spy)

		self.assertEqual(
			seen,
			["Administrator"],
			"мастер ERPNext должен строить компанию от администратора: гостю "
			"нельзя писать System Settings",
		)

	def test_the_caller_is_put_back_afterwards(self):
		self._claim_as_guest(lambda **_kwargs: None)

		self.assertEqual(frappe.session.user, "Guest")

	def test_the_caller_is_put_back_even_when_the_build_fails(self):
		def explode(**_kwargs):
			raise RuntimeError("мастер упал на середине")

		with self.assertRaises(RuntimeError):
			self._claim_as_guest(explode)

		self.assertEqual(
			frappe.session.user,
			"Guest",
			"повышение прав, которое переживает ошибку, — это дыра, а не удобство",
		)


class TestNobodyElsesDemoData(IntegrationTestCase):
	"""Присвоение узла не должно приносить чужую демонстрацию.

	Найдено первой настоящей установкой 3 сентября 2026. Через минуту после
	того, как компания заняла узел, на нём оказались три несуществующих
	сотрудника, двенадцать заявок, семь сделок, семь организаций и одиннадцать
	контактов. Ни один из сотрудников не мог войти — паролей у них нет, — но
	они стояли в списках владельца, и один держал роль Sales Manager.

	Источник не наш: `crm/hooks.py` регистрирует
	`setup_wizard_complete = "crm.demo.api.create_demo_data"`, и хук срабатывает
	на любом сайте, чей мастер настройки завершился. Присвоение узла — это и
	есть завершение мастера. Наша защита пилота сюда не достаёт: она прикрывает
	фикстуры, которые написали мы.

	Рычаг — собственный ранний возврат upstream: при уже поднятом флаге он не
	делает ничего. Поэтому проверяется не «удалили после», а «не создавали
	вовсе»: удаление осталось бы в истории боевой системы клиента.
	"""

	def tearDown(self):
		frappe.set_user("Administrator")

	def test_the_flag_is_up_before_the_wizard_runs_not_after(self):
		"""Порядок здесь и есть содержание проверки.

		Флаг **снимается перед проверкой**, и это не формальность. Первая
		версия этого теста его не снимала — а на стенде разработки он уже стоял
		от прошлых запусков, поэтому тест проходил и с починкой, и без неё.
		Поймано мутацией: убрал вызов, тест остался зелёным. Проверка, которая
		проходит при сломанном коде, хуже отсутствующей — она создаёт
		уверенность.
		"""
		before = frappe.db.get_default(provisioning.CRM_DEMO_STATE_KEY)
		frappe.db.set_default(provisioning.CRM_DEMO_STATE_KEY, "")
		self.addCleanup(
			frappe.db.set_default, provisioning.CRM_DEMO_STATE_KEY, before or ""
		)
		self.assertFalse(
			frappe.db.get_default(provisioning.CRM_DEMO_STATE_KEY),
			"флаг должен быть снят, иначе проверка ниже ничего не проверяет",
		)

		seen = {}

		def spy(_args=None, **_kwargs):
			seen["flag"] = frappe.db.get_default(provisioning.CRM_DEMO_STATE_KEY)

		with (
			patch.object(provisioning, "is_claimed", return_value=False),
			patch(
				"frappe.desk.page.setup_wizard.setup_wizard.setup_complete",
				spy,
			),
		):
			provisioning._run_erpnext_setup(
				company="Проверка флага",
				owner_email="flag@example.com",
				owner_name="Проверка",
				owner_password="не-читается",
				country="Kazakhstan",
				currency="KZT",
				timezone="Asia/Almaty",
				language="ru",
			)

		self.assertEqual(
			seen.get("flag"),
			"1",
			"флаг CRM должен стоять до запуска мастера: иначе демонстрационные "
			"данные создаются, и удалять их придётся уже из боевой системы",
		)

	def test_the_key_is_upstreams_own_name(self):
		"""Переименуем — и предохранитель перестанет срабатывать молча."""
		self.assertEqual(provisioning.CRM_DEMO_STATE_KEY, "crm_demo_data_created")
