#!/usr/bin/env sh
fails=0
ck() { if eval "$2" >/dev/null 2>&1; then echo "CHECK PASS: $1"; else echo "CHECK FAIL: $1"; fails=$((fails+1)); fi; }
for b in node uv gitnexus markitdown graphify; do ck "tool $b in PATH" "command -v $b"; done
ck "settings.json valid" "jq -e . \"$HOME/.claude/settings.json\""
ck "overclaude plugin enabled" "jq -e '.enabledPlugins[\"overclaude@overclaude\"]==true' \"$HOME/.claude/settings.json\""
ck "~/brain exists" "[ -d \"$HOME/brain\" ]"
[ "$fails" -eq 0 ] && echo "ALL CHECKS PASSED" || echo "$fails CHECK(S) FAILED"
exit "$fails"
