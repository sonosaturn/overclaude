#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
s="$root/brain-scaffold"
[ -f "$s/BRAIN.md" ] || fail "no BRAIN.md"
for d in sources wiki conversations bin claude-memory .obsidian; do
  [ -d "$s/$d" ] || fail "missing dir $d"
done

# Il recall poggia su INDEX.md: senza, il CLAUDE.md globale punta a un file inesistente.
[ -f "$s/conversations/INDEX.md" ] || fail "no conversations/INDEX.md"
# claude-memory deve esistere o install.sh non crea mai il symlink della auto-memory.
[ -f "$s/claude-memory/MEMORY.md" ] || fail "no claude-memory/MEMORY.md"
# Vault Obsidian usabile senza setup manuale.
for f in app.json appearance.json core-plugins.json graph.json; do
  [ -f "$s/.obsidian/$f" ] || fail "missing .obsidian/$f"
done
# workspace.json è stato per-macchina: non deve essere versionato.
[ -f "$s/.obsidian/workspace.json" ] && fail "workspace.json versionato"

# Niente contenuto privato: né conversazioni reali, né memorie reali.
! ls "$s/conversations/"Conv_*.md >/dev/null 2>&1 || fail "scaffold leaks conversations"
[ "$(ls "$s/claude-memory" | wc -l)" -eq 1 ] || fail "scaffold leaks memories"
! grep -rIn '/home/xsaturn' "$s" || fail "absolute path in scaffold"
echo "PASS test_scaffold"
