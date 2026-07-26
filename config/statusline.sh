#!/usr/bin/env sh
# Badge statusline dei plugin di modalità perenne (caveman, ponytail).
# Il path della cache plugin contiene la versione: risolto a runtime con un glob,
# così un bump del plugin non rompe la statusline. Gli script dei plugin stampano
# da soli il proprio badge.
cat >/dev/null 2>&1   # consuma il JSON che Claude Code passa su stdin
for p in "$HOME"/.claude/plugins/cache/*/*/*/hooks/*-statusline.sh \
         "$HOME"/.claude/plugins/cache/*/*/*/src/hooks/*-statusline.sh; do
  [ -f "$p" ] || continue
  sh "$p" </dev/null
  printf ' '
done
