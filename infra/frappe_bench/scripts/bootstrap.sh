#!/bin/bash
set -euo pipefail
cd /home/frappe

if [ ! -d frappe-bench/apps/frappe ]; then
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

# Our own custom apps (source lives in backend/, tracked in the root repo -- not vendored,
# not inside the bench-data volume, so it's version-controlled and survives a volume reset).
[ -d apps/korkem_manufacturing ] || bench get-app --soft-link --skip-assets /workspace/custom/korkem_manufacturing
[ -d apps/korkem_ai ]            || bench get-app --soft-link --skip-assets /workspace/custom/korkem_ai

bench setup requirements --dev
bench setup requirements --node

bench set-config -g developer_mode 1
bench set-config -g redis_cache "$FRAPPE_REDIS_CACHE"
bench set-config -g redis_queue "$FRAPPE_REDIS_QUEUE"

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

bench --site "$SITE_NAME" set-config allow_tests true
