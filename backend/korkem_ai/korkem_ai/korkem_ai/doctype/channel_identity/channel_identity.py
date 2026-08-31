# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Who a Telegram or WhatsApp sender actually is.

## Why this exists

Every one of the assistant's tools decides what it may show from
`frappe.session.user` — `scope.current_company()` reads it, and so does every
permission check underneath. A webhook has no session: it arrives as **Guest**,
which resolves to no company and no rights at all.

So an inbound message cannot reach the assistant until it has been turned into a
*person*. This row is that mapping, and it is deliberately the only one: link a
channel identity to a `User` and the whole existing permission model applies
unchanged — same company scoping, same roles, same audit owner.

## Matched exactly, never guessed

A Telegram numeric id or a phone number in international format, compared
literally. Matching a sender by display name would let anyone who can set their
own name in a chat app choose whose data they see, which is not a bug worth
having once.

An unrecognised sender is not an error and is not silently trusted — the row is
created unlinked so an administrator can see who is writing in and decide.
"""

from __future__ import annotations

import frappe
from frappe.model.document import Document
from frappe.utils import now_datetime


class ChannelIdentity(Document):
	def validate(self):
		self.external_id = (self.external_id or "").strip()
		if not self.external_id:
			frappe.throw("A channel identity needs the channel's own identifier.")

		clash = frappe.db.get_value(
			"Channel Identity",
			{"channel": self.channel, "external_id": self.external_id, "name": ["!=", self.name]},
			"name",
		)
		if clash:
			frappe.throw(
				f"{self.channel} identity {self.external_id} is already recorded as {clash}."
			)

	def touch(self):
		"""Record that this identity was heard from, without a full save."""
		self.db_set("last_seen_on", now_datetime(), update_modified=False)


def find(channel: str, external_id: str) -> ChannelIdentity | None:
	"""The identity for this sender, or None if nobody has linked them."""
	name = frappe.db.get_value(
		"Channel Identity",
		{"channel": channel, "external_id": (external_id or "").strip()},
		"name",
	)
	return frappe.get_doc("Channel Identity", name) if name else None


def observe(channel: str, external_id: str, display_name: str | None = None) -> ChannelIdentity:
	"""Find this sender, or record that they exist without granting anything.

	An unknown number writing in is a fact worth keeping — an administrator has
	to be able to see it to link it — but the row starts with no user, and a row
	with no user speaks for nobody.
	"""
	existing = find(channel, external_id)
	if existing:
		if display_name and not existing.display_name:
			existing.db_set("display_name", display_name, update_modified=False)
		existing.touch()
		return existing

	doc = frappe.get_doc(
		{
			"doctype": "Channel Identity",
			"channel": channel,
			"external_id": (external_id or "").strip(),
			"display_name": display_name,
			"enabled": 1,
		}
	)
	doc.insert(ignore_permissions=True)
	doc.touch()
	return doc


def speaker_for(identity: ChannelIdentity | None) -> str | None:
	"""The KORKEM user this identity may act as, or None.

	`None` is the answer for an unknown sender and for one an administrator has
	disabled. The caller must treat it as "do not run anything" rather than as
	"run as somebody harmless" — there is no harmless default here.
	"""
	if not identity or not identity.enabled or not identity.user:
		return None
	if not frappe.db.get_value("User", identity.user, "enabled"):
		return None
	return identity.user
