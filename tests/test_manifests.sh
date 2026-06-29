#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || fail "jq required to run tests"

jq -e . "$root/.claude-plugin/marketplace.json" >/dev/null || fail "marketplace.json invalid JSON"
jq -e . "$root/plugins/overclaude/.claude-plugin/plugin.json" >/dev/null || fail "plugin.json invalid JSON"

# marketplace must reference the overclaude plugin by source path
jq -e '.plugins[] | select(.name=="overclaude") | .source=="./plugins/overclaude"' \
  "$root/.claude-plugin/marketplace.json" >/dev/null || fail "marketplace missing overclaude plugin source"

jq -e '.name=="overclaude"' "$root/plugins/overclaude/.claude-plugin/plugin.json" >/dev/null \
  || fail "plugin.json name != overclaude"

echo "PASS test_manifests"
