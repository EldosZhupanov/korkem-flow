#!/usr/bin/env bash
# Wait until a named Orca agent finishes, then say so.
#
#   scripts/watch_agents.sh codex
#   scripts/watch_agents.sh antigravity
#   scripts/watch_agents.sh            # any of them
#
# Why this exists rather than `orca terminal wait --for tui-idle`: that command
# returns an empty body here and fires on the *current* state, so it reports
# "idle" for an agent that has simply not started yet. `worktree ps` carries the
# same state and is the one Orca call that has been reliable in this
# environment.
#
# Prints one line per state change so a long wait is legible, and exits 0 the
# moment the watched agent reaches `done`.

set -uo pipefail

WANT="${1:-}"
ORCA="${ORCA_CLI_COMMAND:-orca-ide}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

states() {
  "$ORCA" worktree ps --json > "$TMP/ps.json" 2>/dev/null || return 1
  python3 - "$TMP/ps.json" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(1)
for tree in data["result"]["worktrees"]:
    if "furniture" not in tree["repo"]:
        continue
    for agent in tree.get("agents", []):
        if agent["agentType"] == "claude":
            continue          # that is us
        print(agent["agentType"], agent["state"])
PY
}

declare -A last
started=0

while :; do
  while read -r name state; do
    [ -z "$name" ] && continue
    if [ "${last[$name]:-}" != "$state" ]; then
      printf '%s  %-12s %s\n' "$(date +%H:%M:%S)" "$name" "$state"
      last[$name]="$state"
    fi
    # Only report a finish we actually watched begin, so a stale `done` from
    # before the task was sent does not end the wait immediately.
    if [ "$state" = "working" ]; then started=1; fi
    if [ "$state" = "done" ] && [ "$started" = 1 ]; then
      if [ -z "$WANT" ] || [ "$WANT" = "$name" ]; then
        echo "ГОТОВ: $name"
        exit 0
      fi
    fi
  done < <(states)
  sleep 15
done
