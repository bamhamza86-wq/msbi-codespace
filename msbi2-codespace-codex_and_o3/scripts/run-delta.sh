#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

wait_for_sql
run_sql_file sql/40_seed_batch_002_delta.sql
run_sql_file sql/50_run_delta_load.sql

echo "Delta batch 002 loaded."
