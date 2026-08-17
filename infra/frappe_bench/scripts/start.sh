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
  exec bench start
fi

# The Procfile is mounted read-only and honcho is given a path inside the bench
# directory, so it is copied rather than referenced.
cp /workspace/procfiles/Procfile.pilot ./Procfile.pilot

echo "Starting KORKEM in '$KORKEM_ENV' mode (gunicorn, socketio, scheduler, worker)."
exec bench start --no-dev --procfile Procfile.pilot
