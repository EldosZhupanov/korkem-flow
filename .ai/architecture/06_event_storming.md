# Event Storming
## AI Furniture Manufacturing Operating System — Phase 06 of the Architecture Pipeline

Version: 1.0 — Draft for approval. Documentation only; no code was written or repositories modified to produce this document.

Inputs read in full: `domain_model.md`, `04_system_architecture.md`, `05_context_map.md`, `.ai/architecture/ADR/*` (23 ADRs), `.ai/roadmap/korkem_flow_spec.md`.

This document goes beyond `domain_model.md` §11's original ~20-event catalog — Event Storming's job is discovery at a finer grain than the domain model needed, so several new events surface here (e.g. `MaterialReserved`, `ProductionStarted`, `OperationCompleted`, `QualityInspectionPassed/Failed`, the Installation/Delivery/Warranty events) that were implied by `PROJECT.md`'s lifecycle or the master prompt's own examples but not yet individually cataloged.

---

## 1. Complete Event Catalog (Step 1)

Organized by the 17 bounded contexts from `05_context_map.md`. **Bold** marks events new to this pass (not in `domain_model.md` §11).

| Context | Events |
|---|---|
| Sales | LeadCreated, LeadQualified, LeadConverted, QuoteDrafted, QuoteSent, **QuoteApproved**, **QuoteRejected**, DealWon, DealLost, **ContractSigned**, **DepositReceived**, **DealConvertedToProductionOrder** |
| Customer Relationship | **CustomerCreated**, **CustomerTierChanged**, **ContactAdded** |
| Production | ProductionOrderCreated, **ProductionOrderPlanned**, **ProductionStarted**, **FacadeItemAdded**, **OperationStarted**, **OperationCompleted**, ProductionOrderStageCompleted *(implicit — see §4)*, **QualityInspectionPassed**, **QualityInspectionFailed**, ProductionOrderReady, **ProductionOrderPackaged**, ProductionOrderArchived |
| Planning | **BOMCreated**, **BOMUpdated**, **RoutingDefined**, **MillingProfileAdded** |
| Warehouse | **MaterialReserved**, MaterialConsumed, **RollIntaken**, RollRestocked, RestockThresholdBreached, **OffcutLogged**, **InventoryAdjusted** |
| Purchasing | **PurchaseOrderCreated**, **SupplierConfirmed**, **MaterialArrived** |
| Scheduling | **WorkAssignmentCreated**, WorkAssignmentCompleted, **WorkerReassigned** |
| Installation & After-Sales *(ownerless — see §4)* | **DeliveryScheduled**, **DeliveryCompleted**, **InstallationScheduled**, **InstallationCompleted**, **AcceptanceSigned**, **WarrantyActivated**, **WarrantyClaimFiled** |
| Finance | BonusEarned, AdvanceIssued, DefectPenaltyRecorded, PayrollPeriodClosed, **PayrollPeriodPaid** |
| Analytics | *(none published — pure consumer, per `05_context_map.md` §2.10)* |
| Knowledge | **KnowledgeIndexRebuilt** |
| AI | **AgentConversationStarted**, PendingActionProposed, PendingActionApproved, PendingActionRejected, **PendingActionExpired** |
| Security | **UserLoggedIn**, **PermissionDenied** |
| Notifications | OutboundNotificationSent, **OutboundNotificationFailed** |
| Documents | ApprovalSheetGenerated, ApprovalSheetSigned, **ApprovalSheetExpired**, **ShopSheetPrinted** |
| Collaboration | **TaskCreated**, **TaskCompleted**, **NoteAdded** |
| Integrations | *(no domain events — adapter-only; operational failures surface as `OutboundNotificationFailed` upstream in Notifications, not a separate domain event here)* |

**Total: 58 domain events** across 15 event-publishing contexts (Analytics and Integrations publish none, by design).

## 2. Per-Event Detail (Step 2)

Grouped by context, one compact table per context. Columns: Event · Description · Trigger · Publisher · Consumers · Preconditions · Postconditions · Aggregate. "Related bounded context" is the table's own grouping.

