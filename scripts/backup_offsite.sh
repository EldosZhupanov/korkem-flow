#!/usr/bin/env bash
#
# Take a backup and put it somewhere the machine's disk failure cannot reach.
#
#   scripts/backup_offsite.sh                     # uses $KORKEM_BACKUP_DIR
#   scripts/backup_offsite.sh /mnt/c/KorkemBackups
#
# Why this exists. `bench backup` writes into the site directory, which lives
# in the same Docker volume as the database it is backing up — inside the same
# WSL virtual disk. That file is a copy, not a backup: one VHDX corruption
# takes the original and the copy together. This moves it out and, more
# importantly, **proves it arrived intact** rather than assuming a copy
# succeeded because `cp` said nothing.
#
# Three rules:
#
#   * **Every artifact is checksummed on both sides.** A backup nobody verified
#     is a belief. If a digest differs the script fails loudly and keeps the
#     bad copy for inspection instead of silently retrying.
#   * **It never deletes what it did not verify.** Pruning happens only after
#     the new set is confirmed byte-identical.
#   * **It refuses rather than guesses.** No destination, no default guess of
#     where your important files should go.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCH_DIR="$ROOT/infra/frappe_bench"
KEEP="${KORKEM_BACKUP_KEEP:-7}"

say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
ok()   { printf '    \033[32mok\033[0m   %s\n' "$*"; }
warn() { printf '    \033[33mwarn\033[0m %s\n' "$*"; }
die()  { printf '\n\033[31mstopped:\033[0m %s\n\n' "$*" >&2; exit 1; }

DEST="${1:-${KORKEM_BACKUP_DIR:-}}"
[ -n "$DEST" ] || die "No destination. Pass a directory, or set KORKEM_BACKUP_DIR.
There is deliberately no default: this script decides where your only copy lives."

# The whole point is landing outside the WSL virtual disk. /mnt/... is a Windows
# drive or a network mount; anything else is the same disk we are protecting
# against. This warns rather than refuses — a NAS mounted elsewhere is valid.
case "$DEST" in
  /mnt/*) : ;;
  *) warn "$DEST does not look like a mounted host or network drive."
     warn "If it is on the same disk as the bench, this is a copy, not a backup." ;;
esac

mkdir -p "$DEST" || die "Cannot create $DEST"
[ -w "$DEST" ] || die "$DEST is not writable"

# --- which bench, which site --------------------------------------------------
#
# Read from compose rather than by exec'ing into the container: a crash-looping
# container makes `exec` fail, and an empty site name would send the backup
# somewhere nameless.
say "Bench"
PROJECT="${KORKEM_COMPOSE_PROJECT:-korkem-clean}"
CONTAINER="$(docker ps --filter "name=${PROJECT}-bench" --format '{{.Names}}' | head -1)"
[ -n "$CONTAINER" ] || die "No running bench container for compose project '$PROJECT'.
Set KORKEM_COMPOSE_PROJECT if the stack runs under another name."
ok "container $CONTAINER"

SITE="$(grep -E '^SITE_NAME=' "$BENCH_DIR/.env" 2>/dev/null | cut -d= -f2- || true)"
[ -n "$SITE" ] || die "SITE_NAME is not set in $BENCH_DIR/.env"
ok "site $SITE"

REMOTE_DIR="/home/frappe/frappe-bench/sites/$SITE/private/backups"

# --- take it -----------------------------------------------------------------
say "Backup"
before="$(docker exec "$CONTAINER" sh -lc "ls -1 '$REMOTE_DIR' 2>/dev/null | sort" || true)"
docker exec "$CONTAINER" sh -lc \
  "cd /home/frappe/frappe-bench && bench --site '$SITE' backup --with-files" >/dev/null \
  || die "bench backup failed"
after="$(docker exec "$CONTAINER" sh -lc "ls -1 '$REMOTE_DIR' | sort")"

NEW="$(comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after"))"
[ -n "$NEW" ] || die "bench backup reported success but produced no new file in $REMOTE_DIR"
ok "$(printf '%s\n' "$NEW" | wc -l) new artifact(s)"

# --- move it out, and prove it arrived ---------------------------------------
say "Copy out and verify"
STAMP="$(date +%Y-%m-%d_%H%M%S)"
SET_DIR="$DEST/$STAMP"
mkdir -p "$SET_DIR"

failed=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  src_sum="$(docker exec "$CONTAINER" sh -lc "sha256sum '$REMOTE_DIR/$f'" | awk '{print $1}')"
  docker cp "$CONTAINER:$REMOTE_DIR/$f" "$SET_DIR/$f" >/dev/null \
    || { printf '    \033[31mfail\033[0m %s — copy failed\n' "$f"; failed=1; continue; }
  dst_sum="$(sha256sum "$SET_DIR/$f" | awk '{print $1}')"
  if [ "$src_sum" = "$dst_sum" ]; then
    ok "$f  $(stat -c%s "$SET_DIR/$f") bytes  ${src_sum:0:16}…"
    printf '%s  %s\n' "$src_sum" "$f" >> "$SET_DIR/SHA256SUMS"
  else
    printf '    \033[31mfail\033[0m %s — digest differs, copy is corrupt\n' "$f"
    failed=1
  fi
done <<< "$NEW"

[ "$failed" -eq 0 ] || die "At least one artifact did not arrive intact. The bad set is kept at
$SET_DIR for inspection, and nothing older was pruned."

ok "whole set verified byte-for-byte"

# --- prune, but only now ------------------------------------------------------
say "Retention"
mapfile -t sets < <(find "$DEST" -maxdepth 1 -mindepth 1 -type d -name '20*' | sort -r)
if [ "${#sets[@]}" -gt "$KEEP" ]; then
  for old in "${sets[@]:$KEEP}"; do
    rm -rf "$old" && ok "removed $(basename "$old")"
  done
else
  ok "${#sets[@]} set(s) kept, limit $KEEP"
fi

say "Backup is at $SET_DIR"
echo "    Restoring it is a separate, rehearsed procedure — docs/operations/BACKUP_AND_RESTORE.md."
echo "    A backup that has never been restored is a belief, not a backup."
