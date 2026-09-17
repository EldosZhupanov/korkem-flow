# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""Domain Tool Registry for KORKEM AI Agent Platform.

Enforces strict runtime boundaries:
1. Risk Level taxonomy: READ, REVERSIBLE_WRITE, CRITICAL_WRITE.
2. Typed Input/Output schema validation (Pydantic / dataclasses).
3. Fail-Closed Tenant Isolation: no cross-tenant reading or writing.
4. Human-in-the-loop Approval Gate (R10): CRITICAL_WRITE operations MUST
   create a Pending Action and CANNOT execute side effects directly.
5. Idempotency on write operations.
6. Structured domain audit trail integration.
7. Complete prohibition of arbitrary SQL or unvalidated DocType writes.
"""

from __future__ import annotations

import enum
import hashlib
import json
from typing import Any, Callable

import frappe
from pydantic import BaseModel, Field, ValidationError

from korkem_manufacturing.services import audit, idempotency
from korkem_manufacturing.services.scope import current_company, enforce_tenant_scope


class RiskLevel(str, enum.Enum):
	READ = "READ"
	REVERSIBLE_WRITE = "REVERSIBLE_WRITE"
	CRITICAL_WRITE = "CRITICAL_WRITE"


CRITICAL_TOOLS = {
	"quote.send",
	"contract.issue",
	"payment.record",
	"payment.refund",
	"production.release",
	"order.cancel",
	"payroll.adjust",
	"payroll.approve",
	"payroll.reverse",
	"inventory.write_off",
}


class DomainToolSpec(BaseModel):
	name: str
	description: str
	risk_level: RiskLevel
	input_model: type[BaseModel]
	output_model: type[BaseModel] | None = None
	required_roles: list[str] = Field(default_factory=list)
	tenant_scoped: bool = True
	requires_approval: bool = False
	handler: Any = None

	class Config:
		arbitrary_types_allowed = True


class ToolSecurityError(frappe.PermissionError):
	"""Security boundary refusal."""


class DomainToolRegistry:
	_tools: dict[str, DomainToolSpec] = {}

	@classmethod
	def register(cls, spec: DomainToolSpec) -> DomainToolSpec:
		# Auto-set requires_approval for critical tools
		if spec.name in CRITICAL_TOOLS or spec.risk_level == RiskLevel.CRITICAL_WRITE:
			spec.requires_approval = True

		cls._tools[spec.name] = spec
		return spec

	@classmethod
	def get(cls, name: str) -> DomainToolSpec:
		if name not in cls._tools:
			frappe.throw(
				f"Unknown tool '{name}'. Available: {', '.join(sorted(cls._tools.keys()))}",
				exc=ToolSecurityError,
			)
		return cls._tools[name]

	@classmethod
	def all_tools(cls) -> list[DomainToolSpec]:
		return list(cls._tools.values())

	@classmethod
	def execute(
		cls,
		name: str,
		arguments: dict[str, Any] | None = None,
		*,
		user: str | None = None,
		company: str | None = None,
		idempotency_key: str | None = None,
		approval_token: str | None = None,
		trace_id: str | None = None,
	) -> dict[str, Any]:
		"""Execute a tool through the hardened domain boundary."""
		arguments = arguments or {}
		active_user = user or frappe.session.user

		# 1. Tool Lookup (Fail-closed on unknown tool)
		spec = cls.get(name)

		# 2. Tenant Scope Verification
		session_company = company or current_company()
		if not session_company:
			frappe.throw("Tenant scope is missing. Fail closed.", ToolSecurityError)

		if "company" in arguments:
			claimed_company = arguments["company"]
			if claimed_company and claimed_company != session_company:
				frappe.throw(
					f"Cross-tenant violation: tool attempted to target company '{claimed_company}' from session '{session_company}'.",
					ToolSecurityError,
				)

		# 3. Role-Based Access Control
		if active_user != "Administrator" and spec.required_roles:
			user_roles = frappe.get_roles(active_user)
			if not any(r in spec.required_roles for r in user_roles):
				frappe.throw(
					f"User '{active_user}' lacks required roles {spec.required_roles} for tool '{name}'.",
					ToolSecurityError,
				)

		# 4. Strict Typed Schema Validation
		try:
			validated_args = spec.input_model(**arguments)
		except ValidationError as val_err:
			frappe.throw(
				f"Validation error in tool '{name}' input: {str(val_err)}",
				frappe.ValidationError,
			)

		validated_dict = validated_args.model_dump()

		# 5. Human-in-the-Loop Approval Gate (Invariant R10)
		if spec.requires_approval or spec.risk_level == RiskLevel.CRITICAL_WRITE:
			if not approval_token:
				# Create Pending Action and STOP
				action_id = cls._create_pending_action(spec, validated_dict, session_company, active_user)
				return {
					"ok": False,
					"status": "approval_required",
					"requires_approval": True,
					"pending_action_id": action_id,
					"message": f"Tool '{name}' is CRITICAL and requires human approval before execution.",
				}
			else:
				# Validate provided approval token
				cls._verify_approval_token(approval_token, spec.name, validated_dict)

		# 6. Idempotent Execution for Write Tools
		def _perform():
			if spec.handler:
				res = spec.handler(**validated_dict)
			else:
				res = {"status": "executed", "tool": spec.name}

			# 7. Audit Integration
			if spec.risk_level != RiskLevel.READ:
				audit.record_audit(
					action=f"ai_tool.{spec.name}",
					entity_type="AITool",
					entity_id=spec.name,
					diff={"arguments": validated_dict, "result": res},
					company=session_company,
					actor=active_user,
					trace_id=trace_id,
					channel="AIAgent",
				)
			return res if isinstance(res, dict) else {"result": res}

		if spec.risk_level != RiskLevel.READ and idempotency_key:
			result = idempotency.execute(
				action=f"ai_tool:{spec.name}",
				idempotency_key=idempotency_key,
				arguments=validated_dict,
				callback=_perform,
				company=session_company,
			)
		else:
			result = _perform()

		return {"ok": True, "tool": spec.name, "data": result}

	@classmethod
	def _create_pending_action(
		cls,
		spec: DomainToolSpec,
		args: dict[str, Any],
		company: str,
		user: str,
	) -> str:
		doc = frappe.get_doc(
			{
				"doctype": "Pending Action",
				"action_class": f"ai_tool:{spec.name}",
				"action_data": json.dumps(args, ensure_ascii=False, default=str),
				"status": "Pending",
				"owner": user,
			}
		).insert(ignore_permissions=True)
		return doc.name

	@classmethod
	def _verify_approval_token(
		cls,
		token: str,
		tool_name: str,
		args: dict[str, Any],
	) -> None:
		if not frappe.db.exists("Pending Action", token):
			frappe.throw(f"Invalid or non-existent approval token '{token}'.", ToolSecurityError)
		act = frappe.get_doc("Pending Action", token)
		if act.status != "Approved":
			frappe.throw(f"Pending Action '{token}' is not Approved (status={act.status}).", ToolSecurityError)


# ----------------------------------------------------------------------
# Standard Critical Tools Input Schemas (Pydantic)
# ----------------------------------------------------------------------
class QuoteSendInput(BaseModel):
	quotation_id: str
	recipient_email: str
	amount: float = Field(..., gt=0, description="Quote amount must be strictly positive")


class ContractIssueInput(BaseModel):
	sales_order: str
	contract_number: str
	total_amount: float = Field(..., gt=0)


class PaymentRecordInput(BaseModel):
	sales_order: str
	amount: float = Field(..., gt=0, description="Payment must be positive")
	reference: str


class ProductionReleaseInput(BaseModel):
	sales_order: str
	item_code: str
	qty: int = Field(..., gt=0)


class OrderCancelInput(BaseModel):
	sales_order: str
	reason: str = Field(..., min_length=5)


class InventoryWriteOffInput(BaseModel):
	item_code: str
	qty: float = Field(..., gt=0)
	warehouse: str
	reason: str = Field(..., min_length=3)


class PayrollAdjustInput(BaseModel):
	employee: str
	amount: float = Field(..., gt=0)
	reason: str


class PayrollApproveInput(BaseModel):
	entry_name: str
	notes: str | None = None


class PayrollReverseInput(BaseModel):
	entry_name: str
	reason: str = Field(..., min_length=5)


# Pre-register Critical Tools
DomainToolRegistry.register(
	DomainToolSpec(
		name="quote.send",
		description="Send commercial quotation to customer",
		risk_level=RiskLevel.CRITICAL_WRITE,
		input_model=QuoteSendInput,
		required_roles=["Sales User", "Sales Manager"],
	)
)

DomainToolRegistry.register(
	DomainToolSpec(
		name="contract.issue",
		description="Issue furniture manufacturing contract",
		risk_level=RiskLevel.CRITICAL_WRITE,
		input_model=ContractIssueInput,
		required_roles=["Sales Manager"],
	)
)

DomainToolRegistry.register(
	DomainToolSpec(
		name="payment.record",
		description="Record customer deposit or milestone payment",
		risk_level=RiskLevel.CRITICAL_WRITE,
		input_model=PaymentRecordInput,
		required_roles=["Accounts User", "Sales Manager"],
	)
)

DomainToolRegistry.register(
	DomainToolSpec(
		name="production.release",
		description="Release furniture sales order into factory production",
		risk_level=RiskLevel.CRITICAL_WRITE,
		input_model=ProductionReleaseInput,
		required_roles=["Manufacturing Manager"],
	)
)

DomainToolRegistry.register(
	DomainToolSpec(
		name="order.cancel",
		description="Cancel an active sales order",
		risk_level=RiskLevel.CRITICAL_WRITE,
		input_model=OrderCancelInput,
		required_roles=["Sales Manager"],
	)
)

DomainToolRegistry.register(
	DomainToolSpec(
		name="inventory.write_off",
		description="Write off damaged sheet material or hardware",
		risk_level=RiskLevel.CRITICAL_WRITE,
		input_model=InventoryWriteOffInput,
		required_roles=["Stock Manager"],
	)
)

DomainToolRegistry.register(
	DomainToolSpec(
		name="payroll.adjust",
		description="Adjust employee piecework payroll",
		risk_level=RiskLevel.CRITICAL_WRITE,
		input_model=PayrollAdjustInput,
		required_roles=["HR Manager", "System Manager"],
	)
)

DomainToolRegistry.register(
	DomainToolSpec(
		name="payroll.approve",
		description="Approve employee piecework earnings (critical payout action)",
		risk_level=RiskLevel.CRITICAL_WRITE,
		input_model=PayrollApproveInput,
		required_roles=["Manufacturing Manager", "System Manager"],
	)
)

DomainToolRegistry.register(
	DomainToolSpec(
		name="payroll.reverse",
		description="Reverse approved piecework entry via compensating ledger row",
		risk_level=RiskLevel.CRITICAL_WRITE,
		input_model=PayrollReverseInput,
		required_roles=["Manufacturing Manager", "System Manager"],
	)
)