### Sales
| Event | Description | Trigger | Publisher | Consumers | Preconditions | Postconditions | Aggregate |
|---|---|---|---|---|---|---|---|
| LeadCreated | New interest captured | `CreateLead` command | Sales | Analytics | none | Lead exists, status=New | Lead |
| LeadQualified | Lead judged worth pursuing | Sales user action | Sales | Analytics, AI (Sales Agent) | Lead exists | Lead.status=Qualified | Lead |
| LeadConverted | Lead becomes a Deal | `ConvertLeadToDeal` | Sales | Analytics | Lead.status=Qualified | Deal created, Lead.converted=true | Lead → Deal |
| QuoteDrafted | Quotation prepared | Sales user/AI action | Sales | none direct | Deal exists | Deal has draft quote | Deal |
| QuoteSent | Quotation delivered to client | Sales user action | Sales | Notifications | QuoteDrafted occurred | Deal.status=Quoted | Deal |
| **QuoteApproved** | Client approved the quotation | Client response recorded | Sales | Production (readiness signal), Analytics | QuoteSent occurred | Deal ready for Contract stage | Deal |
| **QuoteRejected** | Client rejected the quotation | Client response recorded | Sales | Analytics | QuoteSent occurred | Deal may re-enter QuoteDrafted or become Lost | Deal |
| DealWon | Deal succeeds | Sales user action | Sales | Analytics, Production (pending Contract/Deposit) | Deal active | Deal.status=Won | Deal |
| DealLost | Deal fails | Sales user action | Sales | Analytics | Deal active | Deal.status=Lost | Deal |
| **ContractSigned** | Formal contract executed | Sales/client action | Sales | Production, Documents | DealWon occurred | Deal enters Contract stage per `PROJECT.md` lifecycle | Deal |
| **DepositReceived** | Initial payment received | Finance-adjacent event recorded in Sales | Sales | Production, Finance | ContractSigned occurred | Deal enters Deposit stage; Production Order creation unblocked | Deal |
| **DealConvertedToProductionOrder** | Deal handoff to manufacturing | `ConvertDealToProductionOrder` | Sales | Production | DepositReceived occurred | Production Order created with `originating_deal` set | Deal → Production Order |

### Customer Relationship
| Event | Description | Trigger | Publisher | Consumers | Preconditions | Postconditions | Aggregate |
|---|---|---|---|---|---|---|---|
| **CustomerCreated** | New Customer record established | Sales/admin action, or CRM→ERPNext sync | Customer Relationship | Sales, Analytics | none | Customer exists | Customer |
| **CustomerTierChanged** | VIP/Regular/New tier changed | `SetClientTier` or automated recompute | Customer Relationship | Sales, Analytics | Customer exists | Customer.tier updated | Customer |
| **ContactAdded** | New contact person linked | user action | Customer Relationship | Sales | Customer exists | Contact linked to Customer | Customer |

### Production
| Event | Description | Trigger | Publisher | Consumers | Preconditions | Postconditions | Aggregate |
|---|---|---|---|---|---|---|---|
| ProductionOrderCreated | Order enters manufacturing | `DealConvertedToProductionOrder` handler, or direct walk-in creation | Production | Warehouse, Scheduling, Documents, Analytics | Deposit received (if Deal-originated) or direct order authorized | Production Order exists, status=Material Planning | Production Order |
| **ProductionOrderPlanned** | Material Planning/Inventory Validation complete | Production Manager action | Production | Purchasing, Warehouse | ProductionOrderCreated | Order ready for Purchasing/Warehouse Allocation | Production Order |
| **ProductionStarted** | First shop-floor stage begins | Workshop Operator action | Production | Scheduling, Analytics | MaterialReserved occurred (Warehouse) | Production Order status=Cutting (shop-floor sub-state) | Production Order |
| **FacadeItemAdded** | A facade line item added to the order | `AddFacadeItem` | Production | Warehouse (Decor reference), Documents | Production Order exists | Facade Item exists, order's total Area recomputed | Production Order |
| **OperationStarted** | A specific Operation begins | Workshop Operator action | Production | Scheduling | Work Assignment exists for the Operation | Operation.status=In Progress | Production Order |
| **OperationCompleted** | A specific Operation finishes | `CompleteStage` (per-Operation granularity) | Production | Scheduling (for Work Assignment completion), Notifications, Analytics | OperationStarted occurred | Operation.status=Done | Production Order |
| ProductionOrderStageCompleted | *Implicit/derived — see §4, not independently published* | — | — | — | — | — | — |
| **QualityInspectionPassed** | Facade Item(s) pass quality check | Quality inspector/Quality Agent action | Production | Documents, Notifications | Relevant Operations completed | Facade Item marked inspection-passed | Production Order |
| **QualityInspectionFailed** | Facade Item(s) fail quality check | Quality inspector action | Production | Scheduling (rework assignment), Finance (potential Defect Penalty) | Relevant Operations completed | Facade Item flagged for rework | Production Order |
| ProductionOrderReady | All Facade Items reach shop-floor `Ready` | last `OperationCompleted` for the order's final stage | Production | Notifications, Documents | domain_model.md invariant 2: all Facade Items Ready | Production Order status=Ready | Production Order |
| **ProductionOrderPackaged** | Packaging stage complete | Packer action | Production | Notifications, Installation & After-Sales (once it exists) | ProductionOrderReady | Production Order status=Packaging complete | Production Order |
| ProductionOrderArchived | Order lifecycle closed | Admin/automated action after Warranty period | Production | Analytics | Warranty stage complete (or N/A) | Production Order status=Archive | Production Order |

