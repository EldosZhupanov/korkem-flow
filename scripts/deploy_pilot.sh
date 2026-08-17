#!/usr/bin/env bash
#
# Deploy or update the KORKEM pilot.
#
#   scripts/deploy_pilot.sh --check     preflight only; changes nothing
#   scripts/deploy_pilot.sh             preflight, backup, migrate, start, verify
#
# It is deliberately dull. Everything it does is something an operator could do
# by hand from docs/pilot/DEPLOYMENT.md; what it adds is that it does them in
# the right order and stops at the first thing that is not true.
#
# Three rules it keeps:
#
#   * **It never prints a secret.** Values are checked for presence and for
#     being something other than the example placeholder, and reported as
#     `set` / `missing`. Nothing from `.env` or the site config is echoed.
#   * **It is not destructive.** No `down -v`, no `drop-site`, no `remove-app`,
#     no demo fixture. The only thing it writes to the database is a migration,
#     and it takes a backup first.
#   * **It refuses rather than guesses.** A missing variable, a placeholder
#     password, an unreachable database or a failed health check stops it.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCH_DIR="$ROOT/infra/frappe_bench"
ENV_FILE="$BENCH_DIR/.env"

CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1

COMPOSE=(docker compose
  -f "$BENCH_DIR/docker-compose.yml"
  -f "$BENCH_DIR/docker-compose.pilot.yml")

say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
ok()   { printf '    \033[32mok\033[0m   %s\n' "$*"; }
warn() { printf '    \033[33mwarn\033[0m %s\n' "$*"; }
die()  { printf '\n\033[31mstopped:\033[0m %s\n\n' "$*" >&2; exit 1; }

# --- 1. environment ---------------------------------------------------------

say "Environment"

[ -f "$ENV_FILE" ] || die "$ENV_FILE does not exist. Copy .env.example to .env and fill it in."

# Sourced in a subshell-safe way: this script never re-exports these values and
# never prints them.
set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

require_secret() {
  local name="$1" placeholder="$2"
  local value="${!name:-}"
  [ -n "$value" ] || die "$name is not set in $ENV_FILE."
  [ "$value" != "$placeholder" ] || die "$name is still the example placeholder. Generate a real one."
  ok "$name is set"
}

require_value() {
  local name="$1"
  local value="${!name:-}"
  [ -n "$value" ] || die "$name is not set in $ENV_FILE."
  ok "$name = $value"
}

require_secret MYSQL_ROOT_PASSWORD change_me_root
require_secret ADMIN_PASSWORD change_me_admin
require_value SITE_NAME

case "$SITE_NAME" in
  *.localhost|localhost)
    warn "SITE_NAME is $SITE_NAME — a pilot reached over the internet needs the real hostname,"
    warn "because Frappe resolves a request to a site by its Host header."
    ;;
esac

# The pilot overlay sets KORKEM_ENV=pilot regardless of the file, so this is a
# check on the *file* being consistent with what is being deployed rather than
# on what will actually be applied.
case "${KORKEM_ENV:-development}" in
  pilot|production) ok "KORKEM_ENV = ${KORKEM_ENV}" ;;
  *) warn "KORKEM_ENV in .env is '${KORKEM_ENV:-development}'; the pilot overlay will use 'pilot'." ;;
esac

if [ -n "${KORKEM_PUBLIC_HOST:-}" ]; then
  ok "KORKEM_PUBLIC_HOST = $KORKEM_PUBLIC_HOST"
  [ -n "${KORKEM_ACME_EMAIL:-}" ] || die "KORKEM_PUBLIC_HOST is set but KORKEM_ACME_EMAIL is not; Let's Encrypt needs it."
  COMPOSE+=(-f "$BENCH_DIR/docker-compose.public.yml")
  ok "public front door included, profile '${KORKEM_PROXY_PROFILE:-webhooks}'"
else
  warn "KORKEM_PUBLIC_HOST is empty — deploying without the public front door."
  warn "The site will be reachable on 127.0.0.1:8000 only. See docs/pilot/PRE_DOMAIN_CHECKLIST.md."
fi

# --- 2. tooling -------------------------------------------------------------

say "Tooling"
command -v docker >/dev/null || die "docker is not installed."
docker compose version >/dev/null 2>&1 || die "the docker compose plugin is not available."
ok "docker and docker compose present"
"${COMPOSE[@]}" config >/dev/null || die "the compose configuration is not valid."
ok "compose configuration is valid"

