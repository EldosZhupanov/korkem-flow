> **АРХИВ. Это не описание системы сегодня.**
> Документ сохранён ради причин, стоящих за решениями. Актуальное состояние — в `NOW.md`, `ROADMAP.md`, `PLAN.md`.
> Не строить по этому файлу.

---

# Sprint 1 / Phase C — Execution Log
## Data layer for the Sprint 1 slice

## Real infrastructure gap found and fixed before any DocType work

`korkem_manufacturing`/`korkem_ai` only existed inside the `bench-data` **Docker volume** (created there by `bench new-app` in Phase B) — not bind-mounted from the host, unlike `erpnext`/`frappe`/`crm`. None of that code was version-controlled or visible outside the container; a volume removal would have destroyed it. Fixed before writing any DocTypes:

1. `docker cp`'d both app directories out of the container onto the host under `backend/`.
2. Discovered (empirically, by instantiating bench's own `App` class) that `bench get-app --soft-link` requires the target to be a real git repository, even for a purely local path — a bare directory triggers an unhandled bug in bench's `App.url` property (`AttributeError: 'App' object has no attribute 'org'`), confirmed by reading `bench/app.py`'s source directly rather than guessed.
3. Gave `backend/korkem_manufacturing/` and `backend/korkem_ai/` their own independent git repos (same mechanism as the four vendored projects, added to root `.gitignore`) — the correct, idiomatic shape for a Frappe app regardless, and the only way to satisfy bench's tooling.
4. Updated `docker-compose.yml` (bind-mounts) and `bootstrap.sh` (`get-app --soft-link` for both, from the new bind-mount paths) so a fresh rebuild is fully self-contained.
5. Full clean rebuild (`down`, remove `bench-data` volume, `up`) — succeeded first try with the git-repo fix in place. All 5 apps (`frappe`, `erpnext`, `crm`, `korkem_manufacturing`, `korkem_ai`) confirmed installed; vendored repos confirmed clean (after reverting the same benign `crm/yarn.lock` diff seen in Phases A/B).

## DocTypes written (real schema + real logic, `backend/korkem_ai/`)

- **Agent Conversation** — `user`, `channel` (Web/WhatsApp/Telegram), `status` (Active/Closed), `started_on`. Controller: `add_message()`, `close()`.
- **Agent Conversation Message** — `conversation` (Link), `sender` (User/Agent/System), `content`, `sent_at`.
- **Pending Action** — `entity_type`/`entity_name` (Link/Dynamic Link, generalizes to any doctype), `action_class` (dotted Python path), `action_data`/`display_data`/`result_data` (JSON), `status` (Pending/Approved/Rejected/Expired), `expires_at`, `resolved_by`, `resolved_at`. Controller implements the real approve/reject/expire mechanics from ADR-0003/0008/0014/0015 and `domain_model.md` invariant 9:
  - `approve()`: checks status is Pending, checks not expired, **re-validates the target entity still exists** (invariant 9), dynamically resolves and calls `action_class` with `action_data` as kwargs, records the result.
  - `reject(reason)`: records rejection + optional reason.
  - `expire_stale_pending_actions()`: module-level function wired into `hooks.py`'s `scheduler_events` (hourly) — the System-only `ExpirePendingAction` command from the Command Catalogue.

## `korkem_manufacturing/`: `originating_deal` custom field

Added via a `post_model_sync` patch (`create_custom_field`, idempotent, mirrors the exact pattern used throughout `erpnext/patches/`) — `Work Order.originating_deal` (Link → `CRM Deal`), per `domain_model.md` §3.4. `erpnext` itself is untouched; confirmed via `git status` before and after.

## C4 (Task/`reference_doctype` extension) — turned out to need no code

Checked `crm_task.json` directly: `reference_doctype` is already a plain, unrestricted `Link` to `DocType` with no filters. ADR-0023's assumption that a hook was needed to "extend the valid target list" was incorrect — any Task can already reference a `Work Order` today. No hook written; this finding should be corrected into `domain_model.md`/ADR-0023 on their next revision.

## Bugs found and fixed via real test failures

1. **CRM's own test fixtures were missing a demo user** (`crm.user1@example.com`), causing `setUpClass` to fail for two of the three new test classes with `LinkValidationError`. Root cause: CRM defines a `before_tests` hook (`crm.tests.before_tests`) that seeds this data, but it only runs when CRM's own test suite runs — not when scoped to `--app korkem_ai`. Fixed by running it once (`bench execute crm.tests.before_tests`) — a data-seeding step, not a code change, and it doesn't touch the vendored `crm/` repo.
2. **Real bug in `Pending Action`**: `result_data` (a JSON-fieldtype field) comes back as a raw string after `.reload()` — Frappe's JSON fieldtype serializes dict→string on save but does not auto-deserialize on load (confirmed by reading `frappe/model/base_document.py`). Fixed by using `frappe.parse_json()` wherever these fields are read (the controller's `approve()`, and the tests reading `result_data` after reload) — the correct, idiomatic Frappe pattern for this fieldtype, not a workaround.

## Test results

`bench --site korkem.localhost run-tests --app korkem_ai`: **12/12 passing** (Agent Conversation: 4, Agent Conversation Message: 2, Pending Action: 6, including the invariant-9 re-validation-at-approval-time test and the scheduled-expiry test).

## Status: Phase C COMPLETE
