#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd -P)"
rc=0
for t in "$here"/test-*.sh; do
  echo "=== $(basename "$t") ==="
  if bash "$t"; then echo "PASS"; else echo "FAIL"; rc=1; fi
done
exit "$rc"
