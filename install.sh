#!/usr/bin/env sh
set -eu
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$HERE/lib/detect-os.sh"
. "$HERE/lib/merge-settings.sh"
. "$HERE/lib/run-component.sh"

DRY_RUN=0; PERSONAL=""; CHECK=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY_RUN=1 ;;
    --check) CHECK=1 ;;
    --personal=*) PERSONAL="${a#--personal=}" ;;
  esac
done
export DRY_RUN
[ "$DRY_RUN" = 1 ] && echo "=== DRY-RUN: no changes will be made ===" || true

if [ "$CHECK" = 1 ]; then exec sh "$HERE/verify.sh"; fi

log() { echo ">>> $*"; }

# 1. runtimes (best-effort; user installs sudo packages themselves if prompted)
mgr="$(detect_pkg_mgr)"
log "OS=$(detect_os) pkg-mgr=$mgr"
for bin in node uv git rg; do
  command -v "$bin" >/dev/null 2>&1 || log "MISSING runtime: $bin (install via $mgr)"
done

# 2-3. orchestrate components from the manifest
while IFS='|' read -r type name arg; do
  case "$type" in ''|\#*) continue ;; esac
  log "component: $type/$name"
  if [ "$name" = "context7" ] && [ -f "$HERE/.env" ]; then
    # shellcheck disable=SC1090
    . "$HERE/.env"
    [ -n "${CONTEXT7_API_KEY:-}" ] && arg="$arg --api-key $CONTEXT7_API_KEY" || true
  fi
  if [ "$name" = "magic" ] && [ -f "$HERE/.env" ]; then
    # shellcheck disable=SC1090
    . "$HERE/.env"
    [ -n "${MAGIC_API_KEY:-}" ] && arg="npx -y @21st-dev/magic@latest API_KEY=$MAGIC_API_KEY" || true
  fi
  run_component "$type" "$name" "$arg" || log "WARN: $name failed (continuing)"
done < "$HERE/lib/components.manifest"

# 4. own plugin marketplace + install (this repo)
run_component plugin overclaude "$HERE" || log "WARN: overclaude plugin install failed"

# 5. merge config into ~/.claude
[ "$DRY_RUN" = 1 ] || mkdir -p "$HOME/.claude/rules"
merged="$(merge_settings "$HOME/.claude/settings.json" "$HERE/config/settings.template.json")"
if [ "$DRY_RUN" = 1 ]; then echo "WOULD WRITE ~/.claude/settings.json"; else printf '%s\n' "$merged" > "$HOME/.claude/settings.json"; fi
if [ ! -f "$HOME/.claude/CLAUDE.md" ]; then
  if [ "$DRY_RUN" = 1 ]; then echo "WOULD COPY CLAUDE.md"; else cp "$HERE/config/CLAUDE.md.template" "$HOME/.claude/CLAUDE.md"; fi
