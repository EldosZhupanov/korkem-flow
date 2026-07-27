# furniture_ai

Shared workspace for the furniture business platform, combining vendored ERP/CRM systems with custom integration code.

## Layout

### Custom code (tracked in this repo)
- `frontend/` — user-facing UI (web/app)
- `backend/` — custom backend services/APIs tying the systems below together
- `telegram/` — Telegram bot integration
- `agents/` — AI agent implementations/orchestration
- `docs/` — project documentation
- `prompts/` — shared prompt templates used by `agents/`

### Vendored projects (own git history, ignored by this repo)
- `erpnext/` — ERPNext
- `frappe/` — Frappe framework
- `crm/` — Frappe CRM
- `relaticle/` — Relaticle
