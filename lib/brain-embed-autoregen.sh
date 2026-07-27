#!/usr/bin/env sh
# Indexes the files changed by the commit into ChromaDB — ONLY in the brain vault. Detached: never blocks git.
# Vault guard: presence of bin/brain-embed. No-op if uv or the key is missing. A commit never fails for this.
# ponytail: incremental via git diff-tree; no re-embedding of unchanged files.
command -v uv >/dev/null 2>&1 || exit 0
repo="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$repo" ] || exit 0
[ -f "$repo/bin/brain-embed" ] || exit 0
[ -f "$HOME/.config/brain.env" ] && . "$HOME/.config/brain.env"
[ -n "${GEMINI_API_KEY:-}" ] || exit 0
export GEMINI_API_KEY BRAIN_VAULT="$repo"
setsid sh -c "cd '$repo' && ./bin/brain-embed --changed" >>/tmp/brain-embed.log 2>&1 </dev/null &
exit 0
