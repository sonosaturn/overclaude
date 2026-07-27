#!/usr/bin/env sh
# overclaude-sync.sh — PostToolUse(Bash) hook.
#
# If the bash command that just ran added a **skill** (`npx skills add`, with or without
# `--skill`), an **MCP** (`claude mcp add … -- <cmd>`) or a **plugin**
# (`claude plugin install <name>@<marketplace>`), it appends the line to overclaude's
# manifest (if missing), commits and **pushes** — so the repo keeps up with the config.
#
# PostToolUse only fires on a successful tool call → no sync on failed adds.
# **Secrets** (API_KEY/TOKEN/SECRET/--api-key) are REDACTED before writing and pushing
# (the manifest is public). The real key lives in overclaude's .env.
set -eu

REPO="${OVERCLAUDE_REPO:-$HOME/projects/overclaude}"   # override for the tests
MANIFEST="$REPO/lib/components.manifest"
SETTINGS="$HOME/.claude/settings.json"
[ -f "$MANIFEST" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

cmd="$(jq -r '.tool_input.command // empty')" 2>/dev/null || exit 0
[ -n "$cmd" ] || exit 0

# Compound commands (';', '|', '&&', newline) cannot be attributed with certainty: parsing
# would drag in foreign shell, which would end up in the manifest and which run-component
# runs with eval on the installer's machine. Better to skip the sync — the add can always
# be re-run on its own.
case "$cmd" in
  *';'*|*'|'*|*'&&'*|*'
'*) exit 0 ;;
esac

# first_nonflag <words...> → first token that is neither a flag nor the value of a flag
# that takes one (`--scope user` would otherwise give name="user").
first_nonflag() {
  _skip=0
  for w in "$@"; do
    if [ "$_skip" = 1 ]; then _skip=0; continue; fi
    case "$w" in
      --scope|-s|--transport|-t|--env|-e|--header|-H) _skip=1 ;;
      -*) ;;
      *) printf '%s' "$w"; return ;;
    esac
  done
}
# redact_secrets: blanks out sensitive values in a command string.
# No GNU sed `I` flag: this has to run on macOS BSD sed too, so the case variants are
# spelled out (uppercase env vars, lowercase flags).
redact_secrets() {
  printf '%s' "$1" | sed -E \
    -e 's/([A-Z0-9_]*(KEY|TOKEN|SECRET|PASSWORD|PASSWD|CREDENTIALS?|AUTH|SESSION|COOKIE|DSN)[A-Z0-9_]*=)[^ ]+/\1SET_IN_ENV/g' \
    -e 's/(--?(api-key|apikey|key|token|secret|password|passwd|auth|authorization|bearer|header|credential|cookie)[= ])[^ ]+/\1SET_IN_ENV/g' \
    -e 's#(https?://)[^/ :@]+:[^/ @]+@#\1SET_IN_ENV@#g' \
    -e 's/([?&](key|token|api_key|access_token|apikey|auth)=)[^& ]+/\1SET_IN_ENV/g' \
    -e "s#$HOME#\$HOME#g"
}

# looks_secret: fail-closed. Redaction only knows the shapes we taught it; this catches
# what slips through by looking at the *shape* of the token. If it fires we publish
# nothing: a missed sync is fixed by re-running the add, a secret on a public repo is not.
looks_secret() {
  printf '%s' "$1" | grep -Eq \
    -e '(sk|pk|rk)-[A-Za-z0-9_-]{16,}' \
    -e '(ghp|gho|ghs|ghu|ghr)_[A-Za-z0-9]{16,}|github_pat_[A-Za-z0-9_]{20,}' \
    -e 'xox[abposr]-[A-Za-z0-9-]{10,}' \
    -e 'AKIA[0-9A-Z]{16}' \
    -e 'AIza[0-9A-Za-z_-]{20,}' \
    -e '(hf|gsk|st_sk|ctx7sk|nvapi|glpat|dop_v1)[-_][A-Za-z0-9_-]{16,}' \
    -e 'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}' \
    -e '(^| )[A-Za-z0-9_+/=-]{40,}( |$)'
}

line=""
case " $cmd " in
  *" claude mcp add "*)
    after="${cmd#*claude mcp add }"
    # requires the explicit "... -- <cmd>" form; without '--' we do not guess
    case "$after" in *" -- "*) ;; *) exit 0;; esac
    # shellcheck disable=SC2086
    name="$(first_nonflag ${after%% -- *})"
    mcpcmd="${after#* -- }"
    [ -n "$name" ] && [ -n "$mcpcmd" ] || exit 0
    mcpcmd="$(redact_secrets "$mcpcmd")"
    line="mcp|$name|$mcpcmd"
    ;;
  *" claude plugin install "*)
    after="${cmd#*claude plugin install }"
    # shellcheck disable=SC2086
    pid="$(first_nonflag $after)"          # e.g. designer-toolkit@designer-skills
    case "$pid" in *@*) ;; *) exit 0 ;; esac
    mkt="${pid#*@}"
    # resolve the marketplace's source repo from the settings
    repo="$(jq -r --arg m "$mkt" '.extraKnownMarketplaces[$m].source.repo // empty' "$SETTINGS" 2>/dev/null)"
    [ -n "$repo" ] || exit 0
    # sync only if the plugin really is enabled
    jq -e --arg p "$pid" '.enabledPlugins[$p]==true' "$SETTINGS" >/dev/null 2>&1 || exit 0
    line="plugin|$pid|$repo"
    ;;
  *" skills"*" add "*)
    after="${cmd#*skills}"; after="${after#* add }"
    # shellcheck disable=SC2086
    repo="$(first_nonflag $after)"
    [ -n "$repo" ] || exit 0
    case "$cmd" in
      *"--skill "*)
        name="${cmd#*--skill }"; name="${name%% *}"
        [ -n "$name" ] || exit 0
        [ -e "$HOME/.claude/skills/$name" ] || exit 0   # check it is installed
        line="skills-cli|$name|$repo" ;;
      *)
        # whole-repo install (multi/single skill without --skill: gsap, superdesign, …)
        label="$(basename "$repo" | sed 's/\.git$//')"
        line="skills-repo|$label|$repo" ;;
    esac
    ;;
  *) exit 0 ;;
esac

# Redaction applies to every branch, not just MCPs: an `npx skills add` can carry a token
# too. Then the fail-closed check on the final line.
line="$(redact_secrets "$line")"
if looks_secret "$line"; then
  printf '{"systemMessage":"overclaude: sync skipped, the command contains a value that looks like a secret"}\n'
  exit 0
fi

# dedup: identical line, or same type+name already declared
grep -qxF "$line" "$MANIFEST" && exit 0
key="$(printf '%s' "$line" | cut -d'|' -f1-2)"
grep -q "^$key|" "$MANIFEST" && exit 0

printf '%s\n' "$line" >> "$MANIFEST"

cd "$REPO" || exit 0
git add lib/components.manifest >/dev/null 2>&1 || exit 0
git commit -q -m "chore: auto-sync manifest ($line)" >/dev/null 2>&1 || exit 0
GIT_TERMINAL_PROMPT=0 git push -q >/dev/null 2>&1 || true   # best-effort push, never blocking
printf '{"systemMessage":"overclaude: manifest synced + pushed → %s"}\n' "$line"
