#!/usr/bin/env bash
# SessionStart hook: creates a new conversation file and updates the .current-session marker.
# Recommended matcher: startup|resume|clear (NOT compact, so the running session is not split).
# The header written into the file stays in Italian: it is content of a private vault whose
# existing logs use that wording. To switch it to another language, change it here, in
# new-session.ps1, in log-session.py and in the conversation-log SKILL.md together — the skill
# documents the full list.
set -euo pipefail

dir="$HOME/brain/conversations"
mkdir -p "$dir"

ts="$(date +%d-%m-%y_%H-%M)"           # DD-MM-YY_HH-MM (filesystem-safe)
file="$dir/Conv_${ts}.md"

# Do not overwrite if a file for the same minute happens to exist already.
if [ ! -f "$file" ]; then
  {
    printf '# Conversazione %s\n\n' "$(date '+%d/%m/%Y %H:%M')"
    printf '> Log curato. Prompt utente: verbatim. Risposte Claude: riassunte, senza blocchi di codice.\n'
  } > "$file"
fi

# Marker: source of truth for the active file (survives context compaction).
printf '%s\n' "$file" > "$dir/.current-session"

# Context injection for Claude (a SessionStart hook's stdout enters the context).
printf 'ACTIVE CONVERSATION LOG: %s\n' "$file"
printf 'Update this file on every turn following the "conversation-log" skill: user prompts verbatim, your answers summarised without code blocks, always overwriting this same file.\n'
