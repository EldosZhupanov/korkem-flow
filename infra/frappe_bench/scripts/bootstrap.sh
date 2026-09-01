#!/bin/bash
set -euo pipefail
cd /home/frappe

# development | pilot | production.
#
# Everything below that differs between a laptop and somebody's business is
# decided from this one variable, and the site is *told* which it is
# (`korkem_env`) so that code can refuse to do destructive things on the wrong
# one. Unset means development, because unset is what a developer's shell has.
KORKEM_ENV="${KORKEM_ENV:-development}"
case "$KORKEM_ENV" in
  development|pilot|production) ;;
  *) echo "KORKEM_ENV must be development, pilot or production (got '$KORKEM_ENV')" >&2; exit 1 ;;
esac

# A half-built bench is a deadlock, not a state to preserve. If `bench init`
# dies partway it leaves `frappe-bench/` behind without `apps/frappe`; the test
# below is then true again on the next start, and `bench init` refuses with
# "Bench instance already exists". The container restarts, and repeats that
# forever — CI waited twenty minutes on a loop that could never finish, and a
# client's machine would do the same while saying nothing useful.
#
# Removing it is safe by construction and not a judgement call: a site cannot
# exist without `apps/frappe`, so a bench directory missing it holds no data.
if [ -d frappe-bench ] && [ ! -d frappe-bench/apps/frappe ]; then
  echo "removing a partially initialised bench (no apps/frappe, so no site can exist)"
  rm -rf frappe-bench
fi

if [ ! -d frappe-bench/apps/frappe ]; then
  # Git refuses to touch a repository owned by another user, and every vendored
  # tree is exactly that: the host checkout belongs to whoever cloned it, while
  # this container runs as `frappe` (uid 1000). On a developer's machine both
  # are uid 1000 and nothing happens; on a CI runner the checkout is uid 1001
  # and `bench init --frappe-path` dies with
  #
  #     fatal: detected dubious ownership in repository at '/workspace/vendor/erpnext/.git'
  #
  # which the bench then reports as a failed `git clone`, pointing at the
  # network rather than at the ownership. Found only by the first real remote
  # run — it is not reproducible locally by construction.
  #
  # Scoped to the four vendored paths rather than `*`: this marks somebody
  # else's code readable, and it should say exactly whose.
  for vendored in frappe erpnext crm relaticle; do
    git config --global --add safe.directory "/workspace/vendor/$vendored"
  done

  bench init frappe-bench \
    --frappe-path /workspace/vendor/frappe \
    --frappe-branch develop \
    --python python3.14 \
    --skip-assets \
    --skip-redis-config-generation \
    --no-backups \
    --verbose
fi

cd frappe-bench

# erpnext: a real local clone (zero-network, same mechanism bench init uses for frappe), not --soft-link.
# Its banking/ sub-frontend resolves paths via import.meta.url, which Node/Vite resolve to a symlink's
# REAL target -- under --soft-link that computes /workspace/sites/... instead of frappe-bench/sites/...
# A real clone puts the file at its expected nested path, fixing this without touching vendored source.
[ -d apps/erpnext ] || bench get-app --skip-assets /workspace/vendor/erpnext
[ -d apps/crm ]     || bench get-app --soft-link --skip-assets /workspace/vendor/crm

# Our own apps, linked without `bench get-app`.
#
# They used to be installed with `get-app --soft-link`, which requires each app
# to be its own git repository -- and that requirement is the only reason they
# were kept out of the root repository for a month, which in turn is why a
# clone of this project could not build itself and why CI was impossible.
#
# The requirement is real, not folklore. In bench's `App.__init__`,
# `is_repo` defaults to **True** when the app is not already installed
# (`.../bench/app.py`: `is_git_repo(...) if os.path.exists(...) else True`), so
# `setup_details()` takes the mounted-disk branch and calls `git.Repo(path)`,
# which raises `InvalidGitRepositoryError` on a plain directory. The `--no-git`
# branch above it is unreachable from `get-app`.
#
# So we do the three things `get-app --soft-link` actually accomplishes, and
# nothing else: link it, name it, install it editable. Verified against a bench
# built the old way -- the symlink, the `sites/apps.txt` entry and the editable
# install were exactly its whole effect.
link_own_app() {
  name="$1"
  src="/workspace/custom/$name"

  [ -d "$src" ] || { echo "bootstrap: $src is missing -- run scripts/fetch_vendor.sh? no: this is our own code, so the checkout is incomplete" >&2; exit 1; }

  [ -e "apps/$name" ] || ln -s "$src" "apps/$name"

  # `bench get-app` leaves no trailing newline on sites/apps.txt, so a bare
  # `>>` glues the new name onto the previous one and the site then tries to
  # import a module called `crmkorkem_manufacturing`. Found by the first clean
  # bootstrap through this path, which is precisely what that run was for: the
  # developer bench never showed it, because its apps.txt was written by
  # `get-app` one app at a time.
  if [ -s sites/apps.txt ] && [ -n "$(tail -c1 sites/apps.txt)" ]; then
    echo >> sites/apps.txt
  fi
  grep -qxF "$name" sites/apps.txt 2>/dev/null || echo "$name" >> sites/apps.txt
  ./env/bin/pip install --quiet --editable "$src" --no-deps
}

