#!/usr/bin/env bash
# The whole verification, in one command.
#
#   scripts/ci.sh            everything
#   scripts/ci.sh backend    both bench suites
#   scripts/ci.sh flutter    analyze, format, test
#
# This is the body of CI, kept as a script rather than inlined into a workflow
# file for one reason: a workflow can only be run by the forge, and this
# repository does not have one yet (see .github/workflows/ci.yml). A script can
# be run by a person, today, on the machine where the code actually is — which
# is the difference between verification that exists and verification that is
# described.
#
# It is deliberately dull. `bench run-tests` exits 1 when a test fails
# (frappe/commands/testing.py:172), `flutter analyze` exits 1 on any issue, and
# `dart format --set-exit-if-changed` exits 1 on any reformat. With `set -e`
# that is the whole failure design; nothing here parses output to decide
# whether it passed.

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${KORKEM_COMPOSE_FILE:-$ROOT/infra/frappe_bench/docker-compose.yml}"
TARGET="${1:-all}"

say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
fail() { printf '\033[31mFAIL: %s\033[0m\n' "$*" >&2; exit 1; }

# --- backend ----------------------------------------------------------------
#
# Both apps, in dependency order: korkem_manufacturing is the domain the AI app
# sits on, so its failures are the ones worth seeing first. The AI suite is
# ~1000 tests and takes around 26 minutes — that is why CI runs on a push to
# dev rather than on every commit.
run_backend() {
  local svc
  svc="$(docker compose -f "$COMPOSE_FILE" ps -q bench 2>/dev/null || true)"

  if [ -z "$svc" ]; then
    say "bench is not running — starting it"
    docker compose -f "$COMPOSE_FILE" up -d
    say "waiting for the bench to answer"
    local site
    site="$(docker compose -f "$COMPOSE_FILE" exec -T bench sh -lc 'echo "$SITE_NAME"' | tr -d '\r')"
    for _ in $(seq 1 120); do
      if docker compose -f "$COMPOSE_FILE" exec -T bench \
           curl -fsS -H "Host: $site" http://127.0.0.1:8000/api/method/ping >/dev/null 2>&1; then
        break
      fi
      sleep 10
    done
  fi

  # `Host:` matters everywhere a bench is probed over HTTP: Frappe 17 resolves a
  # request to a site by that header alone, and `default_site` is CLI-only.

  for app in korkem_manufacturing korkem_ai; do
    say "backend: $app"
    docker compose -f "$COMPOSE_FILE" exec -T bench bash -o pipefail -lc \
      "cd /home/frappe/frappe-bench && bench --site \"\$SITE_NAME\" run-tests --app $app" \
      || fail "$app tests"
  done
}

# --- flutter ----------------------------------------------------------------
#
# Four gates, in the order that gives the shortest useful failure: resolve,
# then analyze (fastest signal), then format, then the suite.
run_flutter() {
  command -v flutter >/dev/null 2>&1 || fail "flutter is not on PATH"
  cd "$ROOT/mobile/korkem_flow"

  say "flutter: pub get";  flutter pub get                              || fail "pub get"
  say "flutter: analyze";  flutter analyze                              || fail "analyze"
  say "flutter: format";   dart format --set-exit-if-changed lib test   || fail "format"
  # No --update-goldens, ever: the launcher icon is produced by a `tools`-tagged
  # golden test that is skipped by default, and a bare update would rewrite the
  # shipped app assets.
  say "flutter: test";     flutter test                                 || fail "tests"
}

case "$TARGET" in
  backend) run_backend ;;
  flutter) run_flutter ;;
  all)     run_backend; run_flutter ;;
  *)       fail "unknown target '$TARGET' (backend | flutter | all)" ;;
esac

say "all green"
