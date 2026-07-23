#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || fail "jq required"

hook="$root/bin/overclaude-sync.sh"

# Ogni caso gira su un repo finto: il manifest reale non viene mai toccato.
run_sync() { # run_sync <manifest_dir> <bash command>
  printf '{"tool_input":{"command":%s}}' "$(printf '%s' "$2" | jq -Rs .)" \
    | OVERCLAUDE_REPO="$1" sh "$hook" >/dev/null 2>&1 || true
}
new_repo() {
  d="$(mktemp -d)"; mkdir -p "$d/lib"; : > "$d/lib/components.manifest"
  (cd "$d" && git init -q 2>/dev/null) || true
  printf '%s' "$d"
}

# 1. `--scope user` non deve diventare il nome dell'MCP (regressione: d45222c).
d="$(new_repo)"
run_sync "$d" 'claude mcp add --scope user context7 -- npx -y @upstash/context7-mcp'
grep -qxF 'mcp|context7|npx -y @upstash/context7-mcp' "$d/lib/components.manifest" \
  || fail "nome MCP errato con --scope: $(cat "$d/lib/components.manifest")"
rm -rf "$d"

# 2. Un comando composto non deve sincronizzare nulla: il parser si porterebbe
#    dietro shell estranea, che run-component eseguirebbe con eval.
d="$(new_repo)"
run_sync "$d" 'claude mcp add --scope user context7 -- npx -y @upstash/context7-mcp 2>&1 | tail -2; claude mcp add --scope user playwright -- npx @playwright/mcp@latest'
[ -s "$d/lib/components.manifest" ] \
  && fail "sync su comando composto: $(cat "$d/lib/components.manifest")"
rm -rf "$d"

# 3. Il caso semplice continua a funzionare, e i segreti restano redatti.
d="$(new_repo)"
run_sync "$d" 'claude mcp add magic -- npx -y @21st-dev/magic@latest API_KEY=st_sk_deadbeef'
grep -qxF 'mcp|magic|npx -y @21st-dev/magic@latest API_KEY=SET_IN_ENV' "$d/lib/components.manifest" \
  || fail "redazione o parsing base rotti: $(cat "$d/lib/components.manifest")"
rm -rf "$d"

echo "PASS test_sync"
