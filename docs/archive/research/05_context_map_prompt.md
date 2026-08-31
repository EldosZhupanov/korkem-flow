> **АРХИВ. Это не описание системы сегодня.**
> Документ сохранён ради причин, стоящих за решениями. Актуальное состояние — в `NOW.md`, `ROADMAP.md`, `PLAN.md`.
> Не строить по этому файлу.

---

# CONTEXT MAP MASTER PROMPT
## Domain-Driven Design Context Mapping

==========================================================
ROLE
==========================================================

You are acting as a Domain-Driven Design Architecture Board.

You are a team composed of:

• Eric Evans
• Vaughn Vernon
• Principal Enterprise Architect
• ERP Architect
• Manufacturing Systems Architect
• AI Systems Architect

Your responsibility is to design the Context Map for the entire platform.

No implementation.

No coding.

No refactoring.

Architecture only.

==========================================================
MISSION
==========================================================

The Domain Model and System Architecture have been approved.

The Architecture Decision Records have frozen all irreversible decisions.

Your next responsibility is to define the ownership boundaries of the entire system.

This document becomes the official ownership map of the platform.

==========================================================
INPUT
==========================================================

Read completely:

CLAUDE.md

PROJECT.md

.ai/architecture/domain_model.md

.ai/architecture/04_system_architecture.md

.ai/architecture/ADR/

.ai/roadmap/korkem_flow_spec.md

==========================================================
OBJECTIVE
==========================================================

Generate

.ai/architecture/05_context_map.md

==========================================================
STEP 1

Identify every Bounded Context.

Examples:

Sales

CRM

Production

Planning

Warehouse

Purchasing

Scheduling

Installation

Finance

Analytics

Knowledge

AI

Security

Notifications

Documents

Integrations

==========================================================
STEP 2

For every bounded context document:

Purpose

Responsibilities

Owned Entities

Owned Value Objects

Owned Aggregates

Owned Services

Owned APIs

Owned Events

Owned Commands

Owned Queries

Owned Permissions

Owned Configuration

AI Responsibilities

Human Responsibilities

==========================================================
STEP 3

For every pair of contexts determine:

Customer/Supplier relationship

Upstream

Downstream

Shared Kernel

Conformist

Anti-Corruption Layer

Open Host Service

Published Language

Partnership

Separate Ways

Explain WHY.

==========================================================
STEP 4

Define ownership.

Every entity must have exactly one owner.

Every API must have exactly one owner.

Every Event must have exactly one publisher.

Every Command must have exactly one handler.

Every Aggregate must belong to one bounded context.

==========================================================
STEP 5

Generate a complete Context Map.

Show:

Communication

Dependencies

Ownership

Synchronization

Isolation

Integration

==========================================================
STEP 6

Identify architectural risks.

Detect:

Tight coupling

Circular dependencies

Duplicate ownership

Missing ownership

Leaky abstractions

Chatty integrations

Shared mutable state

Hidden dependencies

==========================================================
STEP 7

Refine until every bounded context has:

High cohesion

Low coupling

Clear ownership

Minimal dependencies

==========================================================
QUALITY GATE
==========================================================

The document must become the definitive ownership reference.

Future Module Architecture must follow this document.

If Module Architecture would contradict this Context Map,
the Context Map wins.

==========================================================
STOP CONDITION
==========================================================

Do not write implementation code.

Do not modify repositories.

Stop after generating:

.ai/architecture/05_context_map.md

Wait for approval.
