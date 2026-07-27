# Backend API Audit — verified facts

> Every statement here was verified against the **running** backend at `http://korkem.localhost:8000`
> or against the vendored source on disk. Nothing is assumed. This document is the factual base for
> [`api_mapping.md`](./api_mapping.md) — if a claim is not here, it was not verified.
>
> Audit date: 2026-07-27. Stack: Frappe 17.x-develop, ERPNext 17.x-develop, Frappe CRM 2.0.0-dev.

## 1. Authentication — three schemes exist

Verified in `frappe/frappe/auth.py`:

| Scheme | Header | Source |
|---|---|---|
| API key/secret | `Authorization: token <api_key>:<api_secret>` | `auth.py:708` `validate_auth_via_api_keys` |
| API key/secret (basic) | `Authorization: Basic base64(key:secret)` | same function |
| OAuth2 bearer | `Authorization: Bearer <access_token>` | `auth.py:659` `validate_oauth` |
| Session cookie | `Cookie: sid=…` | `/api/method/login` |

### CSRF — the decisive constraint

`auth.py:82 validate_csrf_token()` rejects every unsafe HTTP method (POST/PUT/DELETE) when the
session carries a `csrf_token`, unless the request supplies `X-Frappe-CSRF-Token`.

**Empirically confirmed:** a `POST` to a custom method using only a session cookie returned
`400 CSRFTokenError: Invalid Request`.

The guard short-circuits when `frappe.session.data.csrf_token` is absent — which is the case for
header-authenticated requests. **Therefore header-based auth avoids CSRF entirely.** This is why the
mobile client must not use cookie sessions.

### OAuth2 is a full provider (verified via live discovery)

`GET /.well-known/openid-configuration` returned:

| Purpose | Endpoint |
|---|---|
| Authorize | `/api/method/frappe.integrations.oauth2.authorize` |
| Token | `/api/method/frappe.integrations.oauth2.get_token` |
| Revoke | `/api/method/frappe.integrations.oauth2.revoke_token` |
| UserInfo | `/api/method/frappe.integrations.oauth2.openid_profile` |
| Introspect | `/api/method/frappe.integrations.oauth2.introspect_token` |

`oauth2.py:342` declares `code_challenge_methods_supported=["S256"]` — **PKCE is supported**.
ID token signing is `HS256` only.

> **Requires backend configuration (not code):** an `OAuth Client` record must exist with the mobile
> redirect URI registered. None exists yet. See §6.

## 2. REST resource API — verified working

`GET /api/resource/{DocType}` with `fields`, `filters`, `limit_page_length`, `order_by`.

Live responses obtained for `CRM Deal` and `Work Order`. The custom field `originating_deal` is
returned by the REST layer without extra configuration.

Standard shapes:

| Operation | Call |
|---|---|
| List | `GET /api/resource/CRM Deal?fields=["name","status"]&limit_page_length=20` |
| Read | `GET /api/resource/CRM Deal/{name}` |
| Create | `POST /api/resource/CRM Deal` |
| Update | `PUT /api/resource/CRM Deal/{name}` |
| Delete | `DELETE /api/resource/CRM Deal/{name}` |
| Count | `GET /api/method/frappe.client.get_count` |
| Doc method | `GET/POST /api/method/run_doc_method?dt=&dn=&method=` |

`run_doc_method` routing confirmed live: an unknown docname returned `404 Pending Action NOPE not
found`, proving the method was reached.

## 3. Custom API surface — only three whitelisted methods exist

This is the single most important finding for planning. The custom apps expose almost nothing.

| Method | Type | Usable from mobile |
|---|---|---|
| `korkem_manufacturing.shop_floor.complete_task` | `@frappe.whitelist()` module method | **Yes** |
| `Pending Action.approve` | whitelisted doc method → `run_doc_method` | **Yes** |
| `Pending Action.reject` | whitelisted doc method → `run_doc_method` | **Yes** |
| `korkem_ai…whatsapp.webhook` | `allow_guest=True` | **No** — inbound webhook for Meta only |

`complete_task` accepts `task: str | int` because **CRM Task uses `naming_rule: Autoincrement`** —
its `name` is an integer. Mobile DTOs must not type task ids as `String`.