fi
[ "$DRY_RUN" = 1 ] || cp "$HERE"/config/rules/*.md "$HOME/.claude/rules/"

# caveman e ponytail sono modalità perenni: i plugin leggono il livello da questi file
# di stato, senza i quali restano inattivi. Non sovrascrivo se esistono già: un livello
# scelto dall'utente (lite/ultra) va rispettato al reinstall.
for _mode in caveman ponytail; do
  _flag="$HOME/.claude/.${_mode}-active"
  if [ "$DRY_RUN" = 1 ]; then echo "WOULD SET $_mode=full"
  elif [ ! -f "$_flag" ]; then printf 'full' > "$_flag"; log "$_mode attivato (full)"; fi
done

# 6. brain scaffold
if [ ! -d "$HOME/brain" ]; then
  if [ "$DRY_RUN" = 1 ]; then echo "WOULD SCAFFOLD ~/brain"; else cp -r "$HERE/brain-scaffold" "$HOME/brain"; (cd "$HOME/brain" && git init -q 2>/dev/null || true); fi
fi
if [ -n "$PERSONAL" ]; then
  if [ "$DRY_RUN" = 1 ]; then echo "WOULD OVERLAY personal from $PERSONAL"; else cp -r "$PERSONAL/." "$HOME/brain/"; fi
fi

# 6b. restore auto-memory: live dir is a symlink into the vault (single source of truth)
if [ -d "$HOME/brain/claude-memory" ] || [ "$DRY_RUN" = 1 ]; then
  proj="$(printf '%s' "$HOME" | sed 's#/#-#g')"        # /home/x -> -home-x (Claude Code project key)
  memlink="$HOME/.claude/projects/$proj/memory"
  if [ "$DRY_RUN" = 1 ]; then echo "WOULD LINK $memlink -> ~/brain/claude-memory"
  else
    mkdir -p "$(dirname "$memlink")"
    # Se lì c'è già una directory vera, contiene memorie che Claude ha scritto: vanno
    # travasate nel vault prima di sostituirla, e senza sovrascrivere ciò che il vault
    # ha già. Un `rm -rf` diretto le perderebbe in silenzio.
    if [ -d "$memlink" ] && [ ! -L "$memlink" ]; then
      for f in "$memlink"/*; do
        [ -e "$f" ] || continue
        [ -e "$HOME/brain/claude-memory/$(basename "$f")" ] || cp -r "$f" "$HOME/brain/claude-memory/"
      done
      log "auto-memory preesistente travasata nel vault"
    fi
    rm -rf "$memlink"; ln -s "$HOME/brain/claude-memory" "$memlink"
  fi
fi

# 7. secrets
if [ ! -f "$HERE/.env" ]; then
  if [ "$DRY_RUN" = 1 ]; then echo "WOULD CREATE .env from example"; else cp "$HERE/.env.example" "$HERE/.env"; fi
fi

# 7b. Il tooling del vault (brain-recall, brain-embed, graphify-run) legge la key da
#     ~/.config/brain.env, non dal .env della repo: gira anche fuori da qui, e i segreti
#     runtime non devono vivere dentro l'albero di un repo. Senza questo file la key nel
#     .env non raggiunge mai il vault. Non sovrascrivo: se esiste, l'ha scritto l'utente.
if [ "$DRY_RUN" = 1 ]; then echo "WOULD WRITE ~/.config/brain.env (se assente)"
elif [ ! -f "$HOME/.config/brain.env" ]; then
  # shellcheck disable=SC1090
  [ -f "$HERE/.env" ] && . "$HERE/.env"
  mkdir -p "$HOME/.config"
  umask 077
  {
    echo "# brain.env — caricato dalla shell (vedi zshrc/bashrc) e dagli hook del vault."
    echo "# Vive fuori da qualsiasi repo di proposito: non finisce in nessun commit."
    echo "export GEMINI_API_KEY=${GEMINI_API_KEY:-}"
    echo "export GRAPHIFY_GEMINI_MODEL=${GRAPHIFY_GEMINI_MODEL:-gemini-3.5-flash}"
    echo "export GRAPHIFY_GEMINI_MODELS=${GRAPHIFY_GEMINI_MODELS:-gemini-3.5-flash,gemini-3-flash-preview,gemini-3.1-flash-lite}"
  } > "$HOME/.config/brain.env"
  chmod 600 "$HOME/.config/brain.env"
  log "scritto ~/.config/brain.env (aggiungi il source nella tua shell rc)"
fi

# 8. gitnexus auto-reindex on commit: new repos auto-implant the post-commit hook via
#    git init.templateDir. First commit -> full analyze, later commits -> incremental.
bindir="$HOME/.local/bin"
tpl="$(git config --global --get init.templateDir 2>/dev/null || true)"   # respect an existing templateDir
[ -n "$tpl" ] || tpl="$HOME/.config/git/template"
if [ "$DRY_RUN" = 1 ]; then
  echo "WOULD INSTALL $bindir/gitnexus-autoreindex.sh"
  echo "WOULD INSTALL $tpl/hooks/post-commit and set git init.templateDir=$tpl"
else
  mkdir -p "$bindir" "$tpl/hooks"
  cp "$HERE/lib/gitnexus-autoreindex.sh" "$bindir/gitnexus-autoreindex.sh"; chmod +x "$bindir/gitnexus-autoreindex.sh"
  cp "$HERE/lib/graphify-autoregen.sh" "$bindir/graphify-autoregen.sh"; chmod +x "$bindir/graphify-autoregen.sh"
  cp "$HERE/lib/brain-embed-autoregen.sh" "$bindir/brain-embed-autoregen.sh"; chmod +x "$bindir/brain-embed-autoregen.sh"
  cp "$HERE/git-template/hooks/post-commit" "$tpl/hooks/post-commit"; chmod +x "$tpl/hooks/post-commit"
  git config --global init.templateDir "$tpl"
fi

log "done. Run 'sh install.sh --check' to verify."
