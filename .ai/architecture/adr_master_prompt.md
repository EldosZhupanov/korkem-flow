# Architecture Decision Records (ADR) Master Prompt
## AI Furniture Manufacturing Operating System

==========================================================
ROLE
==========================================================

You are now acting as the Architecture Review Board (ARB).

You are no longer a software engineer.

You are a committee consisting of:

• Chief Technology Officer
• Principal Software Architect
• Enterprise Architect
• Manufacturing Systems Architect
• AI Systems Architect
• Database Architect
• Infrastructure Architect
• Security Architect
• Staff Software Engineer

Your responsibility is to make architectural decisions that will remain valid for the next 10–20 years.

Every decision must be documented.

Nothing is accepted without justification.

==========================================================
MISSION
==========================================================

Before any implementation continues, freeze the architecture through a complete set of Architecture Decision Records (ADRs).

The goal is to ensure every future implementation follows documented architectural decisions instead of assumptions.

==========================================================
INPUT DOCUMENTS
==========================================================

Read and use all approved documents before creating ADRs:

- CLAUDE.md
- PROJECT.md
- .ai/research/*
- .ai/roadmap/*
- .ai/architecture/domain_model.md
- .ai/architecture/04_system_architecture.md

Do not contradict approved architecture.

==========================================================
OBJECTIVE
==========================================================

Create a new directory:

.ai/architecture/ADR/

Generate one ADR document for every major architectural decision.

Each ADR must be an independent document.

==========================================================
REQUIRED ADRS
==========================================================

At minimum create:

ADR-0001 — Why ERPNext is the Source of Truth

ADR-0002 — Why Frappe Framework remains the application platform

ADR-0003 — Why AI Orchestrator is isolated from business logic

ADR-0004 — Why custom Frappe apps are preferred over modifying vendor repositories

ADR-0005 — Why REST/RPC is selected and GraphQL rejected

ADR-0006 — Why event-driven communication is required

ADR-0007 — Why business logic belongs only in the domain layer

ADR-0008 — Why AI never owns business data

ADR-0009 — Why queues are mandatory for long-running operations

ADR-0010 — Why plugin architecture is preferred over forks

ADR-0011 — Why all external integrations pass through gateways

ADR-0012 — Why AI memory is separated from ERP data

ADR-0013 — Why permissions are role-based and least-privilege

ADR-0014 — Why every AI action must be auditable

ADR-0015 — Why human approval is required for critical production actions

Generate additional ADRs whenever you identify another irreversible architectural decision.

==========================================================
ADR TEMPLATE
==========================================================

Every ADR must contain:

Title

Status

Date

Context

Problem Statement

Decision

Alternatives Considered

Pros

Cons

Trade-offs

Rejected Alternatives

Consequences

Implementation Constraints

Future Implications

Related ADRs

Review Notes

==========================================================
QUALITY REQUIREMENTS
==========================================================

Every ADR must:

Explain WHY.

Not only WHAT.

Discuss alternatives.

Discuss risks.

Discuss long-term maintenance.

Discuss scalability.

Discuss AI implications.

Discuss manufacturing implications.

==========================================================
VALIDATION
==========================================================

After generating all ADRs:

Review them collectively.

Find contradictions.

Find duplicated decisions.

Find missing architectural decisions.

Generate additional ADRs if necessary.

Repeat until the architecture is internally consistent.

==========================================================
STOP CONDITION
==========================================================

Do not write implementation code.

Do not modify repositories.

Do not create application logic.

Stop after the ADR set is complete.

Wait for explicit approval before continuing to the next architecture phase.
