#!/usr/bin/env bash
#
# Nightly copy of the owner's working base on the laptop (`work.localhost`).
#
#   scripts/backup_work_site.sh [destination]     default: /mnt/d/KORKEM-backups
#
# Run from WSL by a Windows scheduled task while there is no reachable server
# (07.11.2026). It takes a Frappe backup inside the bench — database, site
# config, public and private files — and copies it off the Docker volume to a
# Windows drive, so the copy survives the volume, the WSL disk and a broken
# Ubuntu. The newest KEEP sets are kept; older ones are removed.
#
# Two rules:
#   * If the bench is not running, it does nothing: nobody could have written
#     to the base, and starting four containers at night on a laptop that is
#     also an editing machine is not this script's decision.
#   * It never prints a secret. The site config inside the backup holds the
#     database password; the destination folder is the owner's, on their disk.
set -euo pipefail

DEST="${1:-/mnt/d/KORKEM-backups}"
KEEP="${KEEP:-14}"
SITE=work.localhost
REPO="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE="$REPO/infra/frappe_bench/docker-compose.yml"
BACKUPS=/home/frappe/frappe-bench/sites/$SITE/private/backups

stamp() { date '+%F %T'; }

if ! docker compose -f "$COMPOSE" ps --status running --services 2>/dev/null | grep -qx bench; then
  echo "$(stamp) bench is not running; nothing to back up"
  exit 0
fi

docker compose -f "$COMPOSE" exec -T bench bash -lc \
  "cd /home/frappe/frappe-bench && test -d sites/$SITE && bench --site $SITE backup --with-files >/dev/null"

# The four files of the newest set share a timestamp prefix.
prefix=$(docker compose -f "$COMPOSE" exec -T bench bash -lc \
  "ls -1t $BACKUPS/*-database.sql.gz | head -1 | xargs -n1 basename | sed 's/-database.sql.gz$//'")
[ -n "$prefix" ] || { echo "$(stamp) no backup was written"; exit 1; }

mkdir -p "$DEST/$prefix"
for f in $(docker compose -f "$COMPOSE" exec -T bench bash -lc "ls -1 $BACKUPS/$prefix-*"); do
  docker compose -f "$COMPOSE" cp "bench:$f" "$DEST/$prefix/" >/dev/null 2>&1
done
chmod -R go-rwx "$DEST/$prefix" 2>/dev/null || true

# Keep the newest $KEEP sets.
ls -1dt "$DEST"/*/ 2>/dev/null | tail -n +"$((KEEP + 1))" | xargs -r rm -rf

echo "$(stamp) backup $prefix → $DEST/$prefix ($(du -sh "$DEST/$prefix" | cut -f1))"
