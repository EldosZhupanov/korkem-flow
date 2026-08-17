#!/bin/bash
# The pilot web process: gunicorn, serving Frappe *and its static files*.
#
# Two details here are not cosmetic, and both were found by the process
# crash-looping rather than by reading the source.
#
# **The working directory is `sites`, not the bench root.** Every `bench`
# command chdirs into `sites` before it runs, and Frappe quietly depends on it:
# the site resolver reads `currentsite.txt` from the working directory, the
# static file middleware resolves `/assets` from it, and the logger writes to
# the *relative* path `../logs`. Started from the bench root instead, gunicorn
# died on `FileNotFoundError: /home/frappe/logs/cssutils.log` — one directory
# too high, from a path nobody passed in.
#
# **`korkem_ai.wsgi:application`, not `frappe.app:application`.** Frappe's own
# supervisor template runs the bare application because a classic install has
# nginx on the same machine to serve the static files and rewrite the forwarded
# headers. This deployment has neither, so the entry point does both — see
# `backend/korkem_ai/korkem_ai/wsgi.py`, which explains why the `Secure` flag on
# the session cookie depends on it.
set -euo pipefail

cd /home/frappe/frappe-bench/sites

exec ../env/bin/gunicorn \
  --bind 0.0.0.0:8000 \
  --workers "${KORKEM_GUNICORN_WORKERS:-2}" \
  --timeout 120 \
  --graceful-timeout 30 \
  --max-requests 5000 \
  --max-requests-jitter 500 \
  --preload \
  korkem_ai.wsgi:application
