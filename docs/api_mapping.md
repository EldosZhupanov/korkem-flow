# KORKEM Flow Mobile — API Mapping

> Every endpoint here is traced to [`backend_api_audit.md`](./backend_api_audit.md), where it was
> verified against the running backend. **Nothing in this document is invented.** Rows marked
> **⛔ GAP** have no endpoint today and require your approval before any backend work.
>
> Base URL: `http://korkem.localhost:8000` (dev). Auth: `Authorization: Bearer <access_token>` on
> every request — never cookies (CSRF, audit §1).

## 1. Verified endpoint vocabulary

| Purpose | Endpoint | Verified |
|---|---|---|
| OAuth authorize | `/api/method/frappe.integrations.oauth2.authorize` | ✅ discovery |
| OAuth token | `/api/method/frappe.integrations.oauth2.get_token` | ✅ discovery |
| OAuth revoke | `/api/method/frappe.integrations.oauth2.revoke_token` | ✅ discovery |
| User profile | `/api/method/frappe.integrations.oauth2.openid_profile` | ✅ discovery |
| Logged user | `/api/method/frappe.auth.get_logged_user` | ✅ live 200 |
| List | `GET /api/resource/{DocType}` | ✅ live 200 |
| Read | `GET /api/resource/{DocType}/{name}` | ✅ |
| Create / Update / Delete | `POST` / `PUT` / `DELETE /api/resource/{DocType}[/{name}]` | ✅ |
| Count | `/api/method/frappe.client.get_count` | ✅ |
| Doc method | `POST /api/method/run_doc_method` | ✅ live (404 on unknown doc = routed) |
| Complete task | `POST /api/method/korkem_manufacturing.shop_floor.complete_task` | ✅ live (routed) |
| File upload | `/api/method/upload_file` | ✅ source |
| FCM register | `/api/method/frappe.push_notification.subscribe` | ✅ whitelisted (relay off — G2) |

**That is the complete usable surface.** Everything below composes these.

## 2. Caching and offline legend

| Code | Caching | | Code | Offline |
|---|---|---|---|---|
| **C1** | Network-only | | **O1** | Unavailable offline |
| **C2** | Stale-while-revalidate (Drift) | | **O2** | Read from cache |
| **C3** | Long-TTL master data | | **O3** | Read cache + queue writes |
| **C4** | Memory-only (session) | | **O4** | Read cache, writes **disabled** |

## 3. Auth

| Screen | Call | Doctype | Permission | Cache | Offline |
|---|---|---|---|---|---|
| Login | `oauth2.authorize` → `get_token` | — | public | C4 | O1 |
| Session restore | refresh grant on `get_token` | — | valid refresh token | C4 | O1 |
| Profile | `oauth2.openid_profile` | `User` | self | C2 | O2 |
| Roles | `GET /api/resource/User/{me}?fields=["roles"]` | `User` | self | C2 | O2 |
| Sign out | `oauth2.revoke_token` + local wipe | — | — | — | O1 |

⛔ **G1** — blocked until an `OAuth Client` exists with redirect `korkemflow://auth-callback`.

## 4. Worker — My Tasks

| Screen | Call | Doctype | Permission | Cache | Offline |
|---|---|---|---|---|---|
| My Tasks | `GET /api/resource/CRM Task?filters=[["status","!=","Done"],["reference_doctype","=","Work Order"]]&fields=["name","title","status","priority","due_date","reference_docname","assigned_to"]&order_by=due_date asc` | `CRM Task` | `Shop Floor User` | C2 | O2 |
| Task detail | `GET /api/resource/CRM Task/{name}` | `CRM Task` | same | C2 | O2 |
| ↳ Work order context | `GET /api/resource/Work Order/{reference_docname}` | `Work Order` | `Manufacturing User` | C2 | O2 |
| **Complete task** | `POST /api/method/korkem_manufacturing.shop_floor.complete_task` body `{"task": <int>, "notes": "…"}` | — | whitelisted | C1 | **O3** |

**Critical:** `task` is an **integer** — `CRM Task` uses `naming_rule: Autoincrement` (audit §3). A
`String` id will be rejected by Frappe's runtime type enforcement.

Completion is the one write that queues offline; it is the core shop-floor scenario.

