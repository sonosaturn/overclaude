#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
out="$(sh "$root/install.sh" --dry-run 2>&1)" || fail "dry-run exited nonzero"
echo "$out" | grep -q 'marketplace add obra/superpowers' || fail "superpowers not orchestrated"
echo "$out" | grep -q 'claude mcp add --scope user context7' || fail "context7 not orchestrated"
echo "$out" | grep -q 'claude mcp add --scope user playwright' || fail "playwright not orchestrated"
echo "$out" | grep -q 'gitnexus setup' || fail "gitnexus setup not orchestrated"
echo "$out" | grep -q 'WOULD INSTALL .*/gitnexus-autoreindex.sh' || fail "gitnexus auto-reindex not orchestrated"
echo "$out" | grep -q 'init.templateDir' || fail "git template post-commit hook not orchestrated"
# dry-run must not touch the real ~/.claude
echo "$out" | grep -qi 'DRY-RUN' || fail "dry-run banner missing"
# 7b: senza brain.env il tooling del vault resta senza key anche con il .env compilato
echo "$out" | grep -q 'WOULD WRITE ~/.config/brain.env' || fail "brain.env not orchestrated"
# 6b: auto-memory symlink restore (layer-2)
pout="$(sh "$root/install.sh" --dry-run --personal=/tmp/nope 2>&1)" || fail "personal dry-run nonzero"
echo "$pout" | grep -q 'WOULD OVERLAY personal' || fail "personal overlay not announced"
echo "$pout" | grep -q 'WOULD LINK .*/memory -> ~/brain/claude-memory' || fail "memory symlink restore not announced"
echo "PASS test_install_dryrun"
