# Contesto progetto — vault brain

Second-brain personale, pattern LLM-wiki. Struttura e convenzioni: `README.md` e `BRAIN.md`.

- `conversations/` — una "fotografia" markdown per sessione + `INDEX.md` (TOC). Le scrivono
  l'hook `SessionStart` del plugin overclaude e la skill `overclaude:conversation-log`:
  prompt utente **verbatim**, risposte **riassunte senza blocchi di codice**, sovrascrivendo
  il file della sessione corrente a ogni turno.
- `wiki/` — pagine markdown con cross-reference `[[...]]` per Obsidian.
- `claude-memory/` — auto-memory di Claude Code, symlinkata qui dall'installer.
- `bin/brain-recall` — recall semantico; fail-open su `rg` + `INDEX.md` se manca la key.

Ingest, query e lint del vault: skill `overclaude:brain`. Il **trigger** di recall dalle
altre sessioni sta nel `CLAUDE.md` globale, non qui: deve scattare da qualunque cartella.

## Commit automatico

**Committa automaticamente, senza chiedere conferma**, a ogni unità di lavoro conclusa nel
vault: ingest completato, set di pagine wiki, fix di uno script, lint applicato.
**Non a ogni turno e non a lavoro a metà — una milestone = un commit.**

```
cd ~/brain && git add -A && git commit -m "<tipo>: <descrizione chiara>"
```

`<tipo>` = feat | fix | docs | refactor | chore. Solo il vault, mai `git -C` su altri repo.
**Niente push automatico.**

## Cosa non entra nel vault

Chiavi API e segreti: stanno in `~/.config/brain.env`, che è fuori da qualsiasi repo.
Il vault è versionato, quindi tutto ciò che ci scrivi va considerato permanente.
