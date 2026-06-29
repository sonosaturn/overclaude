---
name: brain
description: >-
  Knowledge base personale (second brain) in ~/brain, pattern LLM-wiki. Usa questa
  skill quando l'utente vuole INGERIRE un documento/URL nella KB, INTERROGARE la
  knowledge base ("cosa so su X?", "cerca nel mio brain/wiki/second brain"), o fare
  il LINT/manutenzione del vault. Converte documenti con markitdown, mantiene pagine
  wiki markdown con cross-reference [[...]] per Obsidian, e può generare un grafo con
  graphify.
---

# Skill: brain

Gestisce la knowledge base in `~/brain`. **Leggere sempre prima `~/brain/BRAIN.md`**
(lo schema: struttura, convenzioni pagine, workflow). Questa skill è l'esecuzione
operativa di quei workflow.

Prerequisiti già installati: `markitdown` e `graphify` in `~/.local/bin`
(se non in PATH: `~/.local/bin/markitdown`).

## Riconoscere l'intento

- **INGEST** — "aggiungi/ingerisci <file|URL> nel brain", "salva questo nella KB".
- **QUERY** — "cosa so su X?", "cerca nel mio brain", "secondo la mia wiki…".
- **LINT** — "fai il lint/la manutenzione della KB", "controlla la wiki".

## INGEST

1. **Convertire la fonte in markdown** dentro `~/brain/sources/` (nome `kebab-case.md`):
   - file (PDF/DOCX/PPTX/XLSX/HTML/audio): `markitdown "<path>" -o ~/brain/sources/<nome>.md`
   - URL/HTML: `markitdown "<url>" -o ~/brain/sources/<nome>.md` (oppure WebFetch → salvare il markdown)
   - se già markdown/testo: copiarlo in `sources/` così com'è.
2. **Leggere** la fonte convertita.
3. **Aggiornare/creare le pagine wiki** in `~/brain/wiki/` pertinenti (tipicamente 5-15
   file): summary, pagine-entità, con frontmatter (vedi BRAIN.md) e cross-reference
   `[[...]]`. Citare sempre `(fonte: sources/<file>)`.
4. **Aggiornare `index.md`** (nuove pagine sotto la categoria giusta) e **`log.md`**
   (riga di ingest con data e fonte).
5. Una fonte alla volta. Al termine, riassumere all'utente cosa è stato creato/toccato.

## QUERY

1. Cercare nel vault: `rg -i "<termine>" ~/brain/wiki ~/brain/index.md` (e `sources/` se serve).
2. Leggere le pagine rilevanti e **sintetizzare con citazioni** alle pagine/fonti.
3. Se l'esplorazione produce conoscenza nuova e utile, **archiviarla** come nuova pagina
   wiki + aggiornare `index.md`/`log.md` (chiedere conferma se è un cambiamento grosso).

## LINT

Eseguire i controlli di `BRAIN.md` § LINT:
- pagine orfane: `rg -L` incrociando i `[[link]]` con i file in `wiki/`;
- `index.md` allineato ai file reali (`ls ~/brain/wiki`);
- contraddizioni/affermazioni obsolete (lettura mirata);
- cross-reference mancanti.
Riportare i problemi, proporre fix, registrare l'esito in `log.md`.

## Grafo (opzionale)
Usare il wrapper con **fallback automatico tra modelli Gemini** (quota/sovraccarico):
`~/brain/bin/graphify-run.sh .` → estrae il grafo in `graphify-out/`.
Poi `GRAPHIFY_GEMINI_MODEL=<modello-attivo> graphify cluster-only ~/brain` per
`graph.html` + `GRAPH_REPORT.md`. Richiede `GEMINI_API_KEY` (da `~/.config/brain.env`).

## Git
Il vault è un repo git. **Commit automatico per milestone** (regola in
`~/.claude/CLAUDE.md`): a ingest/lint completato, committare senza chiedere:
`cd ~/brain && git add -A && git commit -m "<tipo>: <descrizione>"`. Push manuale.
