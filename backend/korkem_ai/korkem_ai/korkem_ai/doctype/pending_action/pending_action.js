// Copyright (c) 2026, KORKEM and contributors
// For license information, please see license.txt

// Approve/reject UI for AI-proposed actions (ADR-0015: every agent write is
// gated on a human). Deliberately minimal Desk UI for Sprint 1 -- the dark-UI
// approval surface is a later phase; this is real, usable functionality now.

frappe.ui.form.on("Pending Action", {
	refresh(frm) {
		if (frm.doc.status !== "Pending") {
			frm.set_intro(
				__("This proposal was {0}.", [frm.doc.status.toLowerCase()]),
				frm.doc.status === "Approved" ? "green" : "red"
			);
			return;
		}

		render_proposal(frm);

		frm.add_custom_button(__("Approve"), () => confirm_approve(frm)).addClass(
			"btn-primary"
		);
		frm.add_custom_button(__("Reject"), () => prompt_reject(frm));
	},
});

// Show the human-readable diff the agent built, so the approver sees what will
// change without reading raw JSON.
function render_proposal(frm) {
	const display = parse_json(frm.doc.display_data);
	if (!display) return;

	const rows = (display.changes || [])
		.map(
			(c) =>
				`<tr><td class="text-muted" style="padding-right:1rem">${frappe.utils.escape_html(
					String(c.field ?? "")
				)}</td><td><b>${frappe.utils.escape_html(String(c.new ?? ""))}</b></td></tr>`
		)
		.join("");

	frm.set_intro(
		`<div><b>${frappe.utils.escape_html(display.summary || __("Proposed action"))}</b>` +
			(rows ? `<table style="margin-top:.5rem">${rows}</table>` : "") +
			`</div>`,
		"blue"
	);
}

function confirm_approve(frm) {
	frappe.confirm(
		__("Approve this action? It will be executed immediately."),
		() => run(frm, "approve", {}, __("Approved"))
	);
}

function prompt_reject(frm) {
	frappe.prompt(
		[{ fieldname: "reason", fieldtype: "Small Text", label: __("Reason (optional)") }],
		({ reason }) => run(frm, "reject", { reason }, __("Rejected")),
		__("Reject proposal"),
		__("Reject")
	);
}

function run(frm, method, args, success_message) {
	frappe.dom.freeze(__("Working..."));
	frm.call(method, args)
		.then(() => {
			frappe.show_alert({ message: success_message, indicator: "green" });
			frm.reload_doc();
		})
		.finally(() => frappe.dom.unfreeze());
}

function parse_json(value) {
	if (!value) return null;
	if (typeof value === "object") return value;
	try {
		return JSON.parse(value);
	} catch (e) {
		return null;
	}
}
