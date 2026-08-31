# ADR-0013 — Why Permissions Are Role-Based and Least-Privilege

**Status:** Accepted
**Date:** 2026-07-27

## Context

`report_erpnext.md` confirms Frappe's native RBAC model: role + per-doctype permission (read/write/create/delete/submit/cancel/…) + an optional `permlevel` field-level tier, enforced both declaratively (doctype JSON) and programmatically (`frappe.has_permission()`). `domain_model.md` §14 maps this onto a permissions table for every human role (Admin, Sales/CRM, Production Manager, Workshop Operator, Warehouse Manager, Accountant/Payroll) and states explicitly: "AI Agent — never direct write, may only create Pending Actions."

## Problem Statement

A system spanning sales, manufacturing, warehouse, payroll, and AI automation has many actors with very different legitimate access needs — a Workshop Operator should never see payroll figures; an AI agent should never have more authority than the human role it's assisting. Without an explicit least-privilege rule, the path of least resistance during implementation is to grant broad access "to unblock a feature," eroding the permission boundary over time.

## Decision

The platform reuses Frappe's native role-based permission model exactly as-is (no custom permission engine). Every human role's access is scoped to only what `domain_model.md` §14 specifies. Every AI agent's tool/Command allow-list is bounded by the equivalent human role's permissions — an agent can never propose an action a human in its equivalent role could not perform.

## Alternatives Considered

1. Build a custom, more flexible permission/authorization system tailored to this platform's exact needs.
2. Reuse Frappe's native RBAC as-is for both humans and AI agents (chosen).
3. Reuse Frappe's native RBAC for humans, but give AI agents a separate, broader "service account" permission model for efficiency.

## Pros

- Confirmed generic, stable, already battle-tested permission model — no new authorization logic to build or secure.
- A single mental model ("role + doctype permission") applies uniformly to humans and AI agents, simplifying reasoning about "what can this actor do."
- Field-level `permlevel` support (confirmed in `report_erpnext.md`) already covers the need to hide sensitive fields (e.g. financials) from certain roles without a bespoke mechanism.

## Cons

- Frappe's permission model, while generic, has its own learning curve and occasional rigidity (e.g. `permlevel` requires careful field tagging).
- Mapping every new custom-app doctype's permissions correctly requires ongoing discipline as new entities are added.

## Trade-offs

Accepting Frappe's existing permission model's rigidity in some edge cases is preferred over the risk and maintenance burden of a bespoke authorization system that must be independently secured and kept correct.

## Rejected Alternatives

- **Custom permission/authorization system**: rejected — duplicates a mature, already-proven mechanism for no evidenced gap in capability.
- **Separate, broader AI "service account" permissions**: rejected — directly undermines the least-privilege principle and `domain_model.md`'s explicit rule that AI agents match their human-role equivalent's authority exactly, no more.

## Consequences

- Every new agent skill (ADR-0016) must have its tool/Command allow-list explicitly derived from an existing human role's permissions — never granted ad hoc.
- New custom-app doctypes must define their permissions table deliberately at creation time, not left to Frappe's defaults.

## Implementation Constraints

No agent skill or service is granted a Frappe role broader than the minimum needed for its documented responsibilities.

## Future Implications

As new verticals/roles are added (per the plugin architecture, ADR-0010), each new role's permissions must be explicitly scoped and reviewed, not copy-pasted from an existing broad role for convenience.

## Related ADRs

ADR-0002 (Frappe platform, source of this permission model), ADR-0003, ADR-0015 (human approval).

## Review Notes

Directly consistent with `domain_model.md` §14; no new claims beyond formalizing why that table's structure was chosen.