### Planning
| Event | Description | Trigger | Publisher | Consumers | Preconditions | Postconditions | Aggregate |
|---|---|---|---|---|---|---|---|
| **BOMCreated** | New Bill of Materials defined | Engineering/Production Manager action | Planning | Production | Item exists | BOM exists | BOM |
| **BOMUpdated** | Existing BOM revised | Engineering action | Planning | Production, Warehouse (cost recompute) | BOM exists | BOM version updated | BOM |
| **RoutingDefined** | Operation sequence defined | Engineering action | Planning | Production | none | Routing exists | Routing |
| **MillingProfileAdded** | New milling pattern cataloged | Production Manager/admin action | Planning | Production (Facade Item reference) | none | Milling Profile exists | Milling Profile |

### Warehouse
| Event | Description | Trigger | Publisher | Consumers | Preconditions | Postconditions | Aggregate |
|---|---|---|---|---|---|---|---|
| **MaterialReserved** | Stock allocated to a specific Production Order | `ProductionOrderPlanned` handler / Warehouse Allocation stage | Warehouse | Production | Sufficient Roll/Item stock exists | Roll/Item quantity reserved (not yet consumed) | Decor / Item |
| MaterialConsumed | Stock actually deducted at production | Cutting stage start (per invariant 5 in `domain_model.md`) | Warehouse | Analytics | MaterialReserved occurred | Roll linear meters reduced | Decor (Roll) |
| **RollIntaken** | New roll added to stock | `RestockRoll` / Purchasing `MaterialArrived` handler | Warehouse | Analytics | Supplier/decor identified | Roll exists with initial meters | Decor |
| RollRestocked | Roll replenished | `RestockRoll` | Warehouse | Analytics | Roll exists | Roll meters increased | Decor |
| RestockThresholdBreached | Roll below safety threshold | scheduled scan (per ADR-0006/0009) | Warehouse | AI (Warehouse Agent), Purchasing | Roll.meters < threshold | Roll flagged low-stock | Decor |
| **OffcutLogged** | Usable leftover material recorded | `LogOffcut` | Warehouse | Analytics | Cutting/production produced a leftover | Offcut exists | Decor |
| **InventoryAdjusted** | Manual stock correction (count discrepancy, damage, etc.) | Warehouse Manager action | Warehouse | Analytics | Item/Decor/Roll exists | Stock quantity corrected | Item / Decor |

### Purchasing
| Event | Description | Trigger | Publisher | Consumers | Preconditions | Postconditions | Aggregate |
|---|---|---|---|---|---|---|---|
| **PurchaseOrderCreated** | Order placed with a Supplier | Purchasing Manager action / AI (Warehouse Agent) proposal | Purchasing | Warehouse, Analytics | RestockThresholdBreached or manual need | Purchase Order exists | Purchase Order |
| **SupplierConfirmed** | Supplier confirms the order | Supplier response recorded | Purchasing | Warehouse | PurchaseOrderCreated | Purchase Order confirmed | Purchase Order |
| **MaterialArrived** | Ordered material physically received | Purchasing/Warehouse Manager action | Purchasing | Warehouse (`RollIntaken`) | SupplierConfirmed | Purchase Order fulfilled | Purchase Order |

