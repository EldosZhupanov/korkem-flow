# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""A film «на глаз» by its colour (owner, 18.11.2026): a photo of a sample
finds the closest decors; a decor finds its look-alikes at other makers; a
white wood and a white solid are told apart by their texture."""

from __future__ import annotations

import base64
import io
import json
import uuid
import zipfile

import frappe
from frappe.tests import IntegrationTestCase
from PIL import Image, ImageDraw

from korkem_manufacturing.services import decor_colors, film_decors, reorder_watch

CUTTER = "colors.cutter@example.com"


def _png(colour, stripes=None, seed=0) -> bytes:
	im = Image.new("RGB", (200, 120), colour)
	# One corner pixel apart: two pictures of one colour are two files, not one
	# deduplicated attachment.
	im.putpixel((0, 0), tuple(uuid.uuid4().bytes[:3]))
	if stripes:
		draw = ImageDraw.Draw(im)
		for x in range(0, 200, 6):
			draw.line([(x + seed, 0), (x + seed, 120)], fill=stripes, width=2)
	buffer = io.BytesIO()
	im.save(buffer, "PNG")
	return buffer.getvalue()


def _pack(rows: list[dict]) -> bytes:
	buffer = io.BytesIO()
	with zipfile.ZipFile(buffer, "w") as z:
		manifest = []
		for r in rows:
			manifest.append({k: v for k, v in r.items() if k != "png"})
			z.writestr(r["image"], r["png"])
		z.writestr("manifest.json", json.dumps(manifest))
	return buffer.getvalue()


class TestDecorColors(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		if not frappe.db.exists("User", CUTTER):
			frappe.get_doc({"doctype": "User", "email": CUTTER, "first_name": "colors", "send_welcome_email": 0,
							"roles": [{"role": "Manufacturing User"}]}).insert(ignore_permissions=True)
		frappe.defaults.set_user_default("Company", "KORKEM", user=CUTTER)

	def setUp(self):
		frappe.set_user("Administrator")
		tag = uuid.uuid4().hex[:4]
		self.a, self.b = f"Цвет Тест А {tag}", f"Цвет Тест Б {tag}"
		rows = [
			# Colours no real catalogue has, so the shop's own decors do not crowd them out.
			{"maker": self.a, "name": "пурпур гладкий", "image": f"wa{tag}.png", "png": _png((255, 0, 255))},
			{"maker": self.a, "name": "пурпурное дерево", "image": f"wwa{tag}.png",
			 "png": _png((250, 10, 250), stripes=(120, 0, 120))},
			{"maker": self.b, "name": "фуксия", "image": f"wb{tag}.png", "png": _png((250, 8, 248))},
			{"maker": self.b, "name": "травяной", "image": f"vb{tag}.png", "png": _png((20, 160, 40))},
		]
		film_decors.import_pack(_pack(rows), source="test")
		self.ids = {
			r.decor_name: r.name
			for r in frappe.get_all(film_decors.DOCTYPE, filters={"maker": ["in", [self.a, self.b]]},
									fields=["name", "decor_name"])
		}

	def test_a_decor_remembers_its_tone_when_its_picture_comes(self):
		solid = frappe.db.get_value(film_decors.DOCTYPE, self.ids["пурпур гладкий"], ["tone_a", "texture"],
									as_dict=True)
		wood = frappe.db.get_value(film_decors.DOCTYPE, self.ids["пурпурное дерево"], ["tone_a", "texture"],
								   as_dict=True)
		self.assertGreater(solid.tone_a, 50)  # strongly red-purple
		self.assertGreater(wood.texture, solid.texture + 2)  # the grain is the difference

	def test_a_photo_of_a_sample_finds_the_closest_solids_not_the_green(self):
		photo = base64.b64encode(_png((252, 4, 252))).decode()
		names = [m["name"] for m in decor_colors.match_photo(photo)["matches"]
				 if m["maker"] in (self.a, self.b)]
		self.assertEqual(set(names[:2]), {"пурпур гладкий", "фуксия"})
		self.assertNotIn("травяной", names[:3])

	def test_a_decors_analogues_are_at_the_other_makers(self):
		got = decor_colors.analogues(decor=self.ids["пурпур гладкий"])["analogues"]
		ours = [m for m in got if m["maker"] in (self.a, self.b)]
		self.assertEqual(ours[0]["name"], "фуксия")
		self.assertEqual(ours[0]["likeness"], "close")
		self.assertNotIn(self.a, [m["maker"] for m in got])

	def test_a_customer_cannot_match_and_staff_can(self):
		photo = base64.b64encode(_png((252, 4, 252))).decode()
		frappe.set_user(CUTTER)
		try:
			self.assertTrue(decor_colors.match_photo(photo)["matches"])
		finally:
			frappe.set_user("Administrator")

	def test_the_morning_list_says_nothing_when_nothing_is_short(self):
		self.assertIsNone(reorder_watch.text({"films": [], "glue": []}, "KORKEM"))
		text = reorder_watch.text({"films": [{"supplier": "Kira", "lines": [{"title": "Графит", "metres": 50}]}],
								   "glue": []}, "KORKEM")
		self.assertIn("Kira: Графит 50 м", text)
		report = reorder_watch.report()
		self.assertIn("films", report)
		self.assertIn("glue", report)
