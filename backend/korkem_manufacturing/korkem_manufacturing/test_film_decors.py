"""Makers' decor catalogues with pictures (owner, 18.11.2026).

A pack in, twice, changes nothing the second time; a film shows its decor's
picture until it has a photo of its own; a decor becomes a film with its
collection, code and colour.
"""

from __future__ import annotations

import base64
import io
import json
import uuid
import zipfile

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.services import film_catalog, film_decors, material_stock

COMPANY = "KORKEM"
CUTTER = "decor.cutter@example.com"
# A 1×1 PNG: enough for a picture to be a picture.
PNG = base64.b64decode(
	"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
)


def _user(email: str, role: str) -> None:
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0,
			 "roles": [{"role": role}]}
		).insert(ignore_permissions=True)
	frappe.defaults.set_user_default("Company", COMPANY, user=email)


def _pack(maker: str, rows: list[dict]) -> bytes:
	buf = io.BytesIO()
	with zipfile.ZipFile(buf, "w") as z:
		z.writestr("pack/manifest.json", json.dumps([{"maker": maker, **r} for r in rows], ensure_ascii=False))
		for r in rows:
			if r.get("image"):
				# Each its own bytes: the File store keeps one copy of equal ones.
				z.writestr(f"pack/clean/{r['image']}", PNG + f"{maker}{r['image']}".encode())
	return buf.getvalue()


class TestFilmDecors(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		_user(CUTTER, "Manufacturing User")

	def setUp(self):
		frappe.set_user("Administrator")
		self.maker = f"Декор Тест {uuid.uuid4().hex[:4]}"
		self.rows = [
			{"collection": "Матовая", "name": "сиена верде", "image": "003-1.jpg", "hex": "#9DAB98"},
			{"collection": "Матовая", "name": "сиена лен", "image": "003-2.jpg"},
			{"collection": "Древесные", "name": "дуб шведский", "image": "051-1.jpg", "code": "MC 51-1"},
		]
		for kind, value in (("Ширина плёнки", "1400"), ("Толщина плёнки", "0,3")):
			material_stock.add_option(kind, value)

	def _as(self, user, fn, *args, **kwargs):
		frappe.set_user(user)
		try:
			return fn(*args, **kwargs)
		finally:
			frappe.set_user("Administrator")

	def test_a_pack_comes_in_once_and_its_maker_with_it(self):
		got = film_decors.import_pack(_pack(self.maker, self.rows), source="test")
		self.assertEqual((got["added"], got["updated"], got["pictures"]), (3, 0, 3))
		self.assertIn(self.maker, material_stock.enabled_values(film_catalog.MAKERS, COMPANY))
		again = film_decors.import_pack(_pack(self.maker, self.rows))
		self.assertEqual((again["added"], again["updated"]), (0, 3))
		mine = [d for d in film_decors.decors(self.maker)["decors"]]
		self.assertEqual(len(mine), 3)
		self.assertTrue(all(d["image"] and d["image"].startswith("/files/") for d in mine))
		self.assertEqual({d["collection"] for d in mine}, {"Матовая", "Древесные"})
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, film_decors.import_pack, _pack(self.maker, self.rows))
		for bad in (b"not a zip", _pack(self.maker, [])):
			with self.assertRaises(frappe.ValidationError):
				film_decors.import_pack(bad)

	def test_a_film_shows_its_decor_until_it_has_its_own_photo(self):
		film_decors.import_pack(_pack(self.maker, self.rows))
		decor = next(d for d in film_decors.decors(self.maker)["decors"] if d["name"] == "сиена верде")
		# The shop's film, typed with a space too many, is the same decor.
		item = film_catalog.add(self.maker, "сиена  верде", thickness="0,3")["item"]
		self.assertEqual(film_catalog.film(item)["image"], decor["image"])
		self.assertFalse(film_catalog.film(item)["image_own"])
		listed = next(f for f in film_catalog.catalog()["films"] if f["item"] == item)
		self.assertEqual(listed["image"], decor["image"])
		linked = next(d for d in film_decors.decors(self.maker)["decors"] if d["name"] == "сиена верде")
		self.assertEqual([f["item"] for f in linked["films"]], [item])
		# Its own photo, on every thickness of it.
		other = film_catalog.add(self.maker, "сиена верде", thickness="0,45")["item"]
		own = film_decors.set_film_image(item, "sample.png", base64.b64encode(PNG + b"own photo").decode())
		self.assertTrue(own["image_own"])
		self.assertNotEqual(own["image"], decor["image"])
		self.assertEqual(film_catalog.film(other)["image"], own["image"])
		with self.assertRaises(frappe.PermissionError):
			self._as(CUTTER, film_decors.set_film_image, item, "x.png", base64.b64encode(PNG).decode())
		with self.assertRaises(frappe.ValidationError):
			film_decors.set_film_image(item, "x.pdf", base64.b64encode(PNG).decode())
		back = film_decors.clear_film_image(item)
		self.assertEqual((back["image"], back["image_own"]), (decor["image"], False))

	def test_a_decor_becomes_a_film_with_its_collection_code_and_colour(self):
		film_decors.import_pack(_pack(self.maker, self.rows))
		oak = next(d for d in film_decors.decors(self.maker)["decors"] if d["name"] == "дуб шведский")
		made = film_decors.from_decor(oak["decor"], thickness="0,3", width="1400")
		self.assertEqual((made["maker"], made["colour"], made["collection"], made["code"]),
						 (self.maker, "дуб шведский", "Древесные", "MC 51-1"))
		self.assertEqual(made["image"], oak["image"])
		self.assertIn("Древесные", film_catalog.collections(COMPANY)[self.maker])
		verde = next(d for d in film_decors.decors(self.maker)["decors"] if d["name"] == "сиена верде")
		self.assertEqual(film_decors.from_decor(verde["decor"])["hex"], "#9DAB98")
		# A maker's catalogue off: the films stay.
		self.assertEqual(film_decors.delete_maker(self.maker)["deleted"], 3)
		self.assertEqual(film_decors.decors(self.maker)["decors"], [])
		self.assertEqual(film_catalog.film(made["item"])["colour"], "дуб шведский")
