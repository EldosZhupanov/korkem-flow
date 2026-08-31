# Backup and restore

**Date:** 2026-08-17.

The pilot runs on one machine. There is no replica and no failover, so **restore
is the disaster plan** — which makes the only meaningful test of a backup a
restore that was actually performed.

No backup of real data was taken while writing this: there is no real data yet,
and taking one would require the operator's own credentials. Every command below
was run against the development bench, which is the same code path.

---

## What holds state

| what | where | lost if |
|---|---|---|
| all business data | `mariadb-data` Docker volume | `docker compose down -v`, or the volume is removed |
| uploaded files, site config, encryption key | `bench-data` volume, under `frappe-bench/sites/<site>` | same |
| enqueued background jobs | `redis-queue-data` volume (append-only) | same |
| cache and sessions | `redis-cache`, no volume | any restart — deliberately, it is all derivable |
| TLS certificate and ACME account | `caddy-data` volume | same; re-issued on next start, which Let's Encrypt rate-limits |

`docker compose down`, `up`, `restart` and `--force-recreate` all keep the
volumes. **`docker compose down -v` is the one command that destroys the
business.** It appears nowhere in `deploy_pilot.sh` and should appear in no
script anybody runs by habit.

Verified: containers torn down with `down`, brought back with the pilot overlay,
and the data was unchanged — 122 Sales Orders, 3 Work Orders, 15 Customers
before and after.

## Taking a backup

Frappe's own command. `deploy_pilot.sh` runs it automatically before every
migration.

```sh
cd infra/frappe_bench
C="docker compose -f docker-compose.yml -f docker-compose.pilot.yml"

# database only — fast, and what a migration needs protecting against
$C exec -T bench bash -lc 'cd ~/frappe-bench && bench --site $SITE_NAME backup'

# database + uploaded files — what a machine failure needs
$C exec -T bench bash -lc 'cd ~/frappe-bench && bench --site $SITE_NAME backup --with-files'
```

It writes into `sites/<site>/private/backups`:

```
20260817_164556-korkem_localhost-database.sql.gz            9.2 MB
20260817_164556-korkem_localhost-site_config_backup.json
```

### Get it off the machine

A backup that lives only on the machine it protects is not a backup of that
machine. Copy it to the host, then to somewhere else entirely:

```sh
# container → host
docker compose cp bench:/home/frappe/frappe-bench/sites/<site>/private/backups ./backups

# host → anywhere off this machine (choose one you actually have)
rsync -av ./backups/ user@another-host:/srv/korkem-backups/
```

### The encryption key

`site_config.json` holds `encryption_key`, and **without it the database backup
is not fully restorable**: every `Password` field — the Telegram token, the
WhatsApp credentials, the AI provider key — is encrypted with it. Frappe writes
`*-site_config_backup.json` alongside the dump for exactly this reason.

Keep it **with** the backup and treat it as a credential: same access control as
the database dump, never in git, never in a chat message.

### On a schedule

Nothing schedules this for you. On the host, once a real pilot exists:

```cron
# 02:15 daily: database + files, then keep 14 days
15 2 * * * cd /path/to/furniture_ai/infra/frappe_bench && \
  docker compose -f docker-compose.yml -f docker-compose.pilot.yml exec -T bench \
  bash -lc 'cd ~/frappe-bench && bench --site <site> backup --with-files' \
  && find /srv/korkem-backups -name '*.sql.gz' -mtime +14 -delete
```

Frappe can also do it itself once the scheduler is enabled (it is, in pilot):
System Settings → **Backup Frequency**. That covers the database; getting the
files off the machine is still yours.

## Restoring

### Into a scratch site first — always

Never restore into the live site to find out whether the backup is good.

```sh
C="docker compose -f docker-compose.yml -f docker-compose.pilot.yml"

$C exec -T bench bash -lc 'cd ~/frappe-bench && bench new-site restore-check.localhost \
    --db-host mariadb --db-root-username root --db-root-password "$MYSQL_ROOT_PASSWORD" \
    --admin-password "$ADMIN_PASSWORD" --no-mariadb-socket'

$C exec -T bench bash -lc 'cd ~/frappe-bench && bench --site restore-check.localhost restore \
    sites/<site>/private/backups/<timestamp>-database.sql.gz'

# then look at it, rather than trusting that the command exited 0
$C exec -T bench bash -lc 'cd ~/frappe-bench && bench --site restore-check.localhost \
    execute frappe.client.get_count --kwargs "{\"doctype\": \"Sales Order\"}"'
```

Delete the scratch site afterwards: `bench drop-site restore-check.localhost`.

### Into the real site, after a failure

```sh
# 1. Stop taking traffic. With the public overlay, this is enough:
docker compose -f docker-compose.yml -f docker-compose.pilot.yml -f docker-compose.public.yml stop proxy

# 2. Take a backup of the broken state. It is evidence, and it may be less
#    broken than the thing you are about to restore.
$C exec -T bench bash -lc 'cd ~/frappe-bench && bench --site <site> backup'

# 3. Restore.
$C exec -T bench bash -lc 'cd ~/frappe-bench && bench --site <site> restore \
    sites/<site>/private/backups/<timestamp>-database.sql.gz'

# 4. Bring the schema up to the running code, in case the backup predates a deploy.
$C exec -T bench bash -lc 'cd ~/frappe-bench && bench --site <site> migrate'

# 5. Check before letting anyone in.
curl -s -H "Host: <site>" http://127.0.0.1:8000/health/ready

# 6. Resume traffic.
docker compose ... start proxy
```

`bench restore` **drops and recreates the site's database**. It is the one
destructive command in this document; that is what restoring means, and it is
why step 2 exists.

If the encryption key was lost, restore will succeed and the encrypted fields
will not decrypt. Re-enter the provider credentials in the app; nothing else is
affected, because nothing else is encrypted at rest.

## Recovering the whole machine

1. Install Docker and clone the repository (plus the four vendored repositories
   and the two custom app repositories — see `CLAUDE.md`).
2. Recreate `infra/frappe_bench/.env` with the **same** `MYSQL_ROOT_PASSWORD`
   and `ADMIN_PASSWORD`.
3. `scripts/deploy_pilot.sh` — this bootstraps an empty site, which is expected.
4. Copy the backup and the `site_config_backup.json` into
   `sites/<site>/private/backups`.
5. Restore as above, then `bench migrate`.
6. Re-enter the provider credentials only if the encryption key was lost.
7. If the domain is unchanged, Caddy re-issues the certificate on first start.
   **Let's Encrypt rate-limits repeat issuance**, so prefer restoring the
   `caddy-data` volume if you have it.

## What is not in place

- **Nothing is automated.** The cron line above is written down, not installed.
- **No off-machine copy is configured.** There is no bucket, no second host and
  no credentials for one — that needs a decision and an account.
- **This procedure has never been run against real data**, because there is
  none. The commands are Frappe's own and the state inventory was verified on
  the real bench; the restore itself is untested here and should be tested by
  the operator on the day the pilot has its first day of data.
