---
name: conversation-log
description: >-
  Mantiene il log curato delle conversazioni in ~/brain/conversations (stile AutoBrain).
  Attivata automaticamente a ogni sessione dall'hook SessionStart, che crea il file e ne
  scrive il percorso in ~/brain/conversations/.current-session. Regole: salvare i prompt
  dell'utente VERBATIM e RIASSUMERE le risposte di Claude SENZA blocchi di codice,
  sovrascrivendo il file della sessione corrente a ogni turno.
---

# Skill: conversation-log

Registra le conversazioni nel vault, una "fotografia" aggiornata a ogni turno.

## File attivo
Il percorso del file della sessione corrente è in `~/brain/conversations/.current-session`
(lo crea l'hook SessionStart). **Leggere quel file** per sapere quale `Conv_*.md` aggiornare.
Se manca (es. prima sessione prima dell'hook), crearne uno: `Conv_<DD-MM-YY_HH-MM>.md`
con l'ora di inizio sessione, e scrivere il percorso nel marker.

## Quando aggiornare
A **ogni turno** (dopo aver risposto), **sovrascrivere** il file attivo con il log
aggiornato dall'inizio della sessione fino a ora. Stesso file per tutta la sessione;
un **nuovo file** nasce solo a una nuova sessione (lo fa l'hook).

## Marker `<!-- curated -->` (IMPORTANTE)
Quando scrivi il log seguendo questa skill, includi **sempre** la riga
`<!-- curated -->` subito dopo l'header (vedi Formato). È il segnale che il file è
curato dal modello e non va rigenerato da nessuno.

> Il marker è predisposto per un paracadute deterministico — un hook `Stop` che, se il
> marker manca, rigeneri il file dal transcript `.jsonl` — che **non è ancora incluso in
> questo plugin**. Finché non c'è, l'unica cosa che scrive il log sei tu: se salti un
> turno, quel turno non c'è. Scrivi il marker lo stesso, così il giorno in cui il
> paracadute arriva non deve rileggere sessioni già curate.

## Regole di contenuto (rigorose)
- **Prompt dell'utente**: copiati **VERBATIM**, senza modificare nulla.
- **Risposte di Claude**: **riassunte**, in forma sintetica.
  - **Nessun blocco di codice.** Per le modifiche ai file scrivere:
    `modifica su "<path>": <spiegazione>`. Per comandi: `eseguito <comando>: <esito>`.
  - Niente output lunghi: solo decisioni, azioni, esiti, file toccati.
- Lingua: italiano (come la conversazione).

## Wikilink `[[...]]` (per il grafo)
Le conversazioni devono diventare **nodi collegati** nel grafo (Obsidian/graphify),
non file orfani. Solo `[[wikilink]]` crea un edge; i link markdown `[testo](file.md)` no.
- **Riga `**Collegamenti:**`** in testa al file (dopo l'header): elenca i progetti e le
  entità ricorrenti toccate, ognuno come `[[nome]]`. Usa gli **stessi nomi** delle pagine
  wiki / dei progetti quando esistono (es. `[[ricing-hyprland]]`, `[[brain-KB]]`,
  `[[config-repo-pubblica]]`), così il nodo si risolve invece di restare "unresolved".
- Inline: alla **prima menzione** di un progetto o di una pagina wiki nel corpo, scrivilo
  come `[[nome]]`. Non wikilinkare ogni ripetizione — solo la prima, e solo concetti che
  meritano un nodo (progetti, temi, pagine wiki), non file di codice o comandi.
- Nomi coerenti e in kebab-case, uguali tra sessioni: due grafie diverse = due nodi diversi.

## Formato
```
# Conversazione DD/MM/YYYY HH:MM

> Log curato. Prompt utente: verbatim. Risposte Claude: riassunte, senza blocchi di codice.

<!-- curated -->

**Collegamenti:** [[progetto-1]] · [[tema-o-pagina-wiki]] · [[altro-progetto]]

## HH:MM — Utente
<prompt verbatim>

## Claude
- <azione/decisione, con [[progetto]] wikilinkato alla prima menzione>
- modifica su "percorso/file": <spiegazione>
- eseguito <comando>: <esito sintetico>

## HH:MM — Utente
...
```

## Indice per il recall (`INDEX.md`)
`~/brain/conversations/INDEX.md` è il TOC curato usato per il recall automatico
(vedi la regola in `~/.claude/CLAUDE.md`). **A fine sessione** (o quando i temi
sono ormai chiari) aggiungere/aggiornare la riga della sessione corrente:

```
- [Conv_DD-MM-YY_HH-MM](Conv_DD-MM-YY_HH-MM.md) — DD/MM HH:MM · <temi sintetici, separati da ;> · *progetti:* [[progetto-1]] [[progetto-2]]
```

Una riga per sessione, ordine cronologico. È la "superficie di ricerca": deve
bastare a decidere quali `Conv_*.md` aprire senza leggerli tutti. Niente code block.

## Note
- Commit del vault automatico per milestone (vedi `~/.claude/CLAUDE.md`): l'update
  di fine sessione di `INDEX.md` rientra nel commit della milestone corrente.
- Il marker `.current-session` non va versionato (vedi .gitignore del vault).
