#!/usr/bin/env sh
# Reindexes the current repo with GitNexus after a commit. Detached: never blocks git.
# First commit in a new repo -> full analyze (self-implanting). Later commits -> incremental.
# Commit-driven: applies to every author, including Claude's automatic commits (CLAUDE.md rules).
# ponytail: silent no-op if gitnexus is not in PATH; a commit must NEVER fail because of this.
command -v gitnexus >/dev/null 2>&1 || exit 0
repo="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$repo" ] || exit 0
# --skip-agents-md: the graph is updated but CLAUDE.md/AGENTS.md are NOT rewritten, otherwise
# every reindex would dirty the working tree (feedback loop with the autocommit).
setsid gitnexus analyze --skip-agents-md "$repo" >>/tmp/gitnexus-reindex.log 2>&1 </dev/null &
exit 0
