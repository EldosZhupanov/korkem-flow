# KORKEM Flow — Product Spec

Client: KORKEM (furniture & door facade manufacturing + advertising agency, Kazakhstan). Saved verbatim as received, for reference against `docs/architecture/domain_model.md` and future milestone planning. Not yet decomposed into implementation milestones or built — see the conversation for the milestone/approach discussion.

---

Create a comprehensive, production-ready ERP system for "KORKEM" (furniture & door facade manufacturing and advertising agency) called "KORKEM Flow". The app features a modern, ultra-clean dark UI (black, dark gray, neon green accents #39ff14) optimized for desktop and mobile shop-floor workers.

### 1. COMPACT ORDERS TABLE & DETAILED BREAKDOWN VIEW
- Main Orders View: Clean compact table showing Order #, Client Name, Phone, Total Area (m²), Status Badges, Stage Checkboxes (Cutting/Кесу, Router/Фреза, Sanding/Шкурка, Vacuum/Вакуум, Paint/Бояу, Ready/Аяқталды), Financials (Total ₸, Paid ₸, Balance ₸), Urgent/VIP badges, and Action Buttons.
- Compact View Toggle: Quick switch to hide financial columns and non-essential data for a sleek, scannable table.
- Detailed Order Drawer/Modal (On Row Click):
  * Header: Client info, total m², total price, advance paid, remaining balance.
  * Itemized Facade List: Product type, Dimensions (H x W x Th mm), Qty, Total m² per item.
  * Film & Material Specs: Top film decor, Bottom film decor (e.g., KIRA, JS Group, Greenwood), code, film consumption estimate (meters).
  * Milling & Edge Specs: Milling pattern / code, edge profile (R3, 90°, etc.).
  * Stage Assignment: Tracks assigned operators for Router (ЧПУшник), Sander (Шкурщик), Vacuum Press (Вакуумщик), Painter (Маляр), and Packer (Упаковщик).

### 2. AUTOMATIC & MANUAL ITEM COLOR-CODING
- Auto Decor Grouping: Automatically assign distinct visual background colors/badges to facade items based on their film decor (e.g., items 1–10 "White Matte" -> Color A, 11–15 "Black Matte" -> Color B, 16–21 "Oak Pine" -> Color C).
- Bulk Manual Color Assignment: Multi-select checkboxes for order position numbers (e.g., selecting non-sequential positions 11, 13, 16, 17) to manually apply a specific decor tag ("Black Matte") or highlight color from a palette in 1 click.
- Non-Sequential Grouping: Allow selecting arbitrary position combinations (e.g., items 12, 14, 15) and applying another decor tag ("Kashmere").
- Visual Differentiation: Highlight color groups with side-borders, badges, or row backgrounds on screen and printed job sheets.

### 3. CLIENTS & ANALYTICS MODULE WITH EXCEL APPROVAL SHEET GENERATOR
- Client Stats Table: Displays Client Name, Phone, VIP Tier, Total Orders Count, Total Area (m²), Total Order Value (₸), Paid Amount (₸), Debt Balance (₸), and Last Order Date.
- Time Filters: "Today", "This Week", "This Month", "All Time", and Custom Date Range.
- Summary Text Report Card: Displays clean text summary (e.g., "Client Altay Sadykov generated 128.5 m² and 1,450,000 ₸ revenue this month; Total paid: 1,200,000 ₸; Remaining balance: 250,000 ₸").
- Excel (.xlsx) Approval Sheet Generation: 1-click button "Загрузить Excel для утверждения" in client view to generate a structured Excel specification sheet containing itemized dimensions, decors, millings, edge types, totals, and a signature approval block ("С детализацией ознакомлен и утвердил: _________") for the client.

### 4. URGENT ORDERS & VIP CLIENT MARKS
- Express Order Toggle: "🔥 Срочный заказ" toggle when creating/editing orders. Highlights urgent orders with a glowing red border and "🔥 СРОЧНО" tag on table and printed shop sheets.
- Client Tiers: "👑 VIP / Особый", "⭐ Постоянный", and "🆕 Новый". Displays VIP badges across all screens.
- Priority Sorting: Filters to show "Urgent First" or "Filter by VIP".

### 5. HYBRID PVC FILM & MDF WAREHOUSE MANAGEMENT
- Pre-loaded Supplier Catalogs: Built-in decor databases from major suppliers (KIRA, JS Group, Greenwood, ALER, etc.) with instant auto-complete suggestions.
- Manual Decor Entry & Custom Catalog: Allow adding custom decors manually via "+ Новый декор" (typing Decor Name, Code, Supplier, Thickness, Cost ₸/m), which automatically saves into KORKEM's custom decor library for future reuse.
- Inventory & Dual Units: Track film stock in Linear Meters (п.м) and Total Area (m²). Roll intake logs supplier, decor code, meters, and cost.
- Auto-Deduction & Offcuts (Деловой отход): Deduct film during production, track direct retail film sales to clients, and log usable film/MDF offcuts (L x W mm) for small jobs.
- Restock Alerts: Visual warning highlight when roll length drops below safety threshold (e.g., < 15 meters).

### 6. WORKSHOP ROLES, CUSTOM ROLES & RESPONSIBILITY CHAIN
- Flexible Roles: Support Router Operator (ЧПУшник), Sander (Шкурщик), Vacuum Operator (Вакуумщик), Painter (Маляр), Packer (Упаковщик).
- Custom & Multi-Roles: Allow typing custom roles manually (e.g., "Поклейщик", "Разнорабочий") and assigning multiple roles to a single worker (e.g., universal worker performing both Sanding and Vacuum operations).
- Multi-Worker Splitting: Allow splitting sanding or prep work between 2–5 workers by percentage (e.g., Azamat 30%, Vova 40%, Semen 30%) or exact area (m²).

### 7. HYBRID BONUS, SALARY & ADVANCE MANAGEMENT
- Daily/Monthly Targets: Auto-suggest bonuses for daily thresholds (>= 50 m²/day -> +5,000 ₸) and monthly milestones (>= 500 m²/month -> +5%).
- Period Filters: "Today", "1st to 15th", "16th to end of month", "Current Month", "Full Year", or Custom Range.
- Payroll Equation: Total Earned - Advances Paid = Remaining Payable Balance. Includes advance logging and defect penalty deductions. Export to PDF/Excel.

### 8. WORKERS MOBILE DASHBOARD (PIN Login)
- 4-digit PIN login with demo user shortcuts on the login screen for testing (Admin: 0000, Router: 1111, Sander: 2222, Vacuum: 3333).
- Touch-friendly controls, large action buttons, task lists, bonus target progress bar ("8 m² left until bonus!").

### 9. SHOP FLOOR JOB SHEETS & WHATSAPP NOTIFICATIONS
- Shop Sheets: Printed workshop orders show ONLY technical parameters (dimensions, millings, decors, edge profiles, color groups)—NO prices or margins.
- WhatsApp Trigger: One-click readiness notification to clients when order reaches "Packaged & Ready".
