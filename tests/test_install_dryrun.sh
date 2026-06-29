#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
out="$(sh "$root/install.sh" --dry-run 2>&1)" || fail "dry-run exited nonzero"
echo "$out" | grep -q 'marketplace add obra/superpowers' || fail "superpowers not orchestrated"
echo "$out" | grep -q 'claude mcp add context7' || fail "context7 not orchestrated"
echo "$out" | grep -q 'claude mcp add playwright' || fail "playwright not orchestrated"
echo "$out" | grep -q 'gitnexus setup' || fail "gitnexus setup not orchestrated"
# dry-run must not touch the real ~/.claude
echo "$out" | grep -qi 'DRY-RUN' || fail "dry-run banner missing"
echo "PASS test_install_dryrun"
