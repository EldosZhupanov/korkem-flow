# Architecture Research Report — ERPNext

Produced per `.ai/research/architecture_research.md`. Research only — no code was modified, refactored, or generated. Repository studied: `erpnext/` (ERPNext ERP application, a Frappe-framework app; sibling `frappe/` is the underlying framework it depends on).

---

## Executive Summary

ERPNext is a mature, large, metadata-driven ERP built as a Frappe framework "app." Every business object (Work Order, BOM, Item, Sales Order, etc.) is a **DocType**: a JSON schema + Python controller + JS client script triad, generated into a database table and a generic form/list UI by the underlying framework. The codebase is a **modular monolith organized by business domain** (accounts, stock, manufacturing, selling, buying, quality_management, projects, support, …), not by technical layer — closer to package-by-feature / bounded-context organization than classic n-tier. Extension happens declaratively through `hooks.py` (lifecycle events, scheduled jobs, regional overrides, permission hooks) rather than through a plugin SDK. The framework beneath it (`frappe/frappe/client.py` + `/api/resource/*`) already provides a **generic, stable CRUD API over any DocType**, plus ERPNext itself exposes 800+ domain-specific whitelisted RPC functions — which together make ERPNext unusually AI-automatable out of the box, provided the calling agent authenticates with an appropriately permissioned user.

## Architecture Summary

- **Style**: Modular monolith / package-by-feature. Not classic layered/hexagonal/clean architecture; not microservices; not event-sourced or CQRS.
- **Object model**: Every DocType inherits `frappe.model.document.Document`. ERPNext layers reusable transactional behavior via an explicit inheritance chain in `erpnext/erpnext/controllers/`: `StatusUpdater(Document) → TransactionBase → AccountsController(TransactionBase) → StockController(AccountsController) → SubcontractingController(StockController) → BuyingController(SubcontractingController)`, with `SellingController(StockController)` as a sibling branch. This is a **template-method/layered mixin** design giving shared GL-posting, stock-ledger, and status-update logic to all transactional doctypes without duplication. Some doctypes (e.g. `BOM(WebsiteGenerator)`) inherit specialized bases instead.
- **Observer pattern**: `hooks.py`'s `doc_events` dict maps DocType (or `"*"` wildcard) + lifecycle event (`validate`, `on_submit`, `on_cancel`, `after_insert`, `on_trash`) → dotted-path callables. This decouples cross-module side effects (e.g. Stock Entry submission updating Material Request quantities) from the emitting doctype's own controller — a textbook Observer/pub-sub mechanism, framework-native rather than hand-rolled.
- **Factory/Command-like elements**: `mapper.py` files per doctype use Frappe's `get_mapped_doc` to construct one document from another (Sales Order → Work Order, BOM → Stock Entry), invoked from UI "Create" buttons.
- **No explicit service/repository layer**: business logic sits directly in DocType controllers or shared `controllers/*.py` mixins. A few doctypes (Work Order, BOM) extract cohesive logic into local `services/` submodules, but this isn't a framework-wide convention — most controllers are large, procedural, and organized as a pipeline of small `validate_*`/`set_*` methods called from one top-level `validate()` (confirmed in `work_order.py` and `bom.py`).
- **Regional variation via hook override**: `regional_overrides` in `hooks.py` maps country name → base-function-path → country-specific override, letting country-specific tax/GL logic replace core behavior without forking (implemented under `erpnext/regional/<country>/`).

## Technology Stack

- **Backend**: Python ≥3.14 (per `pyproject.toml`), Frappe framework ≥17.0.0-dev,<18.0.0. Build backend `flit_core`.
- **Database**: Dual-engine by design — **MariaDB** (default/primary) and **PostgreSQL** (secondary, actively CI-tested). A dedicated doc (`.github/POSTGRES_COMPATIBILITY.md`) codifies the rule "MariaDB behavior must not change; PostgreSQL is brought into line with MariaDB, never the reverse," with dozens of catalogued SQL-portability pitfalls and a custom pre-commit hook (`postgres_compat.py`) that statically flags MySQL-only SQL.
- **Frontend**: Overwhelmingly the generic **Frappe Desk** (metadata-driven forms/lists/reports, jQuery-style client scripts). One exception: `banking/` is a self-contained **React 19 + Vite + Tailwind 4** SPA (`frappe-react-sdk`, `@tanstack/react-table`, `jotai`, `radix-ui`) built separately and mounted at `/banking.html` — a carved-out modern micro-frontend for bank reconciliation, not a platform-wide UI replacement.
- **Testing**: Frappe's own unittest-based runner (`bench run-tests`), not pytest — `test_*.py` colocated per doctype plus a top-level `erpnext/erpnext/tests/` folder. No browser/e2e test suite found in this snapshot.
- **Linting/formatting**: `ruff` (line-length 110, py310 target) + legacy `.flake8` (lenient: max-line-length 200, many codes ignored), `.eslintrc`/`.stylelintrc` for JS/CSS, `.pre-commit-config.yaml` (trailing-whitespace/yaml/json/toml checks, `no-commit-to-branch` guard on `develop`, prettier, eslint, ruff, postgres-compat).
- **CI/CD**: 24 GitHub Actions workflows — sharded MariaDB/Postgres server tests, linters, semantic-release automation (`.releaserc`), Crowdin translation sync, Docker image publishing. No Dockerfile lives in this repo; Docker setup is delegated to the separate `frappe_docker` project.
- **i18n**: Crowdin-managed translations (`crowdin.yml`, `gettext/`, `locale/`).

