# KORKEM Flow Mobile — Application Structure

> Every screen below maps to a **verified** backend capability in
> [`api_mapping.md`](./api_mapping.md). Screens that depend on an endpoint that does not exist yet are
> marked **⛔ blocked** with the gap id — they are not silently designed around.
>
> Role names are the **real** backend roles verified in the audit, never invented ones.

## 1. Role model

Seven personas, mapped to real ERPNext roles:

| Persona | Backend role(s) | Primary job on a phone |
|---|---|---|
| Administrator | `Administrator`, `System Manager` | Everything; system health |
| Manager | `System Manager` + domain managers | Overview, approvals, bottlenecks |
| Sales | `Sales User`, `Sales Manager` | Leads, deals, customer conversations |
| Production | `Manufacturing User`, `Manufacturing Manager` | Work orders, scheduling |
| Warehouse | `Stock User`, `Stock Manager` | Items, stock, movements |
| Worker | `Shop Floor User` | **One thing: my tasks, done fast** |
| Customer | `Customer` | Order status only |

**Design consequence:** the Worker app is not a reduced Manager app. It is a different application
that happens to share a codebase — two tabs, huge targets, offline-first, no dashboards.

## 2. Navigation per role

`StatefulShellRoute` — each tab keeps its own stack and scroll position. 3–5 destinations, never more.

| Role | Tabs |
|---|---|
| Worker | **My Tasks** · Profile |
| Sales | Deals · Leads · Conversations · Profile |
| Production | Work Orders · Tasks · Items · Profile |
| Warehouse | Items · Stock · Work Orders · Profile |
| Manager | Dashboard · Approvals · Production · Deals · Profile |
| Administrator | Dashboard · Approvals · Production · Deals · Profile |
| Customer | My Orders · Profile |

No drawer anywhere (design system §8). Overflow lives in Profile.

## 3. Navigation flow

```
Cold start
   └─ Splash (token check)
        ├─ no session ──────► Login (OAuth2 system browser)  ⛔ G1
        └─ session ─────────► Role home
                                 │
                                 ├─ tab stacks (independent)
                                 ├─ deep link (notification tap) → resolved after auth
                                 └─ 401 → silent refresh → retry, else Login (target preserved)
```

## 4. Screens

### 4.1 Auth

**Splash** — brand mark, token validity check, route decision. No spinner before 300ms (avoids flash).

**Login** ⛔ **G1** — single "Sign in" button opening the **system browser** to Frappe's authorize
endpoint (never an in-app WebView — architecture §7). Server URL is configurable on first run for
staging vs production.

States: idle · authenticating · error (network / cancelled / denied).

> Cannot be implemented until an `OAuth Client` with redirect `korkemflow://auth-callback` exists.

---

### 4.2 Worker — the highest-value surface

**My Tasks** — the entire job. Sectioned list: *Overdue* · *Today* · *Upcoming*.

Each row: work-order code, item, quantity, due time, status chip. Row height 72dp, targets 56dp
(gloves). Pull-to-refresh. Offline-capable: served from Drift, staleness indicator when cached.

Primary action per row: **Complete** — the one verified custom endpoint
(`shop_floor.complete_task`). Confirmation is a bottom sheet with an optional notes field, because
completion is irreversible from the app.

- **Loading**: 5 skeleton rows matching final layout (no layout shift).
- **Empty**: Lottie + "No tasks assigned" + refresh.
- **Error**: inline card + Retry; cached data stays visible beneath.
- **Offline**: banner; Complete still works and queues to the outbox (architecture §6).

**Task Detail** — work order context, item, BOM materials (read-only), notes history, Complete action
in a bottom action bar (not a FAB — it must be labelled).

> Filtering to *this worker's* tasks is client-side today (**G4**). With a server endpoint it becomes
> a single scoped call.

---

### 4.3 Sales

**Deals** — list with search, filter sheet (status, owner, date), sort. Card: organization, status
chip, next step, value, last activity. Infinite scroll (`limit_start`/`limit_page_length`). FAB:
*New deal*.

**Deal Detail** — tabs: **Overview** (fields, status) · **Contacts** · **Tasks** · **Notes** ·
**Activity**. Status change via bottom sheet. Call/WhatsApp actions on contacts.

> `CRM Deal.mobile_no` is **derived** from the primary row of the `contacts` child table (audit §4).
> The UI must edit the contact, never the field — writing `mobile_no` directly is silently discarded.

**Leads** — same shape; convert-to-deal action.

**Conversations** — WhatsApp threads (`Agent Conversation`), chat-shaped: bubbles, sender, timestamps,
System/Agent/User distinguished. Read-only inbound history.

> Outbound send from the app is **⛔ not available** — the only WhatsApp method is a guest webhook for
> Meta (audit §3). Sending would need a new endpoint.

---

### 4.4 Production

**Work Orders** — filter by status (`Not Started`, `In Process`, `Completed`), warehouse, date.
Card: code, item, qty, progress, status chip, originating deal link.

**Work Order Detail** — tabs: **Overview** · **Materials** (BOM explosion, required vs transferred) ·
**Tasks** (attached `CRM Task`s) · **Timeline** (native Frappe comments).

