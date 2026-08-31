---
name: korkem-domain-service
description: How to add a new business action to KORKEM, or extract an existing one out of the AI tool layer into a domain service reachable by every client. Load when implementing any action that changes business state — start production, close an operation, receive a delivery, assign work, create a purchase — or when moving code out of korkem_ai/tools/.
---

# Adding a business action to KORKEM

Every business action in KORKEM is **one domain service** with **four faces**:

```
korkem_manufacturing/domain/<area>.py     ← the rule. one function. no HTTP, no model.
korkem_manufacturing/api/<area>.py        ← @frappe.whitelist wrapper. permission + audit.
korkem_ai/tools/<area>.py                 ← ToolSpec. schema + summarise + calls the service.
mobile/korkem_flow/lib/features/…         ← screen calls the API endpoint. never a doctype.
```

Write them in that order. A `ToolSpec` without a service underneath it is the
mistake this skill exists to prevent (`korkem-architecture` R1, R2, R3).

---

## 1. The domain function

Lives in `korkem_manufacturing`. Takes plain arguments, returns plain data,
raises `frappe.ValidationError` with a sentence a person can act on.

```python
def start_production(sales_order: str, qty: float | None = None) -> dict:
	"""Move material to WIP and put a work order In Process.

	Readiness is physical, not procurement: a purchase order for the board
	does not let anybody cut it. Re-checked here rather than trusted from the
	caller, because somebody else may have consumed the same board since.
	"""
```

Rules for this layer:

- **No `frappe.session.user` branching.** Who is calling is the API layer's
  business. The domain answers "may this happen", not "may *you* do it".
- **Company scope is an argument**, resolved by the caller — never read from a
  request.
- **Never write stock, status or a ledger by hand.** Call ERPNext's own mapper
  (`make_stock_entry`, `make_job_card`, `make_delivery_note`) and let its
  status transitions run. A hand-set `Bin` desynchronises the ledger from
  the shelf and nothing downstream can tell.
- **Re-validate at execution.** Anything checked when a proposal was made must
  be checked again when it is carried out.

## 2. The API endpoint

```python
@frappe.whitelist()
def start_production(sales_order: str, qty: float | None = None) -> dict:
	company = scope.current_company()
	scope.ensure_company("Sales Order", sales_order)
	frappe.only_for(("Production Manager", "Manufacturing Manager"))
	result = domain.start_production(sales_order, qty, company=company)
	audit.record("production.start", sales_order, result)
	return result
```

Rules:

- **Permission before work**, always, and by role or doctype permission — never
  by a flag the client sent.
- **Company scope resolved here** from the session, then passed down.
- **Audit after the write**, with enough to answer "who changed this and why"
  a year later.
- Type-annotate: `require_type_annotated_api_methods = True` is on in
  `hooks.py`, so an unannotated whitelisted method is rejected at load.

## 3. The AI tool

```python
register(ToolSpec(
	name="manufacturing.start_production",
	description="Запустить производство по заказу…",
	input_schema={…},
	risk=Risk.WRITE,                 # → requires confirmation
	doctypes=("Sales Order", "Work Order", "Stock Entry"),
	audit_category="production",
	summarise=lambda **kw: f"Запустить производство по {kw['sales_order']}",
	handler=api.start_production,    # ← the same function the button calls
))
```

Rules:

- `handler` points at the **API function**, not a copy of the logic.
- `risk=Risk.WRITE` or `DESTRUCTIVE` makes confirmation mandatory. Never
  declare a write as `READ` to skip the card.
- `summarise` builds the sentence the person agrees to, from the same
  arguments the call carries. A write with a price or a quantity on it must
  have one; confirming against the model's own prose is not good enough.
- `doctypes` hides the tool from a user who cannot touch them at all.

## 4. The client

The screen calls the endpoint. It does **not** call `/api/resource/<Doctype>`
for anything it intends to act on, and it does not go through `chat.send` to
perform a deterministic action.

```dart
await _client.call('korkem_manufacturing.api.production.start_production',
    {'sales_order': id});
```

---

## Extracting an existing action out of `korkem_ai/tools/`

The migration that Horizon 1 of `ROADMAP.md` is made of. Per action:

1. **Read the whole tool module first**, including its tests. The comments in
   `tools/production.py` carry the reasoning; it must survive the move.
2. **Move the function body** to `korkem_manufacturing`, unchanged. Do not
   improve it in the same commit — a behaviour change hidden inside a move is
   unreviewable.
3. **Move its tests too**, and run them where they now live.
4. **Replace the tool body** with a call to the new API function.
5. **Run both suites.** The tool's own tests must still pass untouched. If a
   tool test needed editing, the move changed behaviour — find out why.
6. **Then** wire the button, in a separate commit.

Do one action per commit. `tools/production.py` alone is 2 096 lines; a single
commit moving all of it cannot be reviewed and cannot be reverted cleanly.

## After any line-range extraction, scan for undefined names

Cutting a block out by line range moves the code and **not its imports**. The
result still compiles — `python -m py_compile` only checks syntax — and fails
at runtime, once, deep inside a call, where the tool layer wraps it as a
generic "That could not be completed."

Moving the shop floor cost 58 failures and 11 errors for exactly this: the
hand-written import line said `flt, now_datetime`, and the block also used
`add_to_date` and `get_datetime`. Ten seconds of scanning would have found it
before a nine-minute suite did:

```python
import ast, builtins
tree = ast.parse(open("services/<new>.py").read())
defined = set(dir(builtins))
for node in ast.walk(tree):
    if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
        defined.add(node.name)
        defined |= {a.arg for a in node.args.args + node.args.kwonlyargs}
    elif isinstance(node, ast.Name) and isinstance(node.ctx, ast.Store):
        defined.add(node.id)
    elif isinstance(node, (ast.Import, ast.ImportFrom)):
        for a in node.names:
            defined.add(a.asname or a.name.split(".")[0])
    elif isinstance(node, ast.comprehension) and isinstance(node.target, ast.Name):
        defined.add(node.target.id)
    elif isinstance(node, ast.ExceptHandler) and node.name:
        defined.add(node.name)
used = {n.id for n in ast.walk(tree) if isinstance(n, ast.Name) and isinstance(n.ctx, ast.Load)}
print(sorted(used - defined))
```

Better still: copy the source module's import block verbatim and delete what is
unused, rather than writing a new one from memory of what the code needs.

## Checklist before calling it done

- [ ] domain function has no session, no HTTP, no model
- [ ] API function checks permission and company scope, and writes an audit row
- [ ] tool handler calls the API function, declares real risk, has `summarise`
- [ ] tests exist at the domain level, not only through the tool
- [ ] the action works with the LLM switched off
- [ ] the action refuses correctly for a user of another company
- [ ] `bench --site korkem.localhost run-tests --app korkem_manufacturing` and
      `--app korkem_ai` both green — output pasted, not assumed
