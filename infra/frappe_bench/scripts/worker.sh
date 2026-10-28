#!/bin/bash
# The queue worker, brought back when it quits on its own.
#
# `bench start` runs every process under honcho, and honcho stops *all* of them
# the moment *one* exits. RQ's worker exits — cleanly, rc=0 — on a Redis
# timeout («Redis connection timeout, quitting...»), expecting a supervisor to
# start it again. Under honcho that took the web server, socket.io and the
# scheduler down with it, and the container restarted.
#
# Seen on 2026-10-28 on the WSL bench: every 7–10 minutes for a whole day.
# Each restart killed whatever ran in the container at that moment — test
# suites stopped mid-run and left their records behind, and the next run failed
# on those («From Time and To Time of PO-JOB00024 are overlapping with
# PO-JOB00010»). A pilot would have dropped every open request the same way.
#
# So the worker restarts here, alone. SIGTERM from honcho still stops it.
set -u
cd /home/frappe/frappe-bench

stopping=0
child=0
trap 'stopping=1; [ "$child" -gt 0 ] && kill -TERM "$child" 2>/dev/null' TERM INT

while [ "$stopping" = 0 ]; do
  bench worker "$@" &
  child=$!
  wait "$child"
  rc=$?
  [ "$stopping" = 1 ] && wait "$child" 2>/dev/null && break
  echo "$(date -u +%FT%TZ) worker exited rc=$rc; starting it again" >&2
  sleep 2
done