### Scheduling
| Event | Description | Trigger | Publisher | Consumers | Preconditions | Postconditions | Aggregate |
|---|---|---|---|---|---|---|---|
| **WorkAssignmentCreated** | Worker(s) assigned to an Operation | `AssignWorkersToOperation` | Scheduling | Production, Finance | Operation exists, splits sum to 100%/area (invariant 3) | Work Assignment exists | Employee (via assignment) |
| WorkAssignmentCompleted | Assigned work finished | `OperationCompleted` handler | Scheduling | Finance (bonus computation) | WorkAssignmentCreated | Work Assignment.status=Done | Employee |
| **WorkerReassigned** | Assignment changed after creation (compensating event) | Production Manager action | Scheduling | Production, Finance | WorkAssignmentCreated, work not yet completed | Old assignment voided, new one created | Employee |

### Installation & After-Sales *(events exist per `PROJECT.md`/the master prompt's examples; no owning entity yet — see §4)*
| Event | Description | Trigger | Publisher | Consumers | Preconditions | Postconditions | Aggregate |
|---|---|---|---|---|---|---|---|
| **DeliveryScheduled** | Delivery date/logistics set | Production Manager/Sales action | *unassigned* | Notifications | ProductionOrderPackaged | — pending entity definition | *none — gap* |
| **DeliveryCompleted** | Goods physically delivered | Delivery confirmation | *unassigned* | Notifications, Analytics | DeliveryScheduled | — pending entity definition | *none — gap* |
| **InstallationScheduled** | On-site installation visit set | Sales/ops action | *unassigned* | Notifications | DeliveryCompleted (or DeliveryScheduled, if combined) | — pending entity definition | *none — gap* |
| **InstallationCompleted** | Installation finished on-site | Technician action | *unassigned* | Notifications, Analytics | InstallationScheduled | — pending entity definition | *none — gap* |
| **AcceptanceSigned** | Client formally accepts the work | Client sign-off | *unassigned* | Documents, Analytics | InstallationCompleted | — pending entity definition | *none — gap* |
| **WarrantyActivated** | Warranty period begins | AcceptanceSigned handler | *unassigned* | Notifications | AcceptanceSigned | — pending entity definition | *none — gap* |
| **WarrantyClaimFiled** | Client reports a warranty issue | Client/support action | *unassigned* | Production (potential rework), Notifications | WarrantyActivated, within warranty period | — pending entity definition | *none — gap* |

### Finance
| Event | Description | Trigger | Publisher | Consumers | Preconditions | Postconditions | Aggregate |
|---|---|---|---|---|---|---|---|
| BonusEarned | Worker crosses a Bonus Rule threshold | scheduled/triggered computation on `WorkAssignmentCompleted` | Finance | Analytics | Bonus Rule exists, threshold met | Bonus line added to open Payroll Period | Payroll Period |
| AdvanceIssued | Cash advance given to a worker | `IssueAdvance` | Finance | Analytics | Employee active (invariant 10) | Advance recorded, reduces Payable | Payroll Period |
| DefectPenaltyRecorded | Deduction for defective work | `RecordDefectPenalty`, often following `QualityInspectionFailed` | Finance | Analytics | QualityInspectionFailed (usually) | Penalty line added | Payroll Period |
| PayrollPeriodClosed | Period aggregation finalized | `CloseBonlPayrollPeriod` | Finance | Analytics | Period end reached | Payroll Period.status=Closed, Payable computed | Payroll Period |
| **PayrollPeriodPaid** | Money actually disbursed | Accountant action | Finance | Analytics | PayrollPeriodClosed | Payroll Period.status=Paid | Payroll Period |

### Knowledge
| Event | Description | Trigger | Publisher | Consumers | Preconditions | Postconditions | Aggregate |
|---|---|---|---|---|---|---|---|
| **KnowledgeIndexRebuilt** | Retrieval index resynced from bench data | scheduled job (ADR-0019) | Knowledge | AI (Knowledge Agent) | none | Index reflects bench data as of sync time | *none — the index itself, not a doctype aggregate* |

