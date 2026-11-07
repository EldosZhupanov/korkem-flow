#!/bin/bash
# What the container runs once `bootstrap.sh` has finished.
#
# One decision, made from `KORKEM_ENV`: a development bench keeps `bench start`
# — the dev server, the asset watcher, everything a developer wants — and a
# pilot or production bench runs the four-process production model from
# `procfiles/Procfile.pilot` (gunicorn, socket.io, scheduler, worker).
#
# `bench start` is still the process manager in both cases, so bench keeps
# owning restarts and signal handling; only the Procfile differs.
set -euo pipefail

KORKEM_ENV="${KORKEM_ENV:-development}"
cd /home/frappe/frappe-bench

if [ "$KORKEM_ENV" = "development" ]; then
  # The generated Procfile starts `bench worker` directly; when it quits on a
  # Redis timeout honcho stops everything else too. See scripts/worker.sh.
  sed -i -E 's#^worker:([[:space:]]+)bench worker#worker:\1/workspace/scripts/worker.sh#' Procfile
  # The owner's working base, while there is no reachable server (07.11.2026):
  # a second site, served on its own port by its own dev server, because
  # `bench serve` answers every request with the default site and ignores the
  # Host header — on :8000 `work.localhost` would silently read the test base.
  # Present only when the site exists; nothing changes on a bench without it.
  sed -i '/^work:/d' Procfile
  if [ -d sites/work.localhost ]; then
    echo "work: bench --site work.localhost serve --port 8002" >> Procfile
  fi
  exec bench start
fi

# The Procfile is mounted read-only and honcho is given a path inside the bench
# directory, so it is copied rather than referenced.
cp /workspace/procfiles/Procfile.pilot ./Procfile.pilot

echo "Starting KORKEM in '$KORKEM_ENV' mode (gunicorn, socketio, scheduler, worker)."
exec bench start --no-dev --procfile Procfile.pilot
