# OverClaude

> **Claude on steroids** — una repo ready-to-go che auto-configura un Claude Code "nudo"
> in una setup avanzata: plugin di processo, code-intelligence, docs aggiornate, browser
> automation, prosa terse, design, discovery skill e un second-brain locale.

OverClaude non ri-ospita codice di terze parti: **orchestra** gli installer ufficiali di
ciascun componente (un solo `lib/components.manifest` da aggiornare) e impacchetta le parti
proprie (`brain`, `conversation-log`, hook di logging) come un plugin Claude Code servito
dalla marketplace di questa repo.

## Quickstart

```bash
git clone https://github.com/<you>/overclaude && cd overclaude
cp .env.example .env        # opzionale: inserisci le tue chiavi
sh install.sh               # Linux / macOS
sh install.sh --check       # verifica
```

Windows (PowerShell):

```powershell
git clone https://github.com/<you>/overclaude; cd overclaude
Copy-Item .env.example .env
./install.ps1
./install.ps1 -Check
```

L'installer è **idempotente**: ri-eseguirlo è sicuro e non distruttivo (il merge di
`settings.json` preserva le tue impostazioni locali).

### Anteprima senza modifiche

```bash
sh install.sh --dry-run     # stampa cosa farebbe, senza toccare nulla
```

## Cosa installa

Sorgente unica in [`lib/components.manifest`](lib/components.manifest). In sintesi:

| Componente | Ruolo |
|---|---|
| superpowers, ponytail | plugin di processo (brainstorm, TDD, debugging, lazy-mode) |
| gitnexus | code-intelligence (grafo, impact analysis) + 9 skill + hook |
| context7 (MCP) | documentazione aggiornata di librerie/SDK |
| playwright (MCP) | automazione browser reale (test E2E, screenshot) |
| caveman, grill-me | prosa terse · interrogatorio adversariale dei piani |
| impeccable | design language per UI |
| find-skills, skill-creator, handoff | discovery / autoring skill · handoff sessione |
| brain, conversation-log (plugin proprio) | second-brain `~/brain` + log curato delle conversazioni |

Tooling user-space installato a parte: `node`, `uv`, `markitdown`, `graphify`.

## Segreti

Nessuna chiave nella repo. Copia `.env.example` → `.env` (gitignorato) e inserisci le tue:

- `CONTEXT7_API_KEY` — opzionale (context7 ha un free tier).
- `GEMINI_API_KEY` + `GRAPHIFY_GEMINI_MODEL(S)` — per il grafo `graphify` del vault.

## Layer personale (opzionale)

La repo pubblica shippa solo uno **scaffold vuoto** del vault (`brain-scaffold/`). Per
ripristinare i TUOI dati (`~/brain`: conversazioni, wiki, memoria) su un nuovo dispositivo,
tienili in una repo/backup privati e sovrapponili:

```bash
sh install.sh --personal=/percorso/al/tuo/backup-brain
```

## Caveat Windows

L'hook SessionStart `new-session` esiste in due varianti (`new-session.sh` e
`new-session.ps1`). Su Windows nativo i SessionStart hook hanno avuto problemi noti in
Claude Code: se il log conversazioni non parte, esegui Claude Code sotto **WSL** (dove la
variante `.sh` funziona). Il resto della config è cross-platform.

## Test

```bash
sh tests/run.sh
```

Test in shell puro (nessun framework). La validazione di sintassi dei `.ps1` richiede `pwsh`
(altrimenti viene saltata con `SKIP`).

## Stato del progetto

Vedi [`docs/STATUS.md`](docs/STATUS.md) — task completati, follow-up aperti, note operative.
