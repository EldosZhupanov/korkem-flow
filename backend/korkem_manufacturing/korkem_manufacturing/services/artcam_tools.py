# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""ArtCAM's tool database (owner, 19.11.2026: «добавим фрезы из арткама»).

A `.tdb` is ArtCAM's own file: an MFC archive of `tpmDB_*` objects — groups
(«Metric Tools / Wood or Plastic / V-Carving») and tools, each with its name,
diameter, step-down, step-over, spindle, feed and plunge, and a V-bit's
angle. There is no published description of it; this reads what the
archive itself says, record by record, and gives each tool in the shape
`cnc_patterns.save_tool` takes — or why it cannot be one:

- an end mill is a straight cutter, a ball nose a radiused one, a V-bit and
  a conical tool a V-shaped one at its angle;
- a profile tool (ogee, roundover, panel raiser) is not cut by our patterns
  yet;
- speeds are kept in mm/min whatever unit the tool was saved in, and a feed
  the machine cannot run is said, not loaded.
"""

from __future__ import annotations

import re
import struct

#: ArtCAM's rate units, in the order its tool form lists them → mm/min.
RATE = {0: 60.0, 1: 1.0, 2: 1000.0, 3: 25.4 * 60, 4: 25.4, 5: 304.8}

#: ArtCAM's tool classes → ours: "v", "ball", "flat"; None — a profile tool.
KINDS = {
	"tpmDB_SlotDrillTool": "flat",
	"tpmDB_BallnoseTool": "ball",
	"tpmDB_VBitTool": "v",
	"tpmDB_FlatConicalTool": "v",
	"tpmDB_RadiusedConicalTool": "v",
}

MAX_BYTES = 5 * 1024 * 1024

_DECL = re.compile(rb"\xff\xff\x01\x00(..)tpmDB_", re.S)
_TOOL = re.compile(rb"(?=\x05\x01\x00\x00\x00\xff\xfe\xff)")
_STR = b"\xff\xfe\xff"


def _string(d: bytes, i: int) -> tuple[str, int]:
	if d[i:i + 3] != _STR:
		raise ValueError("not a string")
	n = d[i + 3]
	j = i + 4
	if n == 0xFF:
		n = struct.unpack("<H", d[j:j + 2])[0]
		j += 2
	return d[j:j + 2 * n].decode("utf-16le", "replace"), j + 2 * n


def read(content: bytes) -> list[dict]:
	"""Every tool in the file, in its order, with the groups it sits in."""
	d = content
	if len(d) > MAX_BYTES or b"tpmDB_" not in d[:64]:
		raise ValueError("Это не база инструмента ArtCAM (.tdb).")
	decls: list[tuple[int, str]] = []
	decl_end: dict[int, str] = {}
	for m in _DECL.finditer(d):
		n = struct.unpack("<H", m.group(1))[0]
		name = d[m.start() + 6:m.start() + 6 + n].decode("ascii", "replace")
		decls.append((m.start(), name))
		decl_end[m.start() + 6 + n] = name
	tool_at = [m.start() for m in _TOOL.finditer(d)]

	# The archive numbers classes and objects as it writes them; a reference
	# names the class by that number. A group's start and end are objects
	# too. A profile tool's own extra objects can put the count a step
	# behind, so a tool's reference takes the nearest class at or below it.
	def numbered(group_marks: list[tuple[int, str]]) -> list[tuple[int, str]]:
		# A class written with its first object counts both: that object is
		# not counted again.
		first = {p for p, _ in decls} | set(decl_end)
		events = sorted([(p, "class", n) for p, n in decls]
						+ [(p, "obj", None) for p in tool_at if p not in first]
						+ [(p, "obj", None) for p, _ in group_marks if p not in first])
		count, out = 1, []
		for _pos, kind, name in events:
			if kind == "class":
				out.append((count, name))
				count += 2
			else:
				count += 1
		return out

	def refs(name: str, declared: list[tuple[int, str]], tail: bytes) -> list[tuple[int, int]]:
		index = next((at for at, n in declared if n == name), None)
		if index is None:
			return []
		tag = struct.pack("<H", 0x8000 | index) + tail
		return [(m.start(), m.start() + len(tag)) for m in re.finditer(re.escape(tag), d)]

	# The first group's class comes first; its starts and the ends follow.
	opens = [(p, "open") for p, _ in refs("tpmDB_GroupStart", numbered([]), b"\x02")]
	opens += [(p, "open") for p, n in decls if n == "tpmDB_GroupStart"]
	ends_decl = [p for p, n in decls if n == "tpmDB_GroupEnd"]
	before = [m for m in opens if not ends_decl or m[0] < ends_decl[0]]
	closes = [(p, "close") for p, _ in refs("tpmDB_GroupEnd", numbered(before), b"\x01")]
	if ends_decl:
		closes.append((ends_decl[0], "close"))
	declared = numbered(opens + closes)

	def class_of(index: int) -> str | None:
		best = None
		for at, name in declared:
			if at <= index and index - at <= 4:
				best = name
		return best

	marks = sorted(opens + closes + [(p, "tool") for p in tool_at])
	path: list[str] = []
	tools: list[dict] = []
	for pos, kind in marks:
		try:
			if kind == "open":
				at = d.find(_STR, pos, pos + 64)
				name, _ = _string(d, at)
				path.append(name)
			elif kind == "close":
				if path:
					path.pop()
			else:
				cls = decl_end.get(pos) or class_of(struct.unpack("<H", d[pos - 2:pos])[0] & 0x7FFF)
				tools.append(_tool(d, pos, cls, path))
		except (ValueError, struct.error):
			continue
	return tools


def _tool(d: bytes, pos: int, cls: str | None, path: list[str]) -> dict:
	name, j = _string(d, pos + 5)
	j += 4
	diameter, stepdown = struct.unpack("<dd", d[j:j + 16])
	_desc, j = _string(d, j + 16)
	stepover, rpm, feed, plunge = struct.unpack("<dddd", d[j:j + 32])
	units = struct.unpack("<i", d[j + 32:j + 36])[0]
	kind = KINDS.get(cls or "")
	# An inch database keeps its sizes in inches.
	inch = units in (3, 4, 5) or (path[:1] and "inch" in path[0].lower())
	if inch:
		diameter, stepdown = diameter * 25.4, stepdown * 25.4
	angle = struct.unpack("<d", d[j + 114:j + 122])[0] if kind == "v" else None
	return {
		"group": " / ".join(path),
		"name": " ".join(name.split()),
		"artcam_type": (cls or "")[6:] or None,
		"kind": kind,
		"diameter": round(diameter, 3),
		"angle": round(angle, 2) if angle else None,
		"pass_depth": round(stepdown, 3),
		"rpm": round(rpm),
		"feed_raw": feed,
		"plunge_raw": plunge,
		"units": units,
		"feed": round(feed * RATE.get(units, 60.0)),
		"plunge": round(plunge * RATE.get(units, 60.0)),
		"inch": bool(inch),
	}
