# Backup and restore

**Last restore rehearsal:** 2026-08-31.

The pilot runs on one machine. There is no replica and no failover, so
**restore is the disaster plan**. A database-and-files backup was restored into
a separate site on the clean Docker stand, migrated, checked against the source
snapshot and removed again. The exact evidence is recorded below.

## What holds state

| what | where | lost if |
|---|---|---|
| all business data | `mariadb-data` Docker volume | `docker compose down -v`, or the volume is removed |
| uploaded files, site config, encryption key | `bench-data` volume, under `frappe-bench/sites/<site>` | same |
| enqueued background jobs | `redis-queue-data` volume (append-only) | same |
| cache and sessions | `redis-cache`, no volume | any restart — deliberately, it is all derivable |
| TLS certificate and ACME account | `caddy-data` volume | same; re-issued on next start, which Let's Encrypt rate-limits |

`docker compose down`, `up`, `restart` and `--force-recreate` keep the volumes.
**`docker compose down -v` destroys the business.** It appears nowhere in
`deploy_pilot.sh` and should appear in no routine script.

## Getting the backup off this disk

`bench backup` writes into the site directory, which lives in the same Docker
volume as the database it just copied — inside the same WSL virtual disk. That
file is **a copy, not a backup**: one VHDX corruption takes the original and the
copy together.

```sh
scripts/backup_offsite.sh /mnt/c/KorkemBackups
```

It takes the backup, copies every artifact out, and **checksums each one on both
sides**. A digest mismatch fails the whole run loudly and keeps the bad set for
inspection — and prunes nothing, because deleting an old good backup because a
new bad one arrived is how people lose data. Retention (`KORKEM_BACKUP_KEEP`,
default 7 sets) runs only after the new set is confirmed byte-identical.

There is **no default destination**. The script refuses without one rather than
guessing where your only copy should live.

### Verified 2026-09-02, on this machine

| | |
|---|---|
| destination | `C:\KorkemBackups`, outside the VHDX |
| database | 1 883 274 bytes, digest matched |
| files / private files / site config | 10 240 / 10 240 / 386 bytes, all matched |
| visible from Windows | yes — `Get-ChildItem C:\KorkemBackups` lists all four plus `SHA256SUMS` |
| refusal with no destination | exits 1 with an explanation |
| retention | with `KORKEM_BACKUP_KEEP=3`, eight sets became three; the three newest survived |

`SHA256SUMS` is written next to each set, so the copy can be checked again later
without the bench being alive:

```sh
cd /mnt/c/KorkemBackups/<set> && sha256sum -c SHA256SUMS
```

**This still is not off-site.** `C:` is a different disk from the VHDX but the
same laptop: it survives a corrupted virtual disk, not a stolen or burnt
machine. A second destination — a NAS, an external drive, object storage — is
the next step, and the script takes any path, so it is a second invocation
rather than new code.

---

## Proven restore rehearsal

The rehearsal ran in project `korkem-clean`, container
`korkem-clean-bench-1`, from source site `korkem.localhost` into scratch site
`restore-check.localhost`.

The accepted snapshot was created by:

```sh
/usr/bin/time -p docker exec korkem-clean-bench-1 sh -lc '
  cd /home/frappe/frappe-bench &&
  bench --site korkem.localhost backup --with-files
'
```

Measured output:

| artifact | bytes | SHA-256 |
|---|---:|---|
| database SQL gzip | 1,332,408 | `dc88e913764d4141fbdc51168aa2727c3610518c9b2e1175c56b7cfe1b27d26b` |
| public files tar | 10,240 | `96793201b40762ce016025e7bcea4659e9c42305e65c66aefbb352ad3ddc1508` |
| private files tar | 10,240 | `a5b62cedb1c29a4950e7e92707c204ece83202f3057f671cd33a32a5a574439d` |
| site config backup | 386 | `d0039e7d0ee48d49e4c70974b5d7450e2f33e747f97c3ca702f9e2c850b59ef5` |

- backup: **13.63 s**;
- scratch-site creation: **101.60 s**;
- database + files restore: **57.59 s** on the first pass;
- migrate: **71.89 s** on the first pass;
- final repeat of the same restore/migrate: **87.09 s / 61.74 s**.

The final source and restored counts matched:

| DocType | source | restored |
|---|---:|---:|
| User | 7 | 7 |
| Company | 1 | 1 |
| Sales Order | 3 | 3 |
| Work Order | 2 | 2 |
| Item | 10 | 10 |

These structural checks also matched at `1` on both sites:

- Custom Field `Work Order.originating_deal`;
- DocType `AI Usage Log`;
- DocType `Pending Action`;
- DocType `Work Instruction`;
- Custom DocPerm on `Sales Order` for `Manufacturing User`.

All three Sales Orders and both Work Orders also matched by name, company,
status and their customer/item/order links. Both source file directories were
empty, so the rehearsal proves creation and extraction of both tar archives but
does not yet prove recovery of a non-empty attachment.

### Problems the rehearsal found

