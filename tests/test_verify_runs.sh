#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
# verify.sh must run and emit at least one CHECK line (exit code may be nonzero on a bare CI box)
out="$(sh "$root/verify.sh" 2>&1 || true)"
echo "$out" | grep -q 'CHECK' || fail "verify produced no checks"
echo "PASS test_verify_runs"
