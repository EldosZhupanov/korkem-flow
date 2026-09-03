# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""Замер — звено между «клиент чего-то хочет» и «мы знаем цену»."""

from __future__ import annotations

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.services import capture as capture_service
from korkem_manufacturing.services import enquiry as enquiry_service
from korkem_manufacturing.services import measurement as service


class TestRecordingAMeasurement(IntegrationTestCase):
	def setUp(self):
		capture = capture_service.record(
			text="Кухня, замерить",
			understood={"customer_hint": f"Клиент {frappe.generate_hash(length=6)}"},
			assign_to="Administrator",
		)["capture"]
		converted = enquiry_service.convert(capture=capture)
		self.enquiry = converted["enquiry"]
		self.capture = capture

	def tearDown(self):
		frappe.set_user("Administrator")

	def test_the_measurement_lands_on_the_enquiry(self):
		service.record(enquiry=self.enquiry, dimensions="3200x600, высота 2100")

		said = frappe.get_all(
			"Comment",
			filters={"reference_doctype": "Opportunity", "reference_name": self.enquiry},
			pluck="content",
		)
		self.assertTrue(any("3200x600" in c for c in said))

	def test_recording_a_measurement_closes_the_measurers_task(self):
		"""Человек делает это одним движением — система тоже."""
		result = service.record(enquiry=self.enquiry, dimensions="3200x600")

		self.assertIsNotNone(result["task_closed"])
		self.assertEqual(
			frappe.db.get_value("CRM Task", result["task_closed"], "status"), "Done"
		)

	def test_an_address_becomes_an_address_not_a_note(self):
		"""Доставка и монтаж будут искать его там, а не в ленте комментариев."""
		result = service.record(
			enquiry=self.enquiry,
			dimensions="3200x600",
			address_line="Абая 12, кв 5",
			city="Астана",
		)

		self.assertIsNotNone(result["address"])
		address = frappe.get_doc("Address", result["address"])
		self.assertEqual(address.address_line1, "Абая 12, кв 5")
		self.assertEqual(address.city, "Астана")

	def test_notes_alone_are_a_valid_measurement(self):
		"""«Стены кривые, нужен доборный элемент» — это результат замера."""
		result = service.record(
			enquiry=self.enquiry, notes="Стены кривые, нужен доборный элемент"
		)
		self.assertIsNotNone(result["task_closed"])

	def test_an_empty_measurement_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			service.record(enquiry=self.enquiry, dimensions="   ", notes="")

	def test_an_enquiry_with_no_task_still_takes_a_measurement(self):
		"""Задачу могли и не создавать — замер от этого не перестаёт быть замером."""
		capture = capture_service.record(
			text="Сам поеду мерить",
			understood={"customer_hint": f"Клиент {frappe.generate_hash(length=6)}"},
		)["capture"]
		enquiry = enquiry_service.convert(capture=capture)["enquiry"]

		result = service.record(enquiry=enquiry, dimensions="1800x600")

		self.assertIsNone(result["task_closed"])


class TestScope(IntegrationTestCase):
	def test_company_is_not_a_caller_argument(self):
		import inspect

		self.assertNotIn("company", inspect.signature(service.record).parameters)

	def test_an_enquiry_from_nowhere_is_refused(self):
		with self.assertRaises(frappe.PermissionError):
			service.record(enquiry="does-not-exist", dimensions="1x1")