## Folder Structure

```
erpnext/                    repo root (README, pyproject.toml, CODEOWNERS, .github/)
├── banking/                 React/Vite/Tailwind micro-frontend (bank reconciliation)
└── erpnext/                 the Frappe "app" package
    ├── hooks.py              central extension/integration wiring (see Extension Points)
    ├── modules.txt           module list shown in Desk
    ├── patches.txt           ordered DB migration patch list
    ├── controllers/          shared base controllers (accounts/stock/buying/selling mixins)
    ├── accounts/  assets/  buying/  selling/  stock/  manufacturing/
    ├── quality_management/  projects/  support/  maintenance/  subcontracting/
    ├── crm/  edi/  telephony/  portal/  shopping_cart/
    ├── regional/<country>/   country-specific overrides
    ├── patches/v*/           versioned migration scripts
    ├── public/  www/  templates/   static assets, web routes, Jinja pages
    └── tests/                 top-level integration tests
```
Every business module follows the canonical per-doctype layout: `<module>/doctype/<name>/{<name>.json, .py, .js, test_<name>.py, README.md}`, optionally with `mapper.py` (doc-to-doc factory), `_dashboard.py` (linked-doc counts), `_list.js`/`_calendar.js` (UI helpers), and occasionally a local `services/` package.

## Domain Model

Core manufacturing chain, confirmed via actual `Link` fields in DocType JSON schemas:

**Sales Order → Work Order → BOM → Item/Warehouse**, and **Work Order → Job Card → Operation/Workstation**, with **Quality Inspection** cross-cutting via Job Card and BOM.

| Entity | Path | Key relationships (Link fields) |
|---|---|---|
| Work Order | `manufacturing/doctype/work_order/` | `production_item→Item`, `bom_no→BOM`, `sales_order→Sales Order`, `wip/fg/scrap/source_warehouse→Warehouse`, `material_request→Material Request`, self-ref `amended_from→Work Order` |
| BOM | `manufacturing/doctype/bom/` | `item→Item`, `routing→Routing`, `quality_inspection_template→Quality Inspection Template`, `default_source/target_warehouse→Warehouse`; child tables `items`(BOM Item), `operations`(BOM Operation), `exploded_items` (computed) |
| Job Card | `manufacturing/doctype/job_card/` | `work_order→Work Order`, `bom_no→BOM`, `workstation→Workstation`, `operation→Operation`, `quality_inspection→Quality Inspection` |
| Stock Entry | `stock/doctype/stock_entry/` | `work_order→Work Order`, `bom_no→BOM`, `from/to_warehouse→Warehouse`, `job_card→Job Card`; child table `items`(Stock Entry Detail) — the literal join point between manufacturing and stock movement |
| Item | `stock/doctype/item/` | `item_code` unique key; `variant_of→Item` (self-ref); child tables `barcodes`, `uoms`, `attributes`, `item_defaults`, `supplier_items` |
| Routing/Operation/Workstation | `manufacturing/doctype/{routing,operation,workstation}/` | operation sequencing and machine/work-center assignment |
| Purchase Order / Sales Order / Quotation / Delivery Note / Quality Inspection | `buying/`, `selling/`, `stock/` doctypes | standard procure-to-pay / order-to-cash chain |

**Business-rule style**: Both `work_order.py::validate()` and `bom.py::validate()` are long, explicit pipelines of ~15-20 small single-purpose `validate_*`/`set_*` methods called from one top-level `validate()` — procedural but decomposed, favoring readability/testability over an OO rules-engine or strategy-pattern abstraction. Backed by very large test suites (Work Order: 175KB/5,417 lines; BOM: 31KB).

## Database Model

Each DocType JSON schema **is** the table DDL: `fields[]` → columns; `fieldtype: Link` → FK-like reference (`options` names the target doctype); `fieldtype: Table` → one-to-many child table (Frappe auto-adds `parent`/`parenttype`/`parentfield` columns); `unique`/`reqd`/`search_index` map to DB constraints/indexes.

