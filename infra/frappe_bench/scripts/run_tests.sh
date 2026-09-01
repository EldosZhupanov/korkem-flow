#!/usr/bin/env bash
# Run a bench suite, and refuse if one is already running.
#
# Two suites against one site deadlock on `tabUser` — every failure comes back
# as `QueryDeadlockError (1020)`, which looks like a product defect and is not.
# It has cost this project a day twice: once diagnosing forty-two phantom
# failures, and once again by the same author who had just written the rule
# down in `korkem-bench`.
#
# A rule you have to remember is not a rule. This is the same rule, enforced.
#
#   scripts/run_tests.sh korkem_ai                 # a whole app
#   scripts/run_tests.sh --module korkem_ai.…      # one module
#
# Environment:
#   KORKEM_BENCH_CONTAINER  default: korkem-clean-bench-1
#   KORKEM_SITE             default: korkem.localhost
set -euo pipefail

CONTAINER="${KORKEM_BENCH_CONTAINER:-korkem-clean-bench-1}"
SITE="${KORKEM_SITE:-korkem.localhost}"

[ $# -gt 0 ] || { echo "usage: $0 <app> | --module <dotted.path>" >&2; exit 2; }

# Read /proc directly. The bench image carries neither `ps` nor `pgrep` — it is
# a slim Debian — so the obvious check silently found nothing and let a second
# suite start, which is exactly the failure this script exists to prevent. A
# guard that cannot detect the thing it guards against is worse than none: it
# reassures.
#
# And the check runs *inside* the container, not on the host: a host-side match
# also catches this script's own command line.
# The inner script goes in on stdin, not as `sh -lc '...'`. It needs single
# quotes of its own (`tr '\000' ' '`), and those silently terminate the outer
# quoted argument — `bash -n` still passes, because the result is valid shell
# that means something else. The guard then found nothing and let a second
# suite start: a guard that cannot detect what it guards against is worse than
# none, because it reassures.
running="$(docker exec -i "$CONTAINER" sh -s <<'DETECT' 2>/dev/null || true
for c in /proc/[0-9]*/cmdline; do
  [ -r "$c" ] || continue
  line=$(tr '\000' ' ' < "$c" 2>/dev/null) || continue
  # Match the runner itself, not anything that merely mentions it: a looser
  # pattern also matched the inner shell of this very guard, whose command
  # line carries the pattern, so it refused because of itself.
  case "$line" in *bench_helper*run-tests*) echo "$line" ;; esac
done
DETECT
)"

if [ -n "$running" ]; then
  echo "REFUSED: a bench suite is already running in $CONTAINER." >&2
  echo "Two suites against one site deadlock on tabUser, and every failure then" >&2
  echo "comes back as QueryDeadlockError — a phantom that reads like a real bug." >&2
  echo "$running" | head -3 >&2
  exit 1
fi

case "$1" in
  --module) target=(--module "${2:?--module needs a dotted path}") ;;
  *)        target=(--app "$1") ;;
esac

log="/tmp/run-$(date +%H%M%S).log"
echo "==> $SITE: bench run-tests ${target[*]}  (log: $CONTAINER:$log)"

# The full output goes to a file inside the container. Reading only a `tail` of
# a suite is how a failing run gets reported as passing — the verdict of
# `analyze` and the first error both live above the last line.
docker exec "$CONTAINER" bash -o pipefail -lc \
  "cd /home/frappe/frappe-bench && bench --site '$SITE' run-tests ${target[*]} > '$log' 2>&1"
status=$?

docker exec "$CONTAINER" sh -lc "sed 's/\x1b\[[0-9;]*m//g' '$log' | tail -3"
exit $status
