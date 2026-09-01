# Architecture Decision Records — Index & Collective Validation

Produced per `docs/archive/research/adr_master_prompt.md`. This index lists every ADR and records the collective validation pass required by that prompt: checking the full set for contradictions, duplicated decisions, and missing decisions, and closing gaps found.

No implementation code was written or modified to produce this ADR set, per the master prompt's Stop Condition.

## Index

| ADR | Title | Status |
|---|---|---|
| [0001](./ADR-0001-erpnext-source-of-truth.md) | Why ERPNext Is the Source of Truth for Manufacturing & Materials | Accepted |
| [0002](./ADR-0002-frappe-application-platform.md) | Why Frappe Framework Remains the Application Platform | Accepted |
| [0003](./ADR-0003-ai-orchestrator-isolated-from-business-logic.md) | Why the AI Orchestrator Is Isolated from Business Logic | Accepted |
| [0004](./ADR-0004-custom-apps-over-vendor-modification.md) | Why Custom Frappe Apps Are Preferred Over Modifying Vendor Repositories | Accepted |
| [0005](./ADR-0005-rest-rpc-over-graphql.md) | Why REST/RPC Is Selected and GraphQL Is Rejected | Accepted |
| [0006](./ADR-0006-event-driven-communication.md) | Why Event-Driven Communication Is Required | Accepted |
| [0007](./ADR-0007-business-logic-only-in-domain-layer.md) | Why Business Logic Belongs Only in the Domain Layer | Accepted |
| [0008](./ADR-0008-ai-never-owns-business-data.md) | Why AI Never Owns Business Data | Accepted |
| [0009](./ADR-0009-queues-mandatory-for-long-running-operations.md) | Why Queues Are Mandatory for Long-Running Operations | Accepted |
| [0010](./ADR-0010-plugin-architecture-over-forks.md) | Why Plugin Architecture Is Preferred Over Forks | Accepted |
| [0011](./ADR-0011-integrations-through-gateways.md) | Why All External Integrations Pass Through Gateways | Accepted |
| [0012](./ADR-0012-ai-memory-separated-from-erp-data.md) | Why AI Memory Is Separated from ERP Data | Accepted |
| [0013](./ADR-0013-role-based-least-privilege-permissions.md) | Why Permissions Are Role-Based and Least-Privilege | Accepted |
| [0014](./ADR-0014-every-ai-action-must-be-auditable.md) | Why Every AI Action Must Be Auditable | Accepted |
| [0015](./ADR-0015-human-approval-for-critical-actions.md) | Why Human Approval Is Required for Critical Production Actions | Accepted |
| [0016](./ADR-0016-agents-as-single-process-not-microservices.md) | Why AI Agents Are Logical Roles in One Process, Not Microservices | Accepted |
| [0017](./ADR-0017-single-queue-technology.md) | Why Redis/RQ Is the Only Queue Technology | Accepted |
| [0018](./ADR-0018-multi-tenancy-deferred.md) | Why Multi-Tenancy Is Deferred | Accepted |
| [0019](./ADR-0019-knowledge-memory-new-component.md) | Why Knowledge Memory Is a New Component, Not Reused from Any Source Repo | Accepted |
| [0020](./ADR-0020-pin-login-resolves-to-frappe-session.md) | Why PIN Login Resolves to a Frappe Session, Not a Parallel Identity System | Accepted |
| [0021](./ADR-0021-crm-not-relaticle-source-of-truth-sales.md) | Why Frappe CRM (Not Relaticle) Is the Source of Truth for Sales & Relationship Data | Accepted — added during validation pass |
| [0022](./ADR-0022-workforce-payroll-decoupled-from-erpnext-hr.md) | Why Workforce & Payroll Is a New Custom App, Decoupled from ERPNext HR | Accepted — added during validation pass |
| [0023](./ADR-0023-task-note-frappe-native-polymorphic-pattern.md) | Why Task/Note Reuse Frappe's Native Polymorphic Pattern, Not Relaticle's | Accepted — added during validation pass |
| [0024](./ADR-0024-node-runs-on-wsl2.md) | Узел работает на WSL2, на компьютере, который у клиента уже есть | Принято |
| [0025](./ADR-0025-cloud-relays-never-stores.md) | Облако передаёт, но не хранит | Принято |
| [0026](./ADR-0026-node-to-cloud-tunnel.md) | Исходящий туннель от узла к облаку | Предложено |

