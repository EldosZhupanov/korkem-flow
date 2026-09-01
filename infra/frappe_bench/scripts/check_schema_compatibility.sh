#!/bin/bash
# Startup gate for a WSL2 node whose data may have been restored or whose code
# may have been rolled back independently of its persistent Docker volumes.
set -euo pipefail

site="${1:?usage: check_schema_compatibility.sh <site>}"
cd /home/frappe/frappe-bench

exec bench --site "$site" execute \
  korkem_ai.korkem_ai.environment.assert_schema_compatible
