# OverClaude — Stato del progetto

Ultimo aggiornamento: 2026-07-26

## Aggiornamento 2026-07-26 (b) — repo in pari con la config live

Passata inversa rispetto al solito: non "installa ciò che manca sulla macchina", ma
"porta nella repo ciò che la macchina ha in più". Delta trovato e chiuso:

- **`rtk`** (rtk-ai/rtk) era l'unico componente della config live assente dal manifest.
  Aggiunto come `cmd` idempotente (installa solo se manca, poi `rtk init -g --auto-patch`,
  che si scrive da sé l'hook `PreToolUse`). Con lui `config/RTK.md`, che il `CLAUDE.md`
  globale include via `@RTK.md`, copiato in `~/.claude` dall'installer.
- **Statusline**: `config/statusline.ps1` (+ gemello `statusline.sh` per POSIX) e lo step
  che lo installa e scrive `statusLine` in `settings.json`. Il path assoluto lo produce
  l'installer, la repo resta senza path cablati.
- **`CLAUDE.md.template`**: assorbito il preambolo che viveva solo in locale (Behavioral
  Guidelines + sezione rtk). 199 righe, al limite delle ~200 dichiarate nel template stesso.
- `settings.template.json`: `autoUpdatesChannel: latest`.
- `detect_os` riconosce Git Bash (`MINGW*`/`MSYS*`/`CYGWIN*`) → `windows`, usato per
  scegliere la variante di statusline.
- `install.ps1` allineato sui punti che gli mancavano del tutto: `rules/`, `RTK.md`,
  `CLAUDE.md` se assente, statusline, flag `.caveman-active`/`.ponytail-active`.
  **Restano fuori** (lag noto, l'install su questa macchina passa da Git Bash):
  `~/.config/brain.env`, symlink della auto-memoria, script in `~/.local/bin` e template
  git per l'auto-reindex.
- `verify.sh`: check di `rtk`, `RTK.md` e statusline. `test_ps_syntax` ora usa anche
  `powershell` 5.1 quando manca `pwsh` → i `.ps1` sono validati per la prima volta.

## Aggiornamento 2026-07-26 (a) — Windows nativo: tre fallimenti silenziosi

Sessione di allineamento macchina ↔ repo su Windows 11 + Git Bash. Tutti e tre i bug
trovati avevano lo stesso profilo: **nessun errore visibile, funzione semplicemente
inerte**. Documentati in [`docs/WINDOWS.md`](WINDOWS.md).

- **Hook `Stop` del log conversazioni mai eseguito** → i `Conv_*.md` di luglio erano stub
  vuoti. Tre cause sommate: (a) `python3` su Windows è l'alias Microsoft Store, presente nel
  `PATH`, che esce 49 senza eseguire; (b) il plugin installato era la 0.1.0, precedente
  all'aggiunta di `log-session.py`, e la versione non era mai stata bumpata → `plugin update`
  no-op; (c) `log-session.py` chiamava `build()` *dentro* `open(conv_file, "w")`, che tronca il
  file prima che l'header venga riletto → data/ora della sessione persa a ogni rigenerazione.
  Corretti: probe dell'interprete in `hooks.json`, versione plugin a **0.2.0**, `build()`
  prima della `open`, letture con `encoding="utf-8", errors="replace"`.
- **`brain-recall` crashava in stampa** (`UnicodeEncodeError`, console cp1252 vs `↔`/`—`):
  `reconfigure(encoding="utf-8", errors="replace")` su stdout/stderr.
- **Self-check del vault falso-negativo**: `uv run … python3 -c` (alias Store) e vault di
  test in un path MSYS `/tmp/...` che python nativo legge come `C:\tmp\...` → embed e count
  su directory diverse. Corretti con `python` e `cygpath -m`.
- `mattpocock/skills` passa a pacchetto intero nel manifest; `config/skills.expected`
  rigenerato (69 skill) → `install.sh --check` **ALL CHECKS PASSED**.
- GitNexus: estensione FTS installata (`GITNEXUS_LBUG_EXTENSION_INSTALL=auto … --repair-fts`),
  BM25 attivo. `VECTOR` resta non disponibile su Windows (exact-scan).

## Aggiornamento 2026-07-06 — allineamento alla config live

Sincronizzata la repo con la config Claude Code effettivamente in uso:

- **Fix `skills-cli` dispatcher** (`lib/run-component.sh`): `npx skills add <repo>` installa
  l'**intero** repo (verificato dal vivo: `mattpocock/skills` → 38 skill). Aggiunto
  `--skill $name --agent claude --global --yes` così installa **solo** la skill nominata.
- **Bundle `context7-mcp`** nel plugin proprio (`plugins/overclaude/skills/context7-mcp/`):
  è una skill companion custom senza upstream, come brain/conversation-log.
- **Exa** documentato nel README come connector lato account claude.ai (non scriptabile).
- playwright/grill-me/caveman erano già nel manifest → confermati come default voluti e
  installati anche in locale (macchina e manifest ora combaciano).
- **Auto-sync** (`bin/overclaude-sync.sh`): hook PostToolUse(Bash) del **maintainer** che,
  quando aggiunge una skill (`npx skills … add <repo> --skill <name>`) o un MCP
  (`claude mcp add <name> -- <cmd>`), appende la riga al manifest, committa e **pusha** in
  automatico → la repo resta al passo con la config live. Cablato nel `settings.json`
  personale (gitignore, non nella repo pubblica). Ceiling: solo skill/MCP via i comandi
  Bash standard; plugin e add interattivi/da terminale utente → sync a mano.

## Stato: BUILD COMPLETA ✅

Tutti i 12 task del [piano](superpowers/plans/2026-06-29-overclaude.md) implementati,
testati e mergiati su `master`. Suite shell verde (10 pass, 1 skip per assenza `pwsh`).

| # | Task | Commit | Stato |
|---|------|--------|-------|
| 1 | Repo skeleton + manifests | `2c959ce` | ✅ |
| 2 | Bundle skill brain + conversation-log | `24adc78`, `2f7535e` | ✅ |
| 3 | Hook SessionStart new-session (sh + ps1) | `185da7d` | ✅ |
| 4 | Scaffold brain vuoto | `97f7e09` | ✅ |
| 5 | Config template + .env.example | `299a1ff` | ✅ |
| 6 | lib/detect-os | `725562d` | ✅ |
| 7 | lib/merge-settings (non distruttivo) | `0a982dc` | ✅ |
| 8 | components.manifest + dispatcher | `579da66` | ✅ |
| 9 | install.sh (POSIX) | `96aee1b` | ✅ |
| 10 | verify.sh | `40c0ce7` | ✅ |
| 11 | install.ps1 + verify.ps1 (Windows) | `42fce88` | ⚠️ vedi sotto |
| 12 | README + test runner | `79d22e0` | ✅ |

## Modalità di esecuzione
Task 1-2 eseguiti subagent-driven (review su sonnet, approvati). Dal Task 3 i subagent
hanno colpito il limite di sessione → esecuzione inline (codice preso dal piano, ogni test
eseguito, commit per task).

## Bug del piano corretti in corsa
- Test manifest: `NF!=3` → `NF<3` (la riga `caveman` contiene `| bash`; l'arg può avere pipe).
- Test dispatch: `read` senza newline finale ritornava 1 sotto `set -e` → aggiunto `\n`.

## Gate di sicurezza (pre-pubblicazione) — superato
Zero path assoluti, zero chiavi, zero symlink, `.env` non tracciato, scaffold con solo
schema + placeholder vuoti, `~/.claude/settings.json` viva intatta dopo il dry-run.

## Follow-up aperti
- [x] ~~⚠️ `install.ps1` / `verify.ps1`: sintassi NON validata~~ — validati il 2026-07-26 su Windows reale: `test_ps_syntax` ripiega su `powershell` 5.1 quando `pwsh` non c'è, e passa. Resta il lag funzionale di `install.ps1` (vedi aggiornamento 26/07 b).
- [x] ~~Confermare i sottocomandi CLI esatti~~ — verificato con `claude plugin --help` (2026-06-29): `claude plugin marketplace add <source>` e `claude plugin install <plugin>@<marketplace>` sono corretti così come in `lib/run-component.sh`.
- [x] ~~Caveat Windows hook SessionStart~~ — verificato su Windows 11 nativo (2026-07-26): la variante `.sh` sotto Git Bash **funziona**, il `Conv_*.md` viene creato a ogni avvio. Il fallback WSL resta documentato per installazioni dove i SessionStart nativi non scattano. Caveat reali di Windows raccolti in [`docs/WINDOWS.md`](WINDOWS.md).
- [x] ~~Nessun git remote~~ — repo pubblica creata e pushata (2026-06-29): https://github.com/sonosaturn/overclaude
- [x] ~~Layer 2 personale (`overclaude-personal`)~~ — creato (2026-06-29): `~/brain` reale pushato su repo GitHub **privata** `sonosaturn/overclaude-personal`. Round-trip verificato (clone → `install.sh --personal=<clone>` → `WOULD OVERLAY`). La auto-memoria è inclusa: la dir live `~/.claude/projects/<home>/memory/` è un symlink a `~/brain/claude-memory/` (single source of truth, versionata col vault); `install.sh --personal` ricrea il symlink dopo l'overlay (step 6b). Test dry-run copre l'annuncio `WOULD LINK`.

## Note operative
- Key context7 ruotata il 2026-06-29 (la vecchia era stata esposta in chat; rigenerata).
- `.env` locale popolato (context7 + Gemini), gitignorato.
- Il ledger SDD vive in `.superpowers/` (gitignorato): non fa parte del repo pubblico.
