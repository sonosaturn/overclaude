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
[ -s "$exp" ] || fail "config/skills.expected mancante o vuoto"

# Ogni skill pinnata nel manifest deve comparire fra quelle attese, o verify.sh
# segnalerebbe come "in più" qualcosa che l'installer mette apposta.
grep '^skills-cli|' "$man" | cut -d'|' -f2 | while read -r s; do
  grep -qx "$s" "$exp" || fail "skills-cli|$s non è in skills.expected"
done

# `skills add <repo>` senza --skill installa il repo INTERO: se quel repo cresce a monte,
# l'installazione diverge in silenzio (è successo con mattpocock/skills: 2 skill -> 22).
# Il tipo skills-repo lo fa apposta ed è coperto dal confronto in verify.sh; una riga cmd
# che lo fa di nascosto, no.
! grep '^cmd|' "$man" | grep 'skills' | grep 'add' | grep -qv -- '--skill' \
  || fail "voce cmd che installa un repo di skill intero: pinna con skills-cli|<nome>|<repo>"
echo "PASS test_skills_clean"
