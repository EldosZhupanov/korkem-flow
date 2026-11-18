# Copyright (c) 2026, KORKEM and contributors
# See license.txt
"""ArtCAM's tool database into «Фрезы» (owner, 19.11.2026: «добавим фрезы
из арткама»). A small database is written here the way ArtCAM writes one —
groups, an end mill, a ball nose with a feed no machine runs, a V-bit, a
profile tool — and read back."""

from __future__ import annotations

import base64
import struct

import frappe
from frappe.tests import IntegrationTestCase

from korkem_manufacturing.services import artcam_tools, cnc_patterns

COMPANY = "KORKEM"
STRANGER = "artcam.stranger@example.com"


def _s(text: str) -> bytes:
	n = len(text)
	return b"\xff\xfe\xff" + (bytes([n]) if n < 255 else b"\xff" + struct.pack("<H", n)) + text.encode("utf-16le")


def _tdb(entries) -> bytes:
	"""An ArtCAM archive: ("open", name), ("close",) or ("tool", class, name,
	diameter, step-down, step-over, rpm, feed, plunge, rate units, angle)."""
	out, classes, count = bytearray(), {}, 1
	for e in entries:
		cls = {"open": "tpmDB_GroupStart", "close": "tpmDB_GroupEnd"}.get(e[0]) or e[1]
		if cls in classes:
			out += struct.pack("<H", 0x8000 | classes[cls])
			count += 1
		else:
			out += b"\xff\xff\x01\x00" + struct.pack("<H", len(cls)) + cls.encode()
			classes[cls] = count
			count += 2
		if e[0] == "open":
			out += b"\x02" + _s(e[1]) + _s("about") + b"\x00\x00\x00\x00"
		elif e[0] == "close":
			out += b"\x01"
		else:
			_, _, name, d, down, over, rpm, feed, plunge, units, angle = e
			out += (b"\x05" + struct.pack("<I", 1) + _s(name) + struct.pack("<I", 1) + struct.pack("<dd", d, down)
					+ _s("desc") + struct.pack("<dddd", over, rpm, feed, plunge) + struct.pack("<ii", units, 3))
			rest = bytearray(92)
			if angle:
				rest[74:82] = struct.pack("<d", angle)
			out += rest
	return bytes(out)


FILE = _tdb([
	("open", "Metric Tools"), ("open", "Wood or Plastic"),
	("tool", "tpmDB_SlotDrillTool", "End Mill 6 Один заход", 6, 17, 2.4, 15000, 76, 50, 0, None),
	("tool", "tpmDB_BallnoseTool", "Ball Nose 6 mm Жалюзи", 6, 16, 1, 18000, 10000, 3000, 0, None),
	("tool", "tpmDB_VBitTool", "V-Bit 32 mm 90 degree", 32, 12, 8, 15000, 42, 12, 0, 90),
	("close",), ("open", "Profiles"),
	("tool", "tpmDB_OgeeTool", "Ogee 6 mm", 32, 3, 3, 15000, 25, 12, 0, None),
	("close",), ("close",),
])


class TestArtcamTools(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		frappe.set_user("Administrator")
		if not frappe.db.exists("User", STRANGER):
			frappe.get_doc({"doctype": "User", "email": STRANGER, "first_name": "artcam", "send_welcome_email": 0,
							"roles": [{"role": "Sales User"}]}).insert(ignore_permissions=True)
		frappe.defaults.set_user_default("Company", COMPANY, user=STRANGER)
		cls.key = f"{cnc_patterns._KEY}:{COMPANY}"
		cls.before = frappe.db.get_default(cls.key)

	@classmethod
	def tearDownClass(cls):
		frappe.set_user("Administrator")
		frappe.db.set_default(cls.key, cls.before or "")
		super().tearDownClass()

	def setUp(self):
		frappe.set_user("Administrator")
		frappe.db.set_default(self.key, "")

	def test_the_file_is_read_group_by_group_in_our_units(self):
		tools = {t["name"]: t for t in artcam_tools.read(FILE)}
		mill = tools["End Mill 6 Один заход"]
		self.assertEqual((mill["group"], mill["kind"], mill["feed"], mill["plunge"]),
						 ("Metric Tools / Wood or Plastic", "flat", 4560, 3000))  # mm/s → mm/min
		self.assertEqual((tools["V-Bit 32 mm 90 degree"]["kind"], tools["V-Bit 32 mm 90 degree"]["angle"]), ("v", 90))
		self.assertEqual(tools["Ogee 6 mm"]["group"], "Metric Tools / Profiles")
		self.assertIsNone(tools["Ogee 6 mm"]["kind"])
		with self.assertRaises(ValueError):
			artcam_tools.read(b"not a database")

	def test_a_preview_says_what_cannot_be_and_the_picked_are_added_once(self):
		b64 = base64.b64encode(FILE).decode()
		rows = {r["name"]: r for r in cnc_patterns.artcam_preview(b64)["tools"]}
		self.assertTrue(rows["End Mill 6 Один заход"]["card"])
		self.assertIn("подача", rows["Ball Nose 6 mm Жалюзи"]["why"])  # 600 000 mm/min: no machine
		self.assertIn("фасонная", rows["Ogee 6 mm"]["why"])
		picked = [rows[n]["index"] for n in ("End Mill 6 Один заход", "Ball Nose 6 mm Жалюзи", "V-Bit 32 mm 90 degree")]
		added = cnc_patterns.artcam_add(b64, picked)["added"]
		self.assertEqual(added, ["End Mill 6 Один заход", "V-Bit 32 mm 90 degree"])
		tools = cnc_patterns._settings(COMPANY)["tools"]
		self.assertEqual((tools["V-Bit 32 mm 90 degree"]["angle"], tools["V-Bit 32 mm 90 degree"]["feed"]), (90, 2520))
		again = {r["name"]: r for r in cnc_patterns.artcam_preview(b64)["tools"]}
		self.assertIn("уже есть", again["End Mill 6 Один заход"]["why"])
		self.assertEqual(cnc_patterns.artcam_add(b64, picked)["added"], [])

	def test_only_the_owner_loads_tools(self):
		frappe.set_user(STRANGER)
		try:
			with self.assertRaises(frappe.PermissionError):
				cnc_patterns.artcam_preview(base64.b64encode(FILE).decode())
		finally:
			frappe.set_user("Administrator")
