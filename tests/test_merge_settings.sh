#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || fail "jq required"
. "$root/lib/merge-settings.sh"
tmp="$(mktemp -d)"
printf '{"model":"sonnet","theme":"light","permissions":{"allow":["X"]}}' > "$tmp/existing.json"
printf '{"model":"opus","theme":"dark","enabledPlugins":{"overclaude@overclaude":true}}' > "$tmp/tmpl.json"
out="$(merge_settings "$tmp/existing.json" "$tmp/tmpl.json")"
echo "$out" | jq -e '.model=="opus"' >/dev/null || fail "template did not win on model"
echo "$out" | jq -e '.permissions.allow[0]=="X"' >/dev/null || fail "existing key lost"
echo "$out" | jq -e '.enabledPlugins["overclaude@overclaude"]==true' >/dev/null || fail "template key missing"
# missing existing -> output equals template
out2="$(merge_settings /nonexistent "$tmp/tmpl.json")"
echo "$out2" | jq -e '.model=="opus"' >/dev/null || fail "missing-existing path broken"
rm -rf "$tmp"
echo "PASS test_merge_settings"
