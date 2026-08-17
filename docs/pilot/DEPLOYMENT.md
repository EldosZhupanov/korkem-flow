# Deploying KORKEM as a pilot

**Date:** 2026-08-17. Written for the deployment that has not happened yet.

This describes how to run KORKEM against a **real furniture business's own
ERPNext data**, on the owner's own server. It is not a demo environment and
there is no demo dataset in it: the fixtures that create one refuse to run here,
by design (see [The refusal](#the-refusal)).

Read [`PRE_DOMAIN_CHECKLIST.md`](./PRE_DOMAIN_CHECKLIST.md) for what is still
outstanding, and [`BACKUP_AND_RESTORE.md`](./BACKUP_AND_RESTORE.md) before the
first day of real data.

---

## What a deployment consists of

```
internet
  → DNS name                       (not yet purchased)
  → :443 Caddy, TLS auto-issued    infra/frappe_bench/docker-compose.public.yml
  → bench:8000 gunicorn            infra/frappe_bench/docker-compose.pilot.yml
  → Frappe + ERPNext + KORKEM      backend/korkem_ai, backend/korkem_manufacturing
  → MariaDB, Redis ×2              named Docker volumes
```

Four containers plus the proxy. Nothing is hosted anywhere else, nothing is
purchased, and no external account is required except the two provider consoles
(Telegram, Meta) if channels are wanted.

## The three compose files, and why they are separate

| file | what it adds | default |
|---|---|---|
| `docker-compose.yml` | the stack: MariaDB, Redis ×2, bench | development |
| `docker-compose.pilot.yml` | production process model, `KORKEM_ENV=pilot`, `restart: always` | opt in |
| `docker-compose.public.yml` | Caddy, TLS, the public hostname | opt in |

They are separate files rather than flags because each is a decision. A bench
that is not published should not be one edit away from being published, and a
development bench should not become a pilot because somebody ran the short
command.

```sh
cd infra/frappe_bench

# development (what every earlier phase used)
docker compose up -d

# pilot, no domain yet — reachable on 127.0.0.1:8000 only
docker compose -f docker-compose.yml -f docker-compose.pilot.yml up -d

# pilot, with the public front door
docker compose -f docker-compose.yml \
               -f docker-compose.pilot.yml \
               -f docker-compose.public.yml up -d
```

Or, which is the same thing plus the checks:

```sh
scripts/deploy_pilot.sh --check     # preflight only; changes nothing
scripts/deploy_pilot.sh             # preflight, backup, migrate, start, verify
```

The script includes the public overlay automatically when `KORKEM_PUBLIC_HOST`
is set in `.env`, and refuses rather than guesses when something is missing. It
never prints a secret — every credential is reported as `set` or `missing`.

## `SITE_NAME` must be the public hostname

Frappe 17 resolves an HTTP request to a site by its **`Host` header and nothing
else** — `default_site` in `common_site_config.json` is read only by the `bench`
CLI. A site created as `korkem.localhost` will answer `Host: korkem.localhost`
and 404 everything else, including `http://localhost:8000/health` from inside
its own container.

Two consequences:

- The container health check and `deploy_pilot.sh` send an explicit
  `Host: $SITE_NAME`. This was found the hard way: a perfectly healthy pilot
  reported itself dead.
- A pilot's `SITE_NAME` has to be the name users will type. Starting the pilot
  from an existing `korkem.localhost` site means renaming it, which is a
  separate operation with its own backup — see the checklist.

## What `pilot` actually changes

Everything is decided from one variable, `KORKEM_ENV`, which
`infra/frappe_bench/scripts/bootstrap.sh` reads and writes into the site config
as `korkem_env`.

| | development | pilot / production |
|---|---|---|
| `developer_mode` | on | **off** |
| `allow_tests` | on | **off**, explicitly |
| scheduler | left as it is | **enabled** |
| web server | `bench serve` (Werkzeug dev server) | **gunicorn**, 2 workers |
| asset watcher | running | **not started** |
| demo fixtures | allowed | **refused** |
| restart policy | `unless-stopped` | `always` |

The four pilot processes — gunicorn, socket.io, the scheduler and one queue
worker — are the same four Frappe's own supervisor configuration runs. They are
listed in `infra/frappe_bench/procfiles/Procfile.pilot`.

### The refusal

`korkem_ai.korkem_ai.environment` answers what kind of site this is, and every
destructive demo fixture asks it first:

```
$ bench --site <site> execute korkem_manufacturing.seed_demo.remove
Deleting the demo factory rewrites or deletes data and is refused on a
'pilot' site. If this site is not a pilot or production site, correct
`korkem_env` in its configuration.
```

Verified against all ten entry points on a real bench in pilot mode. The
environment **fails closed**: a site with no `korkem_env` and no developer mode
is treated as production, and so is a site whose `korkem_env` is a typo.

## Secrets

Nothing sensitive lives in the repository, and the deployment does not put
anything there.

| secret | where it lives | who sets it |
|---|---|---|
| MariaDB root password | `infra/frappe_bench/.env` (gitignored) | operator, once |
| Frappe `Administrator` password | same | operator, once |
| Telegram bot token, webhook secret | encrypted in the database, `Telegram Settings` | operator, in the app |
| WhatsApp token, app secret, verify token | encrypted in the database, `WhatsApp Settings` | operator, in the app |
| AI provider key | encrypted in the database, `AI Provider` | operator, in the app |
| TLS private key | the `caddy-data` Docker volume | Caddy, automatically |

`.gitignore` excludes `.env` and `.env.*` and keeps only `.env.example`. Provider
credentials are `Password` fields, which Frappe stores in `__Auth`; they are
never returned by an API, never written to a log, never rendered in the app, and
masked wherever the settings screen shows them at all.

## Health

Two endpoints, served by the application itself, so a bench with no proxy in
front of it still answers them.

```sh
curl https://<host>/health          # liveness  — is this process serving
curl https://<host>/health/ready    # readiness — is everything it needs there
```

`/health/ready` reports six components: database, Redis cache, Redis queue,
background workers, scheduler, ERPNext. It answers **200** when all are up and
**503** when any is not, so an orchestrator can read the status code alone.

An **anonymous** caller gets a traffic light and nothing else — each component
`ok`, `down` or `unknown`. Versions, queue depths, the environment name, the
site name and the reason a component is down are shown only to a signed-in
**System Manager**. A failure is reported as its exception *class*, never its
message, because a database error message can quote a connection string.

The Docker healthcheck calls `/health`, so what Docker believes and what an
operator's `curl` reports are the same answer from the same code.

## Security posture, item by item

Checked before writing any of this, and re-checked after. Where something was
wrong it says so and says what was done.

| | state |
|---|---|
| **Authentication** | Frappe sessions and API key pairs, unchanged. Onboarding creates no password, so a new account cannot be signed into until an administrator sets one. |
| **Authorization** | stock ERPNext roles throughout. The one custom role, `Korkem Customer`, is granted only by `customer_access.link`, which writes the restriction in the same call. |
| **Company isolation** | a Company `User Permission`, written by onboarding, read by `tools/scope.py`. Verified through the tool, not the permission row. |
| **Customer isolation** | `Portal User` + role + Customer `User Permission`, all three or none. Verified by listing Sales Orders as a customer account. |
| **System Manager endpoints** | every write in `channels_api` and `settings_api` calls `frappe.only_for("System Manager")`. `list_work_instructions` deliberately does not — it reads through `frappe.get_list`, so it grants nothing ERPNext would not. |
| **Onboarding** | not whitelisted at all; bench-only, and `only_for("System Manager")` besides. |
| **CSRF** | Frappe's own check is active; `ignore_csrf` is **not** set on this site or in the common config. |
| **CORS** | `allow_cors` is **not** set, so no cross-origin caller is trusted. |
| **Secure cookies** | **was broken for a TLS pilot, is fixed, and the fix is measured.** `auth.set_cookie` derives the `Secure` flag from `request.scheme`, which behind a proxy is `http`. A pilot now serves through `korkem_ai.wsgi:application`, which applies `ProxyFix` — one trusted hop. Signing in through the TLS proxy returns `sid=…; Secure; HttpOnly; SameSite=Lax`; the same login sent directly over plain HTTP returns the same cookie **without** `Secure`, which is the control that proves it is the forwarded scheme doing the work. |
| **Webhook signatures** | unchanged: Telegram's secret header, Meta's HMAC. Both checked before the body is parsed. |
| **Webhook body limits** | 1 MB in the application, and now 2 MB at the proxy as well, refused before any Python runs. |
| **Rate limiting** | not enabled, on purpose — Frappe's site-wide switch is a shared budget, not per-client, so one caller could lock out everybody. See `PRE_DOMAIN_CHECKLIST.md`. |
| **Debug mode** | `developer_mode 0` in pilot, verified on the bench; `server_script_enabled` is not set, so no Server Script can execute Python. |
| **Internal ports** | MariaDB and both Redis instances publish **nothing**. The application binds `127.0.0.1` even without the public overlay — it used to bind `0.0.0.0`, which on a machine with a public address published the bench to the internet. |
| **Secret leakage** | tracked files scanned for token, key and `Authorization` patterns: nothing. `.env` is gitignored and only `.env.example` is tracked. Health output is tested against the site's own `db_password`, `encryption_key` and `admin_password`. |
| **Proxy config** | the previous public overlay **would not have started**: `header_up` was written at site level, which Caddy rejects as an unrecognised directive. Both profiles now pass `caddy validate`. |

## Onboarding real people

Three functions, run from the bench, all idempotent. None accepts, generates or
returns a password.

```sh
bench --site <site> execute korkem_ai.korkem_ai.onboarding.create_owner \
  --kwargs '{"email": "...", "first_name": "...", "company": "..."}'

bench --site <site> execute korkem_ai.korkem_ai.onboarding.create_employee \
  --kwargs '{"email": "...", "first_name": "...", "roles": ["Manufacturing User", "Stock User"]}'

bench --site <site> execute korkem_ai.korkem_ai.onboarding.create_customer_user \
  --kwargs '{"email": "...", "first_name": "...", "customer": "<Customer name>"}'
```

Every role used is a **stock ERPNext role**. What these add over the desk's own
user form is that the three things which must never come apart are written
together:

- an **employee or owner** gets their roles *and* a Company `User Permission`,
  which is what `tools/scope.py` reads and what makes `get_list` filter by
  company without any of our code being involved;
- a **customer** gets a `Portal User` row, the `Korkem Customer` role and a
  Customer `User Permission` — all three, or none. A customer account is not
  "a user with fewer roles"; without the permission it can read every order on
  the site.

The account is created **enabled and without a password**, so it cannot be
signed into until an administrator sets one (User → Set New Password) or SMTP is
configured and Frappe's own password reset is used. That keeps credentials out
of this repository, out of a return value and out of a log.

Not whitelisted, deliberately: an HTTP endpoint that creates privileged users is
a larger surface than this needs.

## Updating a running pilot

```sh
git pull                       # in the repo, and in backend/korkem_ai etc.
scripts/deploy_pilot.sh        # backs up, rebuilds, restarts, migrates, verifies
```

The script takes a database backup **before** migrating. It never runs
`down -v`, `drop-site`, `remove-app` or any demo fixture.

## What is not covered here, and is not pretended to be

- **No domain, so no *public* certificate has ever been issued.** Both proxy
  profiles have now been exercised for real against the pilot bench, over TLS,
  using Caddy's **internal CA** on the Docker network (`tls internal`, host
  `korkem.localhost`, no host ports published) — see the verification table in
  `PRE_DOMAIN_CHECKLIST.md`. What that leaves untested is exactly one thing: the
  ACME exchange with Let's Encrypt, which needs a public name and open ports.
  Everything downstream of the certificate is measured, not assumed.
- **No real Telegram or WhatsApp traffic.** Unchanged from Phase 33: the
  blocker is credentials plus a public hostname.
- **Backups are not yet automated.** `BACKUP_AND_RESTORE.md` gives the
  procedure and the cron line; nothing schedules it for you.
- **No email.** SMTP is unconfigured, so password resets and Frappe
  notifications will not send. It is not needed for the app or the channels.
- **One machine.** No replication, no failover, no off-machine backup target.
  For a single-factory pilot that is a considered choice, not an oversight —
  but it means the restore procedure is the disaster plan, so test it.
