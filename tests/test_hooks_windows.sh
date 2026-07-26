#!/usr/bin/env sh
# Guardie contro i modi in cui gli hook falliscono in SILENZIO su Windows.
# Dettaglio del perché: docs/WINDOWS.md
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || fail "jq required to run tests"

hooks="$root/plugins/overclaude/hooks/hooks.json"
jq -e . "$hooks" >/dev/null || fail "hooks.json invalid JSON"

# 1. Nessun 'python3' cablato: su Windows è l'alias Microsoft Store, esce 49 senza eseguire.
#    Ammesso solo dentro il probe, che lo prova e ripiega su python/py.
jq -r '.. | .command? // empty' "$hooks" | while read -r cmd; do
  case "$cmd" in
    *python3*)
      case "$cmd" in
        *'for p in python3 python py'*) : ;;
        *) fail "hook invoca python3 senza probe: $cmd" ;;
      esac ;;
  esac
done

# 2. Gli script referenziati dagli hook devono esistere nel plugin: un file mancante
#    non dà errore, l'hook semplicemente non fa nulla.
jq -r '.. | .command? // empty' "$hooks" \
  | tr ' ' '\n' | sed -n 's|.*${CLAUDE_PLUGIN_ROOT}/||p' | tr -d '"' | sort -u \
  | while read -r rel; do
      [ -f "$root/plugins/overclaude/$rel" ] || fail "hook punta a un file inesistente: $rel"
    done

# 3. Ogni open() di log-session.py deve dichiarare l'encoding: senza, Python su Windows
#    usa la codepage (cp1252) e muore sul primo carattere UTF-8 del vault.
bad="$(grep -n 'open(' "$root/plugins/overclaude/hooks/log-session.py" | grep -v 'encoding=' || true)"
[ -z "$bad" ] || fail "open() senza encoding in log-session.py: $bad"

echo "PASS test_hooks_windows"
