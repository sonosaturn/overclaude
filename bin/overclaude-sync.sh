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
# redact_secrets: azzera i valori sensibili in una stringa comando.
# Niente flag `I` di GNU sed: va girare anche sul sed BSD di macOS, quindi le
# varianti di maiuscole sono esplicite (env var maiuscole, flag minuscoli).
redact_secrets() {
  printf '%s' "$1" | sed -E \
    -e 's/([A-Z0-9_]*(KEY|TOKEN|SECRET|PASSWORD|PASSWD|CREDENTIALS?|AUTH|SESSION|COOKIE|DSN)[A-Z0-9_]*=)[^ ]+/\1SET_IN_ENV/g' \
    -e 's/(--?(api-key|apikey|key|token|secret|password|passwd|auth|authorization|bearer|header|credential|cookie)[= ])[^ ]+/\1SET_IN_ENV/g' \
    -e 's#(https?://)[^/ :@]+:[^/ @]+@#\1SET_IN_ENV@#g' \
    -e 's/([?&](key|token|api_key|access_token|apikey|auth)=)[^& ]+/\1SET_IN_ENV/g' \
    -e "s#$HOME#\$HOME#g"
}

# looks_secret: fail-closed. La redazione conosce solo le forme che le abbiamo
# insegnato; questo intercetta ciò che le sfugge guardando la *forma* del token.
# Se scatta non pubblichiamo niente: un sync mancato si rimedia rilanciando l'add,
# un segreto su un repo pubblico no.
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

# La redazione vale per ogni ramo, non solo per gli MCP: anche un `npx skills add`
# può portarsi dietro un token. Poi il fail-closed sulla riga finale.
line="$(redact_secrets "$line")"
if looks_secret "$line"; then
  printf '{"systemMessage":"overclaude: sync saltato, il comando contiene un valore che sembra un segreto"}\n'
  exit 0
fi

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
