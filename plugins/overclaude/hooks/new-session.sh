#!/usr/bin/env bash
set -euo pipefail
dir="$HOME/brain/conversations"
mkdir -p "$dir"
ts="$(date +%d-%m-%y_%H-%M)"
file="$dir/Conv_${ts}.md"
if [ ! -f "$file" ]; then
  {
    printf '# Conversazione %s\n\n' "$(date '+%d/%m/%Y %H:%M')"
    printf '> Log curato. Prompt utente: verbatim. Risposte Claude: riassunte, senza blocchi di codice.\n'
  } > "$file"
fi
printf '%s\n' "$file" > "$dir/.current-session"
printf 'CONVERSATION LOG ATTIVO: %s\n' "$file"
printf 'Aggiorna questo file a ogni turno seguendo la skill "conversation-log": prompt utente verbatim, tue risposte riassunte senza blocchi di codice, sovrascrivendo sempre questo stesso file.\n'
