# OverClaude — Design Spec

> *"Claude on steroids."* Una repo GitHub ready-to-go che auto-configura un Claude Code
> "nudo" replicando una setup avanzata (plugin, skill, MCP, hook, automazioni).

- **Data:** 2026-06-29
- **Stato:** design approvato, in attesa di review utente → writing-plans
- **Slug repo:** `overclaude` · **Tagline:** "Claude on steroids"

---

## 1. Obiettivo e scope

Creare una repo pubblica che, eseguita su una macchina con Claude Code appena
installato, lo porta a una configurazione avanzata identica a quella di riferimento:
plugin di processo (superpowers/ponytail), code-intelligence (gitnexus), docs aggiornate
(context7), browser automation (playwright), prosa terse (caveman), design web (impeccable),
discovery skill (find-skills/skill-creator/grill-me/handoff) e un second-brain locale
(`brain` + `conversation-log`).

**Doppio scopo:**
1. **Condividere** la setup con chiunque (repo pubblica, nessun dato/segreto personale).
2. **Ri-configurarsi** su un nuovo dispositivo attingendo alla stessa repo.

**Non-obiettivi (YAGNI):**
- Non ri-ospitare codice di terze parti (si invocano gli installer ufficiali).
- Non includere dati personali (vault `~/brain`, memoria, chiavi).
- Non gestire orchestrazione runtime/agenti custom (lo fanno già i plugin esistenti).

## 2. Principio architetturale — Approccio C (plugin-nativo + bootstrap sottile)

Si sfrutta al massimo la macchina di plugin/MCP che Claude Code offre già; lo script
fa solo ciò che Claude Code non sa fare (dipendenze di sistema, MCP esterni, scaffold,
segreti). Due categorie di componenti, gestite diversamente:

### 2a. Terze parti → solo *registrate/invocate* (mai ricopiate)
Ognuna col proprio meccanismo ufficiale; la repo non ne ridistribuisce i file
(evita problemi di licenza e di staleness).

| Componente | Tipo | Comando di install |
|---|---|---|
| superpowers | plugin marketplace | `/plugin marketplace add obra/superpowers` + install |
| ponytail | plugin marketplace | `/plugin marketplace add DietrichGebert/ponytail` + install |
| caveman | installer proprio | `curl -fsSL .../install.sh \| bash` (Win: `install.ps1`) |
| grill-me + find-skills + skill-creator + handoff | `skills` CLI | `npx skills@latest add <repo>` |
| impeccable | installer proprio | `npx impeccable install` |
| context7 | MCP | `claude mcp add context7 -- npx -y @upstash/context7-mcp` |
| playwright | MCP | `claude mcp add playwright npx @playwright/mcp@latest` |
| gitnexus | npm global + setup | `npm i -g gitnexus` → `gitnexus setup` (genera MCP + 9 skill + hook) |

> Nota: le 9 skill gitnexus e gli hook `.cjs` NON sono mantenuti da noi → li rigenera
> `gitnexus setup`. Stesso principio per qualsiasi artefatto generato da un tool terzo.

### 2b. Componenti propri → impacchettati come **plugin Claude Code** nella marketplace della repo
Questi sono originali e vanno versionati qui:
- skill **`brain`** (second-brain LLM-wiki: ingest/query/lint)
- skill **`conversation-log`** (log curato delle conversazioni)
- hook **SessionStart `new-session`** (crea il file di sessione + inietta contesto)
- config da fondere: `settings.template.json`, `CLAUDE.md` template (generico), `rules/context7.md`

I path assoluti `/home/xsaturn/...` spariscono usando `${CLAUDE_PLUGIN_ROOT}` e `$HOME`.

## 3. Modello a due layer

