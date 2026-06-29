#!/usr/bin/env sh
set -eu
here="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
rc=0
for t in "$here"/test_*.sh; do
  echo "--- $t"; sh "$t" || rc=1
done
[ "$rc" = 0 ] && echo "ALL TESTS PASSED" || echo "SOME TESTS FAILED"
exit "$rc"
