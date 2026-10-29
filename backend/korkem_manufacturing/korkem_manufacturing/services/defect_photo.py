# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""A photo of a defect, attached to the stage where it happened — if wanted.

Optional by design. A worker who scraps a panel is not stopped and asked for a
picture; most defects are obvious and a mandatory photo is a photo of the
floor. When there *is* something worth showing — a chip in the veneer, a
bubble under the film — it goes on the job card where the defect was booked,
so the person deciding on rework, or the one arguing with the supplier about a
sheet, sees it where they already look.

**Only where a defect was recorded.** A card counts as one if it booked
scrap (`process_loss_qty`), is a rework card itself, or has pieces sent to
rework from it. Anything else is refused: a "defect photo" on a clean stage is
either a mistake or a way to put arbitrary files on production records.

The file itself goes through `photo_files`: JPEG or PNG only, EXIF stripped
(a phone writes the workshop's coordinates into every shot), stored private.
"""

from __future__ import annotations

import frappe
from frappe.utils import flt

from korkem_manufacturing.services import audit, photo_files
from korkem_manufacturing.services.scope import ensure_company

#: Roles that book production. The same set that may report a stage finished;
#: a photo of a defect is part of that report.
MAY_ATTACH = ("Manufacturing Manager", "Manufacturing User", "System Manager")

#: Enough to show a defect from every side. A card with more than this is no
#: longer a report, it is a gallery somebody should look at differently.
MAX_PHOTOS_PER_CARD = 5


def attach(*, job_card: str, filename: str, content: bytes) -> dict:
	"""Attach one defect photo to `job_card`."""
	ensure_company("Job Card", job_card)
	if not set(MAY_ATTACH).intersection(frappe.get_roles()):
		frappe.throw(
			"Фото брака прикладывает тот, кто отчитывается по этапу.",
			frappe.PermissionError,
		)

	card = frappe.db.get_value(
		"Job Card",
		job_card,
		["name", "operation", "work_order", "process_loss_qty", "is_corrective_job_card"],
		as_dict=True,
	)
	if not _has_defect(card):
		frappe.throw(
			f"На этапе «{card.operation}» брак не записан. Сначала отметьте брак "
			"или отправку на исправление, затем приложите фото."
		)

	already = frappe.db.count(
		"File", {"attached_to_doctype": "Job Card", "attached_to_name": card.name}
	)
	if already >= MAX_PHOTOS_PER_CARD:
		frappe.throw(f"К этому этапу уже приложено {already} фото — этого достаточно.")

	file_name, content = photo_files.cleaned(filename, content, fallback_name="брак")
	doc = frappe.get_doc(
		{
			"doctype": "File",
			"file_name": file_name,
			"attached_to_doctype": "Job Card",
			"attached_to_name": card.name,
			"is_private": 1,
			"content": content,
		}
	)
	# The worker may not write the Job Card, and a File attached to a document
	# checks write on it. Who may attach was decided above, by role, company
	# and the defect rule — not by whether ERPNext lets them edit the card.
	doc.insert(ignore_permissions=True)

	audit.record_audit(
		action="manufacturing.defect_photo",
		entity_type="Job Card",
		entity_id=card.name,
		diff={"file": doc.name, "work_order": card.work_order, "operation": card.operation},
	)
	return {
		"job_card": card.name,
		"file": doc.name,
		"file_name": doc.file_name,
		"size": len(content),
		"status": "attached",
	}


def _has_defect(card) -> bool:
	if not card:
		return False
	if flt(card.process_loss_qty) > 0 or card.is_corrective_job_card:
		return True
	# Pieces sent to rework from this card: ERPNext's own link points back here.
	return bool(
		frappe.db.exists("Job Card", {"for_job_card": card.name, "is_corrective_job_card": 1})
	)