- **`overclaude`** (questa repo, pubblica): tutto il generico/condivisibile.
- **`overclaude-personal`** (repo privata o backup dell'utente, opzionale): dati `~/brain`
  reali, `.env` con chiavi vere, aggiunte personali a `CLAUDE.md`. L'installer della base
  accetta `--personal <path|repo>` per sovrapporlo; il suo *contenuto* resta fuori dalla
  repo pubblica.

## 4. Struttura repo pubblica

```
overclaude/
├── README.md                       # overview + quickstart (1 comando)
├── install.sh                      # orchestratore POSIX (Linux/macOS)
├── install.ps1                     # orchestratore Windows (PowerShell)
├── lib/                            # helper condivisi
│   ├── detect-os.sh / .ps1         # OS + package manager (pacman/apt/dnf/brew/winget)
│   ├── merge-settings.*            # deep-merge non distruttivo di settings.json
│   └── components.manifest         # sorgente unica: elenco componenti + comandi + versioni note-buone
├── .claude-plugin/
│   └── marketplace.json            # rende la repo una marketplace Claude Code
├── plugins/overclaude/             # IL plugin proprio
│   ├── .claude-plugin/plugin.json
│   ├── skills/{brain,conversation-log}/SKILL.md
│   ├── hooks/
│   │   ├── hooks.json              # SessionStart → new-session (path via ${CLAUDE_PLUGIN_ROOT})
│   │   ├── new-session.sh          # variante POSIX
│   │   └── new-session.ps1         # variante Windows (o nota WSL)
│   └── commands/                   # (eventuali comandi)
├── config/
│   ├── settings.template.json      # hook/statusline/model/tema da fondere in ~/.claude
│   ├── CLAUDE.md.template          # istruzioni globali generiche (no ricing, no personale)
│   └── rules/context7.md
├── brain-scaffold/                 # vault VUOTO: BRAIN.md, sources/, wiki/, conversations/, .gitignore
├── .env.example                    # placeholder: CONTEXT7_API_KEY, GEMINI_API_KEY, GRAPHIFY_GEMINI_MODEL(S)
├── verify.sh / verify.ps1          # self-check post-install
└── docs/                           # questa spec + manifest leggibile
```

## 5. Flusso installer (idempotente, ri-eseguibile)

1. **Rileva OS + package manager**; installa runtime mancanti: `node`, `uv`, `git`, `ripgrep`.
2. **Tooling user-space**: `gitnexus` (npm -g, prefix utente), `markitdown` + `graphify` (uv tool).
3. **Terze parti** (sezione 2a): plugin marketplace, installer propri, `claude mcp add`, `gitnexus setup`.
   Tutto guidato da `lib/components.manifest` (un solo posto da aggiornare).
4. **Plugin proprio**: registra la repo come marketplace + install del plugin `overclaude`.
5. **Merge config**: deep-merge NON distruttivo di `settings.template.json` in `~/.claude/settings.json`
   (preserva impostazioni locali esistenti); copia `CLAUDE.md` template e `rules/` se assenti.
6. **Scaffold brain**: crea `~/brain` da `brain-scaffold/` se non esiste. Con `--personal`,
   sovrappone i dati personali.
7. **Segreti**: copia `.env.example`→`.env` se assente; chiede le chiavi o lascia i placeholder.
   Le chiavi vengono lette da env, **mai** scritte nella repo.
8. **Verifica** (sezione 7).

**Idempotenza:** ogni passo controlla lo stato prima di agire (componente già installato →
skip; settings già fuso → no-op). Ri-eseguire l'installer è sicuro.

## 6. Sicurezza & dati (vincoli non negoziabili)

- 🔴 **Nessun segreto nella repo**: `.env` gitignorato; solo `.env.example` con placeholder;
  `.credentials.json` mai incluso. La API key context7 attuale va revocata/rigenerata.
- 🟠 **Zero path assoluti**: `${CLAUDE_PLUGIN_ROOT}` (hook/plugin) e `$HOME` (script).
- 🟠 **Zero dati personali**: solo `brain-scaffold/` vuoto; i dati reali vivono nel layer 2.
- La statusline non punta più a un path versionato della cache plugin (fragile al bump):
  si usa il path del plugin ponytail risolto a runtime.

## 7. Verifica (`verify.sh` / `--check`)

Self-check minimo che riporta PASS/FAIL per: plugin attivi (superpowers/ponytail/overclaude),
MCP connessi (context7/gitnexus/playwright), hook SessionStart registrato, tooling nel PATH
(node/uv/gitnexus/markitdown/graphify), scaffold `~/brain` presente. È il segnale che
l'install ha funzionato davvero, non solo "è andato a buon fine".

## 8. Cross-platform — punti di attenzione noti

- `install.sh` (POSIX, Linux/macOS) + `install.ps1` (Windows). Logica condivisa via `lib/`.
- L'hook bash `new-session.sh` ha bisogno di una variante `new-session.ps1` (o nota WSL):
  è il punto più ballerino (i SessionStart hook su Windows hanno avuto bug noti in Claude Code).
- Gli hook gitnexus sono `.cjs` (node) → già cross-platform.
- Package manager per le dipendenze di sistema: pacman/apt/dnf/zypper (Linux), brew (macOS),
  winget/scoop (Windows).

## 9. Rischi & mitigazioni

| Rischio | Mitigazione |
|---|---|
| Installer terzi cambiano comando/URL | `lib/components.manifest` come unico punto di verità; pin versioni note-buone |
| SessionStart hook rotto su Windows | variante `.ps1` + fallback documentato (WSL); il log brain degrada con grazia |
| `gitnexus setup` modifica `~/.claude` in conflitto col merge | eseguire gitnexus setup PRIMA del merge dei nostri settings, poi deep-merge |
| Utente ri-esegue e perde settings locali | merge non distruttivo, mai overwrite cieco |

## 10. Criteri di successo

- Su una VM pulita (Linux), un comando porta Claude Code alla setup completa, verificata da `verify.sh`.
- Nessun segreto o dato personale nella history git della repo pubblica.
- L'utente può ri-configurarsi su nuovo dispositivo con `install.sh --personal <suo-backup>`.
- Aggiungere/rimuovere un componente = una riga in `components.manifest`.