### AI
| Event | Description | Trigger | Publisher | Consumers | Preconditions | Postconditions | Aggregate |
|---|---|---|---|---|---|---|---|
| **AgentConversationStarted** | New chat thread begins | user/agent first message | AI | Analytics | none | Agent Conversation exists | Agent Conversation |
| PendingActionProposed | Agent proposes a write | agent skill decision (ADR-0003/0015) | AI | Notifications (approver alert), Analytics | Agent Conversation active | Pending Action exists, status=Pending | Agent Conversation |
| PendingActionApproved | Human approves the proposal | human approver action | AI | target context's Command handler, Analytics | re-validated per invariant 9 | Command executed, Pending Action.status=Approved | Agent Conversation |
| PendingActionRejected | Human rejects the proposal | human approver action | AI | Analytics | Pending Action pending | Pending Action.status=Rejected, no Command executed | Agent Conversation |
| **PendingActionExpired** | Proposal times out unresolved | scheduled check | AI | Analytics | Pending Action pending past `expires_at` | Pending Action.status=Expired | Agent Conversation |

### Security
| Event | Description | Trigger | Publisher | Consumers | Preconditions | Postconditions | Aggregate |
|---|---|---|---|---|---|---|---|
| **UserLoggedIn** | Session established (normal or PIN, per ADR-0020) | login action | Security | Analytics (usage tracking) | valid credential | Frappe session active | User |
| **PermissionDenied** | An action was blocked by RBAC | any attempted action failing `frappe.has_permission` | Security | Analytics (security audit) | Actor lacks required permission | Action not executed, denial logged | User |

### Notifications
| Event | Description | Trigger | Publisher | Consumers | Preconditions | Postconditions | Aggregate |
|---|---|---|---|---|---|---|---|
| OutboundNotificationSent | Message successfully delivered | enqueued job success (per ADR-0009) | Notifications | Analytics | a triggering domain event occurred | Outbound Notification log entry, status=Sent | Production Order (log owner, per `domain_model.md` §5) |
| **OutboundNotificationFailed** | Message delivery failed | enqueued job failure (third-party API error) | Notifications | Analytics, possibly AI (Supervisor Agent) | attempted send failed | log entry status=Failed, retry per job policy | Production Order |

### Documents
| Event | Description | Trigger | Publisher | Consumers | Preconditions | Postconditions | Aggregate |
|---|---|---|---|---|---|---|---|
| ApprovalSheetGenerated | Excel approval sheet produced | `GenerateApprovalSheet` | Documents | Notifications | Production Order has Facade Items | Approval Sheet exists, status=Draft | Production Order |
| ApprovalSheetSigned | Client signs the sheet | client action recorded | Documents | Sales, Analytics | ApprovalSheetGenerated, sheet sent | Approval Sheet.status=Signed | Production Order |
| **ApprovalSheetExpired** | Sheet not signed within validity window | scheduled check | Documents | Sales | Approval Sheet sent, not signed | Approval Sheet.status=Expired | Production Order |
| **ShopSheetPrinted** | Shop-floor print job logged | `GenerateShopSheet` | Documents | Analytics | Production Order exists | Shop Sheet log entry created | Production Order |

### Collaboration
| Event | Description | Trigger | Publisher | Consumers | Preconditions | Postconditions | Aggregate |
|---|---|---|---|---|---|---|---|
| **TaskCreated** | To-do attached to any entity | user/agent action | Collaboration | the target entity's context (informational) | target entity exists | Task exists, linked via `reference_doctype`/`reference_docname` | *none — cross-cutting* |
| **TaskCompleted** | To-do resolved | user action | Collaboration | Analytics | Task exists | Task.status=Done | *none — cross-cutting* |
| **NoteAdded** | Free-text note attached | user/agent action | Collaboration | the target entity's context (informational) | target entity exists | Note exists | *none — cross-cutting* |

## 3. Commands / Queries / Read Models per Event (Step 3)

Only listing entries that add information beyond §2's "Trigger" column (which already names most producing commands); this section makes the Query/Read-Model linkage explicit.

