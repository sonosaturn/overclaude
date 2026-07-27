#!/usr/bin/env sh
# Stop hook: autocommits ANY change to overclaude's working tree at the end of a turn.
# Runs on every Claude Stop (in any project) but acts ONLY on the overclaude repo
# (~/overclaude by default). If the repo is not checked out here, no-op.
#
# .gitignore is the only filter (.env and secrets stay out). The "why" of the commit cannot be
# derived here → generic message with the file list. Best-effort push, never blocking.
#
# ponytail: generic message + git add -A; if you need granularity, commit by hand before the Stop.
set -eu
# Same default as bin/overclaude-sync.sh: the two hooks must watch the same repo.
REPO="${OVERCLAUDE_REPO:-$HOME/projects/overclaude}"
[ -d "$REPO/.git" ] || exit 0
cd "$REPO" || exit 0

# no commits during an in-flight merge/rebase (it would dirty a half-finished state)
if [ -e "$REPO/.git/MERGE_HEAD" ] || [ -d "$REPO/.git/rebase-merge" ] || [ -d "$REPO/.git/rebase-apply" ]; then
  exit 0
fi

# nothing to commit?
[ -n "$(git status --porcelain)" ] || exit 0

files="$(git status --porcelain | sed 's/^...//' | tr '\n' ' ')"
git add -A >/dev/null 2>&1 || exit 0
git commit -q -m "chore: auto-sync overclaude working tree" -m "files: $files" >/dev/null 2>&1 || exit 0
GIT_TERMINAL_PROMPT=0 git push -q >/dev/null 2>&1 || true   # best-effort: no prompt, never blocks
printf '{"systemMessage":"overclaude: working tree autocommitted → %s"}\n' "$files"