- `Item.item_code`: `Data`, `reqd + unique` — one of the few explicit DB-level unique constraints found.
- `Work Order`: 10+ Link fields, 4 Table (child) fields, several `fetch_from` denormalized lookups (e.g. `item_name` fetched from `production_item.item_name`).
- `BOM`: `search_fields: "item, item_name"`, conditional field visibility via `depends_on` driven by booleans (`is_active`, `is_phantom_bom`, `track_semi_finished_goods`).
- `Stock Entry`: 30+ Link fields — the highest fan-in doctype observed, confirming its role as the central stock-movement join table.
- Naming: transactional doctypes use `naming_series` (e.g. `MFG-WO-.YYYY.-`); `Item` uses `autoname: "field:item_code"` (business key as primary name).
- No visible explicit migration-versioning tool beyond Frappe's own `patches.txt` + `patches/v*/` mechanism (ordered patch list run by `bench migrate`).

## API Summary

- **Whitelisted RPC**: 812 `@frappe.whitelist()` functions across `erpnext/` alone, each callable via `POST /api/method/<dotted.path>` (e.g. `work_order.make_bom`, `work_order.close_work_order`, `stock/get_item_details.py` helpers). Permission checks are enforced *inside* these functions via `frappe.has_permission(...)`, not only at the doctype-declaration level.
- **Generic CRUD**: the underlying framework (`frappe/frappe/client.py`, `frappe/frappe/api/`) exposes doctype-agnostic whitelisted functions (`get_list`, `get`, `insert`, `save`, `submit`, `cancel`, `delete`, `bulk_update`, `rename_doc`, …) plus REST conventions `/api/resource/{doctype}` (list/create) and `/api/resource/{doctype}/{name}` (read/update/delete) — usable against **any** DocType without an ERPNext-specific wrapper.
- **No GraphQL** anywhere in the repo.
- **Background jobs**: `frappe.enqueue(...)` used 39 times directly in `erpnext/` (e.g. BOM cost recalculation, stock-ledger reposting, bulk transaction processing), several with `enqueue_after_commit=True` and custom timeouts/queues (`queue="long"`).
- **Realtime**: `frappe.publish_realtime(...)` pushes websocket progress events (e.g. `"item_reposting_progress"` during stock-ledger reposting, workstation status) — a pub/sub-over-websocket pattern, not external webhooks.
- **Permissions**: role-based, declared per-DocType JSON (`role`, `read/write/create/delete/submit/cancel/...`, optional `permlevel` for field-level restriction) and enforced both declaratively and programmatically.

## Extension Points

`erpnext/erpnext/hooks.py` (~740 lines) is the single central extension file:
- `doc_events` (Observer-style lifecycle hooks), `scheduler_events` (cron + named buckets: hourly/daily/etc. wiring background jobs), `regional_overrides` (per-country function substitution), `permission_query_conditions`/`has_permission` (row-level permission injection), `website_route_rules`/`website_generators` (public portal exposure), `doctype_js` (per-doctype client-script override injection), lifecycle installs (`after_install`, `after_app_install`).
- `patches.txt` + `patches/v*/` — ordered schema/data migrations run by `bench migrate`.
- Beyond files: the standard Frappe extension model also includes downstream **custom apps** layered on top of ERPNext, and runtime/DB-level customizations (Custom Fields, Custom Scripts, Server Scripts, Property Setters) added via the Desk UI — these don't appear as repo files since they're database records, not code artifacts.
- No `fixtures` hook declared by ERPNext itself (fixtures are a downstream-app concern).

## Strengths

- Extremely mature, battle-tested domain model for manufacturing/ERP — the Sales→Work Order→BOM→Job Card→Stock chain already encodes years of real-world business-rule refinement (confirmed via the dense `validate()` pipelines).
- Framework-level generic CRUD API (`frappe/frappe/client.py`) plus 800+ domain RPC functions give an unusually strong out-of-the-box automation/integration surface.
- Declarative, file-based extension model (`hooks.py`, DocType JSON) is highly legible — architecture intent is discoverable by reading config, not by tracing framework internals.
- Dual-database compatibility discipline (MariaDB/Postgres) shows real engineering rigor around portability, backed by an explicit, well-documented policy and automated enforcement (pre-commit + CI).
- Reasonable test-file density (~19-23% of files in stock/manufacturing are tests) with very large, thorough test suites for core transactional doctypes.
- CODEOWNERS routes review by domain, indicating enforced subject-matter-expert review rather than open commit.

## Weaknesses