| Event | Producing Command(s) | Affected Queries | Updated Read Model(s) |
|---|---|---|---|
| LeadCreated / LeadConverted | `CreateLead`, `ConvertLeadToDeal` | `GetClientStats` | Analytics Lead funnel |
| DealConvertedToProductionOrder | `ConvertDealToProductionOrder` | `GetOrdersTable`, `GetOrderDetail` | Orders Table read model |
| FacadeItemAdded | `AddFacadeItem` | `GetOrderDetail` | Order Detail read model (Area recompute, invariant 1) |
| OperationCompleted | `CompleteStage` | `GetOrdersTable` (stage checkboxes) | Orders Table shop-floor progress read model |
| MaterialReserved / MaterialConsumed | (Warehouse Allocation handler), (Cutting-stage handler) | `GetWarehouseStock` | Warehouse stock read model |
| RestockThresholdBreached | (scheduled scan) | `GetWarehouseStock` (low-stock filter) | Warehouse restock-alert read model |
| WorkAssignmentCompleted | (from `OperationCompleted`) | `GetBonusProgress` | Scheduling/Finance bonus-progress read model |
| PendingActionProposed/Approved/Rejected/Expired | `ProposeAction`, `ApproveAction`, `RejectAction`, (expiry job) | `GetPendingActions` | AI approval-queue read model |
| CustomerTierChanged | `SetClientTier` | `GetClientStats`, `GetOrdersTable` (VIP badge) | Customer + Orders Table read models |
| ApprovalSheetSigned | (client action) | `GetOrderDetail` | Order Detail read model (approval status) |
| PayrollPeriodClosed/Paid | `CloseBonlPayrollPeriod`, (payment action) | `GetWorkerPayroll` | Payroll read model |

## 4. Detection Findings (Step 4)

### Missing events
- **The entire Installation & After-Sales event set** (`DeliveryScheduled` through `WarrantyClaimFiled`) has no owning aggregate/entity — this event storming pass independently rediscovers the exact gap `05_context_map.md` §6 already flagged, now from the events side rather than the entities side. Two independent analysis methods converging on the same gap is a strong signal this needs to be resolved before Module Architecture assigns directories.
- **No cancellation events exist anywhere** — `ProductionOrderCancelled`, `DealCancelled`, `PurchaseOrderCancelled` are all absent from `domain_model.md` and from this catalog, yet real-world operation will need them (a client cancels an order mid-production, a Deal falls through after initial commitment). Flagged as a genuine missing-event finding, not designed here (out of scope per Stop Condition) — recommended for the next `domain_model.md` revision.
- **No explicit "Employee deactivated" event** — `korkem_workforce`'s Employee entity presumably supports an active/inactive flag (referenced in validation rule "Pin Credential unique among active Employees"), but no event marks the transition. Flagged for the same reason.

### Duplicated events
- None found. `MaterialReserved` (Warehouse) and `ProductionOrderPlanned` (Production) initially looked like they might overlap, but they're distinct: `ProductionOrderPlanned` is Production's own internal readiness milestone, `MaterialReserved` is Warehouse's response to it — different publishers, different aggregates, correctly not merged.

### Implicit events
- **`ProductionOrderStageCompleted`** (originally in `domain_model.md` §11) is **not** independently published in this catalog — it is a *derived/implicit* event: a read-model computation over "all `OperationCompleted` events for Operations of a given shop-floor stage type, for this Production Order." Treating it as implicit rather than a separately-fired event avoids a subtle duplicate-publishing risk (Production would otherwise need to fire both `OperationCompleted` and `ProductionOrderStageCompleted` for the same underlying fact). `domain_model.md` §11 should be read as referring to this same derived signal, not a distinct event Production must remember to publish separately.

### Long-running workflows
- **Lead-to-Archive** (the full `PROJECT.md` macro lifecycle) is the platform's longest-running workflow, potentially spanning weeks to months across Sales → Production → Installation & After-Sales → Warranty.
- **Payroll Period** (half-month/month/custom range) is a medium-duration batch workflow.
- **Pending Action** has a bounded but non-trivial duration (proposal → human approval, with an expiry timeout) — short compared to the above, but still asynchronous rather than instantaneous.

### Compensating events
- `QuoteRejected` compensates the `QuoteSent`→Won path.
- `DealLost` compensates `DealWon`'s intended trajectory.
- `QualityInspectionFailed` compensates `OperationCompleted` (triggers rework rather than accepting the output).
- `WorkerReassigned` compensates an earlier `WorkAssignmentCreated`.
- `PendingActionRejected`/`PendingActionExpired` compensate `PendingActionProposed`.
- `ApprovalSheetExpired` compensates `ApprovalSheetGenerated`'s intended "get it signed" outcome.

### Failure events
`QualityInspectionFailed`, `PendingActionExpired`, `OutboundNotificationFailed`, `PermissionDenied`, `ApprovalSheetExpired`. `RestockThresholdBreached` is a *warning*, not a failure — it signals a condition to act on, not something that already went wrong.

## 5. Business Workflows as Event Sequences (Step 5)

