#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
[ -f "$root/brain-scaffold/BRAIN.md" ] || fail "no BRAIN.md"
for d in sources wiki conversations bin; do
  [ -d "$root/brain-scaffold/$d" ] || fail "missing dir $d"
done
# scaffold must contain no real conversation logs
! ls "$root/brain-scaffold/conversations/"Conv_*.md >/dev/null 2>&1 || fail "scaffold leaks conversations"
! grep -rIn '/home/xsaturn' "$root/brain-scaffold" || fail "absolute path in scaffold"
echo "PASS test_scaffold"
