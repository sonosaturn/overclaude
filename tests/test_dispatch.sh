#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
. "$root/lib/run-component.sh"
DRY_RUN=1
out="$(run_component mcp playwright 'npx @playwright/mcp@latest')"
echo "$out" | grep -q 'claude mcp add playwright' || fail "mcp dispatch wrong: $out"
out="$(run_component plugin ponytail 'DietrichGebert/ponytail')"
echo "$out" | grep -q 'plugin marketplace add DietrichGebert/ponytail' || fail "plugin dispatch wrong"
out="$(run_component skills-cli grill-me 'mattpocock/skills')"
echo "$out" | grep -q 'npx skills@latest add mattpocock/skills' || fail "skills-cli dispatch wrong"
# manifest is parseable: every non-comment line has at least 3 pipe-fields
# (cmd args may themselves contain '|', e.g. "curl ... | bash"; read -r type name arg
# keeps the remainder, pipes included, in arg — so the invariant is NF>=3, not NF==3).
awk -F'|' 'NF && $0 !~ /^#/ && NF<3 {print; exit 1}' "$root/lib/components.manifest" || fail "manifest malformed"
# the caveman line carries an embedded pipe — confirm arg keeps it intact
line='cmd|caveman|curl -fsSL https://x/install.sh | bash'
printf '%s\n' "$line" | { IFS='|' read -r t n a; echo "$a" | grep -q '| bash' || fail "embedded pipe lost in arg parse"; }
echo "PASS test_dispatch"
