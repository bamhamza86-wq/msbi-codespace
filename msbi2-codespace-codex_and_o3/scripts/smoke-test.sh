#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

cleanup() {
  local exit_code=$?
  if [[ "${KEEP_MSBI2_STACK:-0}" != "1" ]]; then
    compose down -v >/dev/null 2>&1 || true
  fi
  exit "$exit_code"
}
trap cleanup EXIT

compose down -v >/dev/null 2>&1 || true
"$SCRIPT_DIR/deploy.sh"
"$SCRIPT_DIR/run-delta.sh"
"$SCRIPT_DIR/validate.sh"

PYTHON_BIN="${PYTHON:-}"
if [[ -z "$PYTHON_BIN" ]]; then
  if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN=python3
  else
    PYTHON_BIN=python
  fi
fi

"$PYTHON_BIN" -m unittest discover -s tests -v

echo "MSBI2 smoke test complete."
