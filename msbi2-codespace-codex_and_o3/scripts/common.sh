#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env ]]; then
  set -a
  source ./.env
  set +a
fi

export ACCEPT_EULA="${ACCEPT_EULA:-Y}"
export MSSQL_PID="${MSSQL_PID:-Developer}"
export MSSQL_SA_PASSWORD="${MSSQL_SA_PASSWORD:-Passw0rd123!}"
export MSSQL_TCP_PORT="${MSSQL_TCP_PORT:-1433}"
export SQL_CONTAINER_NAME="${SQL_CONTAINER_NAME:-msbi2-mssql}"
export DW_DATABASE="${DW_DATABASE:-DW}"

compose() {
  docker compose "$@"
}

sqlcmd_in_container() {
  docker exec -i "$SQL_CONTAINER_NAME" bash -lc '
    if [[ -x /opt/mssql-tools18/bin/sqlcmd ]]; then
      SQLCMD=/opt/mssql-tools18/bin/sqlcmd
    else
      SQLCMD=/opt/mssql-tools/bin/sqlcmd
    fi
    "$SQLCMD" -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -b "$@"
  ' sqlcmd "$@"
}

run_sql_file() {
  local sql_file="$1"
  echo "-> ${sql_file}"
  sqlcmd_in_container -i /dev/stdin < "$sql_file"
}

wait_for_sql() {
  echo "Waiting for SQL Server health..."
  for _ in $(seq 1 90); do
    if sqlcmd_in_container -Q "SELECT 1" >/dev/null 2>&1; then
      echo "SQL Server is ready."
      return 0
    fi
    sleep 2
  done
  echo "SQL Server did not become ready in time." >&2
  docker logs "$SQL_CONTAINER_NAME" >&2 || true
  return 1
}