Everything else the app needs must go through the generic REST API, or requires new backend
endpoints — which are **out of scope until explicitly approved** (§6).

## 4. Domain model — what actually exists

### Modules and doctypes

| Module | Doctypes |
|---|---|
| **FCRM** | `CRM Lead`, `CRM Deal`, `CRM Organization`, `CRM Task`, `CRM Notification`, `FCRM Note`, `CRM Call Log`, plus status/settings masters |
| **Korkem Ai** | `Agent Conversation`, `Agent Conversation Message`, `Pending Action`, `AI Settings` (single), `WhatsApp Settings` (single) |
| **Korkem Manufacturing** | **none** — it owns no doctypes |

`korkem_manufacturing` adds only a Custom Field (`Work Order.originating_deal`, Link → CRM Deal) and
Python modules. **All manufacturing data lives in native ERPNext doctypes**: `Work Order`, `BOM`,
`Item`, `Stock Entry`, `Warehouse`.

### Known field-level traps (verified in earlier work on this backend)

- `CRM Deal.mobile_no` is **derived**, not stored — `validate()` reads it from the primary row of the
  `contacts` child table. Writing it directly is silently discarded.
- `CRM Task.reference_doctype` is an unrestricted Link to DocType; `reference_docname` is a Dynamic
  Link. This is how tasks attach to Work Orders.
- `CRM Task.status` ∈ `Backlog, Todo, In Progress, Done, Canceled`; `priority` ∈ `Low, Medium, High`.

## 5. Roles — the ones in the brief vs. the ones that exist

55 enabled roles. The seven roles in the brief map onto real ERPNext roles as follows:

| Role in brief | Real backend role(s) | Exists |
|---|---|---|
| Administrator | `Administrator`, `System Manager` | ✅ |
| Manager | `System Manager` (+ domain managers) | ✅ |
| Sales | `Sales User`, `Sales Manager` | ✅ |
| Production | `Manufacturing User`, `Manufacturing Manager` | ✅ |
| Warehouse | `Stock User`, `Stock Manager` | ✅ |
| Worker | `Shop Floor User`, `Shop Floor Manager` | ✅ |
| Customer | `Customer` | ✅ |

There is **no** role literally named "Production", "Warehouse", or "Worker". The app must gate on the
real role names above, never on invented ones.

## 6. Gaps — things the app will need that do not exist yet

Listed explicitly so no screen is designed against an imaginary endpoint. **Each requires your
approval before any backend change.**

| # | Gap | Impact | Type |
|---|---|---|---|
| G1 | No `OAuth Client` record with a mobile redirect URI | Login cannot work | Config |
| G2 | Push relay disabled (`enable_push_notification_relay = 0`) | No push notifications | Config |
| G3 | No aggregate/dashboard endpoint | Dashboard needs N round-trips or a new endpoint | Code |
| G4 | No "my tasks" endpoint scoped to the current worker | Client-side filtering only | Code |
| G5 | No mobile-shaped Work Order detail (BOM + tasks + deal in one call) | Chatty detail screen | Code |
| G6 | No server-side full-text search across entities | Per-doctype search only | Code |

`frappe.push_notification.subscribe(fcm_token, project_name)` **is** whitelisted, so FCM token
registration from the app works as soon as G2 is resolved.

## 7. Supporting infrastructure

| Capability | Status |
|---|---|
| File upload | `/api/method/upload_file` (`frappe/handler.py:130`) — available |
| Realtime | Socket.IO server present (`frappe/socketio.js`), `publish_realtime` available |
| Push notifications | `frappe.push_notification.subscribe` whitelisted; **relay disabled** (G2) |
| Rate limiting | Not configured on this site |

## 8. What was NOT verified

Stated plainly so it is not mistaken for fact:

- **No OAuth2 login flow was executed end-to-end** — no `OAuth Client` exists yet (G1).
- **Permission behaviour per role was not exercised.** All probes ran as `Administrator`, which
  bypasses permission checks. Actual per-role visibility must be tested with real role-holding users
  before the role gating in `mobile_app_structure.md` is trusted.
- **No write operation was performed** against the live backend during this audit, by design.
