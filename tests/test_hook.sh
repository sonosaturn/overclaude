#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || fail "jq required"

jq -e . "$root/plugins/overclaude/hooks/hooks.json" >/dev/null || fail "hooks.json invalid"
jq -e '.hooks.SessionStart[0].matcher=="startup|resume|clear"' \
  "$root/plugins/overclaude/hooks/hooks.json" >/dev/null || fail "wrong matcher"
grep -q 'CLAUDE_PLUGIN_ROOT' "$root/plugins/overclaude/hooks/hooks.json" || fail "hook path not plugin-relative"

# Functional: run the POSIX hook against a temp HOME and check it created the session file.
tmp="$(mktemp -d)"
HOME="$tmp" sh "$root/plugins/overclaude/hooks/new-session.sh" >"$tmp/out.txt"
ls "$tmp/brain/conversations/"Conv_*.md >/dev/null 2>&1 || fail "no Conv file created"
[ -f "$tmp/brain/conversations/.current-session" ] || fail "no .current-session marker"
grep -q 'CONVERSATION LOG ATTIVO' "$tmp/out.txt" || fail "context line not printed"
rm -rf "$tmp"
echo "PASS test_hook"
