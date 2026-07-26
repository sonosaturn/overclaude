# Windows — come trattare la config

Tutto quello che su Windows nativo (Git Bash + Claude Code, **senza WSL**) si comporta
diversamente. Ogni voce è stata riprodotta e corretta su una macchina reale
(Windows 11, luglio 2026), non è prudenza teorica.

Filo comune: gli script della repo girano sotto **Git Bash**, ma gli interpreti che
lanciano (`python`, `node`) sono **binari Windows nativi**. Le due metà non condividono
né i path né la codepage — è da lì che nasce quasi ogni problema qui sotto.

## 1. `python3` non esiste — e non fallisce, il che è peggio

Windows piazza in `%LOCALAPPDATA%\Microsoft\WindowsApps` degli **alias del Microsoft
Store**: `python3.exe` c'è, sta nel `PATH`, `command -v python3` lo trova. Eseguito,
stampa "Python non è stato trovato…" ed esce **49**.

Conseguenza: uno script che si limita a invocare `python3` non esplode, non logga —
semplicemente non fa niente. È così che l'hook `Stop` del logging conversazioni è
rimasto inerte per settimane senza un solo messaggio d'errore.

**Regola:** mai `python3` cablato. Sondare l'interprete e usare il primo che parte
davvero (`hooks/hooks.json` fa esattamente questo):

```sh
for p in python3 python py; do "$p" -c "" >/dev/null 2>&1 && exec "$p" "$1"; done
```

Il probe `-c ""` distingue l'interprete vero dall'alias: lo stub esce ≠ 0.
Vale anche dentro gli script (`uv run … python3 -c` ha lo stesso difetto: usare `python`,
che uv risolve correttamente su entrambe le piattaforme).

## 2. I path di Git Bash non sono i path di Python

`mktemp -d` restituisce `/tmp/tmp.XYZ`, che in Git Bash è
`C:\Users\<tu>\AppData\Local\Temp\tmp.XYZ`. Passato a un python nativo, quello stesso
`/tmp/tmp.XYZ` diventa `C:\tmp\tmp.XYZ`: una cartella diversa, che python crea al volo
senza lamentarsi. Risultato tipico: uno script scrive in una directory e un altro legge
in un'altra, entrambi "con successo".

**Regola:** ogni path che attraversa il confine shell → interprete nativo va convertito.

```sh
VAULT="$(mktemp -d)"
command -v cygpath >/dev/null 2>&1 && VAULT="$(cygpath -m "$VAULT")"
```

`cygpath -m` dà la forma `C:/…` (slash normali), digeribile sia da python che dalla shell.
Nell'altro verso, per passare un path a un `.exe` che vuole i backslash: `cygpath -w`.

## 3. Console in cp1252: l'output UTF-8 fa crashare gli script

Lo stdout di un processo python nella console Windows usa la codepage ANSI (cp1252 in
locale italiano). Stampare un carattere fuori tabella — `—`, `↔`, `…`, tutte cose che
abbondano in un vault markdown — solleva `UnicodeEncodeError` e **uccide lo script a metà
lavoro**.

**Regola:** in testa a ogni CLI che stampa contenuto non ASCII:

```python
for _s in (sys.stdout, sys.stderr):
    _s.reconfigure(encoding="utf-8", errors="replace")
```

Stesso discorso in lettura: `open()` senza `encoding=` usa la codepage, non UTF-8. I file
del vault e i transcript `.jsonl` vanno sempre aperti con `encoding="utf-8"` e, se il file
può essere stato toccato a mano, `errors="replace"` — un byte sporco non deve buttare giù
un hook.

## 4. Hook e plugin: l'aggiornamento passa dalla versione

Il plugin `overclaude` è servito da una marketplace di tipo `directory` che punta al clone
locale della repo. Claude Code però non legge i file dal vivo: al momento dell'install ne
fa una **copia** in `~/.claude/plugins/cache/overclaude/overclaude/<versione>/`. Modificare
i file nella repo non cambia nulla per le sessioni in corso né per quelle future.

Per pubblicare una modifica agli hook:

1. bump di `version` in `plugins/overclaude/.claude-plugin/plugin.json` (senza, l'update è
   un no-op: stessa versione, stessa cache);
2. `claude plugin marketplace update overclaude`
3. `claude plugin update overclaude@overclaude`
4. **riavviare** la sessione: gli hook si caricano all'avvio.

Verifica che la cache contenga davvero i file nuovi:

```sh
ls ~/.claude/plugins/cache/overclaude/overclaude/<versione>/hooks/
```

Un hook che manca dalla cache non dà errore: semplicemente non esiste. Se un
comportamento automatico "non parte", il primo controllo è questo, non il codice.

## 5. Statusline dei plugin di modalità

I badge `[PONYTAIL]`/`[CAVEMAN]` arrivano dagli script `*-statusline.ps1` dentro la cache
del plugin, il cui path contiene la versione. `config/statusline.ps1` li aggrega risolvendo
il path con un glob, così un bump del plugin non rompe la statusline. L'installer lo copia
in `~/.claude/statusline.ps1` e scrive il comando in `settings.json` — il path assoluto
nasce lì, non nella repo. `detect_os` riconosce Git Bash (`MINGW*`/`MSYS*`/`CYGWIN*`) e
sceglie la variante `.ps1`; altrove copia `statusline.sh`. Risultato in `settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\\Users\\<tu>\\.claude\\statusline.ps1\""
}
```

## 6. GitNexus

- L'estensione full-text (BM25) di LadybugDB non è nel pacchetto: la prima analisi avvisa
  che l'FTS è disabilitato. Si installa una volta, con rete:
  `GITNEXUS_LBUG_EXTENSION_INSTALL=auto gitnexus analyze --repair-fts`.
- L'indice `VECTOR` **non è disponibile su questa piattaforma**: la ricerca semantica
  ripiega su exact-scan (limite 10k chunk). Non è un errore da inseguire, `gitnexus doctor`
  lo riporta come tale.
- La cartella `.gitnexus/` (~5 MB) non va versionata.

## 7. Hook SessionStart

`new-session` esiste in due varianti (`.sh` e `.ps1`). Su questa macchina la variante
`.sh` sotto Git Bash **funziona** (il file `Conv_*.md` viene creato a ogni avvio); il
fallback WSL resta valido se nella tua installazione i SessionStart hook nativi non
scattano.

## In sintesi

| Sintomo | Causa |
|---|---|
| Un hook "non fa niente", nessun errore | `python3` → alias Store (§1) o file non presente nella cache del plugin (§4) |
| Due script lavorano su dati diversi | path MSYS non convertito (§2) |
| `UnicodeEncodeError` / `UnicodeDecodeError` | codepage cp1252 in lettura o scrittura (§3) |
| Modifica agli hook senza effetto | versione del plugin non bumpata, o sessione non riavviata (§4) |
