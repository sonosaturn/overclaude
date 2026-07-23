#!/usr/bin/env bash
# Hook SessionStart: crea un nuovo file conversazione e aggiorna il marker .current-session.
# Matcher consigliato: startup|resume|clear (NON compact, per non spezzare la sessione in corso).
set -euo pipefail

dir="$HOME/brain/conversations"
mkdir -p "$dir"

ts="$(date +%d-%m-%y_%H-%M)"           # DD-MM-YY_HH-MM (filesystem-safe)
file="$dir/Conv_${ts}.md"

# Non sovrascrivere se per caso esiste già un file con lo stesso minuto.
if [ ! -f "$file" ]; then
  {
    printf '# Conversazione %s\n\n' "$(date '+%d/%m/%Y %H:%M')"
    printf '> Log curato. Prompt utente: verbatim. Risposte Claude: riassunte, senza blocchi di codice.\n'
  } > "$file"
fi

# Marker: fonte di verità del file attivo (resiste alla compattazione del contesto).
printf '%s\n' "$file" > "$dir/.current-session"

# Iniezione di contesto per Claude (stdout di un hook SessionStart entra nel contesto).
printf 'CONVERSATION LOG ATTIVO: %s\n' "$file"
printf 'Aggiorna questo file a ogni turno seguendo la skill "conversation-log": prompt utente verbatim, tue risposte riassunte senza blocchi di codice, sovrascrivendo sempre questo stesso file.\n'
