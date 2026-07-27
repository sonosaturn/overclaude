#!/usr/bin/env sh
fails=0
ck() { if eval "$2" >/dev/null 2>&1; then echo "CHECK PASS: $1"; else echo "CHECK FAIL: $1"; fails=$((fails+1)); fi; }
for b in node uv gitnexus codeburn markitdown graphify rtk; do ck "tool $b in PATH" "command -v $b"; done
ck "settings.json valid" "jq -e . \"$HOME/.claude/settings.json\""
ck "overclaude plugin enabled" "jq -e '.enabledPlugins[\"overclaude@overclaude\"]==true' \"$HOME/.claude/settings.json\""
ck "~/brain exists" "[ -d \"$HOME/brain\" ]"
ck "RTK.md present (@RTK.md in the global CLAUDE.md)" "[ -f \"$HOME/.claude/RTK.md\" ]"
ck "statusline configured" "jq -e '.statusLine.command | test(\"statusline\")' \"$HOME/.claude/settings.json\""
ck "gitnexus autoreindex script" "[ -x \"$HOME/.local/bin/gitnexus-autoreindex.sh\" ]"
ck "git init.templateDir set" "git config --global --get init.templateDir"
ck "git template post-commit hook" "[ -x \"$(git config --global --get init.templateDir)/hooks/post-commit\" ]"

# User-scope skills: must be exactly the declared ones, no more and no less. This is the
# check that catches silent drift: an upstream repo that adds skills changes what the
# manifest installs without anyone noticing.
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
exp="$HERE/config/skills.expected"
if [ -f "$exp" ] && [ -d "$HOME/.claude/skills" ]; then
  t="$(mktemp -d)"
  ls "$HOME/.claude/skills" 2>/dev/null | sort > "$t/actual"
  grep -v '^#' "$exp" | grep -v '^[[:space:]]*$' | sort > "$t/expected"
  comm -23 "$t/actual" "$t/expected" > "$t/extra"
  comm -13 "$t/actual" "$t/expected" > "$t/missing"
  if [ -s "$t/extra" ] || [ -s "$t/missing" ]; then
    echo "CHECK FAIL: user-scope skills diverge"
    [ -s "$t/extra" ]   && sed 's/^/  extra:     /' "$t/extra"
    [ -s "$t/missing" ] && sed 's/^/  missing:   /' "$t/missing"
    fails=$((fails+1))
  else
    echo "CHECK PASS: user-scope skills ($(wc -l < "$t/expected" | tr -d ' ') expected)"
  fi
  rm -rf "$t"
fi

[ "$fails" -eq 0 ] && echo "ALL CHECKS PASSED" || echo "$fails CHECK(S) FAILED"
exit "$fails"
