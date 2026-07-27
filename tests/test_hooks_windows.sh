#!/usr/bin/env sh
# Guards against the ways hooks fail SILENTLY on Windows.
# The why, in detail: docs/WINDOWS.md
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || fail "jq required to run tests"

hooks="$root/plugins/overclaude/hooks/hooks.json"
jq -e . "$hooks" >/dev/null || fail "hooks.json invalid JSON"

# 1. No hardcoded 'python3': on Windows it is the Microsoft Store alias, exits 49 without running.
#    Allowed only inside the probe, which tries it and falls back to python/py.
jq -r '.. | .command? // empty' "$hooks" | while read -r cmd; do
  case "$cmd" in
    *python3*)
      case "$cmd" in
        *'for p in python3 python py'*) : ;;
        *) fail "hook calls python3 without a probe: $cmd" ;;
      esac ;;
  esac
done

# 2. The scripts referenced by the hooks must exist in the plugin: a missing file
#    raises no error, the hook simply does nothing.
jq -r '.. | .command? // empty' "$hooks" \
  | tr ' ' '\n' | sed -n 's|.*${CLAUDE_PLUGIN_ROOT}/||p' | tr -d '"' | sort -u \
  | while read -r rel; do
      [ -f "$root/plugins/overclaude/$rel" ] || fail "hook punta a un file inesistente: $rel"
    done

# 3. Every open() in log-session.py must declare the encoding: without it, Python on Windows
#    uses the codepage (cp1252) and dies on the vault's first UTF-8 character.
bad="$(grep -n 'open(' "$root/plugins/overclaude/hooks/log-session.py" | grep -v 'encoding=' || true)"
[ -z "$bad" ] || fail "open() without encoding in log-session.py: $bad"

echo "PASS test_hooks_windows"
