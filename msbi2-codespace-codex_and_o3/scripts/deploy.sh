#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Created .env from .env.example."
fi

mkdir -p artifacts/backups artifacts/logs

compose up -d
wait_for_sql

run_sql_file sql/00_create_dw.sql
run_sql_file sql/10_seed_batch_001.sql
run_sql_file sql/20_etl_delta_procs.sql
run_sql_file sql/30_run_initial_load.sql

echo "Initial DW load complete."
