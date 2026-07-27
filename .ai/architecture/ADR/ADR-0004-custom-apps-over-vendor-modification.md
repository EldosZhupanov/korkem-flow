# ADR-0004 — Why Custom Frappe Apps Are Preferred Over Modifying Vendor Repositories

**Status:** Accepted
**Date:** 2026-07-27

## Context

`CLAUDE.md` establishes that `erpnext/`, `frappe/`, `crm/`, and `relaticle/` are independent, vendored git repositories with their own history, tracked separately from this platform's own root repo. `04_system_architecture.md` introduces four new custom Frappe apps (`korkem_manufacturing`, `korkem_workforce`, `korkem_documents`, `korkem_ai`) as the mechanism for adding KORKEM-specific capability.

## Problem Statement

Extending ERPNext/CRM to support Facade Item, Decor, Work Assignment, Payroll, and AI-conversation data requires new doctypes and fields. Doing this by editing `erpnext/`/`crm/` source directly would entangle KORKEM-specific code with upstream code, blocking future upstream updates and violating the repository's own established git boundary.

## Decision

All KORKEM-specific extensions are implemented as new, independent Frappe apps installed alongside `erpnext`/`crm` on the same bench, using Frappe's native extension mechanisms (Custom DocType, Custom Field, `hooks.py`). The vendored repositories are never edited in place.

## Alternatives Considered

1. Fork `erpnext`/`crm` and modify them directly.
2. Use only DB-stored customizations (Custom Field/Custom Script via the Desk UI) with no dedicated app/codebase at all.
3. New custom Frappe apps, version-controlled independently (chosen).

## Pros

- Clean upstream-update path: `erpnext`/`crm` can be updated to new releases without merge conflicts against KORKEM-specific changes.
- Matches Frappe's own idiomatic extension convention exactly — this is how third-party Frappe apps are meant to be built.
- KORKEM-specific code is properly version-controlled, reviewable, and testable as real code, not scattered DB-stored scripts.

## Cons

- Cannot refactor or fix confirmed upstream debt (e.g. ERPNext's large procedural controller files) — must work around it via the extension surface, not repair it directly.
- Requires understanding Frappe's app/hooks system correctly to avoid subtle extension bugs (e.g. custom field naming collisions).

## Trade-offs

Losing the ability to directly patch upstream code is accepted because it's the only path that keeps upstream update compatibility — a direct fork would solve short-term convenience at the cost of long-term maintainability, which `PROJECT.md`'s "optimize for the next ten years" principle explicitly weighs against.

## Rejected Alternatives

- **Forking erpnext/crm**: rejected — loses upstream security/bugfix updates, and directly violates the git-structure rule in `CLAUDE.md` that vendored repos stay pristine clones.
- **DB-only customization (no dedicated app)**: rejected — Custom Scripts stored as DB records are harder to code-review, version, and test than a proper app codebase; acceptable for one-off tweaks, not for KORKEM's substantial new entity set.

## Consequences

- Four new apps must be maintained, versioned, and deployed alongside `erpnext`/`crm` on the bench.
- Any KORKEM-specific doctype that later turns out to belong "upstream" (e.g. a genuinely generic manufacturing concept) requires a deliberate decision to propose it to ERPNext/CRM upstream rather than silently keeping it KORKEM-only forever.

## Implementation Constraints

New doctypes/fields are added only through the four custom apps; `bench` commands (`get-app`, `new-app`, `migrate`) manage their installation — never manual edits inside `erpnext/`/`crm/` directories.

## Future Implications

Multi-vertical expansion (ADR-0001's future implications) is realized by adding further custom apps per vertical, not by branching ERPNext/CRM per vertical.

## Related ADRs

ADR-0001, ADR-0002, ADR-0010 (plugin architecture — this ADR is the Frappe-specific instance of that general principle).

## Review Notes

Directly reused by ADR-0010 as its Frappe-side example; no contradiction between the two — ADR-0010 states the platform-wide principle, this ADR is its concrete Frappe-side application.
