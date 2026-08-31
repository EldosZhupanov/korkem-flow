# ADR-0020 — Why PIN Login Resolves to a Frappe Session, Not a Parallel Identity System

**Status:** Accepted
**Date:** 2026-07-27

## Context

`korkem_flow_spec.md` requires a 4-digit PIN login for shop-floor workers, with demo shortcuts (Admin 0000, Router 1111, Sander 2222, Vacuum 3333). `domain_model.md` introduces `Pin Credential` as "a thin lookup that resolves to a normal Frappe session, it is not a parallel identity system." ADR-0013 establishes Frappe's native RBAC as the platform's sole permission model.

## Problem Statement

A 4-digit PIN is a fundamentally weaker credential than Frappe's normal authentication, and a naive implementation might be tempted to build a separate, lighter-weight session/authorization mechanism for shop-floor logins "since it's just for quick task access" — which would create a second identity/authorization system running alongside Frappe's, each needing independent security review and each capable of drifting out of sync with the other.

## Decision

Pin Credential is a thin mapping (4-digit PIN → Employee → underlying Frappe User) that, on successful PIN entry, establishes a real Frappe session for that User via the normal authentication path. No parallel session, token, or authorization mechanism is built. All of Frappe's native RBAC (ADR-0013) applies identically regardless of whether a user logged in via PIN or a normal username/password flow.

## Alternatives Considered

1. Build a separate, lightweight token/session system specifically for PIN-based shop-floor logins.
2. PIN as a thin front-end that resolves to a standard Frappe session (chosen).

## Pros

- Exactly one authentication/authorization system to secure and audit, regardless of login method.
- Shop-floor workers get identical permission enforcement (ADR-0013) to any other user — no special-cased, potentially weaker authorization path for the group most likely to be handling physical production tasks.
- PIN-specific security properties (short numeric code, workstation-shared devices) are handled as constraints on *when/how* PIN login is offered (e.g. rate-limiting, workstation-bound sessions), not as a reason to weaken the underlying session model.

## Cons

- A 4-digit PIN is inherently lower-entropy than a normal password — this must be mitigated at the login-flow level (lockout after failed attempts, PIN login only available from recognized shop-floor terminals/devices) rather than by the architecture pretending the PIN itself is as strong as a password.

## Trade-offs

The convenience of a fast, low-friction shop-floor login is preserved without weakening the platform's overall security model — the trade-off is pushed into login-flow-level mitigations (rate limiting, device restriction) rather than into a structurally weaker parallel identity system.

## Rejected Alternatives

- **Separate lightweight token/session system for PIN logins**: rejected — creates a second authorization surface to secure, monitor, and keep consistent with Frappe's RBAC, directly undermining ADR-0013's single-permission-model principle for no compensating benefit.

## Consequences

- PIN login flow implementation must include explicit brute-force mitigations (attempt rate limiting, lockout) precisenly because the underlying session it grants is a full, real Frappe session with real permissions.
- Demo/test PIN shortcuts (0000/1111/2222/3333) must be clearly gated to non-production environments — a Phase 12 (Security Architecture) concern to specify precisely.

## Implementation Constraints

Pin Credential lookups must resolve through Frappe's standard session-establishment mechanism; no bespoke JWT/token issuance specific to PIN login is introduced.

## Future Implications

If additional shop-floor-specific authentication methods are added later (e.g. badge/RFID), they should follow this same pattern — thin credential lookup resolving to a standard Frappe session — rather than each inventing its own parallel mechanism.

## Related ADRs

ADR-0013.

## Review Notes

Consistent with `04_system_architecture.md` §22's explicit non-goal ("No parallel authentication system"); this ADR provides the fuller alternatives analysis and names the specific mitigations (rate limiting, device restriction) needed given PIN's lower entropy.