⛔ **G4** — assignee filtering is client-side. A scoped endpoint would remove over-fetching.

## 5. Sales — CRM

| Screen | Call | Doctype | Permission | Cache | Offline |
|---|---|---|---|---|---|
| Deals | `GET /api/resource/CRM Deal?fields=["name","organization","status","next_step","mobile_no","modified"]&limit_page_length=20&limit_start={n}` | `CRM Deal` | `Sales User` | C2 | O2 |
| Deal detail | `GET /api/resource/CRM Deal/{name}` | `CRM Deal` | `Sales User` | C2 | O2 |
| Create deal | `POST /api/resource/CRM Deal` | `CRM Deal` | `Sales User` | C1 | **O4** |
| Update status | `PUT /api/resource/CRM Deal/{name}` | `CRM Deal` | `Sales User` | C1 | O4 |
| Statuses (master) | `GET /api/resource/CRM Deal Status` | `CRM Deal Status` | any | **C3** | O2 |
| Leads | `GET /api/resource/CRM Lead` | `CRM Lead` | `Sales User` | C2 | O2 |
| Organizations | `GET /api/resource/CRM Organization` | `CRM Organization` | `Sales User` | C2 | O2 |
| Notes | `GET/POST /api/resource/FCRM Note` | `FCRM Note` | `Sales User` | C2 | **O3** |

**`mobile_no` is derived, not stored** (audit §4). To change a phone number, write the `contacts`
child table via the parent Deal — a direct `PUT` of `mobile_no` is silently discarded by
`CRM Deal.validate()`. This is the single most likely source of a "the save did nothing" bug.

Deal writes are **O4** (disabled offline): status transitions drive downstream automation.

## 6. Conversations

| Screen | Call | Doctype | Permission | Cache | Offline |
|---|---|---|---|---|---|
| Threads | `GET /api/resource/Agent Conversation?fields=["name","contact_phone","channel","status","started_on"]&order_by=started_on desc` | `Agent Conversation` | `Sales User` | C2 | O2 |
| Messages | `GET /api/resource/Agent Conversation Message?filters=[["conversation","=","{name}"]]&order_by=creation asc` | `Agent Conversation Message` | `Sales User` | C2 | O2 |

⛔ **Outbound send unavailable.** The only WhatsApp method is `whatsapp.webhook`, a guest endpoint for
Meta's inbound callbacks (audit §3). A send endpoint would be new backend work.

## 7. Approvals — the AI gate

| Screen | Call | Doctype | Permission | Cache | Offline |
|---|---|---|---|---|---|
| Pending list | `GET /api/resource/Pending Action?filters=[["status","=","Pending"]]&fields=["name","agent_skill","entity_type","entity_name","display_data","expires_at","creation"]&order_by=creation desc` | `Pending Action` | `System Manager` | C2 | O2 |
| Detail | `GET /api/resource/Pending Action/{name}` | `Pending Action` | `System Manager` | C2 | O2 |
| **Approve** | `POST /api/method/run_doc_method` `{"dt":"Pending Action","dn":"{name}","method":"approve"}` | `Pending Action` | `System Manager` | C1 | **O4** |
| **Reject** | same, `method: "reject"`, `args: {"reason": "…"}` | `Pending Action` | `System Manager` | C1 | **O4** |

`display_data` is a **JSON field returned as a string** — parse client-side; Frappe does not
deserialize it on read.

**O4 is deliberate.** `approve()` re-validates server-side that the target still exists and that the
action has not expired. Queuing an approval offline would let a user approve a proposal whose target
has since changed. Offline, both actions are disabled with an explanation.

## 8. Production

| Screen | Call | Doctype | Permission | Cache | Offline |
|---|---|---|---|---|---|
| Work orders | `GET /api/resource/Work Order?fields=["name","production_item","qty","status","docstatus","originating_deal","planned_start_date","expected_delivery_date"]&limit_page_length=20` | `Work Order` | `Manufacturing User` | C2 | O2 |
| Detail | `GET /api/resource/Work Order/{name}` | `Work Order` | `Manufacturing User` | C2 | O2 |
| Materials | from `required_items` child table on the detail response | `Work Order Item` | same | C2 | O2 |
| BOM | `GET /api/resource/BOM/{bom_no}` | `BOM` | `Manufacturing User` | **C3** | O2 |
| Attached tasks | `GET /api/resource/CRM Task?filters=[["reference_doctype","=","Work Order"],["reference_docname","=","{name}"]]` | `CRM Task` | `Manufacturing User` | C2 | O2 |
| Linked deal | `GET /api/resource/CRM Deal/{originating_deal}` | `CRM Deal` | `Sales User` | C2 | O2 |

