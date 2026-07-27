#!/bin/bash
set -euo pipefail

/workspace/scripts/bootstrap.sh

cd /home/frappe/frappe-bench
exec bench start