if [ "$CHECK_ONLY" = "1" ]; then
  say "Preflight only (--check); nothing was changed."
  exit 0
fi

# --- 3. database ------------------------------------------------------------

say "Database"
"${COMPOSE[@]}" up -d mariadb redis-cache redis-queue
# Compose's own healthcheck is the condition; this waits on it rather than
# re-implementing a ping.
for _ in $(seq 1 60); do
  status="$("${COMPOSE[@]}" ps --format '{{.Service}} {{.Health}}' | awk '$1=="mariadb"{print $2}')"
  [ "$status" = "healthy" ] && break
  sleep 2
done
[ "${status:-}" = "healthy" ] || die "MariaDB did not become healthy. Check: docker compose logs mariadb"
ok "MariaDB healthy, data volume attached"

# --- 4. backup --------------------------------------------------------------

say "Backup before migrating"
if "${COMPOSE[@]}" ps --format '{{.Service}}' | grep -qx bench; then
  if "${COMPOSE[@]}" exec -T bench bash -lc "cd ~/frappe-bench && [ -d sites/$SITE_NAME ]"; then
    "${COMPOSE[@]}" exec -T bench bash -lc \
      "cd ~/frappe-bench && bench --site $SITE_NAME backup" >/dev/null
    ok "database backup written to sites/$SITE_NAME/private/backups"
  else
    warn "site $SITE_NAME does not exist yet; it will be created on first boot."
  fi
else
  warn "bench container is not running yet; nothing to back up."
fi

# --- 5. application ---------------------------------------------------------

say "Application"
"${COMPOSE[@]}" up -d --build
ok "containers started"

# The Host header is not optional: Frappe resolves a request to a site by it,
# and a bench holding more than one site has no meaningful "default".
HEALTH="curl -fsS -H 'Host: $SITE_NAME' http://localhost:8000"

printf '    waiting for the site to answer'
for _ in $(seq 1 150); do
  if "${COMPOSE[@]}" exec -T bench bash -lc "$HEALTH/health >/dev/null 2>&1"; then
    printf '\n'; break
  fi
  printf '.'; sleep 4
done
"${COMPOSE[@]}" exec -T bench bash -lc "$HEALTH/health >/dev/null" \
  || die "the site never answered /health. Check: docker compose logs bench"
ok "/health answers"

# --- 6. migrations ----------------------------------------------------------

say "Migrations"
"${COMPOSE[@]}" exec -T bench bash -lc "cd ~/frappe-bench && bench --site $SITE_NAME migrate"
ok "schema and patches applied"

# --- 7. verification --------------------------------------------------------

say "Verification"

env_name="$("${COMPOSE[@]}" exec -T bench bash -lc \
  "cd ~/frappe-bench && bench --site $SITE_NAME execute korkem_ai.korkem_ai.environment.current" \
  2>/dev/null | tr -d '\r"' | tail -1)"
case "$env_name" in
  pilot|production) ok "the site reports environment '$env_name' — demo fixtures will refuse to run" ;;
  *) die "the site reports environment '$env_name'. Destructive demo fixtures would be allowed. Check KORKEM_ENV." ;;
esac

readiness="$("${COMPOSE[@]}" exec -T bench bash -lc \
  "curl -s -o /tmp/ready.json -w '%{http_code}' -H 'Host: $SITE_NAME' http://localhost:8000/health/ready; cat /tmp/ready.json")"
printf '    readiness: %s\n' "$readiness"
case "$readiness" in
  200*) ok "every component is up" ;;
  *)    warn "the site is degraded — read the component list above before letting users in." ;;
esac

if [ -n "${KORKEM_PUBLIC_HOST:-}" ]; then
  say "Public front door"
  if curl -fsS --max-time 15 "https://$KORKEM_PUBLIC_HOST/health" >/dev/null 2>&1; then
    ok "https://$KORKEM_PUBLIC_HOST/health answers over TLS"
  else
    warn "https://$KORKEM_PUBLIC_HOST/health did not answer."
    warn "With the 'webhooks' profile that is expected — only the two webhook paths are proxied."
    warn "Otherwise: check DNS points here, that ports 80 and 443 are reachable, and"
    warn "  docker compose logs proxy    for what Let's Encrypt said."
  fi
fi

say "Done"
printf '    Site:        %s\n' "$SITE_NAME"
printf '    Environment: %s\n' "$env_name"
printf '    Next:        docs/pilot/PRE_DOMAIN_CHECKLIST.md\n\n'
