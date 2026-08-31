---
name: korkem-bench
description: Running the KORKEM Frappe bench, its tests, and the pilot/public deployment overlays — plus the failures that look like bugs and are not. Load before starting the bench, running backend tests, seeding demo data, deploying a pilot, or debugging "the app cannot reach the server".
---

# The KORKEM bench

Four containers: MariaDB, two Redis (cache and queue), and `bench`. Site is
`korkem.localhost`, reachable at `http://korkem.localhost:8000` once up
(`.localhost` resolves to loopback — no `/etc/hosts` edit).

```sh
docker compose -f infra/frappe_bench/docker-compose.yml up -d
```

First run auto-bootstraps: `scripts/entrypoint.sh` → `bootstrap.sh` →
`start.sh`. Admin password comes from `infra/frappe_bench/.env` (gitignored,
copy from `.env.example`).

## Three compose files, and they compose

| file | adds |
|---|---|
| `docker-compose.yml` | the development bench |
| `docker-compose.pilot.yml` | gunicorn via `scripts/web.sh` + `procfiles/Procfile.pilot`, no asset watcher, `restart: always`, `KORKEM_ENV=pilot` |
| `docker-compose.public.yml` | Caddy with auto-TLS, profile chosen by `KORKEM_PROXY_PROFILE` (`webhooks` default, or `app`) |

`scripts/deploy_pilot.sh --check` then `scripts/deploy_pilot.sh` runs a
deployment with its checks. Full procedure: `docs/operations/`.

## `KORKEM_ENV` decides everything environmental

`development` | `pilot` | `production` — developer mode, `allow_tests`, the
scheduler, which Procfile — written into the site config as `korkem_env`.
`korkem_ai.korkem_ai.environment` is the **one** place that reads it. Every
destructive fixture in `seed_demo` calls `require_non_production` first, and an
unlabelled non-developer site is treated as production.

**Do not add a second way to ask what environment a site is.**

## Tests

```sh
docker compose exec -T bench sh -lc \
  'cd /home/frappe/frappe-bench && bench --site korkem.localhost run-tests --app korkem_manufacturing'
docker compose exec -T bench bash -o pipefail -lc \
  'cd /home/frappe/frappe-bench && bench --site korkem.localhost run-tests --app korkem_ai 2>&1 | tee /tmp/korkem-ai-test.log'
```

The `korkem_ai` suite is ~1 000 tests and takes **around 26 minutes**. Pipe it
to a file inside the container: the statistics scroll away otherwise, and the
log survives the shell that started it.

Known-good baseline, measured 2026-08-31 on a clean volume:
`korkem_manufacturing` **13/13 OK** in 12.3 s; `korkem_ai` **1037 tests, 1028
pass, 0 failures, 0 errors, 9 skipped** in 21 min 24 s. Both exit 0.

Nine skips are expected — provider-credential cases that cannot run without
real secrets. A run reporting **more** skips than that is the failure mode to
watch for: without `before_tests` seeding the demo factory, roughly 130
production tests call `skipTest` and vanish while the run still says OK.

## Failures that look like bugs and are not

**"Site localhost does not exist" on a healthy bench.** Frappe 17 resolves an
HTTP request to a site by its **`Host` header only** — `default_site` is
CLI-only. The healthcheck and `deploy_pilot.sh` therefore send
`Host: $SITE_NAME`. Do the same in any probe you write.

**"The app signs in and then the assistant never answers."** `webserver_host`
must be set (`bench set-config -g webserver_host 127.0.0.1`, done in
`bootstrap.sh`). Without it, socket.io derives the URL it calls the web server
back on from the client's own `Origin` header. A browser on the host sends
`korkem.localhost`, which resolves; an Android emulator sends `10.0.2.2`,
which means nothing inside the container, and every socket connection is
refused as `Unauthorized: TypeError: fetch failed`. HTTP keeps working
throughout, which is what makes it confusing.

**A session cookie without `Secure` behind TLS.** A pilot serves through
`korkem_ai.wsgi:application`, not `frappe.app:application`: it adds the
static-file middleware (the proxy container cannot read the bench's disk) and
`ProxyFix`, without which `request.scheme` is `http` behind TLS.

**All four containers exit 255 at once.** Not the bench — memory. The emulator
and the bench compete for the WSL VM's budget. Boot the emulator with
`-memory 1536`, start the bench first, and stop the Gradle daemon.

**Startup scripts appear not to change.** They are mounted, not baked into the
image — but editing `entrypoint.sh` used to require an image rebuild and
silently did not get one, so bootstrap would configure a pilot and the
container would then start the development server. Restart the container after
editing them.

**A demo run has "broken" production.** Four device runs in a row exhaust the
edge banding, and the fifth correctly refuses to start production. Restore the
demo dataset between runs.

**Test evidence disappears.** The launch-readiness module's teardown deletes
`Notification Delivery` and `Channel Event` **globally**. Take any verification
*before* running further tests.

## Health

`/health` and `/health/ready` are served by
`korkem_ai.korkem_ai.health.HealthPage` through Frappe's `page_renderer` hook —
no proxy needed, answers anonymously, 200 / 503.

## The vendored trees must stay pristine

`erpnext/`, `frappe/`, `crm/`, `relaticle/` are independent git repositories,
excluded from the root repo. `bench build` occasionally touches a tracked file
incidentally (observed: `crm/frontend/auto-imports.d.ts`, `crm/yarn.lock`).
**Check `git -C <repo> status` after any bench rebuild and revert anything
unexpected.**

`backend/korkem_manufacturing/` and `backend/korkem_ai/` **are part of this
repository** as of 2026-08-31. They were separate git repos until then, because
`bench get-app --soft-link` requires one — and that requirement kept the
product's own source out of its own clone for a month.

The requirement is real. In `bench/app.py`, `App.is_repo` defaults to `True`
when the app is not yet installed, so `setup_details()` reaches
`git.Repo(mount_path)` and raises `InvalidGitRepositoryError` on a plain
directory; the `--no-git` branch above it is unreachable from `get-app`.

`bootstrap.sh` therefore no longer calls `get-app` for our apps. It does the
three things that call actually accomplished — symlink into `apps/`, append to
`sites/apps.txt`, `pip install --editable --no-deps` — verified against a bench
built the old way. `pip install -e` on a non-git directory was confirmed to
work here: flit reads the version from `__init__.py`, not from git.

**Not yet verified: a full bootstrap on a clean volume through this path.**
Until it is, treat a fresh-volume bring-up as the riskiest operation in this
repository.
