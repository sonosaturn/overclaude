#!/usr/bin/env sh
fails=0
ck() { if eval "$2" >/dev/null 2>&1; then echo "CHECK PASS: $1"; else echo "CHECK FAIL: $1"; fails=$((fails+1)); fi; }
for b in node uv gitnexus codeburn markitdown graphify; do ck "tool $b in PATH" "command -v $b"; done
ck "settings.json valid" "jq -e . \"$HOME/.claude/settings.json\""
ck "overclaude plugin enabled" "jq -e '.enabledPlugins[\"overclaude@overclaude\"]==true' \"$HOME/.claude/settings.json\""
ck "~/brain exists" "[ -d \"$HOME/brain\" ]"
ck "gitnexus autoreindex script" "[ -x \"$HOME/.local/bin/gitnexus-autoreindex.sh\" ]"
ck "git init.templateDir set" "git config --global --get init.templateDir"
ck "git template post-commit hook" "[ -x \"$(git config --global --get init.templateDir)/hooks/post-commit\" ]"

# Skill user-scope: devono essere esattamente quelle dichiarate, né una in più né una in
# meno. È il controllo che accorge della deriva silenziosa: un repo a monte che aggiunge
# skill cambia ciò che il manifest installa senza che nessuno lo noti.
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
exp="$HERE/config/skills.expected"
if [ -f "$exp" ] && [ -d "$HOME/.claude/skills" ]; then
  t="$(mktemp -d)"
  ls "$HOME/.claude/skills" 2>/dev/null | sort > "$t/actual"
  grep -v '^#' "$exp" | grep -v '^[[:space:]]*$' | sort > "$t/expected"
  comm -23 "$t/actual" "$t/expected" > "$t/extra"
  comm -13 "$t/actual" "$t/expected" > "$t/missing"
  if [ -s "$t/extra" ] || [ -s "$t/missing" ]; then
    echo "CHECK FAIL: skill user-scope divergenti"
    [ -s "$t/extra" ]   && sed 's/^/  in più:    /' "$t/extra"
    [ -s "$t/missing" ] && sed 's/^/  mancante:  /' "$t/missing"
    fails=$((fails+1))
  else
    echo "CHECK PASS: skill user-scope ($(wc -l < "$t/expected" | tr -d ' ') attese)"
  fi
  rm -rf "$t"
fi

[ "$fails" -eq 0 ] && echo "ALL CHECKS PASSED" || echo "$fails CHECK(S) FAILED"
exit "$fails"
