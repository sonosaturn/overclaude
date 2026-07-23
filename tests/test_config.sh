#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || fail "jq required"
jq -e . "$root/config/settings.template.json" >/dev/null || fail "settings.template.json invalid"
! grep -RIn '/home/xsaturn' "$root/config" || fail "absolute path in config"
# no live secrets: the context7 key pattern must not appear
# Le forme note delle chiavi usate qui non devono comparire in nulla di versionato:
# config, .env.example e la documentazione (che le nomina, ma solo come placeholder).
! grep -RInE 'ctx7sk-[A-Za-z0-9-]{8}|AIza[0-9A-Za-z_-]{20}|st_sk_[A-Za-z0-9]{16}|gsk_[A-Za-z0-9]{16}' \
    "$root/config" "$root/.env.example" "$root/docs" "$root/README.md" || fail "secret leaked"
grep -q 'CONTEXT7_API_KEY' "$root/.env.example" || fail ".env.example missing CONTEXT7_API_KEY"
grep -q 'GEMINI_API_KEY' "$root/.env.example" || fail ".env.example missing GEMINI_API_KEY"
echo "PASS test_config"
