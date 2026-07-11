#!/usr/bin/env sh
# Indicizza in ChromaDB i file cambiati dal commit — SOLO nel vault brain. Detached: non blocca git.
# Guardia vault: presenza di bin/brain-embed. No-op se manca uv/key. Un commit non fallisce mai per questo.
# ponytail: incrementale via git diff-tree; nessun re-embed di file invariati.
command -v uv >/dev/null 2>&1 || exit 0
repo="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$repo" ] || exit 0
[ -f "$repo/bin/brain-embed" ] || exit 0
[ -f "$HOME/.config/brain.env" ] && . "$HOME/.config/brain.env"
[ -n "${GEMINI_API_KEY:-}" ] || exit 0
export GEMINI_API_KEY BRAIN_VAULT="$repo"
setsid sh -c "cd '$repo' && ./bin/brain-embed --changed" >>/tmp/brain-embed.log 2>&1 </dev/null &
exit 0
