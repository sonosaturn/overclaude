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
[ "$DRY_RUN" = 1 ] || cp "$HERE/config/rules/context7.md" "$HOME/.claude/rules/context7.md"

# 6. brain scaffold
if [ ! -d "$HOME/brain" ]; then
  if [ "$DRY_RUN" = 1 ]; then echo "WOULD SCAFFOLD ~/brain"; else cp -r "$HERE/brain-scaffold" "$HOME/brain"; (cd "$HOME/brain" && git init -q 2>/dev/null || true); fi
fi
if [ -n "$PERSONAL" ]; then
  if [ "$DRY_RUN" = 1 ]; then echo "WOULD OVERLAY personal from $PERSONAL"; else cp -r "$PERSONAL/." "$HOME/brain/"; fi
fi

# 7. secrets
if [ ! -f "$HERE/.env" ]; then
  if [ "$DRY_RUN" = 1 ]; then echo "WOULD CREATE .env from example"; else cp "$HERE/.env.example" "$HERE/.env"; fi
fi

log "done. Run 'sh install.sh --check' to verify."