Draft vs submitted is explicit: `docstatus` drives whether actions are offered at all
(architecture §5). A draft Work Order must never present live actions.

> Composed from several calls today (**G5**).

---

### 4.5 Warehouse

**Items** — searchable list, group filter, stock level per warehouse.
**Item Detail** — stock by warehouse, UOM, recent movements.
**Stock** — balances by warehouse; movement history from `Stock Entry`.

Stock *movements* are read-only in v1. Creating a `Stock Entry` from a phone has material financial
consequences and needs its own design pass and your explicit approval.

---

### 4.6 Manager / Administrator

**Dashboard** — hero metrics (open work orders, deals in progress, pending approvals, overdue tasks),
then bottlenecks and recent activity.

> **G3**: no aggregate endpoint exists. v1 issues several parallel count calls
> (`frappe.client.get_count`) and caches aggressively. One custom endpoint would replace all of them —
> the single highest-value backend addition.

**Approvals** — the AI gate (`Pending Action`), and the most product-defining screen in the app.

Each card renders `display_data` — the human-readable summary and change list the agent produced — so
the approver sees *what will change* without reading JSON. Actions: **Approve** / **Reject** (with
reason), via `run_doc_method` — both verified.

Rules, driven by backend behaviour:
- Approve/Reject are **never** queued offline; they re-validate server-side at execution
  (architecture §6). Offline they are disabled with an explanation.
- Expired proposals render as expired and are not actionable.
- After action, the card animates out and a snackbar confirms.

**Production / Deals** — manager-scoped versions of §4.4 / §4.3.

---

### 4.7 Customer

**My Orders** — deliberately minimal: order code, item, stage, expected date, progress. No costs, no
internal notes, no staff names.

> Requires verifying that the `Customer` role's permissions actually restrict these records
> server-side. Untested (audit §8) — **must be tested with a real Customer user before release.**
> This is a data-exposure risk, not a cosmetic one.

---

### 4.8 Cross-cutting

**Notifications** — list from `CRM Notification`; tap deep-links to the entity.
Push requires **G2** (relay disabled); until then, refresh-on-foreground.

**Search** — per-doctype today (**G6**: no cross-entity search). Scoped to the active tab's entity,
debounced 300ms, recent searches cached.

**Settings** — theme (system/light/dark), language, notifications, server, sync status, log viewer
(architecture §11), sign out.

**Sync Issues** — surfaces outbox conflicts for human resolution. Small screen, disproportionately
important: it is what makes offline writes trustworthy rather than lossy.

**Not Authorized** — shown when a capability check fails, never a blank screen.

## 5. Universal state contract

Every data-bearing screen implements all five states. `AsyncValue` makes this uniform rather than
per-screen improvisation (architecture §10).

| State | Treatment |
|---|---|
| **Loading** | Skeletons matching final layout. Never a centred spinner on a list. |
| **Data** | Content; staleness indicator if served from cache. |
| **Empty** | Illustration + one sentence + one action. Never a bare "No data". |
| **Error** | Human message from `_server_messages` + Retry. Cached data stays visible. |
| **Offline** | Persistent banner; writes queue or disable per §4.2/§4.6. |

## 6. Forms

ERPNext forms are not ported. Rules:

- One decision per screen, or a short stepper for multi-part input.
- Labels above fields; placeholders are never the only label.
- Validate on blur, not per keystroke.
- Server validation (`417` + `_server_messages`) maps to the offending field inline.
- Numeric input gets numeric keyboards; quantities use steppers.
- Destructive actions confirm; reversible ones use snackbar **Undo** instead.
- Draft state is preserved if the app is backgrounded mid-form.

## 7. Animation inventory

| Where | Motion | Token |
|---|---|---|
| Tab switch | fade-through | `standard` |
| Push/pop | platform-native | `standard` |
| List entry | stagger 20ms, cap 6 rows | `quick` |
| Task complete | check morph + card exit | `standard` |
| Approve/Reject | card slide-out | `standard` |
| Pull-to-refresh | M3 indicator | `quick` |
| FAB | scale in, hide on scroll | `quick` |
| Empty state | Lottie, loop | — |

All collapse to zero when `disableAnimations` is set.

## 8. Screen-to-role matrix

| Screen | Admin | Mgr | Sales | Prod | Whse | Worker | Cust |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| Dashboard | ✅ | ✅ | — | — | — | — | — |
| Approvals | ✅ | ✅ | — | — | — | — | — |
| Deals / Leads | ✅ | ✅ | ✅ | — | — | — | — |
| Conversations | ✅ | ✅ | ✅ | — | — | — | — |
| Work Orders | ✅ | ✅ | — | ✅ | ✅ | — | — |
| My Tasks | ✅ | ✅ | ✅ | ✅ | — | ✅ | — |
| Items / Stock | ✅ | ✅ | — | ✅ | ✅ | — | — |
| My Orders | — | — | — | — | — | — | ✅ |
| Settings | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

Gating is by **capability**, not role string (architecture §8), and is UX only — the server remains
the authority.
