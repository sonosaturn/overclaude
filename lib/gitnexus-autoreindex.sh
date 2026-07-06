#!/usr/bin/env sh
# Reindex del repo corrente con GitNexus dopo un commit. Detached: non blocca mai git.
# Primo commit in un repo nuovo -> analyze completo (autoimpianto). Commit successivi -> incrementale.
# Commit-driven: vale per ogni autore, inclusi i commit automatici di Claude (regole CLAUDE.md).
# ponytail: no-op silenzioso se gitnexus non e' nel PATH; un commit non deve MAI fallire per questo.
command -v gitnexus >/dev/null 2>&1 || exit 0
repo="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$repo" ] || exit 0
# --skip-agents-md: il grafo si aggiorna ma CLAUDE.md/AGENTS.md NON vengono riscritti,
# altrimenti ogni reindex sporcherebbe il working tree (feedback loop con l'autocommit).
setsid gitnexus analyze --skip-agents-md "$repo" >>/tmp/gitnexus-reindex.log 2>&1 </dev/null &
exit 0
