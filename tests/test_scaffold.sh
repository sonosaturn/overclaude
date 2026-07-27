#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
s="$root/brain-scaffold"
[ -f "$s/BRAIN.md" ] || fail "no BRAIN.md"
for d in sources wiki conversations bin claude-memory .obsidian; do
  [ -d "$s/$d" ] || fail "missing dir $d"
done

# Recall leans on INDEX.md: without it the global CLAUDE.md points at a file that does not exist.
[ -f "$s/conversations/INDEX.md" ] || fail "no conversations/INDEX.md"
# claude-memory must exist or install.sh never creates the auto-memory symlink.
[ -f "$s/claude-memory/MEMORY.md" ] || fail "no claude-memory/MEMORY.md"
# Obsidian vault usable with no manual setup.
for f in app.json appearance.json core-plugins.json graph.json; do
  [ -f "$s/.obsidian/$f" ] || fail "missing .obsidian/$f"
done
# workspace.json is per-machine state: it must not be versioned.
[ -f "$s/.obsidian/workspace.json" ] && fail "workspace.json versionato"

# No private content: no real conversations, no real memories.
! ls "$s/conversations/"Conv_*.md >/dev/null 2>&1 || fail "scaffold leaks conversations"
[ "$(ls "$s/claude-memory" | wc -l)" -eq 1 ] || fail "scaffold leaks memories"
! grep -rIn '/home/xsaturn' "$s" || fail "absolute path in scaffold"
echo "PASS test_scaffold"
