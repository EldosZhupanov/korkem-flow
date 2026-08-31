> **АРХИВ. Это не описание системы сегодня.**
> Документ сохранён ради причин, стоящих за решениями. Актуальное состояние — в `NOW.md`, `ROADMAP.md`, `PLAN.md`.
> Не строить по этому файлу.

---

# Sprint 1 / Phase B — Execution Log
## Scaffold korkem_manufacturing and korkem_ai custom apps

## Commands executed

| # | Command | Result |
|---|---|---|
| 1 | `bench new-app korkem_manufacturing` (first attempt, piped stdin answers) | ❌ Aborted — I supplied only 6 of the 7 interactive prompts `_get_user_inputs()` in `frappe/utils/boilerplate.py` asks (App Title, Description, Publisher, Email, License, GitHub Workflow, **Branch Name** — missed the last one), so stdin hit EOF mid-prompt and click aborted. Verified nothing was left on disk (`apps/korkem_manufacturing` didn't exist) before retrying — clean abort, no partial state to clean up. |
| 2 | `bench new-app korkem_manufacturing` (retry, 7 answers) | ✅ App created at `apps/korkem_manufacturing`, installed into the bench (`uv pip install -e`), assets built (esbuild, 144ms). |
| 3 | `bench new-app korkem_ai` (7 answers) | ✅ Same, clean. |
| 4 | `bench --site korkem.localhost install-app korkem_manufacturing` (first attempt) | ❌ **`service "bench" is not running`** — investigated: the container had exited (code 1) ~15s earlier. Log showed honcho's `schedule.1` process crashed with `ModuleNotFoundError: No module named 'korkem_manufacturing'` during its periodic `enqueue_events_for_all_sites` tick — the scheduler process was started at container boot, *before* `korkem_manufacturing` was pip-installed onto the bench, so its Python process never picked up the new editable-install path. Honcho tears down the whole process group when one member crashes (by design), which is why `web`/`socketio`/`watch`/`worker` all stopped too and the container exited. **Not a bug in our setup** — a real, one-time consequence of adding a bench-level app while `bench start` is already running. **Fix**: `docker compose up -d` to restart the container — a fresh process start correctly picks up the already-persisted editable installs. Confirmed stable afterward (no crash-loop). |
| 5 | `bench --site korkem.localhost install-app korkem_manufacturing` (retry) | ✅ Clean. |
| 6 | `bench --site korkem.localhost install-app korkem_ai` | ✅ Clean. |
| 7 | `bench --site korkem.localhost list-apps` | ✅ All 5: `frappe`, `erpnext`, `crm`, `korkem_manufacturing`, `korkem_ai`. |
| 8 | `git status` on `erpnext`/`crm`/`frappe` | `erpnext`/`frappe` clean. `crm` showed the same benign `yarn.lock` diff as Phase A (37 purely-additive lines for a `playwright` dependency, identical to before — confirmed reproducible, not a new issue) — reverted via `git checkout -- yarn.lock`. All three clean after. |

## Operational lesson (carried forward)

**Adding a new app to the bench-level app list while `bench start` is already running requires restarting the container** (or at minimum the `schedule`/`worker`/`web` processes) before the new app's Python module is importable by those long-running processes. `bench --site <site> install-app <app>` (site-level doctype install) does not itself need this — the crash was specifically the scheduler's next periodic tick trying to import an app that didn't exist when it started. Future phases that add more custom apps or update existing ones should restart the bench (`docker compose restart bench` or `up -d`) as a matter of course after any `bench new-app`/`bench get-app`, before relying on the running bench for anything.

## Status: Phase B COMPLETE

Both custom apps scaffolded, installed at bench level and site level, verified via `list-apps`. Vendored repos confirmed clean.
