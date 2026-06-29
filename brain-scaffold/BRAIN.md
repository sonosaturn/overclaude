# BRAIN — schema della knowledge base

> Questo file è lo **schema** del second brain: definisce struttura, convenzioni e
> workflow che l'LLM deve seguire per costruire e mantenere la wiki.
> Pattern di riferimento: "LLM-maintained wiki" di Karpathy
> (raw sources → wiki generata dall'LLM → schema). La parte buona di AutoBrain
> (vault Obsidian + ingest documenti), **senza** Jarvis/voce/webapp.

## Principio
L'LLM non si annoia: fa lui il lavoro tedioso di sintesi, cross-reference e
manutenzione. L'umano cura e interroga. Le risposte non si pescano ogni volta dai
documenti grezzi: si costruisce e si mantiene una **wiki strutturata** che sta in
mezzo tra l'utente e le fonti.

## Tre livelli
1. **`sources/`** — documenti grezzi e immutabili (PDF, md, txt convertiti). Non si modificano mai.
2. **`wiki/`** — pagine markdown generate dall'LLM: summary, pagine-entità, cross-reference `[[wikilink]]`.
3. **`BRAIN.md`** (questo file) — schema: regole di struttura e workflow.

File di navigazione obbligatori:
- **`index.md`** — catalogo di tutte le pagine wiki per categoria.
- **`log.md`** — registro cronologico di ingest e modifiche.

## Convenzioni delle pagine wiki
Ogni pagina in `wiki/` ha frontmatter:
```yaml
---
title: <Titolo leggibile>
aliases: [<sinonimi per Obsidian>]
tags: [<categoria>, <argomento>]
sources: [<file in sources/ o URL da cui deriva>]
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
```
- Nome file: `kebab-case.md`, descrittivo.
- Collegare le entità correlate con `[[nome-pagina]]` (genera il grafo in Obsidian).
- Un `[[link]]` a una pagina non ancora esistente è OK: segnala una pagina da creare.
- Citare sempre la fonte: `(fonte: sources/<file>)` o URL.
- Una pagina = un concetto/entità. Niente muri di testo: summary + sezioni + link.

## Workflow

### INGEST (aggiungere una fonte)
1. Convertire la fonte in markdown con **markitdown** se non lo è già:
   `markitdown <file> -o sources/<nome>.md` (PDF, DOCX, PPTX, XLSX, HTML, audio…).
   Le fonti già markdown si copiano in `sources/` così come sono.
2. Leggere la fonte, scrivere un summary e **aggiornare/creare** le pagine wiki
   pertinenti (tipicamente 5-15 file toccati per fonte), con cross-reference.
3. Aggiornare `index.md` (nuove pagine) e `log.md` (riga di ingest con data).
4. Una fonte alla volta: meglio incrementale e pulito.

### QUERY (interrogare)
1. Cercare nelle pagine wiki (`rg` su `wiki/`, oppure il grafo Obsidian).
2. Sintetizzare la risposta **con citazioni** alle pagine/fonti.
3. Se l'esplorazione produce valore nuovo, **archiviarla** come nuova pagina wiki.

### LINT (manutenzione periodica)
Controllo di salute della wiki:
- contraddizioni e affermazioni obsolete;
- pagine orfane (senza link in entrata);
- cross-reference mancanti;
- `index.md` allineato ai file reali in `wiki/`.
Registrare l'esito in `log.md`.

## Grafo (opzionale)
`~/brain/bin/graphify-run.sh .` dalla root genera un grafo interrogabile in
`graphify-out/` (ignorato da git) — vista d'insieme di entità e relazioni.
Il wrapper fa **fallback automatico** tra i modelli Gemini (`GRAPHIFY_GEMINI_MODELS`
in `~/.config/brain.env`) quando uno esaurisce la quota o è sovraccarico.

## Lingua
Contenuti in italiano salvo che la fonte imponga altro. Termini tecnici in inglese
quando è la forma standard.
