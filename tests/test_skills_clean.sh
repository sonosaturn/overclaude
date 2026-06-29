#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
for s in brain conversation-log; do
  f="$root/plugins/overclaude/skills/$s/SKILL.md"
  [ -f "$f" ] || fail "missing $f"
  head -1 "$f" | grep -q '^---' || fail "$s SKILL.md missing frontmatter"
  grep -q "^name: $s" "$f" || fail "$s SKILL.md name mismatch"
done
# no absolute home paths anywhere in the bundled skills
! grep -rIn '/home/xsaturn' "$root/plugins/overclaude/skills" || fail "absolute path leaked into skills"
echo "PASS test_skills_clean"