1. The bench image did not contain the system executable `file`. This Frappe
   version calls it unconditionally before restore, so `bench restore` failed
   with `file: command not found` — the disaster plan not working on the one
   machine that ever needs it. **Fixed in `infra/frappe_bench/Dockerfile`**;
   verified by rebuilding the image and checking `/usr/bin/file` (5.44) is
   present. A bench built before that commit still needs:

   ```sh
   docker exec -u root <bench-container> \
     sh -lc 'apt-get update && apt-get install -y --no-install-recommends file'
   ```

2. `--no-mariadb-socket` is deprecated. Use
   `--mariadb-user-host-login-scope='%'` for a Docker MariaDB host.
3. Click resolved the `--with-public-files` and `--with-private-files` values
   before changing into the bench directory. Relative paths were rejected;
   absolute paths worked.
4. The diagnostic test transaction briefly added a second company and related
   records while the first snapshot was taken, then rolled them back. Each
   restored snapshot matched its own committed contents, but live counts moved
   during comparison. Operational restore rehearsals must run on a quiescent
   site; do not rely on an old marker in an append-only test log.

## Taking a backup

Frappe's own command. `deploy_pilot.sh` runs a database backup automatically
before migrations. A machine-loss backup must include files:

```sh
cd infra/frappe_bench
C="docker compose -f docker-compose.yml -f docker-compose.pilot.yml"

# database only — protects a migration
$C exec -T bench bash -lc \
  'cd /home/frappe/frappe-bench && bench --site "$SITE_NAME" backup'

# database plus public and private files — protects a machine loss
$C exec -T bench bash -lc \
  'cd /home/frappe/frappe-bench && bench --site "$SITE_NAME" backup --with-files'
```

The files are written under `sites/<site>/private/backups`. Record sizes and
checksums immediately:

```sh
$C exec -T bench bash -lc '
  cd /home/frappe/frappe-bench &&
  ls -lh sites/<site>/private/backups/<timestamp>-* &&
  sha256sum sites/<site>/private/backups/<timestamp>-*
'
```

### Get it off the machine

A backup that lives only on the machine it protects is not a backup of that
machine. On the WSL2 pilot, use the guarded off-VHDX script:

```sh
cd infra/frappe_bench
KORKEM_BACKUP_DIR=/mnt/d/korkem-backups \
SITE_NAME=korkem.localhost \
./scripts/backup_offsite.sh
```

The script rejects WSL filesystem destinations such as `/home/...`, copies the
database, both file archives and the site-config backup as one atomic set,
compares destination SHA-256 hashes and sizes with the container originals,
and retains seven complete sets by default. Override that count with
`KORKEM_BACKUP_KEEP`; it never removes source artifacts from the bench volume.

To re-check every retained copy against its still-present source artifact:

```sh
KORKEM_BACKUP_DIR=/mnt/d/korkem-backups \
./scripts/backup_offsite.sh --verify-only
```

`KORKEM_BENCH_CONTAINER` is only needed when container discovery finds zero or
more than one running Compose `bench` service. The destination is a Windows
mount, but its Windows ACL is still an operator responsibility. The script
requests restrictive Unix modes, verifies that the site-config backup has the
same reported mode as the database artifact, and warns when the Windows mount
does not honor those Unix mode bits.

### The encryption key

`site_config.json` holds `encryption_key`. Without it the SQL rows restore, but
encrypted `Password` values — Telegram, WhatsApp and provider credentials — do
not decrypt. Frappe writes `*-site_config_backup.json` beside the dump.

Keep it with the backup, with the same access control as the database. Never
print the key, put it in Git or paste it into a report.

### On a schedule

No host schedule is installed. A possible daily schedule is:

```cron
15 2 * * * cd /path/to/furniture_ai/infra/frappe_bench && \
  KORKEM_BACKUP_DIR=/mnt/d/korkem-backups SITE_NAME=<site> \
  ./scripts/backup_offsite.sh
```

System Settings → **Backup Frequency** can schedule the database backup once
the scheduler is enabled. It still does not copy anything off the VHDX; do not
use it as a substitute for this host-side copy.

## Restoring into a scratch site

Never restore into the live site to discover whether a backup works.

### 1. Confirm prerequisites and quiescence

```sh
docker top <bench-container> -eo pid,etime,stat,args
docker exec <bench-container> sh -lc 'command -v file'
```

Do not overlap tests, migrations, imports or other writers with the snapshot.

### 2. Create the scratch site

```sh
docker exec <bench-container> sh -lc '
  cd /home/frappe/frappe-bench &&
  bench new-site restore-check.localhost \
    --db-host mariadb \
    --db-root-username root \
    --db-root-password "$MYSQL_ROOT_PASSWORD" \
    --admin-password "$ADMIN_PASSWORD" \
    --mariadb-user-host-login-scope="%"
'
```

### 3. Restore database and both file archives

Use absolute container paths:

