#!/usr/bin/env sh
# overclaude-sync.sh — PostToolUse(Bash) hook.
#
# Legge il JSON del hook su stdin. Se il comando bash appena eseguito ha aggiunto
# una **skill** (`npx skills … add <repo> --skill <name>`) o un **MCP**
# (`claude mcp add <name> -- <cmd>`), appende la riga corrispondente al manifest di
# overclaude (se manca), committa e **pusha** — così la repo resta al passo con la config.
#
# PostToolUse scatta solo su tool riuscito → niente sync su add falliti.
#
# ponytail: cattura solo skill/MCP aggiunti con le forme di comando standard via Bash.
#           Plugin, add interattivi (/plugin), o comandi dal terminale dell'utente NON
#           passano di qui → in quei casi lancia questo script a mano (o aggiorna il
#           manifest e committa). Upgrade path: estendere il case per `claude plugin install`
#           quando servirà (richiede risolvere il source della marketplace).
set -eu

REPO="${OVERCLAUDE_REPO:-$HOME/overclaude}"   # override per i test
MANIFEST="$REPO/lib/components.manifest"
[ -f "$MANIFEST" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

cmd="$(jq -r '.tool_input.command // empty')" 2>/dev/null || exit 0
[ -n "$cmd" ] || exit 0

# first_nonflag <words...> → primo token che non inizia per '-'
first_nonflag() { for w in "$@"; do case "$w" in -*) ;; *) printf '%s' "$w"; return;; esac; done; }

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
    line="mcp|$name|$mcpcmd"
    ;;
  *" skills"*" add "*)
    case "$cmd" in *"--skill "*) ;; *) exit 0;; esac
    after="${cmd#*skills}"; after="${after#* add }"
    # shellcheck disable=SC2086
    repo="$(first_nonflag $after)"
    name="${cmd#*--skill }"; name="${name%% *}"
    [ -n "$repo" ] && [ -n "$name" ] || exit 0
    [ -e "$HOME/.claude/skills/$name" ] || exit 0   # verifica che sia davvero installata
    line="skills-cli|$name|$repo"
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
