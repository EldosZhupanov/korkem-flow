# KORKEM Web Portal Architecture Audit

**Date:** 2026-09-14  
**Status:** PHASE 0 COMPLETED — DO NOT MODIFY CODE YET

---

## 1. Executive Summary

This audit establishes the baseline architecture of the KORKEM repository to guide the design and implementation of the **KORKEM SaaS Web Portal** without disrupting existing mobile (Flutter Android/iOS) or desktop (Windows x64) clients.

The repository is an enterprise monorepo containing:
- **Core Backend:** Frappe Framework + ERPNext v16 + custom apps (`korkem_manufacturing`, `korkem_ai`).
- **Database & Services:** MariaDB 11.8, Redis 7 (cache & queue), Socket.io realtime, Caddy 2 reverse proxy with automated TLS.
- **Mobile Client:** Flutter 3.44.8 / Dart 3.12.2 cross-platform app (`mobile/korkem_flow`).
- **Desktop Client:** Windows x64 Flutter release build (`korkem_flow.exe`, packaged in ZIP).
- **Existing Web Views:** Frappe Desk (`/app`), Frappe CRM (`/crm` via Vue 3 / Frappe UI), Frappe Login (`/login`), and static Caddy download responder (`/download`).

---

## 2. Technology Stack & Frameworks

| Layer | Technology | Location | Role / Usage |
|---|---|---|---|
| **Backend Framework** | Frappe Framework (v16-dev) / Python 3.12+ | `frappe/`, `backend/` | Application server, ORM, REST API, RPC |
| **ERP Layer** | ERPNext (v16-dev) | `erpnext/` | Manufacturing, Stock, Accounts, Buying, Selling |
| **Domain Apps** | `korkem_manufacturing`, `korkem_ai` | `backend/` | Furniture BOM, Cutting, Warehouses, Staff, AI Tools |
| **CRM Web Frontend** | Vue 3 + Vite + Tailwind + Frappe UI | `crm/frontend/` | Embedded CRM SPA at `/crm` |
| **Mobile & Desktop** | Flutter 3.44.8 / Dart 3.12.2 | `mobile/korkem_flow/` | Mobile APK & Windows Desktop application |
| **Database** | MariaDB 11.8 (InnoDB, utf8mb4) | Docker container | Relational data store |
| **Cache & Realtime** | Redis 7 + Socket.io (port 9000) | Docker containers | Session cache, background queues, realtime events |
| **Reverse Proxy / TLS** | Caddy 2 (Alpine) | `infra/frappe_bench/proxy/` | TLS termination, HTTP/2, static file routing |
| **Node.js Environment** | Node.js v24.18.0, npm 11.16.0 | System environment | Build tools and JavaScript execution |

---

## 3. Existing Route Implementations & Where They Live

### Current Route Map

| Public URL Path | Handled By | Implementation Location | Current Behavior |
|---|---|---|---|
| `/` | Frappe Web | `frappe/frappe/www/` | Renders Frappe website default or redirects to `/login` |
| `/login` | Frappe Core | `frappe/frappe/templates/pages/login.html` | Basic server-rendered Frappe login form |
| `/register` | Mobile App / API only | `backend/korkem_manufacturing/.../api/registration.py` | No web UI exists; API endpoint `korkem_manufacturing.api.registration.register` |
| `/download`, `/apps` | Caddy Direct Handler | `infra/frappe_bench/proxy/app.Caddyfile` | Inline HTML responder with download buttons for APK and ZIP |
| `/files/korkem-flow.apk` | Caddy / Frappe Public Files | `/home/frappe/.../public/files/korkem-flow.apk` | Serves 68 MB Android APK with `application/vnd.android.package-archive` |
| `/files/korkem-flow-windows-x64.zip` | Caddy / Frappe Public Files | `/home/frappe/.../public/files/korkem-flow-windows-x64.zip` | Serves 30.6 MB Windows ZIP with `application/zip` |
| `/app` | Frappe Desk | `frappe/frappe/desk/` | Internal Frappe administrative desk SPA |
| `/crm` | Frappe CRM App | `crm/crm/www/crm.html` + `crm/frontend/` | Vue 3 Frappe UI CRM workspace |
| `/api/method/*` | Gunicorn / Frappe RPC | `backend/*/api/*.py` | Whitelisted REST/RPC API endpoints |

---

## 4. Authentication & User Management

### 4.1 Session Mechanism
- **Session Cookie:** Frappe sets an HTTP cookie named `sid`.
  - Path: `/`
  - HttpOnly: `true`
  - SameSite: `Lax`
