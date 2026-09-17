# Engineering build procedures

Read for Mode B/D, or Mode A changes to domain/workflow boundaries. Apply only
the sections relevant to the requested capability.

## Domain specification before implementation

State: entity; lifecycle states; command; validation; side effects; emitted
events; failure semantics; authorization; idempotency; audit; rollback or
compensation. Resolve ambiguity that changes correctness before coding that part.

Choose explicit enums/schemas/state transitions over scattered flags/raw dicts
where they prevent illegal states. Reuse the existing ORM and application stack.
Stable IDs, ownership/tenant scope where applicable, timestamps, actor/source
and deletion semantics should be explicit. Prefer append-only movements for
money, inventory, payroll and audit; corrections use compensating records.

## AI tools at deterministic boundaries

For each tool specify:

`name, purpose, input_schema, output_schema, risk, role, tenant_scope, handler,
idempotency, approval_contract, audit_fields, timeout, retry_policy`.

User → Agent → Tool registry → Validated command → Domain service → Persistence
/ external action. Do not expose unrestricted ORM/SQL mutation to the model.
Check authorization and tenant boundaries inside the executed handler, including
legacy entrypoints and background jobs, not merely in the prompt or UI.

Risk categories:

- READ: no mutation; still respect access control and sensitive outputs.
- REVERSIBLE_WRITE: bounded operational mutation with a tested reversal path.
- CRITICAL_WRITE: money, contracts, destructive inventory, payroll, release,
  deletion/cancellation, or irreversible external communications.

Use the application's explicit approval policy for critical writes, including
already granted user authorization. Design missing product approval controls
when that is in scope; do not infer permission to execute live critical actions
from a request to implement the controls.

## Observable and recoverable workflows

Record actor, ownership, correlation/request ID, safe input summary, result,
state transition, errors, retries, external call IDs and relevant costs. Redact
credentials and minimize personal data; observability is not permission to log all.

For asynchronous work define job ID, idempotency key, status, attempts, timeout,
backoff, checkpoint, error, dead-letter/replay path and correlation ID. If a DB
commit must trigger an external effect, assess a transactional outbox. Distinguish
persisted intent from delivery and consumer completion.

Prefer at-least-once delivery with idempotent consumers. Do not call this exactly
once end-to-end. Same key/same payload, conflicting payload, concurrent duplicate,
partial failure and replay require explicit semantics. A retry must not silently
repeat a non-idempotent external action.

## Architecture and migration value gate

For a dependency/service/abstraction ask: concrete failure solved; existing-stack
alternative; operational burden; reversal cost; maintainer; expected value.
Reject choices justified only by flexibility or hypothetical scale. Modular
monolith is the default, not an unconditional rule.

For migrations specify DB/data/API changes, compatibility, callers, cutover,
rollback/compensation, tests and old-path retirement. No big-bang rewrite without
a demonstrated blocker and an authorized scope. Do not remove historical research
data as part of cleanup.

## Test selection and deployment

Use pure-rule unit tests, state-transition/domain tests, integration boundaries,
failure/retry tests and access-control tests as relevant. Concurrency-sensitive
code needs a race witness. Prove behavior through observable outcomes, not mocked
implementation details alone. Never use production tenants/payments as fixtures.

Mode D adds repeatable deployment, permissions, monitoring, backup/restore and
rollback verification. Add onboarding/billing only if requested. A recovery plan
without a restoration test must be labeled untested. Do all reversible preparation
before any approval that the actual deployment requires.
