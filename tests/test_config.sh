#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || fail "jq required"
jq -e . "$root/config/settings.template.json" >/dev/null || fail "settings.template.json invalid"
! grep -RIn '/home/xsaturn' "$root/config" || fail "absolute path in config"
# no live secrets: the context7 key pattern must not appear
! grep -RIn 'ctx7sk-' "$root/config" "$root/.env.example" || fail "secret leaked"
grep -q 'CONTEXT7_API_KEY' "$root/.env.example" || fail ".env.example missing CONTEXT7_API_KEY"
grep -q 'GEMINI_API_KEY' "$root/.env.example" || fail ".env.example missing GEMINI_API_KEY"
echo "PASS test_config"
