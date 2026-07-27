#!/usr/bin/env sh
# Regenerates the graphify semantic graph after a commit — ONLY in the brain vault. Detached: never blocks git.
# Commit-driven: the graph always keeps up with the vault (conversations, wiki, sources). Incremental:
# graphify only reprocesses changed files, so the per-commit cost is minimal after the first run.
# ponytail: silent no-op if this is not the vault, if graphify is missing, or if the Gemini key is missing;
# a commit must NEVER fail because of this. Ceiling: Gemini cost per commit; if it gets too high,
# add a debounce here (skip if the last run was < N minutes ago).
command -v graphify >/dev/null 2>&1 || exit 0
repo="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$repo" ] || exit 0
# "Is this the brain vault" guard: the graphify-run.sh wrapper only exists in the vault (the scaffold puts it there).
[ -f "$repo/bin/graphify-run.sh" ] || exit 0
# The hook runs in a minimal env: load the Gemini key from brain.env (graphify-run.sh does not source it itself).
[ -f "$HOME/.config/brain.env" ] && . "$HOME/.config/brain.env"
[ -n "${GEMINI_API_KEY:-}" ] || exit 0
export GEMINI_API_KEY
setsid sh "$repo/bin/graphify-run.sh" "$repo" >>/tmp/graphify-regen.log 2>&1 </dev/null &
exit 0
