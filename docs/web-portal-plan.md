# KORKEM Web Portal Implementation Plan

**Date:** 2026-09-14  
**Status:** APPROVED — PROCEEDING TO IMPLEMENTATION

---

## 1. Goal & Architectural Overview

Build a production-grade, responsive B2B SaaS web portal for KORKEM in `web/` using **Next.js (App Router, TypeScript, Tailwind CSS, Radix UI, Lucide Icons)**.

The web portal fulfills two distinct responsibilities:
1. **Public Marketing & Distribution Website:**
   - `/` (Home): Modern B2B SaaS marketing homepage.
   - `/features`: Operational capabilities (CRM, CNC/Cutting, Warehouse, Orders, AI).
   - `/download`: Multiplatform download center (Android APK, Windows ZIP, iPhone PWA, MacBook).
   - `/about`: Company and mission overview.
   - `/login`, `/register`, `/forgot-password`: Clean authentication flows connected to Frappe.
2. **Authenticated KORKEM Web Workspace:**
   - Shell: Professional desktop sidebar + mobile drawer with user profile and navigation.
   - `/app`: Factory executive dashboard.
   - `/app/company`: Real company profile and contact details.
   - `/app/company/settings`: Operational defaults.
   - `/app/warehouses`: Real warehouse CRUD connected to `korkem_manufacturing.api.warehouses`.
   - `/app/warehouses/[id]`: Warehouse detail view with inventory counts.
   - `/app/team`: Real team directory and invitation flow connected to `korkem_manufacturing.api.staff`.
   - `/app/profile`: User account details and logout.

---

## 2. Technical Stack for `web/`

- **Framework:** Next.js 15 (React 19, App Router)
- **Language:** TypeScript 5
- **Styling:** Tailwind CSS + CSS Variables design tokens
- **Primitives:** Radix UI (`@radix-ui/react-*`) + Lucide React icons
- **State & Data Fetching:** Server Components + Client Hooks with SWR / optimistic updates
- **Backend Communication:** Direct cookie-forwarding reverse proxy or API client connecting to Frappe backend on `https://api.korkem.asia` (or `http://127.0.0.1:8000` in dev).

---

## 3. Detailed Stage Breakdown

### Stage 4: Web Application Setup & Design System
- Initialize `web/` with `package.json`, `tsconfig.json`, `next.config.ts`, `tailwind.config.ts`, and `postcss.config.mjs`.
- Define design tokens in `globals.css` (neutral slate, brand blue `#0284C7`, emerald, card surfaces, borders).
- Build core reusable components in `web/components/ui/`:
  - `Button`, `Input`, `Label`, `Textarea`, `Card`, `Badge`, `Table`, `Dialog`, `Sheet`, `DropdownMenu`, `Avatar`, `Skeleton`, `EmptyState`, `PageHeader`.

### Stage 5: Public Marketing Website
- Implement public layout with Sticky Header (Logo, Nav links, Auth buttons) and Footer.
- Implement `/` (Home):
  - Hero with value proposition ("Цифровая платформа для мебельных производств").
  - Metrics & trust badges.
  - 4 core solution areas: CRM & Заказы, Умный раскрой и материалы, Склад и снабжение, AI-ассистент цеха.
  - Interactive platform cards (Android, Windows, iOS, Mac, Web).
  - CTA section.
- Implement `/features` and `/about`.

### Stage 6: Multiplatform Download Center (`/download`)
- Redesign `/download` to look like a world-class SaaS download portal.
- Verify and preserve exact live URLs:
  - Android APK: `https://api.korkem.asia/files/korkem-flow.apk` (68 MB universal release).
  - Windows ZIP: `https://api.korkem.asia/files/korkem-flow-windows-x64.zip` (30.6 MB portable).
  - iPhone / iPad: Step-by-step PWA guide ("На экран Домой" in Safari).
  - MacBook: Web version and native app overview.
- Add system requirements and release information without fabricating false data.

### Stage 7: Authentication UI & Backend Integration
- Implement `/login`: Email + Password form, remember me, error handling, redirects.
- Implement `/register`:
  - Company Name, Owner Name, Email, Password, Phone.
  - Calls `POST /api/method/korkem_manufacturing.api.registration.register`.
  - Automatically logs in and enters `/app`.
- Implement `/forgot-password`: Recovery request.
- Auth client utility managing the Frappe `sid` cookie.

### Stage 8: Workspace Shell (`/app`)
- Implement authenticated layout with:
  - Collapsible Sidebar with KORKEM branding.
  - Navigation items: Главная, Компания, Склады, Команда, Профиль.
  - Top bar with workspace indicator and user menu.
  - Mobile Sheet drawer for screens < 1024px.
  - Protected route guard redirecting unauthenticated visitors to `/login`.

### Stage 9: Company Profile & Onboarding (`/app/company`)
- If user has no company: show onboarding card to create company.
- `/app/company`:
  - Fetch real data via `GET /api/method/korkem_manufacturing.api.company_details.read`.
  - Form to update BIN, phone, email, website, address, city, bank details via `POST .../company_details.save`.
  - Company stats summary (warehouses count, team count).

### Stage 10: Warehouse Management (`/app/warehouses`)
- Fetch real warehouses via `GET /api/method/korkem_manufacturing.api.warehouses.listing`.
- Display warehouse cards and data table: name, status (активен / отключен), stock positions count, shipping default badge.
- Implement "Создать склад" Dialog calling `POST /api/method/korkem_manufacturing.api.warehouses.create`.
- Actions: Set as default shipping warehouse (`set_shipping_default`), Enable/Disable warehouse (`set_disabled`).
- Implement `/app/warehouses/[id]` detail view.

### Stage 11: Team & Staff Management (`/app/team`)
- Fetch real team members via `GET /api/method/korkem_manufacturing.api.staff.members`.
- Fetch available positions via `GET /api/method/korkem_manufacturing.api.invitations.positions`.
- Implement "Пригласить сотрудника" Dialog calling `POST /api/method/korkem_manufacturing.api.invitations.invite`.
- Role changer calling `POST /api/method/korkem_manufacturing.api.staff.change_position`.
- Deactivate / Reactivate actions calling `POST .../staff.deactivate` / `reactivate`.

### Stage 12: Deployment & Caddy Integration
- Build production Next.js build.
- Configure Caddyfile to route `/`, `/features`, `/download`, `/about`, `/login`, `/register`, and `/app/*` to Next.js while forwarding `/api/*` and `/files/*` to Frappe.

### Stage 13: Testing & Verification
- Test all public, auth, company, warehouse, and team flows.
- Verify responsiveness across 360px, 390px, 768px, 1024px, 1440px.
- Run typecheck and linting.
