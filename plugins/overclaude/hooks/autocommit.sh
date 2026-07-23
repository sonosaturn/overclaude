#!/usr/bin/env sh
# Stop hook: autocommit di QUALSIASI modifica al working tree di overclaude a fine turno.
# Gira a ogni Stop di Claude (in qualsiasi progetto) ma agisce SOLO sul repo overclaude
# (~/overclaude di default). Se il repo non è checkato out qui, no-op.
#
# .gitignore è l'unico filtro (.env e segreti restano fuori). Il "perché" del commit non è
# ricavabile qui → messaggio generico con la lista file. Push best-effort, mai bloccante.
#
# ponytail: messaggio generico + git add -A; se serve granularità, committa a mano prima del Stop.
set -eu
# Stesso default di bin/overclaude-sync.sh: i due hook devono guardare lo stesso repo.
REPO="${OVERCLAUDE_REPO:-$HOME/projects/overclaude}"
[ -d "$REPO/.git" ] || exit 0
cd "$REPO" || exit 0

# niente commit durante merge/rebase in corso (eviterebbe di sporcare uno stato a metà)
if [ -e "$REPO/.git/MERGE_HEAD" ] || [ -d "$REPO/.git/rebase-merge" ] || [ -d "$REPO/.git/rebase-apply" ]; then
  exit 0
fi

# nulla da committare?
[ -n "$(git status --porcelain)" ] || exit 0

files="$(git status --porcelain | sed 's/^...//' | tr '\n' ' ')"
git add -A >/dev/null 2>&1 || exit 0
git commit -q -m "chore: auto-sync overclaude working tree" -m "files: $files" >/dev/null 2>&1 || exit 0
GIT_TERMINAL_PROMPT=0 git push -q >/dev/null 2>&1 || true   # best-effort: nessun prompt, mai blocca
printf '{"systemMessage":"overclaude: working tree autocommittato → %s"}\n' "$files"