class TestPhotosFromTheSite(IntegrationTestCase):
	"""Снимок стены — то, что словами не передаётся."""

	@staticmethod
	def _photo(fmt: str) -> bytes:
		"""Настоящий снимок, а не шапка файла.

		Frappe открывает картинку, чтобы срезать EXIF, — на подделке с верной
		шапкой падает разборщик, и тест проверял бы не то.
		"""
		import io

		from PIL import Image

		buffer = io.BytesIO()
		Image.new("RGB", (4, 4), (200, 180, 160)).save(buffer, format=fmt)
		return buffer.getvalue()

	@property
	def JPEG(self) -> bytes:
		return self._photo("JPEG")

	@property
	def PNG(self) -> bytes:
		return self._photo("PNG")

	def setUp(self):
		capture = capture_service.record(
			text="Прихожая, замерить",
			understood={"customer_hint": f"Клиент {frappe.generate_hash(length=6)}"},
			assign_to="Administrator",
		)["capture"]
		self.enquiry = enquiry_service.convert(capture=capture)["enquiry"]

	def tearDown(self):
		frappe.set_user("Administrator")

	def test_a_photo_lands_on_the_enquiry(self):
		result = service.attach_photo(
			enquiry=self.enquiry, filename="IMG_0421.jpg", content=self.JPEG
		)

		self.assertEqual(result["status"], "attached")
		attached = frappe.db.get_value(
			"File", result["file"], ["attached_to_doctype", "attached_to_name"]
		)
		self.assertEqual(attached, ("Opportunity", self.enquiry))

	def test_the_photo_is_private(self):
		"""Это фотография чужой квартиры, а не картинка на сайте."""
		result = service.attach_photo(
			enquiry=self.enquiry, filename="стена.png", content=self.PNG
		)
		self.assertEqual(frappe.db.get_value("File", result["file"], "is_private"), 1)

	def test_the_name_on_the_file_decides_nothing(self):
		"""Расширение пишет отправитель. Тип берётся из содержимого."""
		with self.assertRaises(frappe.ValidationError):
			service.attach_photo(
				enquiry=self.enquiry,
				filename="стена.jpg",
				content=b"MZ\x90\x00" + b"\x00" * 64,
			)

	def test_a_jpeg_header_on_something_else_is_still_refused(self):
		"""Шапку JPEG приписать к чему угодно — минута.

		Раньше это доходило до Frappe и падало там пятисоткой: тот открывает
		картинку, чтобы срезать EXIF. Отказ должен быть здесь и словами.
		"""
		with self.assertRaises(frappe.ValidationError):
			service.attach_photo(
				enquiry=self.enquiry,
				filename="стена.jpg",
				content=b"\xff\xd8\xff\xe0" + b"\x00" * 64,
			)

	def test_a_path_in_the_name_does_not_become_a_path(self):
		result = service.attach_photo(
			enquiry=self.enquiry, filename="../../etc/passwd.jpg", content=self.JPEG
		)
		self.assertNotIn("/", result["file_name"])
		self.assertNotIn("..", result["file_name"])
		self.assertTrue(result["file_name"].endswith(".jpg"))

	def test_an_empty_file_is_refused(self):
		with self.assertRaises(frappe.ValidationError):
			service.attach_photo(enquiry=self.enquiry, filename="x.jpg", content=b"")

	def test_a_video_sized_file_is_refused(self):
		oversized = self.JPEG + b"\x00" * service.MAX_PHOTO_BYTES
		with self.assertRaises(frappe.ValidationError):
			service.attach_photo(
				enquiry=self.enquiry, filename="clip.jpg", content=oversized
			)

	def test_photos_are_listed_in_the_order_they_were_taken(self):
		first = service.attach_photo(
			enquiry=self.enquiry, filename="1.jpg", content=self.JPEG
		)["file"]
		second = service.attach_photo(
			enquiry=self.enquiry, filename="2.png", content=self.PNG
		)["file"]

		listed = [row["file"] for row in service.photos(enquiry=self.enquiry)]
		self.assertEqual(listed, [first, second])

	def test_an_enquiry_from_nowhere_takes_no_photos(self):
		with self.assertRaises(frappe.PermissionError):
			service.attach_photo(
				enquiry="OPP-DOES-NOT-EXIST", filename="x.jpg", content=self.JPEG
			)

	def test_the_customers_address_does_not_ride_along_in_the_photo(self):
		"""Телефон пишет координаты съёмки в сам файл, и делает это молча."""
		import io

		from PIL import Image

		buffer = io.BytesIO()
		source = Image.new("RGB", (4, 4), (200, 180, 160))
		exif = source.getexif()
		gps = exif.get_ifd(0x8825)
		gps[1] = "N"  # широта: полушарие
		gps[2] = (51.0, 10.0, 0.0)  # и сами градусы — то есть дом клиента
		exif[0x0110] = "KORKEM Test Phone"  # модель телефона замерщика
		source.save(buffer, format="JPEG", exif=exif)

		result = service.attach_photo(
			enquiry=self.enquiry, filename="стена.jpg", content=buffer.getvalue()
		)

		stored = frappe.get_doc("File", result["file"]).get_content()
		with Image.open(io.BytesIO(stored)) as reloaded:
			self.assertEqual(dict(reloaded.getexif()), {})
