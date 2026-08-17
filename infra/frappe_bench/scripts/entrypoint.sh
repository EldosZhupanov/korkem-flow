#!/bin/bash
set -euo pipefail

/workspace/scripts/bootstrap.sh
exec /workspace/scripts/start.sh
