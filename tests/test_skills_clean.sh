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

man="$root/lib/components.manifest"
exp="$root/config/skills.expected"
[ -s "$exp" ] || fail "config/skills.expected missing or empty"

# Every skill pinned in the manifest must show up among the expected ones, or verify.sh
# would flag as "extra" something the installer puts there on purpose.
grep '^skills-cli|' "$man" | cut -d'|' -f2 | while read -r s; do
  grep -qx "$s" "$exp" || fail "skills-cli|$s is not in skills.expected"
done

# `skills add <repo>` without --skill installs the WHOLE repo: if that repo grows upstream,
# the installation drifts silently (it happened with mattpocock/skills: 2 skills -> 22).
# The skills-repo type does that on purpose and is covered by verify.sh's comparison; a cmd
# line doing it on the sly is not.
! grep '^cmd|' "$man" | grep 'skills' | grep 'add' | grep -qv -- '--skill' \
  || fail "cmd entry installing a whole skills repo: pin it with skills-cli|<name>|<repo>"
echo "PASS test_skills_clean"
