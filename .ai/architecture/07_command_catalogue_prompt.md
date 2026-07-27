# COMMAND CATALOGUE MASTER PROMPT
## AI Furniture Manufacturing Operating System

==========================================================
ROLE
==========================================================

You are acting as the Command Architecture Board.

You are a team consisting of:

• Principal DDD Architect
• ERP Architect
• Manufacturing Systems Architect
• Staff Backend Engineer
• AI Systems Architect

Your responsibility is to discover every command that changes the
state of the system.

This is architecture work.

No implementation.

==========================================================
INPUT
==========================================================

Read completely:

- .ai/architecture/domain_model.md
- .ai/architecture/05_context_map.md
- .ai/architecture/06_event_storming.md
- .ai/architecture/ADR/*
- PROJECT.md

==========================================================
OBJECTIVE
==========================================================

Generate:

.ai/architecture/07_command_catalogue.md

==========================================================
STEP 1

Identify every command.

Examples:

CreateLead

UpdateLead

CreateQuote

ApproveQuote

RejectQuote

ConvertQuoteToOrder

CreateProductionOrder

ScheduleProduction

ReserveMaterial

ReleaseMaterial

StartOperation

FinishOperation

RecordInspection

ApproveInspection

RejectInspection

ShipOrder

CompleteInstallation

ActivateWarranty

==========================================================
STEP 2

For every command define:

Name

Purpose

Actor

AI Permissions

Human Permissions

Aggregate

Validation Rules

Business Rules

Preconditions

Postconditions

Idempotency

Generated Events

Failure Events

Compensating Commands

==========================================================
STEP 3

Map every command to:

Bounded Context

Aggregate

Published Event

Read Models affected

==========================================================
STEP 4

Detect:

Duplicate commands

Missing commands

Unsafe commands

Commands with multiple owners

Commands with unclear validation

==========================================================
STEP 5

Verify:

Every event from Event Storming has at least one originating command.

Every aggregate exposes only valid commands.

Every command has exactly one owner.

==========================================================
QUALITY GATE
==========================================================

This document becomes the canonical command model of the platform.

Future State Machines must follow this document.

==========================================================
STOP CONDITION
==========================================================

Do not implement code.

Do not design APIs.

Generate only:

.ai/architecture/07_command_catalogue.md

Perform a complete self-review.

Wait for approval.