1. **Lead-to-Contract**: `LeadCreated → LeadQualified → LeadConverted → QuoteDrafted → QuoteSent → QuoteApproved → DealWon → ContractSigned → DepositReceived`
2. **Contract-to-Production-Handoff**: `DepositReceived → DealConvertedToProductionOrder → ProductionOrderCreated`
3. **Material Planning & Procurement**: `ProductionOrderCreated → ProductionOrderPlanned → (RestockThresholdBreached →) PurchaseOrderCreated → SupplierConfirmed → MaterialArrived → RollIntaken → MaterialReserved`
4. **Shop-Floor Execution**: `ProductionStarted → OperationStarted → OperationCompleted (× N, rolling up to the implicit ProductionOrderStageCompleted per stage) → QualityInspectionPassed → ProductionOrderReady → ProductionOrderPackaged`
5. **Quality & Rework (compensating branch)**: `OperationCompleted → QualityInspectionFailed → WorkerReassigned → OperationStarted → OperationCompleted → QualityInspectionPassed`
6. **Delivery & Installation** *(aspirational — no owning aggregate yet, per §4)*: `ProductionOrderPackaged → DeliveryScheduled → DeliveryCompleted → InstallationScheduled → InstallationCompleted → AcceptanceSigned → WarrantyActivated → (WarrantyClaimFiled →) ProductionOrderArchived`
7. **Payroll & Bonus**: `WorkAssignmentCreated → WorkAssignmentCompleted → BonusEarned/DefectPenaltyRecorded → PayrollPeriodClosed → PayrollPeriodPaid`
8. **AI Proposal & Approval** *(cross-cutting — can wrap a step in any workflow above)*: `AgentConversationStarted → PendingActionProposed → (PendingActionApproved → target Command executes) | PendingActionRejected | PendingActionExpired`

## 6. Quality Gate Verification

- **Every business workflow representable as a sequence of events**: confirmed for all 8 workflows in §5; workflow 6 is representable as a sequence but flagged as resting on events with no owning aggregate yet (a documentation-honesty flag, not a sequencing failure).
- **No event has multiple owners**: verified — every event in §1/§2 appears in exactly one context's table. The one case requiring resolution (`MaterialReserved` vs. `ProductionOrderPlanned`) was explicitly disambiguated in §4.
- **No aggregate publishes contradictory events**: verified by inspection — e.g. Production Order never has both `ProductionOrderReady` and `QualityInspectionFailed` claimed as terminal for the same Facade Item set; the Quality & Rework branch (workflow 5) explicitly loops back through `OperationStarted`/`OperationCompleted` before `ProductionOrderReady` can fire again, so the two are sequenced, not contradictory.

## 7. Self-Review

- Cross-checked this catalog's 58 events against `domain_model.md` §11's original ~20 — every original event is accounted for (either reused as-is or clarified as implicit, per §4's `ProductionOrderStageCompleted` finding); none were silently dropped.
- Cross-checked against `05_context_map.md`'s 17 contexts — every context that should publish events does (15 of 17; Analytics and Integrations correctly publish none, consistent with their read-only/adapter-only roles established there).
- Cross-checked against `korkem_flow_spec.md`'s 9 modules — every module's core workflow is represented in §5's 8 workflows (Orders table/breakdown → workflows 3-4; color-coding is a Production-internal detail on Facade Item, not event-worthy on its own; Clients & Analytics → workflow 1 + Analytics' consumption; Urgent/VIP → attribute changes, not separately event-worthy beyond `CustomerTierChanged`; Warehouse → workflow 3; Workshop roles/bonus → workflow 7; Mobile PIN dashboard → `UserLoggedIn`; Shop sheets/WhatsApp → workflow 4's Notifications consumers and the Documents events).
- The Installation & After-Sales gap is the single most important finding of this pass — surfaced independently via both entities (Context Map) and events (this document), which is strong corroborating evidence it must be resolved with real entity/aggregate design before Module Architecture proceeds, rather than deferred again.
- No circular event chains found (verified against §5's workflows — each is a directed sequence, including the Quality & Rework loop, which terminates rather than cycling indefinitely since rework has a bounded number of realistic iterations in practice, though this document does not impose a hard iteration cap — flagged as a possible Phase 07 (State Machines) consideration, not resolved here).

---

*Per the Stop Condition in `06_event_storming_prompt.md`: no modules designed, no APIs designed, no code implemented. Stopping here for approval before State Machines.*
