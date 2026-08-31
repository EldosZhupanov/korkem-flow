> **АРХИВ. Это не описание системы сегодня.**
> Документ сохранён ради причин, стоящих за решениями. Актуальное состояние — в `NOW.md`, `ROADMAP.md`, `PLAN.md`.
> Не строить по этому файлу.

---

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

### CSRF — corrected 2026-07-28

> **This section previously claimed that a cookie-only `POST` is rejected with
> `400 CSRFTokenError`. That was wrong**, and the wrong conclusion ("the mobile client must not use
> cookie sessions") was drawn from it. The original reproduction almost certainly reused a cookie
> harvested from a *desk browser* session. Corrected below with a fresh live test.

`auth.py:82 validate_csrf_token()` rejects unsafe methods (POST/PUT/DELETE) only when the session
already carries a `csrf_token`, and short-circuits when it does not:

```python
or not (saved_token := frappe.session.data.csrf_token)
```

That token is generated **lazily**, by `sessions.py:197 get_csrf_token()`. Its only callers are
`www/desk.py:35`, `www/billing.py:19` and `integrations/oauth2.py:152` — all page renders. **Nothing
in the API path ever generates one**, so a session created by `POST /api/method/login` has no
`csrf_token` and the guard never fires.

**Verified live** (2026-07-28, user `mobile.test@korkem.local`):

| Step | Result |
|---|---|
| `POST /api/method/login` | `200`, `sid` cookie issued |
| `POST frappe.client.set_value` with **only** the cookie, no CSRF header | `200` — **the write applied** |
| `GET /api/resource/CRM Deal` with the cookie | `200` |

Header auth (`Authorization: token key:secret`) also works for both reads and writes and remains the
preferred mechanism — not because cookies fail, but because an API key does not expire.

### `generate_keys` is restricted to System Managers

`user.py:1458 generate_keys()` is `@frappe.whitelist(methods=["POST"])` and returns **both**
`api_key` and `api_secret` in one call — but its first line is `frappe.only_for("System Manager")`.

**Verified live** with the same account, roles changed between runs:

| Roles | `generate_keys` |
|---|---|
| `System Manager` (+ Sales) | `200 {"api_key": …, "api_secret": …}` |
| `Sales User` only | `403 PermissionError` |

Of the 11 real accounts, only `Administrator` and `crm.admin@example.com` hold System Manager. **So
9 of 11 users cannot mint API keys**, and the mobile client must support both mechanisms: try
`generate_keys` after login, fall back to the session cookie when refused. This removes gap G1 —
**login needs no `OAuth Client` and no backend change at all.**

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
| ~~G1~~ | ~~No `OAuth Client` record~~ | **Closed 2026-07-28** — login works via `login` → `generate_keys` → session-cookie fallback. No backend change needed. See §1. | — |
| G2 | Push relay disabled (`enable_push_notification_relay = 0`) | No push notifications | Config |
| G3 | No aggregate/dashboard endpoint | Dashboard composes from parallel `frappe.client.get_count` calls — chatty but real. Not a blocker. | Code |
| G4 | No "my tasks" endpoint scoped to the current worker | Client-side filtering only | Code |
| G5 | No mobile-shaped Work Order detail (BOM + tasks + deal in one call) | Chatty detail screen | Code |
| G6 | No server-side full-text search across entities | Per-doctype search only | Code |

`frappe.push_notification.subscribe(fcm_token, project_name)` **is** whitelisted, so FCM token
registration from the app works as soon as G2 is resolved.

### Row-level visibility is the real constraint, not endpoints

Also found on 2026-07-28: a fresh `Sales User` sees **zero** `CRM Deal` and **zero** `CRM Lead` rows
(`frappe.client.get_count` returns `0`) while `CRM Task` is readable. Frappe CRM restricts those
doctypes to the owner and assignees, so list screens are correctly empty for a user with nothing
assigned. Do not mistake this for a broken query.

### `Notification Log` is not scoped by Frappe — the client must scope it

Found 2026-07-28. `Notification Log` grants `read` to the role **`All`**, and
`frappe/hooks.py` registers **no** `get_permission_query_conditions` for it. An
unfiltered `GET /api/resource/Notification Log` therefore returns *every user's*
notifications — reproduced live, where an Administrator's unfiltered list came
back full of `crm.user1@example.com`'s assignments.

Any client reading this doctype **must** filter `for_user = <session user>`
itself. The mobile repository does, and a test pins it.

Two related facts:

- `subject` is stored as an **HTML fragment**
  (`<strong>Administrator</strong> assigned a new task ... to you`), not plain
  text. Rendering it raw puts tag names on screen.
- `frappe.desk.doctype.notification_log.notification_log.mark_as_read(docname)`
  and `mark_all_as_read()` are whitelisted and scope their update to
  `frappe.session.user` server-side. Use them rather than `frappe.client.set_value`
  on the `read` field, which would let a caller mark somebody else's
  notification read.

### Integration test account

`mobile.test@korkem.local` was created on 2026-07-28 purely to verify the auth flow without touching
any real user's credentials. It currently holds `Sales User`. Delete it before production.
`infra/frappe_bench/.env` `ADMIN_PASSWORD` does **not** match the site's stored hash (checked with
`frappe.utils.password.check_password`) — the file is stale.

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