```sh
docker exec <bench-container> sh -lc '
  cd /home/frappe/frappe-bench &&
  bench --site restore-check.localhost restore \
    /home/frappe/frappe-bench/sites/<source>/private/backups/<timestamp>-database.sql.gz \
    --db-root-username root \
    --db-root-password "$MYSQL_ROOT_PASSWORD" \
    --with-public-files \
      /home/frappe/frappe-bench/sites/<source>/private/backups/<timestamp>-files.tar \
    --with-private-files \
      /home/frappe/frappe-bench/sites/<source>/private/backups/<timestamp>-private-files.tar
'
```

The ordinary backup above is gzip/tar, not an encrypted backup archive. Do not
pass `--encryption-key` for plain tar files: this Frappe version treats the
presence of that option as an instruction to decrypt the file archives.

Restore only the encryption key into the scratch config; never copy the whole
source config because it also contains the source database credentials:

```sh
docker exec <bench-container> sh -lc '
  cd /home/frappe/frappe-bench &&
  RESTORE_KEY=$(python3 -c "import json; print(json.load(open(
    \"/home/frappe/frappe-bench/sites/<source>/private/backups/<timestamp>-site_config_backup.json\"
  ))[\"encryption_key\"])") &&
  bench --site restore-check.localhost set-config encryption_key "$RESTORE_KEY" &&
  unset RESTORE_KEY
'
```

The key is intentionally not printed.

### 4. Migrate and verify

```sh
docker exec <bench-container> sh -lc '
  cd /home/frappe/frappe-bench &&
  bench --site restore-check.localhost migrate
'

docker exec <bench-container> sh -lc '
  cd /home/frappe/frappe-bench &&
  for dt in "User" "Company" "Sales Order" "Work Order" "Item"; do
    printf "%s=" "$dt"
    bench --site restore-check.localhost execute frappe.db.count \
      --args "[\"$dt\"]"
  done
'
```

Run the same count command against the source immediately before the backup,
and compare it with the scratch result. Use `frappe.db.count` for this operator
check; the rehearsal observed stale permission-aware cached counts while test
transactions were changing fixtures.

Also verify the custom schema and permission rows:

```sh
bench --site restore-check.localhost execute frappe.db.count \
  --args '["Custom Field", {"dt":"Work Order","fieldname":"originating_deal"}]'
bench --site restore-check.localhost execute frappe.db.count \
  --args '["DocType", {"name":"AI Usage Log"}]'
bench --site restore-check.localhost execute frappe.db.count \
  --args '["DocType", {"name":"Pending Action"}]'
bench --site restore-check.localhost execute frappe.db.count \
  --args '["DocType", {"name":"Work Instruction"}]'
bench --site restore-check.localhost execute frappe.db.count \
  --args '["Custom DocPerm", {"parent":"Sales Order","role":"Manufacturing User"}]'
```

Check representative Sales Orders and Work Orders by name and business fields,
not only their counts. If the backup includes real attachments, compare their
file count and checksums too.

### 5. Remove the scratch site

```sh
docker exec <bench-container> sh -lc '
  cd /home/frappe/frappe-bench &&
  bench drop-site restore-check.localhost \
    --db-root-username root \
    --db-root-password "$MYSQL_ROOT_PASSWORD" \
    --no-backup --force
'
```

Frappe drops the scratch database and user and moves its site directory under
`archived/sites`. Confirm that `sites/restore-check.localhost` is absent and
that `bench list-sites` lists only active sites.

## Restoring the real site after a failure

1. Stop traffic.
2. Back up the broken state; it is evidence and may be the least damaged copy.
3. Restore the chosen database and both file archives using absolute paths.
4. Restore only `encryption_key` from the config backup.
5. Run `bench --site <site> migrate`.
6. Compare counts, representative records, custom schema, permissions and
   attachments before resuming traffic.
7. Run the readiness endpoint, then resume traffic.

`bench restore` drops and recreates the target database. Never point it at the
live site during a rehearsal.

## Recovering the whole machine

1. Install Docker and clone the repository.
2. Recreate `infra/frappe_bench/.env` with the required root/admin secrets.
3. Ensure the bench image contains the `file` package.
4. Bootstrap the empty site with the deployment script.
5. Copy the database, both file archives and site-config backup onto the new
   machine.
6. Restore and migrate as above.
7. Restore the original encryption key before testing encrypted credentials.
8. Restore `caddy-data` if possible; otherwise Caddy must re-issue certificates
   and Let's Encrypt rate limits apply.

## Still unverified or not in place

- No automated host schedule is installed.
- No off-machine copy or restore from an off-machine copy is configured.
- Restore on a different machine, Docker host and storage volume has not been
  rehearsed.
- The rehearsal's file archives were empty; a real non-empty attachment still
  needs a checksum comparison after restore.
- Deliberate loss of the encryption key has not been rehearsed. Expected
  behaviour — database restore succeeds but encrypted credentials cannot be
  decrypted — still needs an explicit test before relying on it.
- A full-machine recovery including Caddy state and certificate reuse has not
  been rehearsed.
