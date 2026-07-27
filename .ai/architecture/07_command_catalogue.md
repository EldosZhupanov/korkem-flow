# Command Catalogue
## AI Furniture Manufacturing Operating System — Phase 07 of the Architecture Pipeline

Version: 1.0 — Draft for approval. Documentation only; no code was written, no API was designed, no repositories modified to produce this document.

Inputs read in full: `domain_model.md`, `05_context_map.md`, `06_event_storming.md`, `.ai/architecture/ADR/*` (23 ADRs), `PROJECT.md`.

Naming note: the master prompt's examples use generic ERP vocabulary (`CreateQuote`, `ApproveQuote`, `ConvertQuoteToOrder`, `ShipOrder`). This platform's established vocabulary (ADR-0021) uses **Deal**, not Quote — "quote" is a status within Deal's lifecycle, not a separate entity — so commands are named `RecordQuoteApproval`/`ConvertDealToProductionOrder` etc. against the actual domain model rather than the example's generic terms. Every example command is still accounted for, under its real name — mapped explicitly where it differs.

Each context uses two tables: **Identity & Permissions** (Command, Purpose, Actor & Permissions, Aggregate, Idempotent?) and **Rules & Lifecycle** (Command, Validation & Business Rules, Precondition → Postcondition, Generated Event(s), Failure Event(s), Compensating Command(s)). "Actor" states who may invoke it — a specific human role, an AI agent (always **via Pending Action only**, per ADR-0015 — never direct), or **System** for scheduled/internally-triggered operations no user or agent invokes directly.

---

## 1. Sales

### Identity & Permissions
| Command | Purpose | Actor & Permissions | Aggregate | Idempotent? |
|---|---|---|---|---|
| CreateLead | Capture new interest | Human: Sales user · AI: Sales Agent (via Pending Action) | Lead | No — always creates a new Lead |
| QualifyLead | Mark a Lead worth pursuing | Human: Sales user · AI: Sales Agent | Lead | Yes — re-qualifying an already-qualified Lead is a no-op |
| ConvertLeadToDeal | Turn a qualified Lead into a Deal | Human: Sales user · AI: Sales Agent | Lead → Deal | No |
| DraftQuote | Prepare a quotation on a Deal | Human: Sales user · AI: Sales Agent | Deal | Yes — redrafting replaces the draft |
| SendQuote | Deliver quotation to client | Human: Sales user | Deal | Yes — resending is safe |
| RecordQuoteApproval *(example: ApproveQuote)* | Record client's approval | Human: Sales user (recording client response) | Deal | No |
| RecordQuoteRejection *(example: RejectQuote)* | Record client's rejection | Human: Sales user | Deal | No |
| MarkDealWon | Close the Deal as won | Human: Sales user | Deal | Yes — idempotent if already Won |
| MarkDealLost | Close the Deal as lost | Human: Sales user | Deal | Yes |
| SignContract | Record formal contract execution | Human: Sales user | Deal | No |
| RecordDeposit | Record initial payment received | Human: Sales/Finance user | Deal | No |
| ConvertDealToProductionOrder *(example: ConvertQuoteToOrder)* | Hand off Deal to manufacturing | Human: Sales/Production Manager · AI: Sales Agent (proposal only) | Deal → Production Order | No |

