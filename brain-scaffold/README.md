# brain — second brain / knowledge base

Knowledge base personale in markdown, mantenuta dall'LLM (pattern *LLM-wiki*).
Vault Obsidian + ingest documenti via **markitdown** + grafo via **graphify**.

## Le cartelle

| Cartella | Cosa contiene |
|---|---|
| `sources/` | Fonti grezze, immutabili. Ciò che ingerisci finisce qui e non si tocca più. |
| `wiki/` | Pagine generate: entità, sintesi, cross-reference `[[...]]`. Qui si scrive. |
| `conversations/` | Una "fotografia" markdown per sessione + `INDEX.md`, il TOC su cui si regge il recall. |
| `claude-memory/` | Auto-memory di Claude Code, symlinkata qui dall'installer per essere versionata. |
| `bin/` | Tooling del vault: `brain-recall` (recall semantico), `brain-embed`, `graphify-run.sh`. |
| `graphify-out/` | Output del grafo. Rigenerabile, quindi non versionato. |

`BRAIN.md` descrive schema e workflow: leggerlo prima di scrivere nel vault.

## Uso con Claude Code

La skill `overclaude:brain` implementa i flussi:

- "ingerisci `<file>` nella KB" → INGEST
- "cosa so su `<X>`?" → QUERY
- "fai il lint della KB" → LINT

Il log delle conversazioni lo tiene `overclaude:conversation-log`, attivata dall'hook
`SessionStart` del plugin, che crea il file della sessione e ne scrive il percorso in
`conversations/.current-session`.

## Aprire in Obsidian

*Open folder as vault* → questa cartella. La configurazione in `.obsidian/` è già inclusa
(tema, plugin core, impostazioni della graph view), quindi il vault è utilizzabile senza
setup: la graph view mostra i `[[wikilink]]` fra le pagine e fra le conversazioni.

`workspace.json` non è versionato di proposito: è lo stato dei pannelli aperti, cambia a
ogni uso e vale solo per la macchina su cui è stato scritto.

## Recall semantico

`bin/brain-recall "<query>"` cerca per significato, non per stringa, e serve alle
parafrasi che `rg` non prende. Richiede `GEMINI_API_KEY` in `~/.config/brain.env`
(mai in `settings.json`: quel file vive dentro un repo). Senza chiave o senza indice
degrada su `rg` + `INDEX.md` invece di fallire.