- **Login Endpoint:** `POST /api/method/login`
  - Request Body: `{"usr": "<email_or_username>", "pwd": "<password>"}`
  - Response: `{"message": "Logged In", "home_page": "desk", "full_name": "<Display Name>"}`
  - Sets `Set-Cookie: sid=<hex_id>`.
- **Session Verification:** `GET /api/method/frappe.auth.get_logged_user`
  - Returns current user's email ID, or `"Guest"` if unauthenticated.
- **Logout:** `GET /api/method/logout` or `POST /api/method/logout`
  - Clears session on Redis and expires `sid` cookie.
- **API Tokens:** `POST /api/method/frappe.core.doctype.user.user.generate_keys`
  - Generates `api_key` and `api_secret` for programmatic/headless access: `Authorization: token <api_key>:<api_secret>`.
- **JWT / Refresh Tokens:** Not used by core Frappe. Session cookie is the standard, battle-tested web authentication mechanism.
- **Firebase:** Present in Flutter mobile app only for FCM mobile push notifications. NOT required for web portal authentication.

### 4.2 User Model (`tabUser`)
- DocType: `User` (`frappe/frappe/core/doctype/user/user.json`)
- Primary Key: `name` (User's email string)
- Fields: `email`, `first_name`, `last_name`, `full_name`, `user_type` (`"System User"` vs `"Website User"`), `enabled` (0/1), `roles` (Child table `User Role`).
- Role Hierarchy for KORKEM Owners:
  - `System Manager`
  - `Manufacturing Manager`
  - `Stock Manager`
  - `Sales Manager`
  - `Purchase Manager`

---

## 5. Organization, Company & Multi-Tenant Model

### 5.1 Company Model (`tabCompany`)
- DocType: `Company` (`erpnext/erpnext/setup/doctype/company/company.json`)
- Fields:
  - `name`: Company Title (e.g. `"ТОО Мебель-Люкс"`)
  - `company_name`: Same as title
  - `abbr`: Unique 2-5 letter abbreviation (e.g. `"ТМЛ"`)
  - `default_currency`: `"KZT"`
  - `country`: `"Kazakhstan"`
  - `default_warehouse`: Raw materials default warehouse (`Stores`)
  - `default_fg_warehouse`: Finished goods default warehouse
- Auto-Provisioning: On creation, ERPNext automatically generates a Chart of Accounts and root group warehouses.
- Company Details API (`korkem_manufacturing.api.company_details`):
  - `read()`: Returns company profile, BIN, phone, email, website, address, city, banking info.
  - `save(...)`: Updates company profile attributes safely.

### 5.2 Tenant Isolation (`services/scope.py`)
- KORKEM enforces server-authoritative tenant isolation:
  - `current_company()`: Reads `User Permission` (`allow='Company'`, `user=session.user`).
  - `scoped(filters)`: Injects `{"company": current_company()}` into every database read and write.
  - `ensure_company(doctype, name)`: Throws 404/DoesNotExist if a user attempts to access another company's record.
  - Cross-tenant ID tampering is completely blocked at the backend service layer.

---

## 6. Warehouse Model & APIs

### 6.1 Entity Definition (`tabWarehouse`)
- DocType: `Warehouse` (`erpnext/erpnext/stock/doctype/warehouse/warehouse.json`)
- Fields:
  - `name`: Unique key format `"<Display Name> - <Abbr>"` (e.g. `"Цех 1 - ТМЛ"`)
  - `warehouse_name`: Display name without company suffix (e.g. `"Цех 1"`)
  - `company`: Link to `Company`
  - `is_group`: `0` (leaf stock location) or `1` (group category)
  - `disabled`: `0` (active) or `1` (archived/disabled)
  - `parent_warehouse`: Parent group node

### 6.2 Available Backend Endpoints
- `GET /api/method/korkem_manufacturing.api.warehouses.listing`:
  - Returns array of objects:
    ```json
    [
      {
        "warehouse": "Цех 1 - ТМЛ",
        "name": "Цех 1",
        "disabled": false,
        "positions": 14,
        "is_shipping_default": true
      }
    ]
    ```
- `POST /api/method/korkem_manufacturing.api.warehouses.create`:
  - Body: `{"name": "Склад материалов"}`
  - Creates active leaf warehouse under company root.
- `POST /api/method/korkem_manufacturing.api.warehouses.set_shipping_default`:
  - Body: `{"warehouse": "Цех 1 - ТМЛ"}`
- `POST /api/method/korkem_manufacturing.api.warehouses.set_disabled`:
  - Body: `{"warehouse": "Цех 1 - ТМЛ", "disabled": true}`

---

## 7. Team & Staff Model & APIs

### 7.1 Available Backend Endpoints
- `GET /api/method/korkem_manufacturing.api.staff.members`:
  - Returns array of team members: email, first name, last name, position, active status.
- `GET /api/method/korkem_manufacturing.api.staff.can_invite`:
  - Returns boolean whether current session can invite new employees.
- `GET /api/method/korkem_manufacturing.api.invitations.positions`:
  - Returns list of valid roles/positions:
    - Руководитель / Владелец (`System Manager`, etc.)
    - Мастер цеха / Технолог (`Manufacturing Manager`)
    - Кладовщик (`Stock Manager`)
    - Менеджер по продажам (`Sales Manager`)
    - Замерщик / Конструктор
- `POST /api/method/korkem_manufacturing.api.invitations.invite`:
  - Body: `{"email": "...", "position": "...", "first_name": "..."}`
- `POST /api/method/korkem_manufacturing.api.staff.change_position`:
  - Body: `{"email": "...", "position": "..."}`
- `POST /api/method/korkem_manufacturing.api.staff.deactivate` / `reactivate`:
  - Body: `{"email": "..."}`

---

## 8. Registration API

### 8.1 Public Endpoint
- `POST /api/method/korkem_manufacturing.api.registration.register` (`allow_guest=True`)
- Request Body:
  ```json
  {
    "company_name": "ТОО Мебель-Люкс",
    "owner_name": "Азамат Султанов",
    "email": "azamat@korkem.asia",
    "password": "secretpassword123",
    "phone": "+7 701 123 4567"
  }
  ```
- Operations Performed Atomically:
  1. Checks if user already exists.
  2. Creates `Company` with default currency (`KZT`) and country (`Kazakhstan`).
  3. Creates `User` with `"System User"` type.
  4. Sets password securely.
  5. Assigns owner roles (`System Manager`, `Manufacturing Manager`, `Stock Manager`, `Sales Manager`, `Purchase Manager`).
  6. Sets `User Permission` binding user to the new company.
  7. Returns `{"status": "ok", "email": "...", "company": "...", "message": "Регистрация успешно завершена"}`.

---

## 9. Distribution Artifacts & Public Download URLs

- **Android Universal Release APK:**
  - URL: `https://api.korkem.asia/files/korkem-flow.apk`
  - Local Path: `mobile/korkem_flow/build/app/outputs/flutter-apk/app-release.apk`
  - File Size: ~68 MB (FAT APK supporting ARMv7, ARM64, x86_64)
- **Windows Desktop Release ZIP:**
  - URL: `https://api.korkem.asia/files/korkem-flow-windows-x64.zip`
  - Local Path: `/mnt/c/Users/Asus TUF/Downloads/korkem-flow-windows-x64.zip`
  - File Size: ~30.6 MB (Portable self-contained Windows package)
- **Caddyfile Configuration:**
  - `infra/frappe_bench/proxy/app.Caddyfile` sets `@apk` header with `Content-Type: application/vnd.android.package-archive` and `Content-Disposition: attachment`.
  - Both download URLs are verified live and operational with HTTP 200 responses.

---

## 10. Compatibility & Safety Constraints

1. **Mobile Application (Flutter):**
   - Must NOT be touched.
   - Depends strictly on `/api/method/login`, `/api/method/korkem_manufacturing.api.registration.register`, `/api/method/frappe.auth.get_logged_user`, `/api/method/korkem_manufacturing.api.queries.*`.
   - All backend API contracts MUST remain 100% backward compatible.
2. **Windows Desktop Application:**
   - Must NOT be touched.
   - Shares the same Flutter code and API contract.
3. **Database & ERPNext:**
   - Do NOT modify Frappe core tables or alter database schema directly.
   - Use Frappe's whitelisted APIs and document-level transactions.
4. **Web Portal Architecture:**
   - Modern Next.js (React 19 / TypeScript / Tailwind CSS / Radix UI / Lucide Icons).
   - Reuses existing backend APIs via standard HTTP proxying or direct API calls with cookie forwarding.
   - Clean separation between Public marketing routes (`/`, `/features`, `/download`, `/about`, `/login`, `/register`) and Authenticated workspace routes (`/app/*`).

---

## 11. Audit Conclusion & Greenlight

The existing KORKEM backend possesses 100% of the required API endpoints, security mechanisms, tenant isolation, and business entities needed to build a world-class SaaS web portal:
- ✅ Company onboarding and management: READY
- ✅ Warehouse CRUD: READY
- ✅ Team & Staff invitations and role management: READY
- ✅ Public registration and authentication: READY
- ✅ Production, orders, materials, stock queries: READY
- ✅ Download artifact distribution: READY

We can now proceed to Phase 1: Reference Analysis.