link_own_app korkem_manufacturing
link_own_app korkem_ai

bench setup requirements --dev
bench setup requirements --node

# Developer mode rebuilds and re-exports doctype JSON on save, exposes the
# developer tooling in the desk, and is what `seed_users` has always keyed its
# refusal on. It is a development setting and is set as one.
if [ "$KORKEM_ENV" = "development" ]; then
  bench set-config -g developer_mode 1
else
  bench set-config -g developer_mode 0
fi

bench set-config -g redis_cache "$FRAPPE_REDIS_CACHE"
bench set-config -g redis_queue "$FRAPPE_REDIS_QUEUE"

# Where the socket.io process should call the web server back.
#
# Without this, `frappe/realtime/utils.js:get_url` derives that URL from the
# *client's own* Origin header. A browser on the host sends `korkem.localhost`,
# which the container can resolve, so it works and the setting looks unnecessary.
# An Android emulator sends `10.0.2.2` — the host as seen from the guest, and
# meaningless inside this container — so the loopback fetch fails and every
# socket connection is rejected as `Unauthorized: TypeError: fetch failed`.
#
# The app cannot avoid it: the same middleware requires the Origin hostname to
# match the Host it dialled. Diagnosed on a real emulator, where HTTP worked and
# only the socket did not.
bench set-config -g webserver_host 127.0.0.1

if [ ! -d "sites/$SITE_NAME" ]; then
  bench new-site "$SITE_NAME" \
    --db-host mariadb --db-port 3306 \
    --db-root-username root --db-root-password "$MYSQL_ROOT_PASSWORD" \
    --admin-password "$ADMIN_PASSWORD" \
    --set-default --verbose

  bench --site "$SITE_NAME" install-app erpnext
  bench --site "$SITE_NAME" install-app crm
  bench --site "$SITE_NAME" install-app korkem_manufacturing
  bench --site "$SITE_NAME" install-app korkem_ai

  bench build
fi

# The default site for `bench` commands that are not given `--site`.
#
# Worth knowing what this does *not* do: Frappe 17 resolves an **HTTP** request
# to a site by its `Host` header and by nothing else — `default_site` is read
# only by the bench CLI (`utils/bench_helper.py`). Under `bench serve` that is
# invisible, because it is told the site on the command line; under gunicorn it
# is not, and `curl http://localhost:8000/health` inside the container answers
# **"localhost does not exist"**. The container health check and the deployment
# script therefore send an explicit `Host`, and a pilot's `SITE_NAME` must be
# the real public hostname.
bench use "$SITE_NAME"

# Refuse before any web, worker or scheduler process can touch data migrated by
# newer KORKEM code. An older/missing marker is deliberately allowed through:
# that is the normal pre-migration state. The command has no bypass flag and a
# mismatch propagates its non-zero exit through entrypoint.sh.
/workspace/scripts/check_schema_compatibility.sh "$SITE_NAME"

# What environment this site is, written where the application can read it.
# Re-applied on every start, so moving a site between environments is a compose
# variable and not a forgotten command.
bench --site "$SITE_NAME" set-config korkem_env "$KORKEM_ENV"

if [ "$KORKEM_ENV" = "development" ]; then
  bench --site "$SITE_NAME" set-config allow_tests true
else
  # `allow_tests` lets `bench run-tests` run against this site, and the test
  # suites truncate and re-seed tables. Off, explicitly, rather than merely
  # unset — an old development site being promoted keeps its old settings.
  bench --site "$SITE_NAME" set-config allow_tests false
  # Retries, expiries and the five-minute delivery cron all run here. A pilot
  # with a paused scheduler looks healthy and never sends anything.
  bench --site "$SITE_NAME" enable-scheduler
fi