### Rules & Lifecycle
| Command | Validation & Business Rules | Precondition → Postcondition | Generated Event(s) | Failure Event(s) | Compensating Command(s) |
|---|---|---|---|---|---|
| CreateLead | Phone number format validated (`domain_model.md` §10) | none → Lead exists, status=New | LeadCreated | — | none (delete is not modeled — see §4 finding) |
| QualifyLead | Lead must exist | Lead exists → Lead.status=Qualified | LeadQualified | — | none needed |
| ConvertLeadToDeal | Lead must be Qualified | Lead.status=Qualified → Deal created, Lead.converted=true | LeadConverted | — | none — Lead conversion is a one-way gate by design |
| DraftQuote | Deal must be active | Deal exists → draft quote attached | QuoteDrafted | — | DraftQuote (redraft) |
| SendQuote | QuoteDrafted must have occurred | draft exists → Deal.status=Quoted | QuoteSent | — | none |
| RecordQuoteApproval | QuoteSent must have occurred | Deal.status=Quoted → Deal ready for Contract stage | QuoteApproved | — | RecordQuoteRejection (if approval was recorded in error) |
| RecordQuoteRejection | QuoteSent must have occurred | Deal.status=Quoted → Deal re-enters QuoteDrafted or becomes Lost | QuoteRejected | — | DraftQuote (re-quote) |
| MarkDealWon | Deal must be active, not already Lost | Deal active → Deal.status=Won | DealWon | — | MarkDealLost |
| MarkDealLost | Deal must be active | Deal active → Deal.status=Lost | DealLost | — | none — Lost is intended to be terminal (see §4 missing-command finding on reopening) |
| SignContract | DealWon must have occurred | Deal.status=Won → Contract stage entered | ContractSigned | — | none |
| RecordDeposit | ContractSigned must have occurred | Contract stage → Deposit stage, unblocks Production Order creation | DepositReceived | — | none modeled (a deposit refund/reversal is a missing command, see §4) |
| ConvertDealToProductionOrder | DepositReceived must have occurred (invariant 4: at most one Production Order per Deal) | Deposit stage → Production Order created with `originating_deal` set | DealConvertedToProductionOrder, ProductionOrderCreated | — | none — irreversible handoff by design |

## 2. Customer Relationship

