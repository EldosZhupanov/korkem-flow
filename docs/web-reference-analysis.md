# KORKEM Web Portal Reference Analysis

**Date:** 2026-09-14  
**Status:** PHASE 1 COMPLETED — DO NOT MODIFY CODE YET

---

## 1. Introduction

To transform the KORKEM web presence from internal/debug screens into a premier B2B SaaS web portal, two industry-leading references were analyzed:
1. **Primary Architectural Reference:** [`nextjs/saas-starter`](https://github.com/nextjs/saas-starter)
2. **Secondary UI/Dashboard Reference:** [`shadcndashboard/next-shadcn-dashboard`](https://github.com/shadcndashboard/next-shadcn-dashboard)

This document establishes key architectural decisions, UI patterns, and component conventions adapted specifically for the KORKEM ERPNext/Frappe backend ecosystem.

---

## 2. Architectural Analysis: `nextjs/saas-starter`

### 2.1 Marketing Site Architecture
- **Route Grouping:** Uses Next.js App Router route groups `(dashboard)` and `(login)` to isolate distinct layout requirements without adding segments to the public URL paths.
- **Header & Navigation:**
  - Sticky minimal top navigation with company logo, product links, and conditional auth state (Login/Sign-up vs. Dashboard button + User Avatar menu).
  - Clean server/client separation: Marketing pages are server-rendered for instant First Contentful Paint (FCP) and SEO, with minimal client interactive islands (e.g. `UserMenu`, `Terminal`, `PricingToggle`).
- **Hero & Value Proposition:**
  - Clear, restrained typography (`tracking-tight font-extrabold sm:text-5xl md:text-6xl`).
  - Clear single action CTA (`Button size="lg"`).
  - Feature grid with 3-column structured value points (Icon + Title + concise description).

### 2.2 Auth Architecture & Session Handling
- **Route Organization:**
  - `app/(login)/login.tsx` shared by both `sign-in` and `sign-up` via a `mode` parameter.
  - Form actions powered by React 19 / Next.js Server Actions with `useActionState`:
    - Handles pending states (`isPending`, spinner).
    - Returns structured error messages (`{ error: string, email?: string }`).
    - Redirect parameter preservation (`?redirect=/app/warehouses`).
- **Session Handling:**
  - In `saas-starter`, sessions are stored in an encrypted HTTP-only cookie.
  - **KORKEM Mapping:** Matches Frappe's native session architecture perfectly! Frappe sets `sid` (HTTP-only, SameSite=Lax). In KORKEM's web layer, the Next.js API/middleware forwards or reads this cookie, preventing any client-side token exposure.

### 2.3 Protected Routes & Middleware
- **Middleware Flow:**
  - Checks if request path starts with protected routes (`/app/*`, `/dashboard/*`).
  - Verifies presence and validity of session cookie.
  - If unauthenticated, redirects to `/login?redirect=<target_path>`.
  - If authenticated user accesses `/login` or `/register`, redirects to `/app`.

### 2.4 Workspace / Team Concept & Permissions
- **Team / Organization Hierarchy:**
  - Every user is bound to an organization (Team).
  - Roles: `owner`, `admin`, `member`.
  - Invitations: Pending invitations sent by email, accepted via secure token.
- **KORKEM Mapping:**
  - KORKEM already has this exact concept: `Company` in ERPNext.
  - Owner holds `System Manager` + `Manufacturing Manager` + `Stock Manager`.
  - Team members hold positions mapped via `korkem_manufacturing.api.invitations.positions`.
  - Scoping is enforced by `services.scope.current_company()`.

### 2.5 Onboarding Flow
- If an authenticated user has no company membership (or first registration), the router directs them to `/app/company/new` or an onboarding step to register their furniture company.
- After company creation, `User Permission` is bound, and the user enters `/app`.

---

## 3. UI & Design System Analysis: `next-shadcn-dashboard`

### 3.1 Design Tokens & Typography
- **Font Stack:** Inter / system font family (`font-sans`), font weights 400 (regular), 500 (medium), 600 (semibold), 700 (bold).
- **Type Scale:**
  - Page Titles: `text-2xl font-bold tracking-tight` (desktop `text-3xl`).
  - Section Headers: `text-lg font-semibold`.
  - Body Text: `text-sm text-muted-foreground` / `text-foreground`.
  - Microcopy / Badges: `text-xs font-medium`.
- **Spacing:** Strict 4px/8px Tailwind scale (`p-4`, `p-6`, `gap-4`, `space-y-6`).
- **Surfaces & Borders:**
  - Light mode: Clean neutral `#FFFFFF` cards, `#F8FAFC` background, `#E2E8F0` borders.
  - Dark mode: Slate `#0F172A` background, `#1E293B` card surface, `#334155` subtle borders.

### 3.2 Workspace Shell & Navigation Structure
- **Sidebar (`components/ui/sidebar.tsx`):**
  - Collapsible (expanded width 256px `w-64`, icon rail `w-16`).
  - Header: KORKEM Logo + Workspace switcher.
  - Main Navigation: Grouped sections with Lucide icons:
    - *Основное:* Главная (`/app`), Компания (`/app/company`), Склады (`/app/warehouses`), Команда (`/app/team`).
    - *Производство (готовность):* Заказы (`/app/orders`), Закупки, Раскрой.
  - Footer: User profile widget with avatar, name, email, and popover for Profile, Settings, Sign Out.
- **Mobile Responsive Behavior:**
  - Below 1024px (`lg`), the sidebar collapses into a slide-over Sheet / Drawer triggered by a hamburger menu in the top bar.
  - Zero horizontal scrolling or viewport overflow.

### 3.3 Core Components & States
- **Cards (`components/ui/card.tsx`):**
  - Used for metric highlights, warehouse cards, and form sections.
  - Composed of `CardHeader`, `CardTitle`, `CardDescription`, `CardContent`, `CardFooter`.
- **Tables & Data Grids (`components/ui/table.tsx`):**
  - Dense, readable tabular layout for warehouses, team members, and inventory items.
  - Clear headers, status badges, and action menus (3 dots / dropdown).
- **Forms & Inputs (`components/ui/input.tsx`, `field.tsx`):**
  - Standardized inputs with clear focus ring (`focus-visible:ring-2 focus-visible:ring-ring`).
  - Consistent label and helper error message styling.
- **Dialogs & Sheets (`components/ui/dialog.tsx`, `sheet.tsx`):**
  - Modal dialog for fast warehouse creation ("Создать склад").
  - Sheet drawer for slide-over editing.
- **Feedback States:**
  - **LoadingState:** Subtle skeleton loaders (`Skeleton`) rather than jarring full-screen spinners.
  - **EmptyState:** Clear illustration/icon, explanatory message, and primary CTA button (e.g. "У вас пока нет складов — Создать склад").
  - **ErrorState:** Inline banner with retry action.

---

## 4. Synthesis & Architectural Strategy for KORKEM

### 4.1 What We Are Reusing (Source of Truth)
- **Authentication:** Frappe Session (`POST /api/method/login`, `GET /api/method/logout`, `GET /api/method/frappe.auth.get_logged_user`).
- **Registration:** `POST /api/method/korkem_manufacturing.api.registration.register`.
- **Company Management:** `GET / POST /api/method/korkem_manufacturing.api.company_details.*`.
- **Warehouse Management:** `GET / POST /api/method/korkem_manufacturing.api.warehouses.*`.
- **Team & Staff:** `GET / POST /api/method/korkem_manufacturing.api.staff.*` and `invitations.*`.
- **Distribution Files:** Existing build artifacts (`korkem-flow.apk`, `korkem-flow-windows-x64.zip`).

### 4.2 What We Are Building
A high-performance, modern Next.js 15+ application (`web/`) in the repository:
1. **Public Marketing Site:**
   - `/` (Home): SaaS B2B furniture operating system positioning.
   - `/features`: Deep dive into CRM, Cutting/CNC, Warehouse, and AI.
   - `/download`: Professional download center with Android, Windows, Mac, and iPhone guides.
   - `/about`: Philosophy and mission of KORKEM in Central Asia.
2. **Auth Pages:**
   - `/login`: Professional sign-in screen connecting to Frappe auth.
   - `/register`: Workshop & owner onboarding form.
   - `/forgot-password`: Password recovery request.
3. **Authenticated Workspace (`/app`):**
   - `/app`: Executive factory dashboard overview.
   - `/app/company`: Factory profile, BIN, addresses, banking details.
   - `/app/company/settings`: Operational defaults.
   - `/app/warehouses`: Live warehouse list with stock counts and creation dialog.
   - `/app/warehouses/[id]`: Warehouse detail view.
   - `/app/team`: Team member directory, roles, and invitation dialog.
   - `/app/profile`: Current user details and sign out.
