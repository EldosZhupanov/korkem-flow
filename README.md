# furniture_ai

Shared workspace for the furniture business platform, combining vendored ERP/CRM systems with custom integration code.

- **[`PROJECT.md`](./PROJECT.md)** — product constitution: mission, vision, the Production Order lifecycle, AI agents, modules, integrations, and non-goals.
- **[`CLAUDE.md`](./CLAUDE.md)** — operating guidance and repository reference for Claude Code when working in this repo.

## Layout

### Custom code (tracked in this repo)
- `frontend/` — user-facing UI (web/app)
- `backend/` — custom backend services/APIs tying the systems below together
- `infra/` — deployment/infrastructure (currently: `frappe_bench/`, a Docker Compose setup that runs `erpnext`/`crm` on top of the vendored `frappe` framework)
- `telegram/` — Telegram bot integration
- `agents/` — AI agent implementations/orchestration
- `docs/` — project documentation
- `prompts/` — shared prompt templates used by `agents/`

### Vendored projects (own git history, ignored by this repo)
- `erpnext/` — ERPNext
- `frappe/` — Frappe framework
- `crm/` — Frappe CRM
- `relaticle/` — Relaticle
