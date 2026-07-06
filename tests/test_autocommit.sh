#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || fail "jq required"
command -v git >/dev/null 2>&1 || fail "git required"

# wired as a Stop hook, plugin-relative
jq -e '.hooks.Stop[0].hooks[0].command | test("autocommit.sh")' \
  "$root/plugins/overclaude/hooks/hooks.json" >/dev/null || fail "autocommit not wired as Stop hook"

hook="$root/plugins/overclaude/hooks/autocommit.sh"
[ -f "$hook" ] || fail "autocommit.sh missing"

tmp="$(mktemp -d)"
git -C "$tmp" init -q; git -C "$tmp" config user.email t@t; git -C "$tmp" config user.name t
git -C "$tmp" commit -q --allow-empty -m base

# clean tree -> no-op (no new commit)
before="$(git -C "$tmp" rev-list --count HEAD)"
OVERCLAUDE_REPO="$tmp" sh "$hook" >/dev/null
[ "$(git -C "$tmp" rev-list --count HEAD)" = "$before" ] || fail "committed on clean tree"

# dirty tree (tracked + untracked) -> one commit, tree clean after
echo a > "$tmp/f.txt"; echo b > "$tmp/g.txt"
OVERCLAUDE_REPO="$tmp" sh "$hook" >/dev/null
[ "$(git -C "$tmp" rev-list --count HEAD)" = "$((before+1))" ] || fail "did not commit dirty tree"
[ -z "$(git -C "$tmp" status --porcelain)" ] || fail "tree not clean after autocommit"

rm -rf "$tmp"
echo "PASS test_autocommit"