- No service/repository layer separating business logic from the ORM-like Document controller — logic lives directly in fat controller files, several exceeding 1,500-3,700 lines (`stock_ledger.py` 2,706 lines, `serial_and_batch_bundle.py` 3,686 lines, `bom.py` 1,464 lines, `job_card.py` 1,877 lines). This is a real maintainability liability for anyone extending core manufacturing/stock logic.
- UI is almost entirely generic Desk forms — there is no coherent modern frontend architecture to build on for a differentiated UX; the one React micro-app (banking) is isolated and not representative of the platform.
- `ignore_permissions=True` appears in ~10 non-test source files in `stock/` and 1 in `manufacturing/`, concentrated in ledger/reposting logic — defensible individually but each is a place where the declared RBAC model is silently bypassed and must be manually re-verified.
- Business logic is procedural (long validate pipelines) rather than encapsulated in explicit rule/strategy objects — easy to read linearly, harder to unit-test or reuse pieces in isolation.
- No dedicated architecture/design documentation beyond `POSTGRES_COMPATIBILITY.md` and per-doctype one-line READMEs — most architectural knowledge is implicit in code, not written down.

## Risks

- **Tight coupling to Frappe framework internals**: ERPNext cannot be understood or reused independently of `frappe/` — any adoption commits to the whole Frappe stack (ORM, permissions, job queue, Desk UI runtime), not just ERPNext's domain logic.
- **Large-file hotspots** (`stock_ledger.py`, `serial_and_batch_bundle.py`) are single points of failure for core valuation/traceability logic — bugs or performance issues there have wide blast radius.
- **Permission bypass surface**: the `ignore_permissions=True` call sites need explicit inventory and justification before trusting the API layer as a complete authorization boundary for AI-driven automation.
- **Postgres is the "second-class" backend** by explicit policy — any deployment choosing Postgres inherits an ongoing compatibility-maintenance burden that MariaDB does not have.
- **No e2e/browser test suite found** — regressions in cross-doctype workflows (e.g. full Sales Order → Work Order → Job Card → Delivery flow) rely on unit-level `test_*.py` coverage rather than integration/browser tests.

## Scalability

Background-job offloading (`frappe.enqueue`, dedicated queues/timeouts for BOM cost recalculation and stock reposting) and realtime progress publishing show the framework already accounts for long-running/heavy operations at scale. However, the domain logic itself (e.g. BOM explosion, stock valuation) is centralized in a few very large modules, which will concentrate performance risk as transaction volume grows — horizontal scaling of the *application tier* is a Frappe/bench operational concern (multiple workers, Redis-backed queues) rather than something this repo's code structure blocks or specifically enables.

## Maintainability

Mixed. The declarative parts (DocType JSON, `hooks.py`) are highly maintainable — configuration-as-code that's easy to audit and extend without touching framework internals. The imperative parts (large controller files, procedural validation pipelines with no rule-object abstraction) are harder to maintain safely at scale, especially for a team unfamiliar with Frappe conventions. CODEOWNERS-enforced review and strong test-file density partially offset this.

## AI Integration Potential

High, and this is ERPNext/Frappe's strongest asset for the furniture_ai mission. The framework already provides:
1. A **generic, doctype-agnostic CRUD API** (`frappe/frappe/client.py` + `/api/resource/*`) that lets an AI agent create/read/update/delete/list *any* business object (Work Order, BOM, Item, etc.) without ERPNext-specific code, enforced through the same role/permission system as the human UI.
2. **800+ pre-built domain-specific RPC functions** (`@frappe.whitelist()`) for higher-level operations beyond generic CRUD (e.g. computing item details, closing a work order, generating a BOM from a Work Order).
3. **Async/background-job support** and **realtime pub/sub** for operations that can't complete synchronously — relevant for AI-triggered long-running production/stock recalculations.
4. **Declarative lifecycle hooks** (`doc_events`, `scheduler_events`) as a natural place to wire AI-driven side effects (e.g. auto-trigger an AI risk assessment on `Work Order.on_submit`) without modifying core ERPNext code.

The main caveat for AI use: the `ignore_permissions=True` bypass points mean the permission system is not a 100%-complete authorization boundary, so an AI agent's effective authority should be scoped carefully (dedicated API user/role) rather than assumed fully bounded by DocType permissions alone.

## Overall Score

**7.5 / 10** for use as a foundational manufacturing domain-model and integration backend. Very strong domain model, extension model, and AI-facing API surface; held back by large-file/procedural-logic maintainability debt and a UI layer (generic Desk) that is not a good foundation for the "Linear + Notion"-grade AI-native UX described in `PROJECT.md`. Recommendation direction (pending the remaining reports for Frappe/CRM/Relaticle before a final cross-repo recommendation): **reuse the domain model and API layer** (ERPNext-as-backend via its REST/RPC surface), **do not build the new product's UI on top of Frappe Desk**.

---

*Next per the research prompt: Frappe Framework, then Frappe CRM, then Relaticle — one report at a time, each awaiting approval before proceeding. This report covers ERPNext only.*
