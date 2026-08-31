> **АРХИВ. Это не описание системы сегодня.**
> Документ сохранён ради причин, стоящих за решениями. Актуальное состояние — в `NOW.md`, `ROADMAP.md`, `PLAN.md`.
> Не строить по этому файлу.

---

# EVENT STORMING MASTER PROMPT
## AI Furniture Manufacturing Operating System

==========================================================
ROLE
==========================================================

You are an Event Storming facilitation team composed of:

- Domain-Driven Design Expert
- Manufacturing Systems Architect
- ERP Architect
- Principal Software Architect
- AI Systems Architect
- Product Architect

Your responsibility is to discover every business event that can
occur inside the KORKEM platform.

No implementation.

No code.

Architecture only.

==========================================================
INPUT
==========================================================

Read completely:

- .ai/architecture/domain_model.md
- .ai/architecture/04_system_architecture.md
- .ai/architecture/05_context_map.md
- .ai/architecture/ADR/*
- .ai/roadmap/korkem_flow_spec.md

==========================================================
OBJECTIVE
==========================================================

Generate:

.ai/architecture/06_event_storming.md

==========================================================
STEP 1

Identify every Domain Event.

Examples:

LeadCreated

QuoteApproved

ProductionOrderCreated

MaterialReserved

ProductionStarted

OperationCompleted

InventoryAdjusted

QualityInspectionPassed

DeliveryScheduled

InstallationCompleted

WarrantyActivated

==========================================================
STEP 2

For every event define:

- Description
- Trigger
- Publisher
- Consumers
- Preconditions
- Postconditions
- Related aggregate
- Related bounded context

==========================================================
STEP 3

For every event identify:

Commands that produce it.

Queries affected by it.

Read models updated by it.

==========================================================
STEP 4

Detect:

Missing events

Duplicated events

Implicit events

Long-running workflows

Compensating events

Failure events

==========================================================
STEP 5

Group events into complete business workflows.

==========================================================
QUALITY GATE
==========================================================

Every business workflow must be representable as a sequence of events.

No event may have multiple owners.

No aggregate may publish contradictory events.

==========================================================
STOP CONDITION
==========================================================

Do not design modules.

Do not design APIs.

Do not implement code.

Generate only:

.ai/architecture/06_event_storming.md

Perform a self-review.

Stop and wait for approval.