26 ADRs total: the 15 required by the master prompt, plus 8 identified as necessary during authoring and validation (0016-0023), and 3 product decisions added later (0024-0026).

## Collective Validation Pass

### Contradictions checked and resolved

- **ADR-0008 ("AI never owns business data") vs. ADR-0012 ("AI memory is separated from ERP data")** — read in isolation these sound opposed. Resolved explicitly in both documents' Review Notes: "separated" (ADR-0012) means schema-level separation (a distinct `korkem_ai` Frappe app) for independent evolution and permission scoping; it does **not** mean a second physical datastore, which is exactly what ADR-0008 forbids. Both ADRs cross-reference each other and state this distinction explicitly, rather than leaving it implicit.
- **ADR-0001/ADR-0004 ("extend ERPNext, reuse before rebuilding") vs. ADR-0022 ("Workforce & Payroll is decoupled from ERPNext HR")** — ADR-0022 is a deliberate, explicitly-justified departure from the general reuse-first principle (HR's presence was never confirmed by evidence, and its scope is heavier than needed), not an unexplained inconsistency. ADR-0022's Review Notes state this explicitly and cross-reference ADR-0001.
- **ADR-0009 ("queues mandatory") vs. ADR-0017 ("single queue technology")** — complementary, not overlapping: 0009 establishes *when* to queue, 0017 establishes *what* technology to queue with. No contradiction.
- **ADR-0016 ("agents as one process") vs. ADR-0010 ("plugin architecture")** — no contradiction: agent *skills* are plugins in the logical sense (system prompt + tool allow-list), which is compatible with all skills running inside one physical process (ADR-0016 scopes the deployment topology; ADR-0010 scopes the extensibility contract).

### Duplicated decisions checked

- ADR-0004 and ADR-0010 both discuss "extension over modification," but at different scopes (ADR-0004 is the Frappe-specific mechanism; ADR-0010 is the platform-wide principle, of which ADR-0004 and ADR-0016 are the two concrete instances). Kept as three separate ADRs rather than merged, since each is independently citable for its own layer (a future reader asking "why don't we fork ERPNext" should find ADR-0004 directly, not have to infer it from a general principle document).
- ADR-0007 ("business logic only in domain layer," general principle) and ADR-0003 ("AI Orchestrator isolated from business logic," specific instance) — same relationship, kept separate for the same reason.

### Missing decisions found and closed

Three architectural decisions were already made informally in `domain_model.md`/`04_system_architecture.md` but had no dedicated ADR — added as ADR-0021, ADR-0022, ADR-0023 (see table above for what each closes). No further gaps were identified against the full content of `domain_model.md` and `04_system_architecture.md` as of this pass.

### Outcome

No unresolved contradictions remain. All decisions in `domain_model.md` and `04_system_architecture.md` that qualify as irreversible/architectural (per the master prompt's definition) now have a corresponding ADR. Two evidence gaps from `domain_model.md` §18 (ERPNext HR presence, generic `Event`/calendar doctype presence) remain open — these are research gaps, not architectural contradictions, and are explicitly out of scope for this ADR set to resolve (they are flagged as follow-up research in ADR-0022 and `domain_model.md` §18 respectively).

---

*Per the Stop Condition in `adr_master_prompt.md`: no implementation code, no repository modifications, no application logic. Stopping here for approval before the next architecture phase.*