`originating_deal` is the custom field added by `korkem_manufacturing` and is returned by REST without
extra configuration (audit §2). `docstatus` must gate every action (draft ≠ live).

⛔ **G5** — the detail screen currently needs up to four calls.

## 9. Warehouse

| Screen | Call | Doctype | Permission | Cache | Offline |
|---|---|---|---|---|---|
| Items | `GET /api/resource/Item?fields=["name","item_name","item_group","stock_uom"]` | `Item` | `Stock User` | C2 | O2 |
| Item detail | `GET /api/resource/Item/{name}` | `Item` | `Stock User` | C2 | O2 |
| Stock balance | `GET /api/resource/Bin?filters=[["item_code","=","{item}"]]&fields=["warehouse","actual_qty","reserved_qty"]` | `Bin` | `Stock User` | C2 | O2 |
| Warehouses | `GET /api/resource/Warehouse` | `Warehouse` | `Stock User` | **C3** | O2 |
| Movements | `GET /api/resource/Stock Entry?limit_page_length=20` | `Stock Entry` | `Stock User` | C2 | O2 |

Stock **writes are out of scope for v1** — material and financial consequences require a dedicated
design pass and your explicit approval.

## 10. Dashboard

⛔ **G3** — no aggregate endpoint. v1 composes parallel counts:

| Metric | Call |
|---|---|
| Open work orders | `get_count` on `Work Order`, `filters=[["status","in",["Not Started","In Process"]]]` |
| Pending approvals | `get_count` on `Pending Action`, `status = Pending` |
| Deals in progress | `get_count` on `CRM Deal`, `status = Proposal/Quotation` |
| Overdue tasks | `get_count` on `CRM Task`, `due_date < today`, `status != Done` |

Cache **C2**, TTL 5 min, refresh on pull. One custom aggregate endpoint would replace all four — the
highest-value backend addition available.

## 11. Notifications

| Screen | Call | Doctype | Cache | Offline |
|---|---|---|---|---|
| List | `GET /api/resource/CRM Notification?filters=[["to_user","=","{me}"]]&order_by=creation desc` | `CRM Notification` | C2 | O2 |
| Mark read | `PUT /api/resource/CRM Notification/{name}` | `CRM Notification` | C1 | O3 |
| Register device | `GET /api/method/frappe.push_notification.subscribe?fcm_token={t}&project_name={p}` | — | C1 | O1 |

⛔ **G2** — relay disabled (`enable_push_notification_relay = 0`). Until enabled, notifications are
poll-on-foreground only.

## 12. Search

⛔ **G6** — no cross-entity search. v1 searches per doctype:

```
GET /api/resource/{DocType}?filters=[["{field}","like","%{q}%"]]&limit_page_length=20
```

Debounce 300ms, scoped to the active tab. **C1 / O2** (cached results remain searchable offline).

## 13. Consolidated gap register

Ordered by value delivered per unit of backend work. **None may proceed without your approval.**

| Gap | Need | Type | Impact | Priority |
|---|---|---|---|---|
| **G1** | `OAuth Client` + redirect URI | Config | **Blocks all authentication** | P0 |
| **G2** | Enable push relay + credentials | Config | No push notifications | P1 |
| **G3** | Dashboard aggregate endpoint | Code | 4 calls → 1 | P1 |
| **G4** | "My tasks" scoped to current user | Code | Removes over-fetch on the busiest screen | P2 |
| **G5** | Work Order composite | Code | 4 calls → 1 | P2 |
| **G6** | Cross-entity search | Code | Unified search UX | P3 |

## 14. Permission caveat

All endpoint probing ran as `Administrator`, which **bypasses ERPNext permission checks** (audit §8).
The `Permission` column above reflects the *intended* role model, not measured behaviour.

Before release, every role must be exercised with a real role-holding user — in particular the
**Customer** role, where an incorrect permission is a data-exposure incident, not a bug.
