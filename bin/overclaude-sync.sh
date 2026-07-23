#!/usr/bin/env sh
# overclaude-sync.sh — PostToolUse(Bash) hook.
#
# Se il comando bash appena eseguito ha aggiunto una **skill** (`npx skills add`,
# con o senza `--skill`), un **MCP** (`claude mcp add … -- <cmd>`) o un **plugin**
# (`claude plugin install <name>@<marketplace>`), appende la riga al manifest di
# overclaude (se manca), committa e **pusha** — così la repo resta al passo con la config.
#
# PostToolUse scatta solo su tool riuscito → niente sync su add falliti.
# I **segreti** (API_KEY/TOKEN/SECRET/--api-key) vengono REDATTI prima di scrivere e
# pushare (il manifest è pubblico). La key vera vive nel .env di overclaude.
set -eu

REPO="${OVERCLAUDE_REPO:-$HOME/projects/overclaude}"   # override per i test
MANIFEST="$REPO/lib/components.manifest"
SETTINGS="$HOME/.claude/settings.json"
[ -f "$MANIFEST" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

cmd="$(jq -r '.tool_input.command // empty')" 2>/dev/null || exit 0
[ -n "$cmd" ] || exit 0

# Comandi composti (';', '|', '&&', newline) non sono attribuibili con certezza: il
# parsing si porterebbe dietro shell estranea, che finirebbe nel manifest e che
# run-component esegue con eval sulla macchina di chi installa. Meglio saltare il
# sync — l'add si può sempre rilanciare da solo.
case "$cmd" in
  *';'*|*'|'*|*'&&'*|*'
'*) exit 0 ;;
esac

# first_nonflag <words...> → primo token che non è un flag né il valore di un flag
# che ne prende uno (`--scope user` darebbe altrimenti name="user").
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
# redact_secrets: azzera i valori sensibili in una stringa comando
redact_secrets() {
  printf '%s' "$1" | sed -E \
    -e 's/(API_KEY=)[^ ]+/\1SET_IN_ENV/g' \
    -e 's/([A-Za-z_]*TOKEN=)[^ ]+/\1SET_IN_ENV/g' \
    -e 's/([A-Za-z_]*SECRET=)[^ ]+/\1SET_IN_ENV/g' \
    -e 's/(--api-key[= ])[^ ]+/\1SET_IN_ENV/g'
}

line=""
case " $cmd " in
  *" claude mcp add "*)
    after="${cmd#*claude mcp add }"
    # richiede la forma esplicita "... -- <cmd>"; senza '--' non indoviniamo
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
    pid="$(first_nonflag $after)"          # es. designer-toolkit@designer-skills
    case "$pid" in *@*) ;; *) exit 0 ;; esac
    mkt="${pid#*@}"
    # risolvi il source repo della marketplace dai settings
    repo="$(jq -r --arg m "$mkt" '.extraKnownMarketplaces[$m].source.repo // empty' "$SETTINGS" 2>/dev/null)"
    [ -n "$repo" ] || exit 0
    # sync solo se il plugin risulta davvero abilitato
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
        [ -e "$HOME/.claude/skills/$name" ] || exit 0   # verifica installata
        line="skills-cli|$name|$repo" ;;
      *)
        # install intero repo (multi/single skill senza --skill: gsap, superdesign, …)
        label="$(basename "$repo" | sed 's/\.git$//')"
        line="skills-repo|$label|$repo" ;;
    esac
    ;;
  *) exit 0 ;;
esac

# dedup: riga identica o stesso type+name già dichiarati
grep -qxF "$line" "$MANIFEST" && exit 0
key="$(printf '%s' "$line" | cut -d'|' -f1-2)"
grep -q "^$key|" "$MANIFEST" && exit 0

printf '%s\n' "$line" >> "$MANIFEST"

cd "$REPO" || exit 0
git add lib/components.manifest >/dev/null 2>&1 || exit 0
git commit -q -m "chore: auto-sync manifest ($line)" >/dev/null 2>&1 || exit 0
GIT_TERMINAL_PROMPT=0 git push -q >/dev/null 2>&1 || true   # push best-effort, mai bloccante
printf '{"systemMessage":"overclaude: manifest sincronizzato + pushato → %s"}\n' "$line"
