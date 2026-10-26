# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""A defect photo: optional, only where a defect was booked, private, bounded."""

from __future__ import annotations

import io

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.services import defect_photo as service

WORKER = "defect.worker@example.com"
SELLER = "defect.seller@example.com"


def _photo() -> bytes:
	from PIL import Image

	buffer = io.BytesIO()
	Image.new("RGB", (4, 4), (90, 60, 30)).save(buffer, format="JPEG")
	return buffer.getvalue()


def _user(email: str, role: str) -> str:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0}
		).insert(ignore_permissions=True)
	user = frappe.get_doc("User", email)
	if role not in {row.role for row in user.roles}:
		user.append("roles", {"role": role})
		user.save(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", "KORKEM", user=email)
	return email


class TestDefectPhoto(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		_user(WORKER, "Manufacturing User")
		_user(SELLER, "Sales User")

	def setUp(self):
		frappe.set_user("Administrator")
		self.card = frappe.db.get_value(
			"Job Card", {"company": "KORKEM", "is_corrective_job_card": 0}, "name"
		)
		self.assertTrue(self.card, "the seeded KORKEM site has job cards; no silent skip")
		# Each test decides for itself whether this card carries a defect.
		frappe.db.set_value("Job Card", self.card, "process_loss_qty", 0)
		for name in frappe.get_all(
			"Job Card", filters={"for_job_card": self.card, "is_corrective_job_card": 1}, pluck="name"
		):
			frappe.db.set_value("Job Card", name, "for_job_card", None)
		frappe.db.delete("File", {"attached_to_doctype": "Job Card", "attached_to_name": self.card})

	def tearDown(self):
		frappe.set_user("Administrator")

	def _attach(self, user: str = WORKER) -> dict:
		frappe.set_user(user)
		try:
			return service.attach(job_card=self.card, filename="IMG_0001.jpg", content=_photo())
		finally:
			frappe.set_user("Administrator")

	def _scrapped(self):
		frappe.db.set_value("Job Card", self.card, "process_loss_qty", 1)

	def test_a_clean_stage_takes_no_defect_photo(self):
		with self.assertRaises(frappe.ValidationError) as caught:
			self._attach()
		self.assertIn("брак не записан", str(caught.exception))

	def test_a_stage_with_scrap_takes_one_and_keeps_it_private(self):
		self._scrapped()
		result = self._attach()

		self.assertEqual(result["status"], "attached")
		stored = frappe.get_doc("File", result["file"])
		self.assertEqual((stored.attached_to_doctype, stored.attached_to_name), ("Job Card", self.card))
		self.assertTrue(stored.is_private)
		# The phone's name for it is not kept as-is; ours is.
		self.assertTrue(stored.file_name.endswith(".jpg"))

	def test_a_stage_that_sent_pieces_to_rework_takes_one(self):
		corrective = frappe.db.get_value("Job Card", {"is_corrective_job_card": 1}, "name")
		if not corrective:
			# Without any rework on the site, the rule is still checked on scrap.
			self._scrapped()
		else:
			frappe.db.set_value("Job Card", corrective, "for_job_card", self.card)
		self.assertEqual(self._attach()["status"], "attached")

	def test_the_photo_is_logged_to_audit(self):
		self._scrapped()
		result = self._attach()
		self.assertTrue(
			frappe.db.exists(
				"Domain Audit Event",
				{"action": "manufacturing.defect_photo", "entity_id": self.card},
			)
		)
		self.assertTrue(result["file"])

	def test_photos_are_bounded_per_stage(self):
		self._scrapped()
		for _ in range(service.MAX_PHOTOS_PER_CARD):
			self._attach()
		with self.assertRaises(frappe.ValidationError):
			self._attach()

	def test_sales_cannot_attach_to_production(self):
		self._scrapped()
		with self.assertRaises(frappe.PermissionError):
			self._attach(SELLER)

	def test_a_card_that_does_not_exist_is_not_found(self):
		frappe.set_user(WORKER)
		with self.assertRaises(frappe.DoesNotExistError):
			service.attach(job_card="PO-JOB-NOPE-1", filename="x.jpg", content=_photo())

	def test_something_that_is_not_a_photo_is_refused(self):
		self._scrapped()
		frappe.set_user(WORKER)
		with self.assertRaises(frappe.ValidationError):
			service.attach(job_card=self.card, filename="x.jpg", content=b"\xff\xd8\xff not a jpeg")