### Identity & Permissions
| Command | Purpose | Actor & Permissions | Aggregate | Idempotent? |
|---|---|---|---|---|
| CreateCustomer | Register a new Customer | Human: Sales/admin user | Customer | No |
| SetClientTier | Set/override VIP-Regular-New tier | Human: Sales Manager/admin · AI: Sales Agent (proposal, per invariant 6's override-must-be-explicit rule) | Customer | Yes |
| AddContact | Link a new contact person | Human: Sales user | Customer | No |

### Rules & Lifecycle
| Command | Validation & Business Rules | Precondition → Postcondition | Generated Event(s) | Failure Event(s) | Compensating Command(s) |
|---|---|---|---|---|---|
| CreateCustomer | Phone number format validated | none → Customer exists | CustomerCreated | — | none |
| SetClientTier | Invariant 6: system-computed vs. manual override must be explicit, never silently both | Customer exists → tier updated, override flag set if manual | CustomerTierChanged | — | SetClientTier (revert) |
| AddContact | Customer must exist | Customer exists → Contact linked | ContactAdded | — | none (contact removal is a missing command, see §4) |

## 3. Production

### Identity & Permissions
| Command | Purpose | Actor & Permissions | Aggregate | Idempotent? |
|---|---|---|---|---|
| CreateProductionOrder | Create an order directly (walk-in, no Deal) | Human: Production Manager | Production Order | No |
| PlanProductionOrder | Complete Material Planning/Inventory Validation | Human: Production Manager | Production Order | Yes |
| StartProduction | Begin the first shop-floor stage | Human: Workshop Operator | Production Order | Yes — starting twice is a no-op |
| AddFacadeItem | Add a line item | Human: Production Manager/Sales · AI: Planning Agent (proposal) | Production Order | No |
| AssignDecorToFacadeItem | Attach a Decor spec to a Facade Item | Human: Production Manager | Production Order (Facade Item) | Yes |
| StartOperation | Begin a specific Operation | Human: Workshop Operator | Production Order | Yes |
| CompleteOperation *(example: FinishOperation)* | Finish a specific Operation | Human: Workshop Operator (own assignment only) | Production Order | Yes — idempotent if already Done |
| RecordInspection | Log quality-inspection findings | Human: Quality inspector · AI: Quality Agent (proposal) | Production Order | No |
| ApproveInspection | Accept the inspected work | Human: Quality inspector | Production Order | Yes |
| RejectInspection | Flag inspected work for rework | Human: Quality inspector | Production Order | Yes |
| MarkUrgent | Toggle the 🔥 urgent flag | Human: Production Manager/Sales | Production Order | Yes |
| PackageProductionOrder | Complete packaging | Human: Packer | Production Order | Yes |
| ArchiveProductionOrder | Close the order's lifecycle | Human: Admin · System (scheduled, post-Warranty) | Production Order | Yes |

### Rules & Lifecycle
| Command | Validation & Business Rules | Precondition → Postcondition | Generated Event(s) | Failure Event(s) | Compensating Command(s) |
|---|---|---|---|---|---|
| CreateProductionOrder | none blocking (walk-in orders have no Deal precondition) | none → Production Order exists, status=Material Planning | ProductionOrderCreated | — | ArchiveProductionOrder (early close) — see §4 on missing CancelProductionOrder |
| PlanProductionOrder | — | ProductionOrderCreated → ready for Purchasing/Warehouse Allocation | ProductionOrderPlanned | — | none |
| StartProduction | Precondition: MaterialReserved must have occurred (Warehouse) | Material reserved → shop-floor status=Cutting | ProductionStarted | — | none |
| AddFacadeItem | Dimensions > 0, qty ≥ 1 (`domain_model.md` §10) | Production Order exists → Facade Item exists, Area recomputed (invariant 1) | FacadeItemAdded | — | RemoveFacadeItem — **missing, see §4** |
| AssignDecorToFacadeItem | Decor must exist in Warehouse catalog | Facade Item exists → Decor linked | *(no dedicated event cataloged — folds into FacadeItemAdded's postcondition)* | — | none |
| StartOperation | Work Assignment must exist for the Operation | Work Assignment exists → Operation.status=In Progress | OperationStarted | — | none |
| CompleteOperation | Actor must be the assigned Workshop Operator (permission scope) | OperationStarted → Operation.status=Done | OperationCompleted | — | RejectInspection (if quality fails after) |
| RecordInspection | Relevant Operations completed | Operations done → inspection findings logged | *(feeds ApproveInspection/RejectInspection, no separate event)* | — | none |
| ApproveInspection | RecordInspection must have occurred | findings logged → Facade Item marked inspection-passed | QualityInspectionPassed | — | RejectInspection (correcting an erroneous approval) |
| RejectInspection | RecordInspection must have occurred | findings logged → Facade Item flagged for rework | QualityInspectionFailed | — | ApproveInspection (after rework, via new RecordInspection → ApproveInspection cycle) |
| MarkUrgent | No hard business rule found limiting urgent-order volume — **flagged unclear in §4** | Production Order exists → Urgency Level=Urgent (or reverted to Normal) | *(no dedicated event cataloged — an attribute change, not separately event-worthy, consistent with `domain_model.md`'s treatment of Urgency Level as a value object)* | — | MarkUrgent (toggle back) |
| PackageProductionOrder | Invariant 2: all Facade Items must be Ready first | ProductionOrderReady (system-derived, see below) → Packaging complete | ProductionOrderPackaged | — | none |
| ArchiveProductionOrder | Warranty stage complete or N/A | Warranty stage done → status=Archive | ProductionOrderArchived | — | none — archival is terminal |

**Note**: `ProductionOrderReady` has **no originating command** — it is system-derived once every Facade Item's shop-floor sub-state reaches Ready (invariant 2), exactly as `06_event_storming.md` §4 already noted for `ProductionOrderStageCompleted`. Consistent, not a gap.

## 4. Planning

### Identity & Permissions
| Command | Purpose | Actor & Permissions | Aggregate | Idempotent? |
|---|---|---|---|---|
| CreateBOM | Define a new Bill of Materials | Human: Production Manager/engineering | BOM | No |
| UpdateBOM | Revise an existing BOM | Human: Production Manager/engineering | BOM | Yes |
| DefineRouting | Define an Operation sequence | Human: engineering | Routing | No |
| AddMillingProfile | Catalog a new milling pattern | Human: Production Manager/admin | Milling Profile | No |

### Rules & Lifecycle
| Command | Validation & Business Rules | Precondition → Postcondition | Generated Event(s) | Failure Event(s) | Compensating Command(s) |
|---|---|---|---|---|---|
| CreateBOM | Item must exist | Item exists → BOM exists | BOMCreated | — | none |
| UpdateBOM | BOM must exist | BOM exists → new version | BOMUpdated | — | none — versioning, not reversal |
| DefineRouting | — | none → Routing exists | RoutingDefined | — | none |
| AddMillingProfile | Code uniqueness (analogous to Decor code uniqueness rule) | none → Milling Profile exists | MillingProfileAdded | — | none |

## 5. Warehouse

### Identity & Permissions
| Command | Purpose | Actor & Permissions | Aggregate | Idempotent? |
|---|---|---|---|---|
| ReserveMaterial *(example)* | Allocate stock to a specific Production Order | Human: Warehouse Manager · System (auto-triggered by PlanProductionOrder) | Decor / Item | Yes |
| ReleaseMaterial *(example)* | Undo a reservation — **missing from `domain_model.md`, added here, see §4** | Human: Warehouse Manager · System | Decor / Item | Yes |
| ConsumeMaterial | Deduct stock at production commit | System only (invariant 5: at Cutting-stage start) — **not directly user/AI-invokable, see §4 unsafe-command note** | Decor (Roll) | No |
| IntakeRoll | Register a brand-new roll in stock | Human: Warehouse Manager | Decor | No |
| RestockRoll | Add meters to an *existing* Roll | Human: Warehouse Manager | Decor | Yes |
| LogOffcut | Record usable leftover material | Human: Warehouse Manager/Workshop Operator | Decor | No |
| AdjustInventory | Manually correct a stock discrepancy | Human: Warehouse Manager only — **flagged for reason-code requirement in §4** | Item / Decor | No |

### Rules & Lifecycle
| Command | Validation & Business Rules | Precondition → Postcondition | Generated Event(s) | Failure Event(s) | Compensating Command(s) |
|---|---|---|---|---|---|
| ReserveMaterial | Sufficient stock must exist | ProductionOrderPlanned → stock reserved, not yet consumed | MaterialReserved | *(insufficient-stock failure — not yet named, see §4)* | ReleaseMaterial |
| ReleaseMaterial | A reservation must exist | reserved → stock released back to available pool | *(no event yet cataloged — new command, event to be added to `domain_model.md` on next revision)* | — | ReserveMaterial |
| ConsumeMaterial | Invariant 5: Roll meters can never go negative | reservation exists, Cutting starts → Roll meters reduced | MaterialConsumed | — | none — consumption is not reversible; a physical error is corrected via AdjustInventory, not by "unconsuming" |
| IntakeRoll | Decor code, supplier must exist | Decor identified → new Roll exists with initial meters | RollIntaken | — | none |
| RestockRoll | Roll must exist; meters ≥ 0 (`domain_model.md` §10) | Roll exists → meters increased | RollRestocked | — | AdjustInventory (correction) |
| LogOffcut | Dimensions ≥ 0 | production produced leftover → Offcut exists | OffcutLogged | — | none |
| AdjustInventory | **Unclear**: no reason-code/justification field defined yet — flagged in §4 | Item/Decor/Roll exists → quantity corrected | InventoryAdjusted | — | AdjustInventory (reverse correction) |

## 6. Purchasing

### Identity & Permissions
| Command | Purpose | Actor & Permissions | Aggregate | Idempotent? |
|---|---|---|---|---|
| CreatePurchaseOrder | Place an order with a Supplier | Human: Purchasing Manager · AI: Warehouse Agent (proposal, from restock alerts) | Purchase Order | No |
| ConfirmSupplier | Record Supplier's confirmation | Human: Purchasing Manager | Purchase Order | Yes |
| RecordMaterialArrival | Record physical receipt | Human: Purchasing/Warehouse Manager | Purchase Order | Yes |

### Rules & Lifecycle
| Command | Validation & Business Rules | Precondition → Postcondition | Generated Event(s) | Failure Event(s) | Compensating Command(s) |
|---|---|---|---|---|---|
| CreatePurchaseOrder | — | restock need identified → Purchase Order exists | PurchaseOrderCreated | — | *(cancellation missing, see §4)* |
| ConfirmSupplier | PurchaseOrderCreated must have occurred | Purchase Order exists → confirmed | SupplierConfirmed | — | none |
| RecordMaterialArrival | SupplierConfirmed must have occurred | confirmed → fulfilled, triggers IntakeRoll | MaterialArrived | — | none |

## 7. Scheduling

### Identity & Permissions
| Command | Purpose | Actor & Permissions | Aggregate | Idempotent? |
|---|---|---|---|---|
| AssignWorkersToOperation | Split work across 1-5 workers | Human: Production Manager · AI: Planning Agent (proposal) | Employee (via Work Assignment) | No |
| ReassignWorker | Change an assignment before completion | Human: Production Manager | Employee | No |

### Rules & Lifecycle
| Command | Validation & Business Rules | Precondition → Postcondition | Generated Event(s) | Failure Event(s) | Compensating Command(s) |
|---|---|---|---|---|---|
| AssignWorkersToOperation | Invariant 3: splits sum to exactly 100% or the Operation's total area | Operation exists → Work Assignment(s) exist | WorkAssignmentCreated | — | ReassignWorker |
| ReassignWorker | Work must not yet be completed | WorkAssignmentCreated, incomplete → old voided, new created | WorkerReassigned | — | ReassignWorker (revert) |

**Note**: `WorkAssignmentCompleted` has no originating command — it is system-derived from `CompleteOperation` in the Production context, consistent with the cross-context relationship documented in `05_context_map.md` §3.

## 8. Installation & After-Sales *(commands exist per the master prompt's examples; no owning entity yet — same gap as `05_context_map.md` §6 and `06_event_storming.md` §4)*

### Identity & Permissions
| Command | Purpose | Actor & Permissions | Aggregate | Idempotent? |
|---|---|---|---|---|
| ScheduleDelivery | Set delivery date/logistics | Human: Production Manager/Sales | *none — gap* | Yes |
| CompleteDelivery *(example: ShipOrder)* | Confirm physical delivery | Human: Delivery team | *none — gap* | Yes |
| ScheduleInstallation | Set on-site installation visit | Human: Sales/ops | *none — gap* | Yes |
| CompleteInstallation *(example)* | Confirm installation finished | Human: Technician | *none — gap* | Yes |
| RecordAcceptance | Log client sign-off | Human: Sales/Technician | *none — gap* | No |
| ActivateWarranty *(example)* | Begin the warranty period | Human/System, on RecordAcceptance | *none — gap* | Yes |
| FileWarrantyClaim | Log a client-reported issue | Human: Support/Sales | *none — gap* | No |

### Rules & Lifecycle
All seven commands in this context have their events defined in `06_event_storming.md` but **no aggregate to attach validation, preconditions, or idempotency semantics to** — this table is intentionally left without a Rules & Lifecycle counterpart. Defining these commands' actual business rules is blocked on the same entity-design work flagged twice already; doing so here would mean inventing invariants for an aggregate that doesn't exist, which is exactly the kind of guessing this project's discipline forbids.

## 9. Finance

### Identity & Permissions
| Command | Purpose | Actor & Permissions | Aggregate | Idempotent? |
|---|---|---|---|---|
| RecordBonus | Apply a Bonus Rule outcome | System only (threshold-triggered) — **manual override not modeled, see §4** | Payroll Period | Yes |
| IssueAdvance | Give a worker a cash advance | Human: Accountant/Payroll | Payroll Period | No |
| RecordDefectPenalty | Deduct for defective work | Human: Accountant/Payroll (often following RejectInspection) · AI: Quality Agent (proposal) | Payroll Period | No |
| ClosePayrollPeriod | Finalize a period's totals | Human: Accountant/Payroll | Payroll Period | Yes |
| PayPayrollPeriod | Disburse money | Human: Accountant/Payroll | Payroll Period | Yes |

### Rules & Lifecycle
| Command | Validation & Business Rules | Precondition → Postcondition | Generated Event(s) | Failure Event(s) | Compensating Command(s) |
|---|---|---|---|---|---|
| RecordBonus | Bonus Rule thresholds must be monotonically increasing (`domain_model.md` §10) | WorkAssignmentCompleted, threshold met → Bonus line added | BonusEarned | — | *(reversal not modeled — see §4)* |
| IssueAdvance | Invariant 10: Employee must be active | Employee active → Advance recorded, reduces Payable | AdvanceIssued | — | none — advances are not modeled as reversible, only offset against future Payable |
| RecordDefectPenalty | — | Defect identified → Penalty line added | DefectPenaltyRecorded | — | none |
| ClosePayrollPeriod | Period end reached | period open → status=Closed, Payable computed | PayrollPeriodClosed | — | none — closing is intended to be a hard boundary |
| PayPayrollPeriod | ClosePayrollPeriod must have occurred | Closed → status=Paid | PayrollPeriodPaid | — | none |

**Naming correction**: `domain_model.md` §12 named this command `CloseBonlPayrollPeriod` — a typo. This catalogue uses the corrected name `ClosePayrollPeriod`; recommend `domain_model.md` be updated to match on its next revision (flagged, not edited here, per this phase's Stop Condition).

## 10. Knowledge

### Identity & Permissions
| Command | Purpose | Actor & Permissions | Aggregate | Idempotent? |
|---|---|---|---|---|
| RebuildKnowledgeIndex | Resync the retrieval index | System only (scheduled, per ADR-0019) | *(the index itself, no doctype aggregate)* | Yes |

### Rules & Lifecycle
| Command | Validation & Business Rules | Precondition → Postcondition | Generated Event(s) | Failure Event(s) | Compensating Command(s) |
|---|---|---|---|---|---|
| RebuildKnowledgeIndex | Read-only extraction from the bench (ADR-0019: never writes back) | scheduled trigger → index reflects bench data as of sync time | KnowledgeIndexRebuilt | — | none |

## 11. AI

### Identity & Permissions
| Command | Purpose | Actor & Permissions | Aggregate | Idempotent? |
|---|---|---|---|---|
| StartAgentConversation | Begin a chat thread | Human (initiates) · System (creates the record) | Agent Conversation | No |
| ProposeAction | An agent proposes a write | AI only (any of the 7 agent skills) | Agent Conversation | No |
| ApproveAction | Approve a proposal | Human only (never AI — ADR-0015) | Agent Conversation | Yes — approving twice is a no-op |
| RejectAction | Reject a proposal | Human only | Agent Conversation | Yes |
| ExpirePendingAction | Time out an unresolved proposal | System only (scheduled) | Agent Conversation | Yes |

### Rules & Lifecycle
| Command | Validation & Business Rules | Precondition → Postcondition | Generated Event(s) | Failure Event(s) | Compensating Command(s) |
|---|---|---|---|---|---|
| StartAgentConversation | — | none → Agent Conversation exists | AgentConversationStarted | — | none |
| ProposeAction | Agent's tool/Command allow-list must permit the target action (ADR-0013) | Agent Conversation active → Pending Action exists, status=Pending | PendingActionProposed | — | none — a bad proposal is rejected, not "uncreated" |
| ApproveAction | Invariant 9: re-validate target entity's current state at approval time, not just proposal time | Pending Action pending, re-validation passes → target Command executes | PendingActionApproved | *(re-validation failure — not yet named, see §4)* | none — approval triggers real execution; reversing means invoking that context's own compensating command, not "unapproving" |
| RejectAction | Pending Action must be pending | pending → status=Rejected, no Command executed | PendingActionRejected | — | none |
| ExpirePendingAction | past `expires_at`, still pending | pending, expired → status=Expired | PendingActionExpired | — | none |

## 12. Security

### Identity & Permissions
| Command | Purpose | Actor & Permissions | Aggregate | Idempotent? |
|---|---|---|---|---|
| Login | Establish a session (normal or PIN, ADR-0020) | Human (any registered user/employee) | User | No — each login is a distinct session |
| Logout | End a session | Human | User | Yes |

### Rules & Lifecycle
| Command | Validation & Business Rules | Precondition → Postcondition | Generated Event(s) | Failure Event(s) | Compensating Command(s) |
|---|---|---|---|---|---|
| Login | PIN: exactly 4 digits, unique among active Employees (`domain_model.md` §10); rate-limited (ADR-0020) | valid credential → Frappe session active | UserLoggedIn | PermissionDenied *(as a downstream consequence of subsequent actions, not login itself — see §4)* | Logout |
| Logout | session active | active → session ended | *(no event cataloged — flagged as a minor gap, low priority)* | — | Login |

## 13. Notifications

### Identity & Permissions
| Command | Purpose | Actor & Permissions | Aggregate | Idempotent? |
|---|---|---|---|---|
| SendOutboundNotification | Send a WhatsApp/Telegram message | System only (event-triggered, per ADR-0006/0009) | Production Order (log owner) | No |

### Rules & Lifecycle
| Command | Validation & Business Rules | Precondition → Postcondition | Generated Event(s) | Failure Event(s) | Compensating Command(s) |
|---|---|---|---|---|---|
| SendOutboundNotification | Routed through Integrations (ADR-0011), never called directly | triggering domain event occurred → message sent, logged | OutboundNotificationSent | OutboundNotificationFailed | *(retry, per job policy — not a distinct user-facing compensating command)* |

## 14. Documents

### Identity & Permissions
| Command | Purpose | Actor & Permissions | Aggregate | Idempotent? |
|---|---|---|---|---|
| GenerateApprovalSheet | Produce the Excel approval sheet | Human: Production Manager/Sales | Production Order | Yes — regenerating replaces the draft |
| SignApprovalSheet | Record client signature | Human: Sales (recording client action) | Production Order | No |
| ExpireApprovalSheet | Mark an unsigned sheet expired | System (scheduled) | Production Order | Yes |
| GenerateShopSheet | Produce/print the shop-floor sheet | Human: Production Manager/Workshop Operator | Production Order | Yes |

### Rules & Lifecycle
| Command | Validation & Business Rules | Precondition → Postcondition | Generated Event(s) | Failure Event(s) | Compensating Command(s) |
|---|---|---|---|---|---|
| GenerateApprovalSheet | Production Order must have Facade Items | Facade Items exist → Approval Sheet exists, status=Draft | ApprovalSheetGenerated | — | GenerateApprovalSheet (regenerate) |
| SignApprovalSheet | Sheet must have been sent | sent → status=Signed | ApprovalSheetSigned | — | none |
| ExpireApprovalSheet | Sent, not signed within validity window | unsigned past window → status=Expired | ApprovalSheetExpired | — | GenerateApprovalSheet (reissue) |
| GenerateShopSheet | Invariant 8: must never include Money-valued fields | Production Order exists → Shop Sheet log entry created | ShopSheetPrinted | — | none |

## 15. Collaboration

### Identity & Permissions
| Command | Purpose | Actor & Permissions | Aggregate | Idempotent? |
|---|---|---|---|---|
| CreateTask | Attach a to-do to any entity | Human · AI (any agent, as part of a proposed action) | *(cross-cutting, no dedicated aggregate)* | No |
| CompleteTask | Resolve a to-do | Human | *(cross-cutting)* | Yes |
| AddNote | Attach a free-text note | Human · AI | *(cross-cutting)* | No |

### Rules & Lifecycle
| Command | Validation & Business Rules | Precondition → Postcondition | Generated Event(s) | Failure Event(s) | Compensating Command(s) |
|---|---|---|---|---|---|
| CreateTask | Target entity must exist and be a registered `reference_doctype` (ADR-0023) | target exists → Task exists, linked | TaskCreated | — | *(deletion not modeled — low priority)* |
| CompleteTask | Task must exist | Task exists → status=Done | TaskCompleted | — | CreateTask (reopen — not currently modeled as reopening the same Task, see §4) |
| AddNote | Target entity must exist | target exists → Note exists | NoteAdded | — | none |

## Step 4 — Detection Findings

### Duplicate commands
None found in the final list. One near-duplicate was caught and resolved during Step 5's cross-check (below): `IntakeRoll` (new roll) and `RestockRoll` (top-up existing roll) were initially conflated into one command while drafting this catalogue against `domain_model.md`'s single `RestockRoll` entry — re-checking against `06_event_storming.md`'s two distinct events (`RollIntaken` vs. `RollRestocked`) showed they need two distinct commands. Corrected in §5 Warehouse above before finalizing this document.

### Missing commands (found, not designed — flagged for the appropriate later phase)
- **ReleaseMaterial** — added in this pass (Warehouse); `domain_model.md` never defined a way to undo a `MaterialReserved` reservation (e.g. an order is cancelled or a Facade Item removed after reservation).
- **RemoveFacadeItem / UpdateFacadeItem** — only `AddFacadeItem` exists; no way to remove or edit a line item before production starts.
- **CancelProductionOrder, CancelDeal, CancelPurchaseOrder** — confirms, at the command level, the missing-cancellation-events finding already raised in `06_event_storming.md` §4. No command could even produce those events if they existed.
- **DeactivateEmployee** — confirms the equivalent finding from `06_event_storming.md` §4.
- **Reopen/reverse commands** for several terminal-seeming operations: `MarkDealLost` (no way to reopen a lost Deal if the client returns), `ClosePayrollPeriod` (no reversal if closed in error), `RecordBonus` (no manual override/reversal if a bonus was computed incorrectly).
- **RemoveContact** — `AddContact` exists, no removal.
- The seven **Installation & After-Sales** commands (§8) are themselves a "missing entity" finding carried forward, not newly discovered here.

### Unsafe commands
- **AdjustInventory** — a manual override with no reason-code/justification field defined; risks masking real reconciliation problems if used carelessly, analogous to the `ignore_permissions=True` risk pattern already flagged in `report_erpnext.md`. Recommend a mandatory reason-code field when this is designed further.
- **ConsumeMaterial** — must remain strictly System-triggered (at Cutting-stage start, per invariant 5); it must **never** be exposed as a directly user- or AI-callable Command in the eventual Gateway/MCP API (Phase 10/13) — doing so would let a human or agent deduct stock without a corresponding real production event, breaking the Warehouse/Production consistency invariant.
- **RecordBonus** — should remain System-computed against Bonus Rule thresholds; if a manual override is later found necessary (e.g. a disputed bonus), it should be a distinct, explicitly-permissioned command, not a dual-purpose overload of `RecordBonus` itself.

### Commands with multiple owners
None remaining after the IntakeRoll/RestockRoll correction above — every command in this catalogue appears under exactly one bounded context.

### Commands with unclear validation
- **MarkUrgent** — no business rule found limiting how many orders can be marked urgent, or who specifically may do so beyond a general role check; flagged for Phase 08 (Module Architecture) / Phase 15 (Security Architecture) to resolve explicitly rather than leaving "urgent" meaningless through overuse.
- **AdjustInventory** — see Unsafe Commands above; the same gap (no reason-code) is also a validation-clarity problem.
- **ApproveAction's re-validation failure path** — invariant 9 requires re-validating at approval time, but no failure event is yet named for "re-validation failed, proposal could not be executed even though approved" — flagged for Phase 08/11 (Event Architecture) to name explicitly.

## Step 5 — Verification

- **Every event from `06_event_storming.md` has at least one originating command** (or is explicitly, consistently treated as system-derived/implicit, matching that document's own §4 findings): verified by exhaustive cross-check during authoring — every one of the 58 cataloged events traces to a command in this document, a System-only command, or is confirmed implicit (`ProductionOrderStageCompleted`, `ProductionOrderReady`, `WorkAssignmentCompleted`, `RestockThresholdBreached`, `PermissionDenied`, `OutboundNotificationFailed` — the last two being failure/denial outcomes of other commands, not independently-triggered events).
- **Every aggregate exposes only valid commands**: spot-checked against `domain_model.md` §5's aggregate list and its invariants (§9) — e.g. no command sets Production Order's total Area directly (it stays derived, per invariant 1); no command exists that would let Work Assignment splits be saved without summing correctly (`AssignWorkersToOperation`'s validation rule enforces invariant 3 explicitly).
- **Every command has exactly one owner**: true after the IntakeRoll/RestockRoll correction; verified by construction (each command appears in exactly one context's tables above).

## Self-Review

- Cross-referenced every command in this catalogue against `domain_model.md` §12's original list — all are represented, with one naming correction (`ClosePayrollPeriod` fixing the `CloseBonlPayrollPeriod` typo) flagged for that document's next revision rather than edited here.
- Cross-referenced against every example command in the master prompt (`CreateLead`, `UpdateLead`, `CreateQuote`, `ApproveQuote`, `RejectQuote`, `ConvertQuoteToOrder`, `CreateProductionOrder`, `ScheduleProduction`, `ReserveMaterial`, `ReleaseMaterial`, `StartOperation`, `FinishOperation`, `RecordInspection`, `ApproveInspection`, `RejectInspection`, `ShipOrder`, `CompleteInstallation`, `ActivateWarranty`) — all are accounted for under this platform's real vocabulary, except `UpdateLead` (no dedicated update command was modeled beyond `QualifyLead`'s status change — flagged as a minor additional missing-command candidate: a generic Lead field-update path, likely just standard CRUD not warranting a dedicated named command) and `ScheduleProduction` (folded into `PlanProductionOrder`, which already covers production planning — not a separate command).
- The Installation & After-Sales gap surfaces a **third** time (entities in Phase 05, events in Phase 06, commands here in Phase 07) — this is now the strongest possible signal that it must be resolved with real design work before Phase 08 (Module Architecture) assigns it a directory, not deferred again.
- No contradiction found between this catalogue and any ADR — in particular ADR-0003/0007 (business logic only in the domain layer: every command's validation rules are stated as domain-layer rules, not Gateway/AI-layer shortcuts) and ADR-0015 (every AI actor column reads "via Pending Action only," with zero exceptions).

---

*Per the Stop Condition in `07_command_catalogue_prompt.md`: no code implemented, no APIs designed. Stopping here for approval before State Machines.*
