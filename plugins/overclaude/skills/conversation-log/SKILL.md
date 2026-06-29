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

## Regole di contenuto (rigorose)
- **Prompt dell'utente**: copiati **VERBATIM**, senza modificare nulla.
- **Risposte di Claude**: **riassunte**, in forma sintetica.
  - **Nessun blocco di codice.** Per le modifiche ai file scrivere:
    `modifica su "<path>": <spiegazione>`. Per comandi: `eseguito <comando>: <esito>`.
  - Niente output lunghi: solo decisioni, azioni, esiti, file toccati.
- Lingua: italiano (come la conversazione).

## Formato
```
# Conversazione DD/MM/YYYY HH:MM

## HH:MM — Utente
<prompt verbatim>

## Claude
- <azione/decisione>
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
- [Conv_DD-MM-YY_HH-MM](Conv_DD-MM-YY_HH-MM.md) — DD/MM HH:MM · <temi sintetici, separati da ;> · *progetti:* <nomi>
```

Una riga per sessione, ordine cronologico. È la "superficie di ricerca": deve
bastare a decidere quali `Conv_*.md` aprire senza leggerli tutti. Niente code block.

## Note
- Commit del vault automatico per milestone (vedi `~/.claude/CLAUDE.md`): l'update
  di fine sessione di `INDEX.md` rientra nel commit della milestone corrente.
- Il marker `.current-session` non va versionato (vedi .gitignore del vault).
