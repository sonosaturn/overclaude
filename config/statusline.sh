#!/usr/bin/env sh
# Statusline badges for the always-on mode plugins (caveman, ponytail).
# The plugin cache path contains the version: resolved at runtime with a glob, so a plugin
# version bump does not break the statusline. The plugin scripts print their own badge.
cat >/dev/null 2>&1   # consume the JSON Claude Code passes on stdin
for p in "$HOME"/.claude/plugins/cache/*/*/*/hooks/*-statusline.sh \
         "$HOME"/.claude/plugins/cache/*/*/*/src/hooks/*-statusline.sh; do
  [ -f "$p" ] || continue
  sh "$p" </dev/null
  printf ' '
done
